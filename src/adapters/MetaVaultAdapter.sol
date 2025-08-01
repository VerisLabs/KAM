// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import { IMetaVault } from "src/interfaces/IMetaVault.sol";

/// @title MetaVaultAdapter
/// @notice Adapter for DeFi protocol integrations using IMetaVault interface
/// @dev Handles complex DeFi interactions with request/claim patterns and share conversions
contract MetaVaultAdapter is BaseAdapter {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultDestinationUpdated(address indexed vault, address indexed oldVault, address indexed newVault);
    event RedemptionQueued(uint256 indexed requestId, address indexed vault, uint256 shares);

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
        mapping(address vault => IMetaVault metaVault) vaultDestinations;
        mapping(uint256 requestId => PendingRedemption) pendingRedemptions;
        uint256 nextRequestId;
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
        // Intentionally empty - do not disable initializers
        // This allows the proxy to initialize properly
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the MetaVault adapter
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    function initialize(address registry_, address owner_, address admin_) external initializer {
        __BaseAdapter_init(registry_, owner_, admin_, "MetaVaultAdapter", "1.0.0");

        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        $.nextRequestId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets to MetaVault strategy
    /// @param asset The asset to deposit
    /// @param amount The amount to deposit
    /// @param onBehalfOf The vault address this deposit is for
    function _deposit(address asset, uint256 amount, address onBehalfOf) internal override {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[onBehalfOf];
        if (address(metaVault) == address(0)) revert MetaVaultNotSet();

        // Transfer assets from kAssetRouter to this contract
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Approve MetaVault to spend assets
        asset.safeApprove(address(metaVault), amount);

        // Deposit to MetaVault and receive shares
        uint256 shares = metaVault.deposit(amount, address(this));

        // Track shares (not assets) in adapter balance for MetaVault
        _adapterDeposit(onBehalfOf, asset, shares);

        emit Deposited(asset, amount, onBehalfOf);
    }

    /// @notice Processes redemption request from MetaVault strategy
    /// @param asset The asset to redeem
    /// @param amount The amount to redeem (in underlying assets)
    /// @param onBehalfOf The vault address this redemption is for
    function _redeem(address asset, uint256 amount, address onBehalfOf) internal override {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[onBehalfOf];
        if (address(metaVault) == address(0)) revert MetaVaultNotSet();

        // Convert amount (assets) to shares
        uint256 shares = metaVault.convertToShares(amount);

        // Request redemption from MetaVault
        uint256 metaVaultRequestId = metaVault.requestRedeem(shares, address(this), address(this));

        // Store pending redemption with our internal request ID
        uint256 requestId = $.nextRequestId++;
        $.pendingRedemptions[requestId] = PendingRedemption({
            vault: onBehalfOf,
            asset: asset,
            shares: shares,
            metaVaultRequestId: metaVaultRequestId,
            processed: false
        });

        // Update adapter balance (remove shares)
        _adapterRedeem(onBehalfOf, asset, shares);

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

        IMetaVault metaVault = $.vaultDestinations[pending.vault];

        // Check if redemption is ready
        uint256 claimableShares = metaVault.claimableRedeemRequest(address(this));
        if (claimableShares < pending.shares) revert RedemptionNotReady();

        // Process redemption from MetaVault
        assets = metaVault.redeem(pending.shares, _getKAssetRouter(), address(this));

        // Mark as processed
        pending.processed = true;

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

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current total assets across all MetaVaults for this asset
    /// @param asset The asset to query
    /// @return Total assets currently deployed in MetaVault strategies managed by this adapter
    function totalAssets(address asset) external view override returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        // Sum adapter balances across all vaults using this adapter for this asset
        uint256 total = 0;
        address[] memory vaults = _registry().getVaultsByAsset(asset);

        for (uint256 i = 0; i < vaults.length; i++) {
            // Only count if this vault uses this adapter
            if (_registry().getAdapter(vaults[i]) == address(this)) {
                IMetaVault metaVault = $.vaultDestinations[vaults[i]];
                if (address(metaVault) != address(0)) {
                    // Get shares for this vault and convert to assets
                    uint256 shares = this.adapterBalance(vaults[i], asset);
                    total += metaVault.convertToAssets(shares);
                }
            }
        }

        return total;
    }

    /// @notice Returns estimated total assets including pending yield
    /// @param asset The asset to query
    /// @return Estimated total assets including unrealized gains
    function estimatedTotalAssets(address asset) external view override returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        // Sum estimated assets across all vaults using this adapter for this asset
        uint256 total = 0;
        address[] memory vaults = _registry().getVaultsByAsset(asset);

        for (uint256 i = 0; i < vaults.length; i++) {
            // Only count if this vault uses this adapter
            if (_registry().getAdapter(vaults[i]) == address(this)) {
                IMetaVault metaVault = $.vaultDestinations[vaults[i]];
                if (address(metaVault) != address(0)) {
                    // Get shares for this vault and use share price for estimation
                    uint256 shares = this.adapterBalance(vaults[i], asset);
                    uint256 sharePrice = metaVault.sharePrice();
                    total += shares.mulWad(sharePrice);
                }
            }
        }

        return total;
    }

    /// @notice Returns the current total assets for a specific vault
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Total assets currently deployed in MetaVault for this vault
    function totalAssetsForVault(address vault, address asset) external view override returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[vault];
        if (address(metaVault) == address(0)) return 0;

        // Get shares for this vault and convert to assets
        uint256 shares = this.adapterBalance(vault, asset);
        return metaVault.convertToAssets(shares);
    }

    /// @notice Returns estimated total assets for a specific vault including pending yield
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Estimated total assets including unrealized gains for this vault
    function estimatedTotalAssetsForVault(address vault, address asset) external view override returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[vault];
        if (address(metaVault) == address(0)) return 0;

        // Get shares for this vault and use share price for estimation
        uint256 shares = this.adapterBalance(vault, asset);
        uint256 sharePrice = metaVault.sharePrice();
        return shares.mulWad(sharePrice);
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

    /// @notice Returns the number of claimable shares for this adapter
    /// @param vault The vault to query
    /// @return Claimable shares from MetaVault
    function getClaimableShares(address vault) external view returns (uint256) {
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        IMetaVault metaVault = $.vaultDestinations[vault];
        if (address(metaVault) == address(0)) return 0;

        return metaVault.claimableRedeemRequest(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the MetaVault for a vault
    /// @param vault The vault address
    /// @param metaVault The MetaVault address for this vault
    function setVaultDestination(address vault, address metaVault) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0) || metaVault == address(0)) {
            revert InvalidMetaVault();
        }

        // Validate vault is registered
        if (!_registry().isVault(vault)) {
            revert InvalidMetaVault();
        }

        // Validate MetaVault asset matches vault asset
        address vaultAsset = _registry().getVaultAsset(vault);
        if (IMetaVault(metaVault).asset() != vaultAsset) revert InvalidMetaVault();

        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();
        address oldVault = address($.vaultDestinations[vault]);
        $.vaultDestinations[vault] = IMetaVault(metaVault);

        emit VaultDestinationUpdated(vault, oldVault, metaVault);
    }

    /*//////////////////////////////////////////////////////////////
                          EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency withdrawal from MetaVault
    /// @param asset Asset to withdraw
    /// @param amount Amount to withdraw (in shares)
    /// @param to Recipient address
    function _emergencyWithdraw(address asset, uint256 amount, address to) internal override {
        // For emergency withdrawals, we need to withdraw from all MetaVaults
        // This is a last resort function
        MetaVaultAdapterStorage storage $ = _getMetaVaultAdapterStorage();

        address[] memory vaults = _registry().getVaultsByAsset(asset);

        for (uint256 i = 0; i < vaults.length; i++) {
            if (_registry().getAdapter(vaults[i]) == address(this)) {
                IMetaVault metaVault = $.vaultDestinations[vaults[i]];
                if (address(metaVault) != address(0)) {
                    // Emergency redeem all shares directly to recipient
                    uint256 shares = metaVault.balanceOf(address(this));
                    if (shares > 0) {
                        metaVault.redeem(shares, to, address(this));
                    }
                }
            }
        }
    }
}
