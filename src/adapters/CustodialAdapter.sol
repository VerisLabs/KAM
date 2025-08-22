// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { BaseAdapter } from "src/adapters/BaseAdapter.sol";

/// @title CustodialAdapter
/// @notice Adapter for custodial address integrations (CEX, CEFFU, etc.)
/// @dev Simple adapter that transfers assets to custodial addresses and tracks virtual balances
contract CustodialAdapter is BaseAdapter, Initializable, UUPSUpgradeable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultDestinationUpdated(address indexed vault, address indexed oldAddress, address indexed newAddress);
    event TotalAssetsUpdated(address indexed vault, uint256 totalAssets);
    event Deposited(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event RedemptionRequested(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event RedemptionProcessed(uint256 indexed requestId, uint256 assets);
    event AdapterBalanceUpdated(address indexed vault, address indexed asset, uint256 newBalance);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCustodialAddress();
    error VaultDestinationNotSet();
    error AssetsNotTranfered();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.CustodialAdapter
    struct CustodialAdapterStorage {
        uint256 nextRequestId;
        mapping(address vault => mapping(address asset => uint256 balance)) balanceOf;
        mapping(address vault => mapping(address asset => uint256 totalAssets)) totalAssets;
        mapping(address vault => address custodialAddress) vaultDestinations;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.CustodialAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CUSTODIAL_ADAPTER_STORAGE_LOCATION =
        0x6096605776f37a069e5fb3b2282c592b4e41a8f7c82e8665fde33e5acbdbaf00;

    function _getCustodialAdapterStorage() internal pure returns (CustodialAdapterStorage storage $) {
        assembly {
            $.slot := CUSTODIAL_ADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Empty constructor to ensure clean initialization state
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the MetaVault adapter
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    function initialize(address registry_, address owner_, address admin_) external initializer {
        __BaseAdapter_init(registry_, owner_, admin_, "CustodialAdapter", "1.0.0");

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        $.nextRequestId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets to external strategy
    /// @param asset The asset to deposit
    /// @param amount The amount to deposit
    /// @param onBehalfOf The vault address this deposit is for
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf
    )
        external
        nonReentrant
        onlyKAssetRouter
        whenRegistered
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();
        if (onBehalfOf == address(0)) revert InvalidAsset();

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        address custodialAddress = $.vaultDestinations[onBehalfOf];
        if (custodialAddress == address(0)) revert VaultDestinationNotSet();

        // Validate if the assets are available
        if (asset.balanceOf(address(this)) < amount) {
            revert AssetsNotTranfered();
        }

        // Update adapter balance tracking
        $.balanceOf[onBehalfOf][asset] += amount;

        emit Deposited(asset, amount, onBehalfOf);
    }

    /// @notice Redeems assets from external strategy
    /// @param asset The asset to redeem
    /// @param amount The amount to redeem
    /// @param onBehalfOf The vault address this redemption is for
    function redeem(
        address asset,
        uint256 amount,
        address onBehalfOf
    )
        external
        virtual
        nonReentrant
        onlyKAssetRouter
        whenRegistered
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();
        if (onBehalfOf == address(0)) revert InvalidAsset();

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        address custodialAddress = $.vaultDestinations[onBehalfOf];
        if (custodialAddress == address(0)) revert VaultDestinationNotSet();

        // Update adapter balance tracking
        $.balanceOf[onBehalfOf][asset] -= amount;

        emit RedemptionRequested(asset, amount, onBehalfOf);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current total assets across all custodial addresses for this asset
    /// @param vault The vault to query
    /// @return Total assets currently held across all custodial addresses managed by this adapter
    function totalEstimatedAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        address custodialAddress = $.vaultDestinations[vault];
        return asset.balanceOf(custodialAddress);
    }

    /// @notice Returns the total assets in storage for a given vault
    /// @param vault The vault address
    /// @return Total assets currently held in storage for this vault
    function totalVirtualAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.balanceOf[vault][asset];
    }

    /// @notice Returns the total assets for a given vault and asset
    /// @param vault The vault address
    /// @return Total assets currently held for this vault and asset
    function totalAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.totalAssets[vault][asset];
    }

    /// @notice Returns the last total assets for a given vault and asset
    /// @param vault The vault address
    /// @param asset The asset address
    /// @return The last total assets for the vault and asset
    function getLastTotalAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.totalAssets[vault][asset];
    }

    /// @notice Returns the custodial address for a given vault
    /// @param vault The vault address
    /// @return The custodial address for the vault
    function getVaultDestination(address vault) external view returns (address) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.vaultDestinations[vault];
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the custodial address for a vault
    /// @param vault The vault address
    /// @param custodialAddress The custodial address for this vault
    function setVaultDestination(address vault, address custodialAddress) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0) || custodialAddress == address(0)) {
            revert InvalidCustodialAddress();
        }

        // Validate vault is registered
        if (!_registry().isVault(vault)) {
            revert InvalidCustodialAddress();
        }

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        address oldAddress = $.vaultDestinations[vault];
        $.vaultDestinations[vault] = custodialAddress;

        emit VaultDestinationUpdated(vault, oldAddress, custodialAddress);
    }

    /// @notice Sets the total assets for a given vault
    /// @param vault The vault address
    /// @param totalAssets_ The total assets to set
    function setTotalAssets(address vault, address asset, uint256 totalAssets_) external onlyKAssetRouter {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        $.totalAssets[vault][asset] = totalAssets_;

        emit TotalAssetsUpdated(vault, totalAssets_);
    }

    /*//////////////////////////////////////////////////////////////
                          UPGRADE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize contract upgrade
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
    }
}
