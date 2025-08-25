// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {EnumerableSetLib} from "solady/utils/EnumerableSetLib.sol";
import {Initializable} from "solady/utils/Initializable.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IkRegistry} from "src/interfaces/IkRegistry.sol";

import {kToken} from "src/kToken.sol";

/// @title kRegistry
/// @notice Central registry for KAM protocol contracts
/// @dev Manages singleton contracts, vault registration, asset support, and kToken mapping
contract kRegistry is IkRegistry, Initializable, UUPSUpgradeable, OwnableRoles {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;
    using LibClone for address;

    /*//////////////////////////////////////////////////////////////
                              ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant FACTORY_ROLE = _ROLE_1;
    uint256 internal constant RELAYER_ROLE = _ROLE_2;
    uint256 internal constant GUARDIAN_ROLE = _ROLE_3;

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
        address kTokenImpl;
        mapping(bytes32 => address) singletonContracts;
        mapping(address => bool) isSingletonContract;
        mapping(address => bool) isVault;
        mapping(address => uint8 vaultType) vaultType;
        mapping(address => mapping(uint8 vaultType => address)) assetToVault;
        mapping(address => EnumerableSetLib.AddressSet) vaultAsset; // kMinter will have > 1 assets
        EnumerableSetLib.AddressSet allVaults;
        mapping(address => EnumerableSetLib.AddressSet) vaultsByAsset;
        mapping(bytes32 => address) singletonAssets;
        mapping(address => address) assetToKToken;
        mapping(address => bool) isKToken;
        mapping(address => address) kTokenToAsset;
        mapping(address => bool) isRegisteredAsset;
        EnumerableSetLib.AddressSet supportedAssets;
        EnumerableSetLib.AddressSet deployedKTokens;
        mapping(address => EnumerableSetLib.AddressSet) vaultAdapters; // vault => adapter
        mapping(address => bool) registeredAdapters; // adapter => registered
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KREGISTRY_STORAGE_LOCATION =
        0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;

    function _getkRegistryStorage()
        private
        pure
        returns (kRegistryStorage storage $)
    {
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
        address relayer_,
        address guardian_
    ) external initializer {
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (relayer_ == address(0)) revert ZeroAddress();

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(relayer_, RELAYER_ROLE);
        _grantRoles(guardian_, GUARDIAN_ROLE);

        kRegistryStorage storage $ = _getkRegistryStorage();
        address kTokenImpl_ = address(new kToken());
        if (kTokenImpl_ == address(0)) revert ZeroAddress();
        $.kTokenImpl = kTokenImpl_;
    }

    /*//////////////////////////////////////////////////////////////
                             DEPLOY KTOKEN
    //////////////////////////////////////////////////////////////*/
    function deployKToken(
        address owner_,
        address admin_,
        address emergencyAdmin_,
        uint8 decimals_
    ) external onlyRoles(ADMIN_ROLE) returns (address) {
        // Validate input parameters
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();
        if (decimals_ > 18) revert InvalidParameter();

        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.kTokenImpl == address(0)) revert KTokenImplementationNotSet();

        bytes32 salt = keccak256(
            abi.encodePacked(
                owner_,
                admin_,
                emergencyAdmin_,
                decimals_,
                block.timestamp,
                msg.sender,
                $.deployedKTokens.length()
            )
        );

        address predicted = $.kTokenImpl.predictDeterministicAddress(
            salt,
            msg.sender
        );
        if (predicted.code.length > 0) revert SaltAlreadyUsed();

        address kTokenProxy = $.kTokenImpl.cloneDeterministic(salt);
        // Get minter address (should be kMinter singleton)
        address minterAddress = $.singletonContracts[K_MINTER];
        if (minterAddress == address(0)) revert MinterNotSet();

        try
            kToken(kTokenProxy).initialize(
                owner_,
                admin_,
                emergencyAdmin_,
                minterAddress,
                decimals_
            )
        {
            $.deployedKTokens.add(kTokenProxy);
            emit KTokenDeployed(kTokenProxy, owner_, admin_);
            return kTokenProxy;
        } catch {
            revert TokenInitializationFailed();
        }
    }

    /// @notice Set the kToken implementation address
    /// @param kTokenImpl_ The kToken implementation contract address
    /// @dev Only callable by ADMIN_ROLE
    function setKTokenImplementation(
        address kTokenImpl_
    ) external onlyRoles(ADMIN_ROLE) {
        if (kTokenImpl_ == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        $.kTokenImpl = kTokenImpl_;
        emit KTokenImplementationSet(kTokenImpl_);
    }

    /*//////////////////////////////////////////////////////////////
                          SINGLETON MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Set a singleton contract address
    /// @param id Contract identifier (e.g., K_MINTER, K_BATCH)
    /// @param contractAddress Address of the singleton contract
    /// @dev Only callable by ADMIN_ROLE
    function setSingletonContract(
        bytes32 id,
        address contractAddress
    ) external onlyRoles(ADMIN_ROLE) {
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
    /// @param kToken_ Corresponding kToken address (e.g., kUSD, kBTC)
    /// @dev Only callable by ADMIN_ROLE, establishes bidirectional mapping
    function registerAsset(
        address asset,
        address kToken_,
        bytes32 id
    ) external onlyRoles(ADMIN_ROLE) {
        if (asset == address(0) || kToken_ == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if (id == bytes32(0)) revert ZeroAddress();
        if (!$.deployedKTokens.contains(kToken_)) revert KTokenNotRegistered();

        // Register asset
        if (!$.isRegisteredAsset[asset]) {
            $.isRegisteredAsset[asset] = true;
            $.supportedAssets.add(asset);
            $.singletonAssets[id] = asset;
            emit AssetSupported(asset);
        }

        // Register kToken
        $.assetToKToken[asset] = kToken_;
        $.kTokenToAsset[kToken_] = asset;
        $.isKToken[kToken_] = true;

        emit KTokenRegistered(asset, kToken_);
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a new vault in the protocol
    /// @param vault Vault contract address
    /// @param type_ Type of vault (MINTER, DN, ALPHA, BETA)
    /// @param asset Underlying asset the vault manages
    /// @dev Only callable by ADMIN_ROLE, sets as primary if first of its type
    function registerVault(
        address vault,
        VaultType type_,
        address asset
    ) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.isVault[vault]) revert AlreadyRegistered();
        if (!$.isRegisteredAsset[asset]) revert AssetNotSupported();

        // Register vault
        $.isVault[vault] = true;
        $.vaultType[vault] = uint8(type_);
        $.vaultAsset[vault].add(asset);
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
    function registerAdapter(
        address vault,
        address adapter
    ) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0) || adapter == address(0)) {
            revert InvalidAdapter();
        }

        kRegistryStorage storage $ = _getkRegistryStorage();

        // Validate vault is registered
        if (!$.isVault[vault]) revert AssetNotSupported(); // Reuse error

        // Check if adapter is already set for this vault
        if ($.vaultAdapters[vault].contains(address(0))) {
            revert AdapterAlreadySet();
        }

        // Validate adapter implements IAdapter interface
        if (!IAdapter(adapter).registered()) revert AdapterNotRegistered();

        $.vaultAdapters[vault].add(adapter);
        $.registeredAdapters[adapter] = true;

        emit AdapterRegistered(vault, adapter);
    }

    /// @notice Removes an adapter for a specific vault
    /// @param vault The vault address
    function removeAdapter(
        address vault,
        address adapter
    ) external onlyRoles(ADMIN_ROLE) {
        kRegistryStorage storage $ = _getkRegistryStorage();

        if (!$.vaultAdapters[vault].contains(adapter)) revert InvalidAdapter();
        $.vaultAdapters[vault].remove(adapter);
        $.registeredAdapters[adapter] = false;

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
        address[] memory assets = new address[]($.supportedAssets.length());
        for (uint256 i; i < $.supportedAssets.length(); ) {
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
    function getVaultsByAsset(
        address asset
    ) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.vaultsByAsset[asset].values().length == 0) revert ZeroAddress();
        return $.vaultsByAsset[asset].values();
    }

    /// @notice Get a vault address by asset and vault type
    /// @param asset Asset address
    /// @param vaultType Vault type
    /// @return Vault address
    /// @dev Reverts if vault not found
    function getVaultByAssetAndType(
        address asset,
        uint8 vaultType
    ) external view returns (address) {
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

    /// @notice Check if the caller is the relayer
    /// @return Whether the caller is the relayer
    function isRelayer(address account) external view returns (bool) {
        return hasAnyRole(account, RELAYER_ROLE);
    }

    function isGuardian(address account) external view returns (bool) {
        return hasAnyRole(account, GUARDIAN_ROLE);
    }

    /// @notice Check if an asset is supported
    /// @param asset Asset address
    /// @return Whether the asset is supported
    function isRegisteredAsset(address asset) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isRegisteredAsset[asset];
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
    function isSingletonContract(
        address contractAddress
    ) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isSingletonContract[contractAddress];
    }

    /// @notice Check if a kToken is registered
    /// @param kToken_ KToken address
    /// @return Whether the kToken is registered
    function isKToken(address kToken_) external view returns (bool) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.isKToken[kToken_];
    }

    /// @notice Get the adapter for a specific vault
    /// @param vault Vault address
    /// @return Adapter address (address(0) if none set)
    function getAdapters(
        address vault
    ) external view returns (address[] memory) {
        kRegistryStorage storage $ = _getkRegistryStorage();
        if ($.vaultAdapters[vault].values().length == 0) revert ZeroAddress();
        return $.vaultAdapters[vault].values();
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
    function getVaultAssets(
        address vault
    ) external view returns (address[] memory) {
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

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @param newImplementation New implementation address
    /// @dev Only callable by contract owner
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive ETH (for gas refunds, etc.)
    receive() external payable {}

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
