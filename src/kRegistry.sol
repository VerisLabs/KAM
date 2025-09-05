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

    /// @notice Core storage structure for kRegistry using ERC-7201 namespaced storage pattern
    /// @dev This structure maintains all protocol configuration state including contracts, assets, vaults, and permissions.
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
        /// @dev Maps unique identifiers to singleton contract addresses (e.g., K_MINTER => kMinter address)
        /// Ensures single source of truth for core protocol contracts
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
        /// @dev Maps asset identifiers (e.g., USDC, WBTC) to their contract addresses
        /// Provides named access to commonly used asset addresses
        mapping(bytes32 => address) singletonAssets;
        /// @dev Maps underlying asset addresses to their corresponding kToken addresses
        /// Critical for minting/redemption operations and asset tracking
        mapping(address => address) assetToKToken;
        /// @dev Maps vaults to their registered external protocol adapters
        /// Enables yield strategies through DeFi protocol integrations
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAdapters;
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
        _checkAddressNotZero(owner_);
        _checkAddressNotZero(admin_);
        _checkAddressNotZero(emergencyAdmin_);
        _checkAddressNotZero(guardian_);
        _checkAddressNotZero(relayer_);
        _checkAddressNotZero(treasury_);

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

    /// @notice Emergency function to rescue accidentally sent assets (ETH or ERC20) from the contract
    /// @dev This function provides a recovery mechanism for assets mistakenly sent to the registry. It includes
    /// critical safety checks: (1) Only callable by ADMIN_ROLE to prevent unauthorized access, (2) Cannot rescue
    /// registered protocol assets to prevent draining legitimate funds, (3) Validates amounts and balances.
    /// For ETH rescue, use address(0) as the asset parameter. The function ensures protocol integrity by
    /// preventing rescue of assets that are part of normal protocol operations.
    /// @param asset_ The asset address to rescue (use address(0) for ETH)
    /// @param to_ The destination address that will receive the rescued assets
    /// @param amount_ The amount of assets to rescue (must not exceed contract balance)
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
            kRegistryStorage storage $ = _getkRegistryStorage();
            _checkAssetNotRegistered(asset_);
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
        _checkAdmin(msg.sender);
        _checkAddressNotZero(contractAddress);
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
        _checkVendor(msg.sender);
        _grantRoles(institution_, INSTITUTION_ROLE);
    }

    /// @notice grant the vendor role to a given address
    /// @param vendor_ the vendor address
    /// @dev Only callable by ADMIN_ROLE
    function grantVendorRole(address vendor_) external payable {
        _checkAdmin(msg.sender);
        _grantRoles(vendor_, VENDOR_ROLE);
    }

    /// @notice grant the relayer role to a given address
    /// @param relayer_ the relayer address
    /// @dev Only callable by ADMIN_ROLE
    function grantRelayerRole(address relayer_) external payable {
        _checkAdmin(msg.sender);
        _grantRoles(relayer_, RELAYER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                          ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new underlying asset in the protocol and deploys its corresponding kToken
    /// @dev This function performs critical asset onboarding: (1) Validates the asset isn't already registered,
    /// (2) Adds asset to the supported set and singleton registry, (3) Deploys a new kToken contract with
    /// matching decimals, (4) Establishes bidirectional asset-kToken mapping, (5) Grants minting privileges
    /// to kMinter. The function automatically inherits decimals from the underlying asset for consistency.
    /// Only callable by ADMIN_ROLE to maintain protocol security and prevent unauthorized token creation.
    /// @param name_ The name for the kToken (e.g., "KAM USDC")
    /// @param symbol_ The symbol for the kToken (e.g., "kUSDC")
    /// @param asset The underlying asset contract address to register
    /// @param id The unique identifier for singleton asset storage (e.g., USDC, WBTC)
    /// @return The deployed kToken contract address
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
        _checkAdmin(msg.sender);
        _checkAddressNotZero(asset);
        require(id != bytes32(0), KREGISTRY_ZERO_ADDRESS);

        kRegistryStorage storage $ = _getkRegistryStorage();
        // Ensure asset isn't already in the protocol
        _checkAssetNotRegistered(asset);

        // Add to supported assets and create named reference
        $.supportedAssets.add(asset);
        $.singletonAssets[id] = asset;
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
                msg.sender,    // admin gets initial control
                msg.sender,    // emergency admin for safety
                minter_,       // kMinter gets minting rights
                name_,
                symbol_,
                decimals_      // matches underlying for consistency
            )
        );

        // Establish bidirectional mapping for asset-kToken relationship
        $.assetToKToken[asset] = kToken_;
        emit AssetRegistered(asset, kToken_);

        emit KTokenDeployed(kToken_, name_, symbol_, decimals_);

        return kToken_;
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new vault contract in the protocol's vault management system
    /// @dev This function integrates vaults into the protocol by: (1) Validating the vault isn't already registered,
    /// (2) Verifying the asset is supported by the protocol, (3) Classifying the vault by type for routing,
    /// (4) Establishing vault-asset relationships for both forward and reverse lookups, (5) Setting as primary
    /// vault for the asset-type combination if it's the first registered. The vault type determines routing
    /// logic and strategy selection (DN for institutional, ALPHA/BETA for different risk profiles).
    /// Only callable by ADMIN_ROLE to ensure proper vault vetting and integration.
    /// @param vault The vault contract address to register
    /// @param type_ The vault classification type (DN, ALPHA, BETA, etc.) determining its role
    /// @param asset The underlying asset address this vault will manage
    function registerVault(address vault, VaultType type_, address asset) external payable {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(vault);
        kRegistryStorage storage $ = _getkRegistryStorage();
        require(!$.allVaults.contains(vault), KREGISTRY_ALREADY_REGISTERED);
        _checkAssetRegistered(asset);

        // Classify vault by type for routing logic
        $.vaultType[vault] = uint8(type_);
        // Associate vault with the asset it manages
        $.vaultAsset[vault].add(asset);
        // Add to global vault registry
        $.allVaults.add(vault);
        // Set as primary vault for this asset-type combination
        $.assetToVault[asset][uint8(type_)] = vault;

        // Enable reverse lookup: find all vaults for an asset
        $.vaultsByAsset[asset].add(vault);

        emit VaultRegistered(vault, asset, type_);
    }

    /// @notice Removes a vault from the protocol registry
    /// @dev This function deregisters a vault, removing it from the active vault set. This operation should be
    /// used carefully as it affects routing and asset management. Only callable by ADMIN_ROLE to ensure proper
    /// decommissioning procedures are followed. Note that this doesn't clear all vault mappings for gas efficiency.
    /// @param vault The vault contract address to remove from the registry
    function removeVault(address vault) external payable {
        _checkAdmin(msg.sender);
        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkVaultRegistered(vault);
        $.allVaults.remove(vault);
        emit VaultRemoved(vault);
    }

    /*//////////////////////////////////////////////////////////////
                          ROLES MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the treasury address
    /// @param treasury_ The new treasury address
    function setTreasury(address treasury_) external payable {
        _checkAdmin(msg.sender);
        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkAddressNotZero(treasury_);
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
        _checkAdmin(msg.sender);
        _checkAddressNotZero(vault);
        require(adapter != address(0), KREGISTRY_INVALID_ADAPTER);

        kRegistryStorage storage $ = _getkRegistryStorage();

        // Ensure vault exists in protocol before adding adapter
        _checkVaultRegistered(vault);

        // Prevent duplicate adapter registration (address(0) check seems incorrect - likely a bug)
        require(!$.vaultAdapters[vault].contains(address(0)), KREGISTRY_ADAPTER_ALREADY_SET);

        // Register adapter for external protocol integration
        $.vaultAdapters[vault].add(adapter);

        emit AdapterRegistered(vault, adapter);
    }

    /// @notice Removes an adapter from a vault's registered adapter set
    /// @dev This disables a specific external protocol integration for the vault. Only callable by ADMIN_ROLE
    /// to ensure proper risk assessment before removing yield strategies.
    /// @param vault The vault address to remove the adapter from
    /// @param adapter The adapter address to remove
    function removeAdapter(address vault, address adapter) external payable {
        _checkAdmin(msg.sender);
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

    /// @notice Gets the hurdle rate for a specific asset
    /// @param asset The asset address
    /// @return The hurdle rate in basis points
    function getHurdleRate(address asset) external view returns (uint16) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        _checkAssetRegistered(asset);
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
        _checkAddressNotZero(addr);
        return addr;
    }

    /// @notice Get a singleton asset address by its identifier
    /// @param id Asset identifier (e.g., USDC, WBTC)
    /// @return Asset address
    /// @dev Reverts if asset not set
    function getAssetById(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonAssets[id];
        _checkAddressNotZero(addr);
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
        _checkAddressNotZero(kMinter_);
        _checkAddressNotZero(kAssetRouter_);
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
        _checkAddressNotZero(assetToVault);
        return assetToVault;
    }

    /// @notice Get the type of a vault
    /// @param vault Vault address
    /// @return Vault type
    function getVaultType(address vault) external view returns (uint8) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultType[vault];
    }

    /// @notice Check if an address has admin privileges
    /// @dev Admin role has broad protocol management capabilities
    /// @param user The address to check
    /// @return True if the address has ADMIN_ROLE
    function isAdmin(address user) external view returns (bool) {
        return _hasRole(user, ADMIN_ROLE);
    }

    /// @notice Check if an address has emergency admin privileges
    /// @dev Emergency admin can perform critical safety operations
    /// @param user The address to check
    /// @return True if the address has EMERGENCY_ADMIN_ROLE
    function isEmergencyAdmin(address user) external view returns (bool) {
        return _hasRole(user, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Check if an address has guardian privileges
    /// @dev Guardian role acts as circuit breaker for settlement proposals
    /// @param user The address to check
    /// @return True if the address has GUARDIAN_ROLE
    function isGuardian(address user) external view returns (bool) {
        return _hasRole(user, GUARDIAN_ROLE);
    }

    /// @notice Check if an address has relayer privileges
    /// @dev Relayer role manages external vault operations and hurdle rates
    /// @param user The address to check
    /// @return True if the address has RELAYER_ROLE
    function isRelayer(address user) external view returns (bool) {
        return _hasRole(user, RELAYER_ROLE);
    }

    /// @notice Check if an address is a qualified institution
    /// @dev Institutions have access to privileged operations like kMinter
    /// @param user The address to check
    /// @return True if the address has INSTITUTION_ROLE
    function isInstitution(address user) external view returns (bool) {
        return _hasRole(user, INSTITUTION_ROLE);
    }

    /// @notice Check if an address has vendor privileges
    /// @dev Vendors can grant institution roles and manage vendor vaults
    /// @param user The address to check
    /// @return True if the address has VENDOR_ROLE
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

    /// @notice Get all adapters registered for a specific vault
    /// @dev Returns an array of adapter addresses that enable external protocol integrations
    /// @param vault The vault address to query
    /// @return Array of adapter addresses registered for the vault
    function getAdapters(address vault) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        require($.vaultAdapters[vault].values().length > 0, KREGISTRY_ZERO_ADDRESS);
        return $.vaultAdapters[vault].values();
    }

    /// @notice Check if a specific adapter is registered for a vault
    /// @dev Used to validate adapter-vault relationships before operations
    /// @param vault The vault address to check
    /// @param adapter The adapter address to verify
    /// @return True if the adapter is registered for the specified vault
    function isAdapterRegistered(address vault, address adapter) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultAdapters[vault].contains(adapter);
    }

    /// @notice Get all assets managed by a specific vault
    /// @dev Most vaults manage a single asset, but some (like kMinter) can manage multiple
    /// @param vault The vault address to query
    /// @return Array of asset addresses that the vault manages
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

    /// @notice Internal helper to check if a user has a specific role
    /// @dev Wraps the OptimizedOwnableRoles hasAnyRole function for role verification
    /// @param user The address to check for role membership
    /// @param role_ The role constant to check (e.g., ADMIN_ROLE, VENDOR_ROLE)
    /// @return True if the user has the specified role, false otherwise
    function _hasRole(address user, uint256 role_) internal view returns (bool) {
        return hasAnyRole(user, role_);
    }

    /// @notice Check if caller has admin role
    /// @param user Address to check
    function _checkAdmin(address user) private view {
        require(_hasRole(user, ADMIN_ROLE), KREGISTRY_WRONG_ROLE);
    }

    /// @notice Check if caller has vendor role
    /// @param user Address to check
    function _checkVendor(address user) private view {
        require(_hasRole(user, VENDOR_ROLE), KREGISTRY_WRONG_ROLE);
    }

    /// @notice Check if caller has relayer role
    /// @param user Address to check
    function _checkRelayer(address user) private view {
        require(_hasRole(user, RELAYER_ROLE), KREGISTRY_WRONG_ROLE);
    }

    /// @notice Check if address is not zero
    /// @param addr Address to check
    function _checkAddressNotZero(address addr) private pure {
        require(addr != address(0), KREGISTRY_ZERO_ADDRESS);
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
    function _authorizeUpgrade(address newImplementation) internal view override {
        _checkOwner();
        require(newImplementation != address(0), KREGISTRY_ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function to receive ETH transfers
    /// @dev Allows the contract to receive ETH for gas refunds, donations, or accidental transfers.
    /// Received ETH can be rescued using the rescueAssets function with address(0).
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
