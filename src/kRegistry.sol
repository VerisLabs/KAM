// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OptimizedOwnableRoles } from "src/libraries/OptimizedOwnableRoles.sol";

import { OptimizedAddressEnumerableSetLib } from "src/libraries/OptimizedAddressEnumerableSetLib.sol";
import { Initializable } from "src/vendor/Initializable.sol";

import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";

import {
    KREGISTRY_ADAPTER_ALREADY_SET,
    KREGISTRY_ALREADY_REGISTERED,
    KREGISTRY_ASSET_NOT_SUPPORTED,
    KREGISTRY_FEE_EXCEEDS_MAXIMUM,
    KREGISTRY_INVALID_ADAPTER,
    KREGISTRY_TRANSFER_FAILED,
    KREGISTRY_WRONG_ASSET,
    KREGISTRY_WRONG_ROLE,
    KREGISTRY_ZERO_ADDRESS,
    KREGISTRY_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { kToken } from "src/kToken.sol";

/// @title kRegistry
/// @notice Central registry for KAM protocol contracts
/// @dev Manages singleton contracts, vault registration, asset support, and kToken mapping
contract kRegistry is IkRegistry, Initializable, UUPSUpgradeable, OptimizedOwnableRoles {
    using OptimizedAddressEnumerableSetLib for OptimizedAddressEnumerableSetLib.AddressSet;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin role for authorized operations
    uint256 internal constant ADMIN_ROLE = _ROLE_0;

    /// @notice Emergency admin role for emergency operations
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /// @notice Guardian role as a circuit breaker for settlement proposals
    uint256 internal constant GUARDIAN_ROLE = _ROLE_2;

    /// @notice Relayer role for external vaults
    uint256 internal constant RELAYER_ROLE = _ROLE_3;

    /// @notice Reserved role for special whitelisted addresses
    uint256 internal constant INSTITUTION_ROLE = _ROLE_4;

    /// @notice Vendor role for vendor vaults
    uint256 internal constant VENDOR_ROLE = _ROLE_5;

    /*//////////////////////////////////////////////////////////////
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

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kRegistry
    struct kRegistryStorage {
        OptimizedAddressEnumerableSetLib.AddressSet supportedAssets;
        OptimizedAddressEnumerableSetLib.AddressSet allVaults;
        address treasury;
        mapping(bytes32 => address) singletonContracts;
        mapping(address => uint8 vaultType) vaultType;
        mapping(address => mapping(uint8 vaultType => address)) assetToVault;
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAsset; // kMinter will have > 1 assets
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultsByAsset;
        mapping(bytes32 => address) singletonAssets;
        mapping(address => address) assetToKToken;
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAdapters; // vault => adapter
        mapping(address => bool) registeredAdapters; // adapter => registered
        mapping(address => uint16) assetHurdleRate; // asset => hurdle rate
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KREGISTRY_STORAGE_LOCATION =
        0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;

    /// @dev Returns the kRegistry storage pointer
    function _getkRegistryStorage() private pure returns (kRegistryStorage storage $) {
        assembly {
            $.slot := KREGISTRY_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
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
        require(owner_ != address(0), KREGISTRY_ZERO_ADDRESS);
        require(admin_ != address(0), KREGISTRY_ZERO_ADDRESS);
        require(emergencyAdmin_ != address(0), KREGISTRY_ZERO_ADDRESS);
        require(guardian_ != address(0), KREGISTRY_ZERO_ADDRESS);
        require(relayer_ != address(0), KREGISTRY_ZERO_ADDRESS);

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(admin_, VENDOR_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(guardian_, GUARDIAN_ROLE);
        _grantRoles(relayer_, RELAYER_ROLE);
        _getkRegistryStorage().treasury = treasury_;
    }

    /*//////////////////////////////////////////////////////////////
                                RESCUER
    //////////////////////////////////////////////////////////////*/

    /// @notice rescues locked assets (ETH or ERC20) in the contract
    /// @param asset_ the asset to rescue (use address(0) for ETH)
    /// @param to_ the address that will receive the assets
    /// @param amount_ the amount to rescue
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        require(to_ != address(0), KREGISTRY_ZERO_ADDRESS);

        if (asset_ == address(0)) {
            // Rescue ETH
            require(amount_ != 0 && amount_ <= address(this).balance, KREGISTRY_ZERO_AMOUNT);

            (bool success,) = to_.call{ value: amount_ }("");
            require(success, KREGISTRY_TRANSFER_FAILED);

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            kRegistryStorage storage $ = _getkRegistryStorage();
            require(!$.supportedAssets.contains(asset_), KREGISTRY_WRONG_ASSET);
            require(amount_ != 0 && amount_ <= asset_.balanceOf(address(this)), KREGISTRY_ZERO_AMOUNT);

            asset_.safeTransfer(to_, amount_);
            emit RescuedAssets(asset_, to_, amount_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          SINGLETON MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Set a singleton contract address
    /// @param id Contract identifier (e.g., K_MINTER, K_BATCH)
    /// @param contractAddress Address of the singleton contract
    /// @dev Only callable by ADMIN_ROLE
    function setSingletonContract(bytes32 id, address contractAddress) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        require(contractAddress != address(0), KREGISTRY_ZERO_ADDRESS);
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.singletonContracts[id] == address(0), KREGISTRY_ALREADY_REGISTERED);
        $.singletonContracts[id] = contractAddress;
        emit SingletonContractSet(id, contractAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          ROLES MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice grant the institution role to a given address
    /// @param institution_ the institution address
    /// @dev Only callable by VENDOR_ROLE
    function grantInstitutionRole(address institution_) external payable {
        require(_hasRole(msg.sender, VENDOR_ROLE), KREGISTRY_WRONG_ROLE);
        _grantRoles(institution_, INSTITUTION_ROLE);
    }

    /// @notice grant the vendor role to a given address
    /// @param vendor_ the vendor address
    /// @dev Only callable by ADMIN_ROLE
    function grantVendorRole(address vendor_) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        _grantRoles(vendor_, VENDOR_ROLE);
    }

    /// @notice grant the relayer role to a given address
    /// @param relayer_ the relayer address
    /// @dev Only callable by ADMIN_ROLE
    function grantRelayerRole(address relayer_) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        _grantRoles(relayer_, RELAYER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                          ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Register support for a new asset and its corresponding kToken
    /// @param asset Underlying asset address (e.g., USDC, WBTC)
    /// @dev Only callable by ADMIN_ROLE, establishes bidirectional mapping
    function registerAsset(
        string memory name_,
        string memory symbol_,
        address asset,
        bytes32 id
    )
        external
        payable
        returns (address)
    {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        require(asset != address(0), KREGISTRY_ZERO_ADDRESS);
        require(id != bytes32(0), KREGISTRY_ZERO_ADDRESS);

        kRegistryStorage storage $ = _getkRegistryStorage();
        require(!$.supportedAssets.contains(asset), KREGISTRY_ALREADY_REGISTERED);

        $.supportedAssets.add(asset);
        $.singletonAssets[id] = asset;
        emit AssetSupported(asset);

        address minter_ = getContractById(K_MINTER);
        require(minter_ != address(0), KREGISTRY_ZERO_ADDRESS);

        (bool success, uint8 decimals_) = _tryGetAssetDecimals(asset);
        if (!success) revert();

        address kToken_ = $.assetToKToken[asset];
        require(kToken_ == address(0), KREGISTRY_ALREADY_REGISTERED);

        kToken_ = address(
            new kToken(
                owner(),
                msg.sender,
                msg.sender, // adjust emergencyAdmin and metadata
                minter_,
                name_,
                symbol_,
                decimals_
            )
        );

        // Register kToken
        $.assetToKToken[asset] = kToken_;
        emit AssetRegistered(asset, kToken_);

        emit KTokenDeployed(kToken_, name_, symbol_, decimals_);

        return kToken_;
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a new vault in the protocol
    /// @param vault Vault contract address
    /// @param type_ Type of vault (MINTER, DN, ALPHA, BETA)
    /// @param asset Underlying asset the vault manages
    /// @dev Only callable by ADMIN_ROLE, sets as primary if first of its type
    function registerVault(address vault, VaultType type_, address asset) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        require(vault != address(0), KREGISTRY_ZERO_ADDRESS);
        kRegistryStorage storage $ = _getkRegistryStorage();
        require(!$.allVaults.contains(vault), KREGISTRY_ALREADY_REGISTERED);
        require($.supportedAssets.contains(asset), KREGISTRY_ASSET_NOT_SUPPORTED);

        // Register vault
        $.vaultType[vault] = uint8(type_);
        $.vaultAsset[vault].add(asset);
        $.allVaults.add(vault);
        $.assetToVault[asset][uint8(type_)] = vault;

        // Track by asset
        $.vaultsByAsset[asset].add(vault);

        emit VaultRegistered(vault, asset, type_);
    }

    function removeVault(address vault) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.allVaults.contains(vault), KREGISTRY_ASSET_NOT_SUPPORTED);
        $.allVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    /*//////////////////////////////////////////////////////////////
                          ROLES MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the treasury address
    /// @param treasury_ The new treasury address
    function setTreasury(address treasury_) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        kRegistryStorage storage $ = _getkRegistryStorage();
        require(treasury_ != address(0), KREGISTRY_ZERO_ADDRESS);
        $.treasury = treasury_;
        emit TreasurySet(treasury_);
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers an adapter for a specific vault
    /// @param vault The vault address
    /// @param adapter The adapter address
    function registerAdapter(address vault, address adapter) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        require(vault != address(0) && adapter != address(0), KREGISTRY_INVALID_ADAPTER);

        kRegistryStorage storage $ = _getkRegistryStorage();

        // Validate vault is registered
        require($.allVaults.contains(vault), KREGISTRY_ASSET_NOT_SUPPORTED); // Reuse error

        // Check if adapter is already set for this vault
        require(!$.vaultAdapters[vault].contains(address(0)), KREGISTRY_ADAPTER_ALREADY_SET);

        $.vaultAdapters[vault].add(adapter);

        emit AdapterRegistered(vault, adapter);
    }

    /// @notice Removes an adapter for a specific vault
    /// @param vault The vault address
    function removeAdapter(address vault, address adapter) external payable {
        require(_hasRole(msg.sender, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
        kRegistryStorage storage $ = _getkRegistryStorage();

        require($.vaultAdapters[vault].contains(adapter), KREGISTRY_INVALID_ADAPTER);
        $.vaultAdapters[vault].remove(adapter);

        emit AdapterRemoved(vault, adapter);
    }

    /*//////////////////////////////////////////////////////////////
                      HURDLE RATE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the hurdle rate for a specific asset
    /// @param asset The asset address
    /// @param hurdleRate The hurdle rate in basis points
    function setHurdleRate(address asset, uint16 hurdleRate) external payable {
        require(_hasRole(msg.sender, RELAYER_ROLE), KREGISTRY_WRONG_ROLE);
        require(hurdleRate <= MAX_BPS, KREGISTRY_FEE_EXCEEDS_MAXIMUM);

        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.supportedAssets.contains(asset), KREGISTRY_ASSET_NOT_SUPPORTED);

        $.assetHurdleRate[asset] = hurdleRate;
        emit HurdleRateSet(asset, hurdleRate);
    }

    /// @notice Gets the hurdle rate for a specific asset
    /// @param asset The asset address
    /// @return The hurdle rate in basis points
    function getHurdleRate(address asset) external view returns (uint16) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.supportedAssets.contains(asset), KREGISTRY_ASSET_NOT_SUPPORTED);
        return $.assetHurdleRate[asset];
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get a singleton contract address by its identifier
    /// @param id Contract identifier (e.g., K_MINTER, K_BATCH)
    /// @return Contract address
    /// @dev Reverts if contract not set
    function getContractById(bytes32 id) public view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonContracts[id];
        require(addr != address(0), KREGISTRY_ZERO_ADDRESS);
        return addr;
    }

    /// @notice Get a singleton asset address by its identifier
    /// @param id Asset identifier (e.g., USDC, WBTC)
    /// @return Asset address
    /// @dev Reverts if asset not set
    function getAssetById(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonAssets[id];
        require(addr != address(0), KREGISTRY_ZERO_ADDRESS);
        return addr;
    }

    /// @notice Get all supported assets
    /// @return Array of supported asset addresses
    function getAllAssets() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.supportedAssets.length() > 0, KREGISTRY_ZERO_ADDRESS);
        return $.supportedAssets.values();
    }

    /// @notice Get all vaults registered in the protocol
    /// @return Array of vault addresses
    function getAllVaults() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.allVaults.length() > 0, KREGISTRY_ZERO_ADDRESS);
        return $.allVaults.values();
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the treasury address
    /// @return The treasury address
    function getTreasury() external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.treasury;
    }

    /// @notice Get all core singleton contracts at once
    /// @return kMinter The kMinter contract address
    /// @return kAssetRouter The kAssetRouter contract address
    function getCoreContracts() external view returns (address, address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address kMinter_ = $.singletonContracts[K_MINTER];
        address kAssetRouter_ = $.singletonContracts[K_ASSET_ROUTER];
        require(kMinter_ != address(0) && kAssetRouter_ != address(0), KREGISTRY_ZERO_ADDRESS);
        return (kMinter_, kAssetRouter_);
    }

    /// @notice Get all vaults registered for a specific asset
    /// @param asset Asset address to query
    /// @return Array of vault addresses
    function getVaultsByAsset(address asset) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.vaultsByAsset[asset].values().length > 0, KREGISTRY_ZERO_ADDRESS);
        return $.vaultsByAsset[asset].values();
    }

    /// @notice Get a vault address by asset and vault type
    /// @param asset Asset address
    /// @param vaultType Vault type
    /// @return Vault address
    /// @dev Reverts if vault not found
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address assetToVault = $.assetToVault[asset][vaultType];
        require(assetToVault != address(0), KREGISTRY_ZERO_ADDRESS);
        return assetToVault;
    }

    /// @notice Get the type of a vault
    /// @param vault Vault address
    /// @return Vault type
    function getVaultType(address vault) external view returns (uint8) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultType[vault];
    }

    /// @notice Check if caller is the Admin
    /// @return Whether the caller is a Admin
    function isAdmin(address user) external view returns (bool) {
        return _hasRole(user, ADMIN_ROLE);
    }

    /// @notice Check if caller is the EmergencyAdmin
    /// @return Whether the caller is a EmergencyAdmin
    function isEmergencyAdmin(address user) external view returns (bool) {
        return _hasRole(user, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Check if caller is the Guardian
    /// @return Whether the caller is a Guardian
    function isGuardian(address user) external view returns (bool) {
        return _hasRole(user, GUARDIAN_ROLE);
    }

    /// @notice Check if the caller is the relayer
    /// @return Whether the caller is the relayer
    function isRelayer(address user) external view returns (bool) {
        return _hasRole(user, RELAYER_ROLE);
    }

    /// @notice Check if the caller is a institution
    /// @return Whether the caller is a institution
    function isInstitution(address user) external view returns (bool) {
        return _hasRole(user, INSTITUTION_ROLE);
    }

    /// @notice Check if the caller is a vendor
    /// @return Whether the caller is a vendor
    function isVendor(address user) external view returns (bool) {
        return _hasRole(user, VENDOR_ROLE);
    }

    /// @notice Check if an asset is supported
    /// @param asset Asset address
    /// @return Whether the asset is supported
    function isAsset(address asset) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.supportedAssets.contains(asset);
    }

    /// @notice Check if a vault is registered
    /// @param vault Vault address
    /// @return Whether the vault is registered
    function isVault(address vault) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.allVaults.contains(vault);
    }

    /// @notice Get the adapter for a specific vault
    /// @param vault Vault address
    /// @return Adapter address (address(0) if none set)
    function getAdapters(address vault) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.vaultAdapters[vault].values().length > 0, KREGISTRY_ZERO_ADDRESS);
        return $.vaultAdapters[vault].values();
    }

    /// @notice Check if an adapter is registered
    /// @param adapter Adapter address
    /// @return True if adapter is registered
    function isAdapterRegistered(address vault, address adapter) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultAdapters[vault].contains(adapter);
    }

    /// @notice Get the asset for a specific vault
    /// @param vault Vault address
    /// @return Asset address that the vault manages
    function getVaultAssets(address vault) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.vaultAsset[vault].values().length > 0, KREGISTRY_ZERO_ADDRESS);
        return $.vaultAsset[vault].values();
    }

    /// @notice Get the kToken for a specific asset
    /// @param asset Asset address
    /// @return KToken address
    function assetToKToken(address asset) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address assetToToken_ = $.assetToKToken[asset];
        require(assetToToken_ != address(0), KREGISTRY_ZERO_ADDRESS);
        return assetToToken_;
    }

    /// @notice check if the user has the given role
    /// @return Wether the caller have the given role
    function _hasRole(address user, uint256 role_) internal view returns (bool) {
        return hasAnyRole(user, role_);
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
            success :=
                and(
                    // Returned value is less than 256, at left-padded to 32 bytes.
                    and(lt(mload(0x00), 0x100), gt(returndatasize(), 0x1f)),
                    // The staticcall succeeds.
                    staticcall(gas(), underlying, 0x1c, 0x04, 0x00, 0x20)
                )
            result := mul(mload(0x00), success)
        }
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @param newImplementation New implementation address
    /// @dev Only callable by contract owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        require(newImplementation != address(0), KREGISTRY_ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive ETH (for gas refunds, etc.)
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kRegistry";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
