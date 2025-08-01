// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/// @title BaseAdapter
/// @notice Abstract base contract for all protocol adapters
/// @dev Provides common functionality and virtual balance tracking for external strategy integrations
abstract contract BaseAdapter is IAdapter, OwnableRoles, Initializable, UUPSUpgradeable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyKAssetRouter();
    error ContractNotFound(bytes32 identifier);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.BaseAdapter
    struct BaseAdapterStorage {
        address registry;
        mapping(address vault => mapping(address asset => uint256)) adapterBalances;
        bool registered;
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
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Restricts function access to kAssetRouter only
    modifier onlyKAssetRouter() {
        if (msg.sender != _getKAssetRouter()) revert OnlyKAssetRouter();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    function _registry() internal view returns (IkRegistry) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return IkRegistry($.registry);
    }

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

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
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
        onlyInitializing
    {
        // Initialize OwnableRoles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);

        // Initialize adapter storage
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        $.registry = registry_;
        $.registered = true;
        $.name = name_;
        $.version = version_;
    }

    /*//////////////////////////////////////////////////////////////
                          ADAPTER BALANCE TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to update adapter balance on deposit
    /// @param vault The vault address
    /// @param asset The asset address
    /// @param amount The amount to add to adapter balance
    function _adapterDeposit(address vault, address asset, uint256 amount) internal {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        $.adapterBalances[vault][asset] += amount;
        emit AdapterBalanceUpdated(vault, asset, $.adapterBalances[vault][asset]);
    }

    /// @notice Internal function to update adapter balance on redemption
    /// @param vault The vault address
    /// @param asset The asset address
    /// @param amount The amount to subtract from adapter balance
    function _adapterRedeem(address vault, address asset, uint256 amount) internal {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        if ($.adapterBalances[vault][asset] < amount) revert InsufficientBalance();
        $.adapterBalances[vault][asset] -= amount;
        emit AdapterBalanceUpdated(vault, asset, $.adapterBalances[vault][asset]);
    }

    /*//////////////////////////////////////////////////////////////
                          ABSTRACT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets to external strategy - must be implemented by child contracts
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    )
        external
        virtual
        override
        onlyKAssetRouter
        whenRegistered
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();
        if (onBehalfOf == address(0)) revert InvalidAsset();

        _deposit(asset, amount, onBehalfOf);
    }

    /// @notice Redeems assets from external strategy - must be implemented by child contracts
    function redeem(
        address asset,
        uint256 amount,
        address onBehalfOf
    )
        external
        virtual
        override
        onlyKAssetRouter
        whenRegistered
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();
        if (onBehalfOf == address(0)) revert InvalidAsset();

        _redeem(asset, amount, onBehalfOf);
    }

    /// @notice Implementation-specific deposit logic
    function _deposit(address asset, uint256 amount, address onBehalfOf) internal virtual;

    /// @notice Implementation-specific redemption logic
    function _redeem(address asset, uint256 amount, address onBehalfOf) internal virtual;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the adapter balance for a specific vault and asset
    /// @param vault The vault address
    /// @param asset The asset address
    /// @return Adapter balance for the vault
    function adapterBalance(address vault, address asset) external view override returns (uint256) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.adapterBalances[vault][asset];
    }

    /// @notice Returns whether this adapter is registered
    /// @return True if adapter is registered and active
    function registered() public view override returns (bool) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.registered;
    }

    /// @notice Returns the adapter's name
    /// @return Human readable adapter name
    function name() external view override returns (string memory) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.name;
    }

    /// @notice Returns the adapter's version
    /// @return Version string
    function version() external view override returns (string memory) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.version;
    }

    /// @notice Returns the current total assets for a specific vault
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Total assets currently deployed for this vault
    /// @dev Default implementation returns adapter balance, override for more complex calculations
    function totalAssetsForVault(address vault, address asset) external view virtual override returns (uint256) {
        return this.adapterBalance(vault, asset);
    }

    /// @notice Returns estimated total assets for a specific vault including pending yield
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Estimated total assets including unrealized gains for this vault
    /// @dev Default implementation returns totalAssetsForVault, override for yield calculations
    function estimatedTotalAssetsForVault(
        address vault,
        address asset
    )
        external
        view
        virtual
        override
        returns (uint256)
    {
        return this.totalAssetsForVault(vault, asset);
    }

    /*//////////////////////////////////////////////////////////////
                          EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency withdrawal function - must be implemented by child contracts
    /// @param asset Asset to withdraw
    /// @param amount Amount to withdraw
    /// @param to Recipient address
    function emergencyWithdraw(
        address asset,
        uint256 amount,
        address to
    )
        external
        virtual
        onlyRoles(EMERGENCY_ADMIN_ROLE)
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();
        if (to == address(0)) revert InvalidAsset();

        _emergencyWithdraw(asset, amount, to);
    }

    /// @notice Implementation-specific emergency withdrawal logic
    function _emergencyWithdraw(address asset, uint256 amount, address to) internal virtual;

    /*//////////////////////////////////////////////////////////////
                          UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize contract upgrade - only admin can upgrade
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert InvalidAsset();
    }
}
