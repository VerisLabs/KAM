// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { kToken } from "src/kToken.sol";

/// @title kRegistry
/// @notice Central registry for KAM protocol contracts
/// @dev Manages singleton contracts, vault registration, asset support, and kToken mapping
contract kRegistry is IkRegistry, Initializable, UUPSUpgradeable, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 internal constant GUARDIAN_ROLE = _ROLE_2;
    uint256 internal constant RELAYER_ROLE = _ROLE_3;
    uint256 internal constant INSTITUTION_ROLE = _ROLE_4;
    uint256 internal constant VENDOR_ROLE = _ROLE_5;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Singleton contracts (only one instance in the protocol)
    bytes32 public constant K_MINTER = keccak256("K_MINTER");
    bytes32 public constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    // Singleton Assets - We might add more following the same pattern
    bytes32 public constant USDC = keccak256("USDC");
    bytes32 public constant WBTC = keccak256("WBTC");

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kRegistry
    struct kRegistryStorage {
        EnumerableSetLib.AddressSet supportedAssets;
        EnumerableSetLib.AddressSet allVaults;
        address treasury;
        mapping(bytes32 => address) singletonContracts;
        mapping(address => uint8 vaultType) vaultType;
        mapping(address => mapping(uint8 vaultType => address)) assetToVault;
        mapping(address => EnumerableSetLib.AddressSet) vaultAsset; // kMinter will have > 1 assets
        mapping(address => EnumerableSetLib.AddressSet) vaultsByAsset;
        mapping(bytes32 => address) singletonAssets;
        mapping(address => address) assetToKToken;
        mapping(address => EnumerableSetLib.AddressSet) vaultAdapters; // vault => adapter
        mapping(address => bool) registeredAdapters; // adapter => registered
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KREGISTRY_STORAGE_LOCATION =
        0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;

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
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();
        if (guardian_ == address(0)) revert ZeroAddress();
        if (relayer_ == address(0)) revert ZeroAddress();
        if (treasury_ == address(0)) revert ZeroAddress();

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
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        if (to_ == address(0)) revert ZeroAddress();

        if (asset_ == address(0)) {
            // Rescue ETH
            if (amount_ == 0 || amount_ > address(this).balance) revert ZeroAmount();

            (bool success,) = to_.call{ value: amount_ }("");
            if (!success) revert TransferFailed();

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            kRegistryStorage storage $ = _getkRegistryStorage();
            if ($.supportedAssets.contains(asset_)) revert WrongAsset();
            if (amount_ == 0 || amount_ > asset_.balanceOf(address(this))) revert ZeroAmount();

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
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        if (contractAddress == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.singletonContracts[id] != address(0)) revert AlreadyRegistered();
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
        if (!_hasRole(msg.sender, VENDOR_ROLE)) revert WrongRole();
        _grantRoles(institution_, INSTITUTION_ROLE);
    }

    /// @notice grant the vendor role to a given address
    /// @param vendor_ the vendor address
    /// @dev Only callable by ADMIN_ROLE
    function grantVendorRole(address vendor_) external payable {
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        _grantRoles(vendor_, VENDOR_ROLE);
    }

    /// @notice grant the relayer role to a given address
    /// @param relayer_ the relayer address
    /// @dev Only callable by ADMIN_ROLE
    function grantRelayerRole(address relayer_) external payable {
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
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
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        if (asset == address(0)) revert ZeroAddress();
        if (id == bytes32(0)) revert ZeroAddress();

        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.supportedAssets.contains(asset)) revert AlreadyRegistered();

        $.supportedAssets.add(asset);
        $.singletonAssets[id] = asset;
        emit AssetSupported(asset);

        address minter_ = getContractById(K_MINTER);
        if (minter_ == address(0)) revert ZeroAddress();

        uint8 decimals_ = IERC20Metadata(asset).decimals();
        if (decimals_ == 0) decimals_ = 18;

        address kToken_ = $.assetToKToken[asset];
        if (kToken_ != address(0)) revert AlreadyRegistered();

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
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        if (vault == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.allVaults.contains(vault)) revert AlreadyRegistered();
        if (!$.supportedAssets.contains(asset)) revert AssetNotSupported();

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
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if (!$.allVaults.contains(vault)) revert AssetNotSupported();
        $.allVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    /*//////////////////////////////////////////////////////////////
                          ROLES MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the treasury address
    /// @param treasury_ The new treasury address
    function setTreasury(address treasury_) external payable {
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if (treasury_ == address(0)) revert ZeroAddress();
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
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        if (vault == address(0) || adapter == address(0)) {
            revert InvalidAdapter();
        }

        kRegistryStorage storage $ = _getkRegistryStorage();

        // Validate vault is registered
        if (!$.allVaults.contains(vault)) revert AssetNotSupported(); // Reuse error

        // Check if adapter is already set for this vault
        if ($.vaultAdapters[vault].contains(address(0))) {
            revert AdapterAlreadySet();
        }

        $.vaultAdapters[vault].add(adapter);

        emit AdapterRegistered(vault, adapter);
    }

    /// @notice Removes an adapter for a specific vault
    /// @param vault The vault address
    function removeAdapter(address vault, address adapter) external payable {
        if (!_hasRole(msg.sender, ADMIN_ROLE)) revert WrongRole();
        kRegistryStorage storage $ = _getkRegistryStorage();

        if (!$.vaultAdapters[vault].contains(adapter)) revert InvalidAdapter();
        $.vaultAdapters[vault].remove(adapter);

        emit AdapterRemoved(vault, adapter);
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
        if (addr == address(0)) revert ZeroAddress();
        return addr;
    }

    /// @notice Get a singleton asset address by its identifier
    /// @param id Asset identifier (e.g., USDC, WBTC)
    /// @return Asset address
    /// @dev Reverts if asset not set
    function getAssetById(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonAssets[id];
        if (addr == address(0)) revert ZeroAddress();
        return addr;
    }

    /// @notice Get all supported assets
    /// @return Array of supported asset addresses
    function getAllAssets() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.supportedAssets.length() == 0) revert ZeroAddress();
        return $.supportedAssets.values();
    }

    /// @notice Get all vaults registered in the protocol
    /// @return Array of vault addresses
    function getAllVaults() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.allVaults.length() == 0) revert ZeroAddress();
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
        if (kMinter_ == address(0) || kAssetRouter_ == address(0)) {
            revert ZeroAddress();
        }
        return (kMinter_, kAssetRouter_);
    }

    /// @notice Get all vaults registered for a specific asset
    /// @param asset Asset address to query
    /// @return Array of vault addresses
    function getVaultsByAsset(address asset) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.vaultsByAsset[asset].values().length == 0) revert ZeroAddress();
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
        if (assetToVault == address(0)) revert ZeroAddress();
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
        if ($.vaultAdapters[vault].values().length == 0) revert ZeroAddress();
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
        if ($.vaultAsset[vault].values().length == 0) revert ZeroAddress();
        return $.vaultAsset[vault].values();
    }

    /// @notice Get the kToken for a specific asset
    /// @param asset Asset address
    /// @return KToken address
    function assetToKToken(address asset) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address assetToToken_ = $.assetToKToken[asset];
        if (assetToToken_ == address(0)) revert ZeroAddress();
        return assetToToken_;
    }

    /// @notice check if the user has the given role
    /// @return Wether the caller have the given role
    function _hasRole(address user, uint256 role_) internal view returns (bool) {
        return hasAnyRole(user, role_);
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @param newImplementation New implementation address
    /// @dev Only callable by contract owner
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
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
