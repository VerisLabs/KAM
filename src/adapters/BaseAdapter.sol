// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/// @title BaseAdapter
/// @notice Abstract base contract for all protocol adapters
/// @dev Provides common functionality and virtual balance tracking for external strategy integrations
contract BaseAdapter is OwnableRoles, ReentrancyGuardTransient {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant K_MINTER = keccak256("K_MINTER");
    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyKAssetRouter();
    error ContractNotFound(bytes32 identifier);
    error ZeroAddress();
    error InvalidRegistry();
    error AssetNotSupported(address asset);
    error InvalidAmount();
    error InvalidAsset();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.BaseAdapter
    struct BaseAdapterStorage {
        address registry;
        bool registered;
        bool initialized;
        string name;
        string version;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.BaseAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BASE_ADAPTER_STORAGE_LOCATION =
        0x5547882c17743d50a538cd94a34f6308d65f7005fe26b376dcedda44d3aab800;

    function _getBaseAdapterStorage() internal pure returns (BaseAdapterStorage storage $) {
        assembly {
            $.slot := BASE_ADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base adapter
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    /// @param name_ Human readable name for this adapter
    /// @param version_ Version string for this adapter
    function __BaseAdapter_init(
        address registry_,
        address owner_,
        address admin_,
        string memory name_,
        string memory version_
    )
        internal
    {
        // Initialize adapter storage
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();

        if ($.initialized) revert AlreadyInitialized();
        if (registry_ == address(0)) revert InvalidRegistry();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();

        $.registry = registry_;
        $.registered = true;
        $.initialized = true;
        $.name = name_;
        $.version = version_;

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    function _registry() internal view returns (IkRegistry) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return IkRegistry($.registry);
    }

    /*//////////////////////////////////////////////////////////////
                           GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the kAssetRouter singleton contract address
    /// @return router The kAssetRouter contract address
    function _getKAssetRouter() internal view returns (address router) {
        router = _registry().getContractById(K_ASSET_ROUTER);
        if (router == address(0)) revert ContractNotFound(K_ASSET_ROUTER);
    }

    /// @notice Checks if an address is a relayer
    /// @return Whether the address is a relayer
    function _getRelayer() internal view returns (bool) {
        return _registry().isRelayer(msg.sender);
    }

    /// @notice Gets the kToken address for a given asset
    /// @param asset The underlying asset address
    /// @return kToken The corresponding kToken address
    /// @dev Reverts if asset not supported
    function _getKTokenForAsset(address asset) internal view returns (address kToken) {
        kToken = _registry().assetToKToken(asset);
        if (kToken == address(0)) revert AssetNotSupported(asset);
    }

    /// @notice Gets the asset managed by a vault
    /// @param vault The vault address
    /// @return asset The asset address managed by the vault
    /// @dev Reverts if vault not registered
    function _getVaultAsset(address vault) internal view returns (address asset) {
        asset = _registry().getVaultAsset(vault);
        if (asset == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether this adapter is registered
    /// @return True if adapter is registered and active
    function registered() public view returns (bool) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.registered;
    }

    /// @notice Returns the adapter's name
    /// @return Human readable adapter name
    function name() external view returns (string memory) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.name;
    }

    /// @notice Returns the adapter's version
    /// @return Version string
    function version() external view returns (string memory) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.version;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts function access to kAssetRouter only
    modifier onlyKAssetRouter() {
        if (msg.sender != _getKAssetRouter()) revert OnlyKAssetRouter();
        _;
    }

    /// @notice Restricts function access to the relayer
    modifier onlyRelayer() {
        if (!_getRelayer()) revert OnlyKAssetRouter(); // Reuse error for simplicity
        _;
    }

    /// @notice Ensures the adapter is registered and active
    modifier whenRegistered() {
        if (!registered()) revert InvalidAsset(); // Reuse error for simplicity
        _;
    }
}
