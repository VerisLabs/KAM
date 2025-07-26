// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/// @title kBase
/// @notice Base contract providing common functionality for all KAM protocol contracts
/// @dev Includes registry integration, role management, pause functionality, and helper methods
contract kBase is OwnableRoles, ReentrancyGuardTransient {
    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Paused(bool paused);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant K_MINTER = keccak256("K_MINTER");
    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidRegistry();
    error NotInitialized();
    error ContractNotFound(bytes32 identifier);
    error AssetNotSupported(address asset);
    error InvalidVault(address vault);
    error OnlyKMinter();
    error OnlyKAssetRouter();
    error OnlyKBatch();
    error OnlyRelayer();

    /*//////////////////////////////////////////////////////////////
                        STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kBase
    struct kBaseStorage {
        address registry;
        bool initialized;
        bool paused;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KBASE_STORAGE_LOCATION = 0xe91688684975c4d7d54a65dd96da5d4dcbb54b8971c046d5351d3c111e43a800;

    function _getBaseStorage() internal pure returns (kBaseStorage storage $) {
        assembly {
            $.slot := KBASE_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base contract with registry and pause state
    /// @param registry_ Address of the kRegistry contract
    /// @param paused_ Initial pause state
    /// @dev Can only be called once during initialization
    function __kBase_init(address registry_, address owner_, address admin_, bool paused_) internal {
        kBaseStorage storage $ = _getBaseStorage();

        if ($.initialized) revert AlreadyInitialized();
        if (registry_ == address(0)) revert InvalidRegistry();

        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();

        $.registry = registry_;
        $.paused = paused_;
        $.initialized = true;

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract address
    /// @return The kRegistry contract address
    /// @dev Reverts if contract not initialized
    function registry() public view returns (address) {
        kBaseStorage storage $ = _getBaseStorage();
        if (!$.initialized) revert NotInitialized();
        return $.registry;
    }

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    /// @dev Internal helper for typed registry access
    function _registry() internal view returns (IkRegistry) {
        kBaseStorage storage $ = _getBaseStorage();
        if (!$.initialized) revert NotInitialized();
        return IkRegistry($.registry);
    }

    /*//////////////////////////////////////////////////////////////
                          GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _getKMinter() internal view returns (address minter) {
        minter = _registry().getContractById(K_MINTER);
        if (minter == address(0)) revert ContractNotFound(K_MINTER);
    }

    /// @notice Gets the kAssetRouter singleton contract address
    /// @return router The kAssetRouter contract address
    /// @dev Reverts if kAssetRouter not set in registry
    function _getKAssetRouter() internal view returns (address router) {
        router = _registry().getContractById(K_ASSET_ROUTER);
        if (router == address(0)) revert ContractNotFound(K_ASSET_ROUTER);
    }

    /// @notice Checks if an address is a relayer
    /// @return Whether the address is a relayer
    function _getRelayer() internal view returns (bool) {
        return _registry().isRelayer(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          ASSET HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the kToken address for a given asset
    /// @param asset The underlying asset address
    /// @return kToken The corresponding kToken address
    /// @dev Reverts if asset not supported
    function _getKTokenForAsset(address asset) internal view returns (address kToken) {
        kToken = _registry().assetToKToken(asset);
        if (kToken == address(0)) revert AssetNotSupported(asset);
    }

    /// @notice Checks if an asset is supported by the protocol
    /// @param asset The asset address to check
    /// @return Whether the asset is supported
    function _isAssetSupported(address asset) internal view returns (bool) {
        return _registry().isSupportedAsset(asset);
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the asset managed by a vault
    /// @param vault The vault address
    /// @return asset The asset address managed by the vault
    /// @dev Reverts if vault not registered
    function _getVaultAsset(address vault) internal view returns (address asset) {
        asset = _registry().vaultAsset(vault);
        if (asset == address(0)) revert InvalidVault(vault);
    }

    /// @notice Gets the DN vault address for a given asset
    /// @param asset The asset address
    /// @return vault The corresponding DN vault address
    /// @dev Reverts if asset not supported
    function _getDNVaultByAsset(address asset) internal view returns (address vault) {
        vault = _registry().getVaultByAssetAndType(asset, uint8(IkRegistry.VaultType.DN_VAULT));
        if (vault == address(0)) revert InvalidVault(vault);
    }

    /// @notice Checks if an address is a registered vault
    /// @param vault The address to check
    /// @return Whether the address is a registered vault
    function _isVault(address vault) internal view returns (bool) {
        return _registry().isVault(vault);
    }

    function _isSupportedAsset(address asset) internal view returns (bool) {
        return _registry().isSupportedAsset(asset);
    }

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function _setPaused(bool paused_) internal {
        kBaseStorage storage $ = _getBaseStorage();
        if (!$.initialized) revert NotInitialized();
        $.paused = paused_;
        emit Paused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                          MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts function access to the kMinter contract
    modifier onlyKMinter() {
        if (msg.sender != _getKMinter()) revert OnlyKMinter();
        _;
    }

    /// @notice Restricts function access to the relayer
    /// @dev Only callable internally by inheriting contracts
    modifier onlyRelayer() {
        if (!_getRelayer()) revert OnlyRelayer();
        _;
    }

    /// @notice Ensures the asset is supported by the protocol
    /// @param asset The asset address to validate
    modifier onlySupportedAsset(address asset) {
        if (!_isAssetSupported(asset)) revert AssetNotSupported(asset);
        _;
    }
}
