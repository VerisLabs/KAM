// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { MultiFacetProxy } from "kam/src/base/MultiFacetProxy.sol";
import { OptimizedAddressEnumerableSetLib } from "solady/utils/EnumerableSetLib/OptimizedAddressEnumerableSetLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { kBaseRoles } from "kam/src/base/kBaseRoles.sol";
import {
    KREGISTRY_ADAPTER_ALREADY_SET,
    KREGISTRY_ALREADY_REGISTERED,
    KREGISTRY_ASSET_NOT_SUPPORTED,
    KREGISTRY_FEE_EXCEEDS_MAXIMUM,
    KREGISTRY_INVALID_ADAPTER,
    KREGISTRY_TRANSFER_FAILED,
    KREGISTRY_WRONG_ASSET,
    KREGISTRY_ZERO_ADDRESS,
    KREGISTRY_ZERO_AMOUNT
} from "kam/src/errors/Errors.sol";

import { IRegistry } from "kam/src/interfaces/IRegistry.sol";
import { IVersioned } from "kam/src/interfaces/IVersioned.sol";
import { kToken } from "kam/src/kToken.sol";

/// @title kRegistry
/// @notice Central configuration hub and contract registry for the KAM protocol ecosystem
/// @dev This contract serves as the protocol's backbone for configuration management and access control. It provides
/// five critical functions: (1) Singleton contract management - registers and tracks core protocol contracts like
/// kMinter and kAssetRouter ensuring single source of truth, (2) Asset and kToken management - handles asset
/// whitelisting, kToken deployment, and maintains bidirectional mappings between underlying assets and their
/// corresponding kTokens, (3) Vault registry - manages vault registration, classification (DN, ALPHA, BETA, etc.),
/// and routing logic to direct assets to appropriate vaults based on type and strategy, (4) Role-based access
/// control - implements a hierarchical permission system with ADMIN, EMERGENCY_ADMIN, GUARDIAN, RELAYER, INSTITUTION,
/// and VENDOR roles to enforce protocol security, (5) Adapter management - registers and tracks external protocol
/// adapters per vault enabling yield strategy integrations. The registry uses upgradeable architecture with UUPS
/// pattern and ERC-7201 namespaced storage to ensure future extensibility while maintaining state consistency.
contract kRegistry is IRegistry, kBaseRoles, Initializable, UUPSUpgradeable, MultiFacetProxy {
    using OptimizedAddressEnumerableSetLib for OptimizedAddressEnumerableSetLib.AddressSet;
    using SafeTransferLib for address;

    /* //////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice kMinter key
    bytes32 public constant K_MINTER = keccak256("K_MINTER");

    /// @notice kAssetRouter key
    bytes32 public constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /// @notice USDC key
    bytes32 public constant USDC = keccak256("USDC");

    /// @notice WBTC key
    bytes32 public constant WBTC = keccak256("WBTC");

    /// @notice Maximum basis points (100%)
    uint256 constant MAX_BPS = 10_000;

    /* //////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Core storage structure for kRegistry using ERC-7201 namespaced storage pattern
    /// @dev This structure maintains all protocol configuration state including contracts, assets, vaults, and
    /// permissions.
    /// Uses the diamond storage pattern to prevent storage collisions in upgradeable contracts.
    /// @custom:storage-location erc7201:kam.storage.kRegistry
    struct kRegistryStorage {
        /// @dev Set of all protocol-supported underlying assets (e.g., USDC, WBTC)
        /// Used to validate assets before operations and maintain a whitelist
        OptimizedAddressEnumerableSetLib.AddressSet supportedAssets;
        /// @dev Set of all registered vault contracts across all types
        /// Enables iteration and validation of vault registrations
        OptimizedAddressEnumerableSetLib.AddressSet allVaults;
        /// @dev Protocol treasury address for fee collection and reserves
        /// Receives protocol fees and serves as emergency fund holder
        address treasury;
        /// @dev Maps assets to their maximum mint amount per batch
        mapping(address => uint256) maxMintPerBatch;
        /// @dev Maps assets to their maximum redeem amount per batch
        mapping(address => uint256) maxBurnPerBatch;
        /// @dev Maps singleton contract identifiers to their deployed addresses
        mapping(bytes32 => address) singletonContracts;
        /// @dev Maps vault addresses to their type classification (DN, ALPHA, BETA, etc.)
        /// Used for routing and strategy selection based on vault type
        mapping(address => uint8 vaultType) vaultType;
        /// @dev Nested mapping: asset => vaultType => vault address for routing logic
        /// Enables efficient lookup of the primary vault for an asset-type combination
        mapping(address => mapping(uint8 vaultType => address)) assetToVault;
        /// @dev Maps vault addresses to sets of assets they manage
        /// Supports multi-asset vaults (e.g., kMinter managing multiple assets)
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAsset;
        /// @dev Reverse lookup: maps assets to all vaults that support them
        /// Enables finding all vaults that can handle a specific asset
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultsByAsset;
        /// @dev Maps underlying asset addresses to their corresponding kToken addresses
        /// Critical for minting/redemption operations and asset tracking
        mapping(address => address) assetToKToken;
        /// @dev Maps vaults to their registered external protocol adapters
        /// Enables yield strategies through DeFi protocol integrations
        mapping(address => mapping(address => address)) vaultAdaptersByAsset;
        /// @dev Tracks whether an adapter address is registered in the protocol
        /// Used for validation and security checks on adapter operations
        mapping(address => bool) registeredAdapters;
        /// @dev Maps assets to their hurdle rates in basis points (100 = 1%)
        /// Defines minimum performance thresholds for yield distribution
        mapping(address => uint16) assetHurdleRate;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KREGISTRY_STORAGE_LOCATION =
        0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;

    /// @notice Retrieves the kRegistry storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The kRegistryStorage struct reference for state modifications
    function _getkRegistryStorage() private pure returns (kRegistryStorage storage $) {
        assembly {
            $.slot := KREGISTRY_STORAGE_LOCATION
        }
    }

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kRegistry contract
    /// @param owner_ Contract owner address
    /// @param admin_ Admin role recipient
    /// @param emergencyAdmin_ Emergency admin role recipient
    /// @param guardian_ Guardian role recipient
    /// @param relayer_ Relayer role recipient
    /// @param treasury_ Treasury address
    function initialize(
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address guardian_,
        address relayer_,
        address treasury_
    )
        external
        initializer
    {
        _checkAddressNotZero(owner_);
        _checkAddressNotZero(admin_);
        _checkAddressNotZero(emergencyAdmin_);
        _checkAddressNotZero(guardian_);
        _checkAddressNotZero(relayer_);
        _checkAddressNotZero(treasury_);

        __kBaseRoles_init(owner_, admin_, emergencyAdmin_, guardian_, relayer_);

        _getkRegistryStorage().treasury = treasury_;
    }

    /* //////////////////////////////////////////////////////////////
                          SINGLETON MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function setSingletonContract(bytes32 id, address contractAddress) external payable {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(contractAddress);
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.singletonContracts[id] == address(0), KREGISTRY_ALREADY_REGISTERED);
        $.singletonContracts[id] = contractAddress;
        emit SingletonContractSet(id, contractAddress);
    }

    /* //////////////////////////////////////////////////////////////
                          ROLES MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function grantInstitutionRole(address institution_) external payable {
        _checkVendor(msg.sender);
        _grantRoles(institution_, INSTITUTION_ROLE);
    }

    /// @inheritdoc IRegistry
    function grantVendorRole(address vendor_) external payable {
        _checkAdmin(msg.sender);
        _grantRoles(vendor_, VENDOR_ROLE);
    }

    /// @inheritdoc IRegistry
    function grantRelayerRole(address relayer_) external payable {
        _checkAdmin(msg.sender);
        _grantRoles(relayer_, RELAYER_ROLE);
    }

    /// @inheritdoc IRegistry
    function grantManagerRole(address manager_) external payable {
        _checkAdmin(msg.sender);
        _grantRoles(manager_, MANAGER_ROLE);
    }

    /// @inheritdoc IRegistry
    function setTreasury(address treasury_) external payable {
        _checkAdmin(msg.sender);
        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkAddressNotZero(treasury_);
        $.treasury = treasury_;
        emit TreasurySet(treasury_);
    }

    /// @inheritdoc IRegistry
    function setHurdleRate(address asset, uint16 hurdleRate) external payable {
        // Only relayer can set hurdle rates (performance thresholds)
        _checkRelayer(msg.sender);
        // Ensure hurdle rate doesn't exceed 100% (10,000 basis points)
        require(hurdleRate <= MAX_BPS, KREGISTRY_FEE_EXCEEDS_MAXIMUM);

        kRegistryStorage storage $ = _getkRegistryStorage();
        // Asset must be registered before setting hurdle rate
        _checkAssetRegistered(asset);

        // Set minimum performance threshold for yield distribution
        $.assetHurdleRate[asset] = hurdleRate;
        emit HurdleRateSet(asset, hurdleRate);
    }

    /// @inheritdoc IRegistry
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(to_);

        if (asset_ == address(0)) {
            // Rescue ETH
            require(amount_ != 0 && amount_ <= address(this).balance, KREGISTRY_ZERO_AMOUNT);

            (bool success,) = to_.call{ value: amount_ }("");
            require(success, KREGISTRY_TRANSFER_FAILED);

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            _checkAssetNotRegistered(asset_);
            require(amount_ != 0 && amount_ <= asset_.balanceOf(address(this)), KREGISTRY_ZERO_AMOUNT);

            asset_.safeTransfer(to_, amount_);
            emit RescuedAssets(asset_, to_, amount_);
        }
    }

    /* //////////////////////////////////////////////////////////////
                          ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function setAssetBatchLimits(address asset_, uint256 maxMintPerBatch_, uint256 maxBurnPerBatch_) external payable {
        _checkAdmin(msg.sender);

        kRegistryStorage storage $ = _getkRegistryStorage();
        $.maxMintPerBatch[asset_] = maxMintPerBatch_;
        $.maxBurnPerBatch[asset_] = maxBurnPerBatch_;
    }

    /// @inheritdoc IRegistry
    function registerAsset(
        string memory name_,
        string memory symbol_,
        address asset,
        bytes32 id,
        uint256 maxMintPerBatch,
        uint256 maxBurnPerBatch
    )
        external
        payable
        returns (address)
    {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(asset);
        require(id != bytes32(0), KREGISTRY_ZERO_ADDRESS);

        kRegistryStorage storage $ = _getkRegistryStorage();
        // Ensure asset isn't already in the protocol
        _checkAssetNotRegistered(asset);

        // Add to supported assets and create named reference
        $.supportedAssets.add(asset);
        emit AssetSupported(asset);

        // Get kMinter address for granting mint permissions
        address minter_ = getContractById(K_MINTER);
        _checkAddressNotZero(minter_);

        // Extract decimals from underlying asset for kToken consistency
        (bool success, uint8 decimals_) = _tryGetAssetDecimals(asset);
        require(success, KREGISTRY_WRONG_ASSET);

        // Ensure no kToken exists for this asset yet
        address kToken_ = $.assetToKToken[asset];
        _checkAssetNotRegistered(kToken_);

        // Deploy new kToken with matching decimals and grant minter privileges
        kToken_ = address(
            new kToken(
                owner(),
                msg.sender, // admin gets initial control
                msg.sender, // emergency admin for safety
                minter_, // kMinter gets minting rights
                name_,
                symbol_,
                decimals_ // matches underlying for consistency
            )
        );

        $.maxMintPerBatch[asset] = maxMintPerBatch;
        $.maxBurnPerBatch[asset] = maxBurnPerBatch;

        // Register kToken
        $.assetToKToken[asset] = kToken_;
        emit AssetRegistered(asset, kToken_);

        emit KTokenDeployed(kToken_, name_, symbol_, decimals_);

        return kToken_;
    }

    /* //////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function registerVault(address vault, VaultType type_, address asset) external payable {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(vault);

        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkAssetRegistered(asset);

        // Associate vault with the asset it manages
        $.vaultAsset[vault].add(asset);

        // Set as primary vault for this asset-type combination
        $.assetToVault[asset][uint8(type_)] = vault;

        // Enable reverse lookup: find all vaults for an asset
        $.vaultsByAsset[asset].add(vault);

        address kMinter_ = $.singletonContracts[K_MINTER];
        if (kMinter_ == vault && $.allVaults.contains(kMinter_)) return;

        // Classify vault by type for routing logic
        $.vaultType[vault] = uint8(type_);

        require(!$.allVaults.contains(vault), KREGISTRY_ALREADY_REGISTERED);
        $.allVaults.add(vault);

        emit VaultRegistered(vault, asset, type_);
    }

    /// @inheritdoc IRegistry
    function removeVault(address vault) external payable {
        _checkAdmin(msg.sender);
        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkVaultRegistered(vault);
        $.allVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    /* //////////////////////////////////////////////////////////////
                          ADAPTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function registerAdapter(address vault, address asset, address adapter) external payable {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(vault);
        require(adapter != address(0), KREGISTRY_INVALID_ADAPTER);

        kRegistryStorage storage $ = _getkRegistryStorage();

        // Ensure vault exists in protocol before adding adapter
        if ($.singletonContracts[K_MINTER] != vault) _checkVaultRegistered(vault);

        require($.vaultAdaptersByAsset[vault][asset] == address(0), KREGISTRY_ADAPTER_ALREADY_SET);

        // Register adapter for external protocol integration
        $.vaultAdaptersByAsset[vault][asset] = adapter;

        emit AdapterRegistered(vault, asset, adapter);
    }

    /// @inheritdoc IRegistry
    function removeAdapter(address vault, address asset, address adapter) external payable {
        _checkAdmin(msg.sender);
        kRegistryStorage storage $ = _getkRegistryStorage();

        require($.vaultAdaptersByAsset[vault][asset] == adapter, KREGISTRY_INVALID_ADAPTER);
        delete $.vaultAdaptersByAsset[vault][asset];

        emit AdapterRemoved(vault, asset, adapter);
    }

    /* //////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IRegistry
    function getMaxMintPerBatch(address asset) external view returns (uint256) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.maxMintPerBatch[asset];
    }

    /// @inheritdoc IRegistry
    function getMaxBurnPerBatch(address asset) external view returns (uint256) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.maxBurnPerBatch[asset];
    }

    /// @notice Gets the hurdle rate for a specific asset
    /// @param asset The asset address
    /// @return The hurdle rate in basis points
    function getHurdleRate(address asset) external view returns (uint16) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkAssetRegistered(asset);
        return $.assetHurdleRate[asset];
    }

    /// @inheritdoc IRegistry
    function getContractById(bytes32 id) public view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonContracts[id];
        _checkAddressNotZero(addr);
        return addr;
    }

    /// @inheritdoc IRegistry
    function getAllAssets() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.supportedAssets.length() > 0, KREGISTRY_ZERO_ADDRESS);
        return $.supportedAssets.values();
    }

    /// @inheritdoc IRegistry
    function getAllVaults() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.allVaults.length() > 0, KREGISTRY_ZERO_ADDRESS);
        return $.allVaults.values();
    }

    /// @inheritdoc IRegistry
    function getTreasury() external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.treasury;
    }

    /// @inheritdoc IRegistry
    function getCoreContracts() external view returns (address, address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address kMinter_ = $.singletonContracts[K_MINTER];
        address kAssetRouter_ = $.singletonContracts[K_ASSET_ROUTER];
        _checkAddressNotZero(kMinter_);
        _checkAddressNotZero(kAssetRouter_);
        return (kMinter_, kAssetRouter_);
    }

    /// @inheritdoc IRegistry
    function getVaultsByAsset(address asset) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.vaultsByAsset[asset].values().length > 0, KREGISTRY_ZERO_ADDRESS);
        return $.vaultsByAsset[asset].values();
    }

    /// @inheritdoc IRegistry
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address assetToVault = $.assetToVault[asset][vaultType];
        _checkAddressNotZero(assetToVault);
        return assetToVault;
    }

    /// @inheritdoc IRegistry
    function getVaultType(address vault) external view returns (uint8) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultType[vault];
    }

    /// @inheritdoc IRegistry
    function isAdmin(address user) external view returns (bool) {
        return _hasRole(user, ADMIN_ROLE);
    }

    /// @inheritdoc IRegistry
    function isEmergencyAdmin(address user) external view returns (bool) {
        return _hasRole(user, EMERGENCY_ADMIN_ROLE);
    }

    /// @inheritdoc IRegistry
    function isGuardian(address user) external view returns (bool) {
        return _hasRole(user, GUARDIAN_ROLE);
    }

    /// @inheritdoc IRegistry
    function isRelayer(address user) external view returns (bool) {
        return _hasRole(user, RELAYER_ROLE);
    }

    /// @inheritdoc IRegistry
    function isInstitution(address user) external view returns (bool) {
        return _hasRole(user, INSTITUTION_ROLE);
    }

    /// @inheritdoc IRegistry
    function isVendor(address user) external view returns (bool) {
        return _hasRole(user, VENDOR_ROLE);
    }

    /// @inheritdoc IRegistry
    function isManager(address user) external view returns (bool) {
        return _hasRole(user, MANAGER_ROLE);
    }

    /// @inheritdoc IRegistry
    function isAsset(address asset) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.supportedAssets.contains(asset);
    }

    /// @inheritdoc IRegistry
    function isVault(address vault) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.allVaults.contains(vault);
    }

    /// @inheritdoc IRegistry
    function getAdapter(address vault, address asset) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address adapter = $.vaultAdaptersByAsset[vault][asset];
        _checkAddressNotZero(adapter);
        return adapter;
    }

    /// @inheritdoc IRegistry
    function isAdapterRegistered(address vault, address asset, address adapter) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultAdaptersByAsset[vault][asset] == adapter;
    }

    /// @inheritdoc IRegistry
    function getVaultAssets(address vault) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.vaultAsset[vault].values().length > 0, KREGISTRY_ZERO_ADDRESS);
        return $.vaultAsset[vault].values();
    }

    /// @inheritdoc IRegistry
    function assetToKToken(address asset) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address assetToToken_ = $.assetToKToken[asset];
        require(assetToToken_ != address(0), KREGISTRY_ZERO_ADDRESS);
        return assetToToken_;
    }

    /// @notice Validates that an asset is not already registered in the protocol
    /// @dev Reverts with KREGISTRY_ALREADY_REGISTERED if the asset exists in supportedAssets set.
    /// Used to prevent duplicate registrations and maintain protocol integrity.
    /// @param asset The asset address to validate
    function _checkAssetNotRegistered(address asset) private view {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require(!$.supportedAssets.contains(asset), KREGISTRY_ALREADY_REGISTERED);
    }

    /// @notice Validates that an asset is registered in the protocol
    /// @dev Reverts with KREGISTRY_ASSET_NOT_SUPPORTED if the asset doesn't exist in supportedAssets set.
    /// Used to ensure operations only occur on whitelisted assets.
    /// @param asset The asset address to validate
    function _checkAssetRegistered(address asset) private view {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.supportedAssets.contains(asset), KREGISTRY_ASSET_NOT_SUPPORTED);
    }

    /// @notice Validates that a vault is registered in the protocol
    /// @dev Reverts with KREGISTRY_ASSET_NOT_SUPPORTED if the vault doesn't exist in allVaults set.
    /// Used to ensure operations only occur on registered vaults. Note: error message could be improved.
    /// @param vault The vault address to validate
    function _checkVaultRegistered(address vault) private view {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.allVaults.contains(vault), KREGISTRY_ASSET_NOT_SUPPORTED);
    }

    /// @dev Helper function to get the decimals of the underlying asset.
    /// Useful for setting the return value of `_underlyingDecimals` during initialization.
    /// If the retrieval succeeds, `success` will be true, and `result` will hold the result.
    /// Otherwise, `success` will be false, and `result` will be zero.
    ///
    /// Example usage:
    /// ```
    /// (bool success, uint8 result) = _tryGetAssetDecimals(underlying);
    /// _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
    /// ```
    function _tryGetAssetDecimals(address underlying) internal view returns (bool success, uint8 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector of `decimals()`.
            mstore(0x00, 0x313ce567)
            // Arguments are evaluated last to first.
            success := and(
                // Returned value is less than 256, at left-padded to 32 bytes.
                and(lt(mload(0x00), 0x100), gt(returndatasize(), 0x1f)),
                // The staticcall succeeds.
                staticcall(gas(), underlying, 0x1c, 0x04, 0x00, 0x20)
            )
            result := mul(mload(0x00), success)
        }
    }

    /* //////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @param newImplementation New implementation address
    /// @dev Only callable by contract owner
    function _authorizeUpgrade(address newImplementation) internal view override {
        _checkOwner();
        require(newImplementation != address(0), KREGISTRY_ZERO_ADDRESS);
    }

    /* //////////////////////////////////////////////////////////////
                        FUNCTIONS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize function modification
    /// @dev This allows modifying functions while keeping modules separate
    function _authorizeModifyFunctions(address) internal view override {
        _checkOwner();
    }

    /* //////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to receive ETH transfers
    /// @dev Allows the contract to receive ETH for gas refunds, donations, or accidental transfers.
    /// Received ETH can be rescued using the rescueAssets function with address(0).
    receive() external payable { }

    /* //////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVersioned
    function contractName() external pure returns (string memory) {
        return "kRegistry";
    }

    /// @inheritdoc IVersioned
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
