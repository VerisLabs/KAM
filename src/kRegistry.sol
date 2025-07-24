// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

/// @title kRegistry
/// @notice Central registry for KAM protocol contracts
/// @dev Manages singleton contracts, vault registration, asset support, and kToken mapping
contract kRegistry is Initializable, UUPSUpgradeable, OwnableRoles {
    /*//////////////////////////////////////////////////////////////
                              ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant FACTORY_ROLE = _ROLE_1;
    uint256 internal constant RELAYER_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event SingletonContractSet(bytes32 indexed id, address indexed contractAddress);
    event VaultRegistered(address indexed vault, VaultType indexed vaultType, address indexed asset);
    event KTokenRegistered(address indexed asset, address indexed kToken);
    event AssetSupported(address indexed asset);
    event PrimaryVaultSet(address indexed asset, VaultType indexed vaultType, address indexed vault);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error AlreadyRegistered();
    error AssetNotSupported();
    error ContractNotSet();

    /*//////////////////////////////////////////////////////////////
                              ENUMS
    //////////////////////////////////////////////////////////////*/

    enum VaultType {
        DN_VAULT,
        STAKING_VAULT
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Singleton contracts (only one instance in the protocol)
    bytes32 public constant K_MINTER = keccak256("K_MINTER");
    bytes32 public constant K_BATCH = keccak256("K_BATCH");
    bytes32 public constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
    bytes32 public constant K_VAULT_FACTORY = keccak256("K_VAULT_FACTORY");
    bytes32 public constant K_UPGRADE_MANAGER = keccak256("K_UPGRADE_MANAGER");

    // Singleton Assets - We might add more following the same pattern
    bytes32 public constant USDC = keccak256("USDC");
    bytes32 public constant WBTC = keccak256("WBTC");

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kRegistry
    struct kRegistryStorage {
        mapping(bytes32 => address) singletonContracts;
        mapping(address => bool) isSingletonContract;
        mapping(address => bool) isVault;
        mapping(address => VaultType) vaultType;
        mapping(address => address) vaultAsset;
        address[] allVaults;
        mapping(address => address[]) vaultsByAsset;
        mapping(bytes32 => address) singletonAssets;
        mapping(address => address) assetToKToken;
        mapping(address => bool) isKToken;
        mapping(address => address) kTokenToAsset;
        mapping(address => bool) isSupportedAsset;
        address[] supportedAssets;
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
    function initialize(address owner_, address admin_, address relayer_) external initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (relayer_ == address(0)) revert ZeroAddress();

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(relayer_, RELAYER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                          SINGLETON MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Set a singleton contract address
    /// @param id Contract identifier (e.g., K_MINTER, K_BATCH)
    /// @param contractAddress Address of the singleton contract
    /// @dev Only callable by ADMIN_ROLE
    function setSingletonContract(bytes32 id, address contractAddress) external onlyRoles(ADMIN_ROLE) {
        if (contractAddress == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.isSingletonContract[contractAddress]) revert AlreadyRegistered();
        $.singletonContracts[id] = contractAddress;
        $.isSingletonContract[contractAddress] = true;
        emit SingletonContractSet(id, contractAddress);
    }

    /*//////////////////////////////////////////////////////////////
                          ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Register support for a new asset and its corresponding kToken
    /// @param asset Underlying asset address (e.g., USDC, WBTC)
    /// @param kToken Corresponding kToken address (e.g., kUSD, kBTC)
    /// @dev Only callable by ADMIN_ROLE, establishes bidirectional mapping
    function registerAsset(address asset, address kToken, bytes32 id) external onlyRoles(ADMIN_ROLE) {
        if (asset == address(0) || kToken == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if (id == bytes32(0)) revert ZeroAddress();

        // Register asset
        if (!$.isSupportedAsset[asset]) {
            $.isSupportedAsset[asset] = true;
            $.supportedAssets.push(asset);
            $.singletonAssets[id] = asset;
            emit AssetSupported(asset);
        }

        // Register kToken
        $.assetToKToken[asset] = kToken;
        $.kTokenToAsset[kToken] = asset;
        $.isKToken[kToken] = true;

        emit KTokenRegistered(asset, kToken);
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a new vault in the protocol
    /// @param vault Vault contract address
    /// @param type_ Type of vault (DN_VAULT or STAKING_VAULT)
    /// @param asset Underlying asset the vault manages
    /// @dev Only callable by FACTORY_ROLE, sets as primary if first of its type
    function registerVault(address vault, VaultType type_, address asset) external onlyRoles(FACTORY_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.isVault[vault]) revert AlreadyRegistered();
        if (!$.isSupportedAsset[asset]) revert AssetNotSupported();

        // Register vault
        $.isVault[vault] = true;
        $.vaultType[vault] = type_;
        $.vaultAsset[vault] = asset;
        $.allVaults.push(vault);

        // Track by asset
        $.vaultsByAsset[asset].push(vault);

        emit VaultRegistered(vault, type_, asset);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get a singleton contract address by its identifier
    /// @param id Contract identifier (e.g., K_MINTER, K_BATCH)
    /// @return Contract address
    /// @dev Reverts if contract not set
    function getSingletonContract(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonContracts[id];
        if (addr == address(0)) revert ContractNotSet();
        return addr;
    }

    /// @notice Get a singleton asset address by its identifier
    /// @param id Asset identifier (e.g., USDC, WBTC)
    /// @return Asset address
    /// @dev Reverts if asset not set
    function getSingletonAsset(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonAssets[id];
        if (addr == address(0)) revert ContractNotSet();
        return addr;
    }

    /// @notice Get all core singleton contracts at once
    /// @return kMinter The kMinter contract address
    /// @return kBatch The kBatch contract address
    /// @return kAssetRouter The kAssetRouter contract address
    /// @return kVaultFactory The kVaultFactory contract address
    /// @return upgradeManager The upgrade manager contract address
    function getCoreContracts()
        external
        view
        returns (address kMinter, address kBatch, address kAssetRouter, address kVaultFactory, address upgradeManager)
    {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return (
            $.singletonContracts[K_MINTER],
            $.singletonContracts[K_BATCH],
            $.singletonContracts[K_ASSET_ROUTER],
            $.singletonContracts[K_VAULT_FACTORY],
            $.singletonContracts[K_UPGRADE_MANAGER]
        );
    }

    /// @notice Get all vaults registered for a specific asset
    /// @param asset Asset address to query
    /// @return Array of vault addresses
    function getVaultsByAsset(address asset) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultsByAsset[asset];
    }

    /// @notice Check if the caller is the relayer
    /// @return Whether the caller is the relayer
    function isRelayer(address account) external view returns (bool) {
        return hasAnyRole(account, RELAYER_ROLE);
    }

    /// @notice Check if an asset is supported
    /// @param asset Asset address
    /// @return Whether the asset is supported
    function isSupportedAsset(address asset) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isSupportedAsset[asset];
    }

    /// @notice Check if a vault is registered
    /// @param vault Vault address
    /// @return Whether the vault is registered
    function isVault(address vault) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isVault[vault];
    }

    /// @notice Check if a contract is a singleton contract
    /// @param contractAddress Contract address
    /// @return Whether the contract is a singleton contract
    function isSingletonContract(address contractAddress) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isSingletonContract[contractAddress];
    }

    /// @notice Check if a kToken is registered
    /// @param kToken KToken address
    /// @return Whether the kToken is registered
    function isKToken(address kToken) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isKToken[kToken];
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
