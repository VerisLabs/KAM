// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import { IMetaVault } from "src/interfaces/IMetaVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title MetaVaultAdapter
/// @notice Adapter for DeFi protocol integrations using IMetaVault interface
/// @dev Handles complex DeFi interactions with request/claim patterns and share conversions
contract MetaVaultAdapter is BaseAdapter, Initializable, UUPSUpgradeable {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;
    using EnumerableSetLib for EnumerableSetLib.Uint256Set;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultDestinationUpdated(address indexed vault, address indexed oldVault, address indexed newVault);
    event RedemptionQueued(uint256 indexed requestId, address indexed vault, uint256 shares);
    event Deposited(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event RedemptionRequested(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event RedemptionProcessed(uint256 indexed requestId, uint256 assets);
    event Initialized(address indexed registry, address indexed owner, address indexed admin);
    event TotalAssetsUpdated(address indexed vault, address indexed asset, uint256 totalAssets);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error MetaVaultNotSet();
    error InvalidMetaVault();
    error RedemptionNotReady();
    error InvalidRequestId();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.MetaVaultAdapter
    struct MetaVaultAdapterStorage {
        uint256 nextRequestId;
        mapping(uint256 requestId => PendingRedemption) pendingRedemptions;
        mapping(address vault => EnumerableSetLib.Uint256Set) vaultPendingRedemptions;
        mapping(address vault => address asset) vaultAsset;
        mapping(address vault => mapping(address asset => uint256 totalShares)) adapterTotalShares;
        mapping(address vault => IMetaVault metaVault) vaultDestinations;
        mapping(address vault => mapping(address asset => uint256 lastAssets)) lastTotalAssets;
    }

    struct PendingRedemption {
        address vault;
        address asset;
        uint256 shares;
        uint256 metaVaultRequestId;
        bool processed;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.MetaVaultAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant METAVAULT_ADAPTER_STORAGE_LOCATION =
        0x3f68094a4ea432eac02d84a1a05d9f7b554c537178acbf8854a838d55efe7300;

    function _getMetaVaultAdapterStorage() internal pure returns (MetaVaultAdapterStorage storage $) {
        assembly {
            $.slot := METAVAULT_ADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Empty constructor to ensure clean initialization state
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the MetaVault adapter
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    function initialize(address registry_, address owner_, address admin_) external initializer {
        __BaseAdapter_init(registry_, owner_, admin_, "MetaVaultAdapter", "1.0.0");

        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        $.nextRequestId = 1;

        emit Initialized(registry_, owner_, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets to MetaVault strategy
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
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[onBehalfOf];
        if (address(metaVault) == address(0)) revert MetaVaultNotSet();

        // Transfer assets from kAssetRouter to this contract
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Approve MetaVault to spend assets
        asset.safeApprove(address(metaVault), amount);

        // Deposit to MetaVault and receive shares
        // Set Controller!?
        metaVault.requestDeposit(amount, address(this), address(this));
        uint256 shares = metaVault.deposit(amount, address(this));
        $.adapterTotalShares[onBehalfOf][asset] += shares;

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
        nonReentrant
        onlyKAssetRouter
        whenRegistered
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();
        if (onBehalfOf == address(0)) revert InvalidAsset();

        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[onBehalfOf];
        if (address(metaVault) == address(0)) revert MetaVaultNotSet();

        uint256 shares = metaVault.convertToShares(amount);
        $.adapterTotalShares[onBehalfOf][asset] -= shares;

        // Request redemption from MetaVault
        uint256 metaVaultRequestId = metaVault.requestRedeem(shares, _getKAssetRouter(), onBehalfOf);

        // Store pending redemption with our internal request ID
        uint256 requestId = $.nextRequestId++;
        $.pendingRedemptions[requestId] = PendingRedemption({
            vault: onBehalfOf,
            asset: asset,
            shares: shares,
            metaVaultRequestId: metaVaultRequestId,
            processed: false
        });

        if ($.vaultPendingRedemptions[onBehalfOf].contains(requestId)) revert InvalidRequestId();
        $.vaultPendingRedemptions[onBehalfOf].add(requestId);

        emit RedemptionRequested(asset, amount, onBehalfOf);
        emit RedemptionQueued(requestId, onBehalfOf, shares);
    }

    /*//////////////////////////////////////////////////////////////
                          REDEMPTION PROCESSING
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes a pending redemption when ready
    /// @param requestId The internal request ID to process
    /// @return assets The amount of assets received
    function processRedemption(uint256 requestId) external onlyRelayer returns (uint256 assets) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        PendingRedemption storage pending = $.pendingRedemptions[requestId];
        if (pending.vault == address(0)) revert InvalidRequestId();
        if (pending.processed) revert RedemptionNotReady();
        pending.processed = true;

        IMetaVault metaVault = $.vaultDestinations[pending.vault];

        // Check if redemption is ready
        uint256 claimableShares = metaVault.claimableRedeemRequest(pending.vault);
        if (claimableShares < pending.shares) revert RedemptionNotReady();

        if (!$.vaultPendingRedemptions[pending.vault].contains(requestId)) revert InvalidRequestId();
        $.vaultPendingRedemptions[pending.vault].remove(requestId);

        // Process redemption from MetaVault
        assets = metaVault.redeem(pending.shares, pending.vault, _getKAssetRouter());

        emit RedemptionProcessed(requestId, assets);
    }

    /// @notice Batch processes multiple redemptions
    /// @param requestIds Array of request IDs to process
    /// @return totalAssetsReceived Total assets received from all redemptions
    function batchProcessRedemptions(uint256[] calldata requestIds)
        external
        onlyRelayer
        returns (uint256 totalAssetsReceived)
    {
        for (uint256 i = 0; i < requestIds.length; i++) {
            totalAssetsReceived += this.processRedemption(requestIds[i]);
        }
    }

    /// @notice Sets the total assets for a given vault
    /// @param vault The vault address
    /// @param totalAssets_ The total assets to set
    function setTotalAssets(address vault, address asset, uint256 totalAssets_) external onlyKAssetRouter {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        $.lastTotalAssets[vault][asset] = totalAssets_;

        emit TotalAssetsUpdated(vault, asset, totalAssets_);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the last total assets for a given vault and asset
    /// @param vault The vault address
    /// @param asset The asset address
    /// @return The last total assets for the vault and asset
    function getLastTotalAssets(address vault, address asset) external view returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        return $.lastTotalAssets[vault][asset];
    }

    /// @notice Returns the adapter balance for a specific vault and asset
    /// @param vault The vault address
    /// @param asset The asset address
    /// @return Adapter balance for the vault
    function totalAssets(address vault, address asset) external view returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        IMetaVault metaVault = $.vaultDestinations[vault];
        uint256 balance = $.adapterTotalShares[vault][asset];
        uint256 totalAssets_ = metaVault.convertToAssets(balance); // + insuranceFund
        uint256 totalKTokens = IkToken(asset).totalSupply();
        if (totalAssets_ > totalKTokens) return totalKTokens;
        return totalAssets_;
    }

    /// @notice Returns the current total assets for a specific vault
    /// @param vault The vault address
    /// @return Total assets currently deployed in MetaVault for this vault
    function totalShares(address vault) external view returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[vault];
        if (address(metaVault) == address(0)) return 0;

        return metaVault.balanceOf(vault);
    }

    /// @notice Returns the MetaVault for a given vault
    /// @param vault The vault address
    /// @return The MetaVault address for the vault
    function getVaultDestination(address vault) external view returns (address) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        return address($.vaultDestinations[vault]);
    }

    /// @notice Returns details about a pending redemption
    /// @param requestId The request ID to query
    /// @return vault The vault address
    /// @return asset The asset address
    /// @return shares The number of shares being redeemed
    /// @return processed Whether the redemption has been processed
    function getPendingRedemption(uint256 requestId)
        external
        view
        returns (address vault, address asset, uint256 shares, bool processed)
    {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        PendingRedemption storage pending = $.pendingRedemptions[requestId];

        return (pending.vault, pending.asset, pending.shares, pending.processed);
    }

    /// @notice Returns the pending redemptions for a vault
    /// @param vault The vault address
    /// @return Pending redemptions for the vault
    function getPendingRedemptions(address vault) external view returns (uint256[] memory) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        return $.vaultPendingRedemptions[vault].values();
    }

    /// @notice Returns the number of claimable shares for this adapter
    /// @param vault The vault to query
    /// @return Claimable shares from MetaVault
    function getClaimableShares(address vault) external view returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[vault];
        if (address(metaVault) == address(0)) return 0;

        return metaVault.claimableRedeemRequest(address(this));
    }

    function convertToAssets(address vault, uint256 shares) external view returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        IMetaVault metaVault = $.vaultDestinations[vault];
        return metaVault.convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the MetaVault for a vault
    /// @param vault The vault address
    /// @param metaVault The MetaVault address for this vault
    function setVaultDestination(address vault, address asset_, address metaVault) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0) || metaVault == address(0)) {
            revert InvalidMetaVault();
        }

        // Validate vault is registered
        if (!_registry().isVault(vault)) {
            revert InvalidMetaVault();
        }

        if (IMetaVault(metaVault).asset() != asset_) revert InvalidMetaVault();

        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        address oldVault = address($.vaultDestinations[vault]);
        $.vaultDestinations[vault] = IMetaVault(metaVault);

        emit VaultDestinationUpdated(vault, oldVault, metaVault);
    }

    /*//////////////////////////////////////////////////////////////
                          EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency withdrawal function - must be implemented by child contracts
    /// @param vault Vault to withdraw from
    /// @param asset Asset to withdraw
    /// @param amount Amount to withdraw
    function emergencyWithdraw(
        address vault,
        address asset,
        uint256 amount
    )
        external
        virtual
        onlyRoles(EMERGENCY_ADMIN_ROLE)
    {
        if (asset == address(0)) revert InvalidAsset();
        if (amount == 0) revert InvalidAmount();

        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        IMetaVault metaVault = $.vaultDestinations[vault];
        if (address(metaVault) != address(0)) {
            // Emergency redeem all shares directly to recipient
            uint256 shares = metaVault.balanceOf(vault);
            if (shares > 0) {
                metaVault.redeem(shares, vault, _getKAssetRouter());
            }
        }
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
