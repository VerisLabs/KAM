// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/// @title BaseAdapter
/// @notice Abstract base contract for all protocol adapters
/// @dev Provides common functionality and virtual balance tracking for external strategy integrations
contract BaseAdapter is ReentrancyGuardTransient {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
    event RescuedETH(address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroAmount();
    error WrongRole();
    error WrongAsset();
    error TransferFailed();
    error InvalidRegistry();
    error InvalidAmount();
    error InvalidAsset();
    error AlreadyInitialized();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.BaseAdapter
    struct BaseAdapterStorage {
        address registry;
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
    /// @param name_ Human readable name for this adapter
    /// @param version_ Version string for this adapter
    function __BaseAdapter_init(address registry_, string memory name_, string memory version_) internal {
        // Initialize adapter storage
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();

        if ($.initialized) revert AlreadyInitialized();
        if (registry_ == address(0)) revert InvalidRegistry();

        $.registry = registry_;
        $.initialized = true;
        $.name = name_;
        $.version = version_;
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract address
    /// @return The kRegistry contract address
    /// @dev Reverts if contract not initialized
    function registry() external view returns (address) {
        return address(_registry());
    }

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    function _registry() internal view returns (IkRegistry) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return IkRegistry($.registry);
    }

    /*//////////////////////////////////////////////////////////////
                                RESCUER
    //////////////////////////////////////////////////////////////*/

    /// @notice rescues locked assets (ETH or ERC20) in the contract
    /// @param asset_ the asset to rescue (use address(0) for ETH)
    /// @param to_ the address that will receive the assets
    /// @param amount_ the amount to rescue
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        if (to_ == address(0)) revert ZeroAddress();

        if (asset_ == address(0)) {
            // Rescue ETH
            if (amount_ == 0 || amount_ > address(this).balance) revert ZeroAmount();

            (bool success,) = to_.call{ value: amount_ }("");
            if (!success) revert TransferFailed();

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            if (_isAsset(asset_)) revert WrongAsset();
            if (amount_ == 0 || amount_ > asset_.balanceOf(address(this))) revert ZeroAmount();

            asset_.safeTransfer(to_, amount_);
            emit RescuedAssets(asset_, to_, amount_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           GETTERS
    //////////////////////////////////////////////////////////////*/

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
                            VALIDATORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an address is a admin
    /// @return Whether the address is a admin
    function _isAdmin(address user) internal view returns (bool) {
        return _registry().isAdmin(user);
    }

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _isKAssetRouter(address user) internal view returns (bool) {
        bool isTrue;
        address _kAssetRouter = _registry().getContractById(K_ASSET_ROUTER);
        if (_kAssetRouter == user) isTrue = true;
        return isTrue;
    }

    /// @notice Checks if an asset is registered
    /// @param asset The asset address to check
    /// @return Whether the asset is registered
    function _isAsset(address asset) internal view returns (bool) {
        return _registry().isAsset(asset);
    }
}
