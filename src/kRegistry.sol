// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/// @title kRegistry
/// @notice Central registry for KAM protocol contracts
/// @dev Manages singleton contracts, vault registration, asset support, and kToken mapping
contract kRegistry is IkRegistry, Initializable, UUPSUpgradeable, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    /*//////////////////////////////////////////////////////////////
                              ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant FACTORY_ROLE = _ROLE_1;
    uint256 internal constant RELAYER_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    // Singleton contracts (only one instance in the protocol)
    bytes32 public constant K_MINTER = keccak256("K_MINTER");
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
        mapping(address => uint8 vaultType) vaultType;
        mapping(address => mapping(uint8 vaultType => address)) assetToVault;
        mapping(address => address) vaultAsset;
        EnumerableSetLib.AddressSet allVaults;
        mapping(address => EnumerableSetLib.AddressSet) vaultsByAsset;
        mapping(bytes32 => address) singletonAssets;
        mapping(address => address) assetToKToken;
        mapping(address => bool) isKToken;
        mapping(address => address) kTokenToAsset;
        mapping(address => bool) isSupportedAsset;
        EnumerableSetLib.AddressSet supportedAssets;
        mapping(address => address) vaultAdapters; // vault => adapter
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
            $.supportedAssets.add(asset);
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
        $.vaultType[vault] = uint8(type_);
        $.vaultAsset[vault] = asset;
        $.allVaults.add(vault);
        $.assetToVault[asset][uint8(type_)] = vault;

        // Track by asset
        $.vaultsByAsset[asset].add(vault);

        emit VaultRegistered(vault, asset, type_);
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers an adapter for a specific vault
    /// @param vault The vault address
    /// @param adapter The adapter address
    function registerAdapter(address vault, address adapter) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0) || adapter == address(0)) revert InvalidAdapter();

        kRegistryStorage storage $ = _getkRegistryStorage();

        // Validate vault is registered
        if (!$.isVault[vault]) revert AssetNotSupported(); // Reuse error

        // Check if adapter is already set for this vault
        if ($.vaultAdapters[vault] != address(0)) revert AdapterAlreadySet();

        // Validate adapter implements IAdapter interface
        if (!IAdapter(adapter).registered()) revert AdapterNotRegistered();

        $.vaultAdapters[vault] = adapter;
        $.registeredAdapters[adapter] = true;

        emit AdapterRegistered(vault, adapter);
    }

    /// @notice Removes an adapter for a specific vault
    /// @param vault The vault address
    function removeAdapter(address vault) external onlyRoles(ADMIN_ROLE) {
        kRegistryStorage storage $ = _getkRegistryStorage();

        address adapter = $.vaultAdapters[vault];
        if (adapter == address(0)) revert InvalidAdapter();

        delete $.vaultAdapters[vault];
        delete $.registeredAdapters[adapter];

        emit AdapterRemoved(vault, adapter);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get a singleton contract address by its identifier
    /// @param id Contract identifier (e.g., K_MINTER, K_BATCH)
    /// @return Contract address
    /// @dev Reverts if contract not set
    function getContractById(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonContracts[id];
        if (addr == address(0)) revert ContractNotSet();
        return addr;
    }

    /// @notice Get a singleton asset address by its identifier
    /// @param id Asset identifier (e.g., USDC, WBTC)
    /// @return Asset address
    /// @dev Reverts if asset not set
    function getAssetById(bytes32 id) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address addr = $.singletonAssets[id];
        if (addr == address(0)) revert ContractNotSet();
        return addr;
    }

    /// @notice Get all supported assets
    /// @return Array of supported asset addresses
    function getAllAssets() external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        address[] memory assets = new address[]($.supportedAssets.length());
        for (uint256 i; i < $.supportedAssets.length();) {
            assets[i] = $.supportedAssets.at(i);
            unchecked {
                ++i;
            }
        }
        return assets;
    }

    /// @notice Get all core singleton contracts at once
    /// @return kMinter The kMinter contract address
    /// @return kAssetRouter The kAssetRouter contract address
    /// @return kVaultFactory The kVaultFactory contract address
    /// @return upgradeManager The upgrade manager contract address
    function getCoreContracts()
        external
        view
        returns (address kMinter, address kAssetRouter, address kVaultFactory, address upgradeManager)
    {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return (
            $.singletonContracts[K_MINTER],
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
        return $.vaultsByAsset[asset].values();
    }

    /// @notice Get a vault address by asset and vault type
    /// @param asset Asset address
    /// @param vaultType Vault type
    /// @return Vault address
    /// @dev Reverts if vault not found
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.assetToVault[asset][vaultType];
    }

    /// @notice Get the type of a vault
    /// @param vault Vault address
    /// @return Vault type
    function getVaultType(address vault) external view returns (uint8) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultType[vault];
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

    /// @notice Get the adapter for a specific vault
    /// @param vault Vault address
    /// @return Adapter address (address(0) if none set)
    function getAdapter(address vault) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultAdapters[vault];
    }

    /// @notice Check if an adapter is registered
    /// @param adapter Adapter address
    /// @return True if adapter is registered
    function isAdapterRegistered(address adapter) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.registeredAdapters[adapter];
    }

    /// @notice Get the asset for a specific vault
    /// @param vault Vault address
    /// @return Asset address that the vault manages
    function getVaultAsset(address vault) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.vaultAsset[vault];
    }

    /// @notice Get the kToken for a specific asset
    /// @param asset Asset address
    /// @return KToken address
    function assetToKToken(address asset) external view returns (address) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.assetToKToken[asset];
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
