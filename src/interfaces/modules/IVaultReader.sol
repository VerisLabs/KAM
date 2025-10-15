// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { IVersioned } from "kam/src/interfaces/IVersioned.sol";
import { BaseVaultTypes } from "kam/src/kStakingVault/types/BaseVaultTypes.sol";

/// @title IVaultReader
/// @notice Read-only interface for querying vault state, calculations, and metrics without modifying contract state
/// @dev This interface provides comprehensive access to vault information for external integrations, front-ends, and
/// analytics without gas costs or state modifications. The interface covers several key areas: (1) Configuration:
/// Registry references, underlying assets, and fee parameters, (2) Financial Metrics: Share prices, total assets,
/// and fee calculations for accurate vault valuation, (3) Batch Information: Current and historical batch states
/// for settlement tracking, (4) Fee Calculations: Real-time fee accruals and next fee timestamps, (5) Safety Functions:
/// Validated batch ID and receiver retrieval preventing errors. This read-only approach enables efficient monitoring
/// and integration while maintaining clear separation from state-modifying operations. All calculations reflect current
/// vault state including pending fees and accrued yields, providing accurate real-time vault metrics for users and
/// integrations.
interface IVaultReader is IVersioned {
    /// @notice Returns the protocol registry address for configuration and role management
    /// @return Address of the kRegistry contract managing protocol-wide settings
    function registry() external view returns (address);

    /// @notice Returns the vault's share token (stkToken) address for ERC20 operations
    /// @return Address of this vault's stkToken contract representing user shares
    function asset() external view returns (address);

    /// @notice Returns the underlying asset address that this vault generates yield on
    /// @return Address of the base asset (USDC, WBTC, etc.) managed by this vault
    function underlyingAsset() external view returns (address);

    /// @notice Calculates accumulated fees for the current period including management and performance components
    /// @dev Computes real-time fee accruals based on time elapsed and vault performance since last fee charge.
    /// Management fees accrue continuously based on assets under management and time passed. Performance fees
    /// are calculated on share price appreciation above watermarks and hurdle rates. This function provides
    /// accurate fee projections for settlement planning and user transparency without modifying state.
    /// @return managementFees Accrued management fees in underlying asset terms
    /// @return performanceFees Accrued performance fees in underlying asset terms
    /// @return totalFees Combined management and performance fees for total fee burden
    function computeLastBatchFees()
        external
        view
        returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees);

    /// @notice Returns the timestamp when management fees were last processed
    /// @return Timestamp of last management fee charge for accrual calculations
    function lastFeesChargedManagement() external view returns (uint256);

    /// @notice Returns the timestamp when performance fees were last processed
    /// @return Timestamp of last performance fee charge for watermark tracking
    function lastFeesChargedPerformance() external view returns (uint256);

    /// @notice Returns the hurdle rate threshold for performance fee calculations
    /// @return Hurdle rate in basis points that vault performance must exceed
    function hurdleRate() external view returns (uint16);

    /// @notice Returns whether the current hurdle rate is a hard hurdle rate
    /// @return True if the current hurdle rate is a hard hurdle rate, false otherwise
    function isHardHurdleRate() external view returns (bool);

    /// @notice Returns the current performance fee rate charged on excess returns
    /// @return Performance fee rate in basis points (1% = 100)
    function performanceFee() external view returns (uint16);

    /// @notice Calculates the next timestamp when performance fees can be charged
    /// @return Projected timestamp for next performance fee evaluation
    function nextPerformanceFeeTimestamp() external view returns (uint256);

    /// @notice Calculates the next timestamp when management fees can be charged
    /// @return Projected timestamp for next management fee evaluation
    function nextManagementFeeTimestamp() external view returns (uint256);

    /// @notice Returns the current management fee rate charged on assets under management
    /// @return Management fee rate in basis points (1% = 100)
    function managementFee() external view returns (uint16);

    /// @notice Returns the high watermark used for performance fee calculations
    /// @dev The watermark tracks the highest share price achieved, ensuring performance fees are only
    /// charged on new highs and preventing double-charging on recovered losses. Reset occurs when new
    /// high watermarks are achieved, establishing a new baseline for future performance fee calculations.
    /// @return Current high watermark share price in underlying asset terms
    function sharePriceWatermark() external view returns (uint256);

    /// @notice Checks if the current batch is closed to new requests
    /// @return True if current batch is closed and awaiting settlement
    function isBatchClosed() external view returns (bool);

    /// @notice Checks if the current batch has been settled with finalized prices
    /// @return True if current batch is settled and ready for claims
    function isBatchSettled() external view returns (bool);

    /// @notice Returns comprehensive information about the current batch
    /// @return batchId Current batch identifier
    /// @return batchReceiver Address of batch receiver contract (may be zero if not created)
    /// @return isClosed Whether the batch is closed to new requests
    /// @return isSettled Whether the batch has been settled
    function getCurrentBatchInfo()
        external
        view
        returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled);

    /// @notice Returns comprehensive information about a specific batch
    /// @param batchId The batch identifier to query
    /// @return batchReceiver Address of batch receiver contract (may be zero if not deployed)
    /// @return isClosed Whether the batch is closed to new requests
    /// @return isSettled Whether the batch has been settled
    /// @return sharePrice Share price of settlement
    /// @return netSharePrice Net share price of settlement
    function getBatchIdInfo(bytes32 batchId)
        external
        view
        returns (address batchReceiver, bool isClosed, bool isSettled, uint256 sharePrice, uint256 netSharePrice);

    /// @notice Returns the batch receiver address for a specific batch ID
    /// @param batchId The batch identifier to query
    /// @return Address of the batch receiver (may be zero if not deployed)
    function getBatchReceiver(bytes32 batchId) external view returns (address);

    /// @notice Returns batch receiver address with validation, creating if necessary
    /// @param batchId The batch identifier to query
    /// @return Address of the batch receiver (guaranteed non-zero)
    function getSafeBatchReceiver(bytes32 batchId) external view returns (address);

    /// @notice Calculates current share price including all accrued yields
    /// @dev Returns net share price after fee deductions, reflecting total vault performance.
    /// Used for settlement calculations and performance tracking.
    /// @return Share price per stkToken in underlying asset terms (scaled to token decimals)
    function netSharePrice() external view returns (uint256);

    /// @notice Calculates current share price including all accrued yields
    /// @dev Returns gross share price before fee deductions, reflecting total vault performance.
    /// Used for settlement calculations and performance tracking.
    /// @return Share price per stkToken in underlying asset terms (scaled to token decimals)
    function sharePrice() external view returns (uint256);

    /// @notice Returns total assets under management including pending fees
    /// @return Total asset value managed by the vault in underlying asset terms
    function totalAssets() external view returns (uint256);

    /// @notice Returns net assets after deducting accumulated fees
    /// @dev Provides user-facing asset value after management and performance fee deductions.
    /// Used for accurate user balance calculations and net yield reporting.
    /// @return Net asset value available to users after fee deductions
    function totalNetAssets() external view returns (uint256);

    /// @notice Returns the current active batch identifier
    /// @return Current batch ID for new requests
    function getBatchId() external view returns (bytes32);

    /// @notice Returns current batch ID with safety validation
    /// @return Current batch ID (guaranteed to be valid and initialized)
    function getSafeBatchId() external view returns (bytes32);

    /// @notice Converts a given amount of shares to assets
    /// @param shares The amount of shares to convert
    /// @return The equivalent amount of assets
    function convertToShares(uint256 shares) external view returns (uint256);

    /// @notice Converts a given amount of assets to shares
    /// @param assets The amount of assets to convert
    /// @return The equivalent amount of shares
    function convertToAssets(uint256 assets) external view returns (uint256);

    /// @notice Converts a given amount of shares to assets with a specified total assets
    /// @param shares The amount of shares to convert
    /// @param totalAssets The total assets available for conversion
    /// @return The equivalent amount of assets
    function convertToAssetsWithTotals(uint256 shares, uint256 totalAssets) external view returns (uint256);

    /// @notice Converts a given amount of assets to shares with a specified total assets
    /// @param assets The amount of assets to convert
    /// @param totalAssets The total assets available for conversion
    /// @return The equivalent amount of shares
    function convertToSharesWithTotals(uint256 assets, uint256 totalAssets) external view returns (uint256);

    /// @notice Gets all request IDs associated with a user
    /// @param user The address to query requests for
    /// @return requestIds An array of all request IDs (both stake and unstake) for the user
    function getUserRequests(address user) external view returns (bytes32[] memory requestIds);

    /// @notice Gets the details of a specific stake request
    /// @param requestId The unique identifier of the stake request
    /// @return stakeRequest The stake request struct containing all request details
    function getStakeRequest(bytes32 requestId) external view returns (BaseVaultTypes.StakeRequest memory stakeRequest);

    /// @notice Gets the details of a specific unstake request
    /// @param requestId The unique identifier of the unstake request
    /// @return unstakeRequest The unstake request struct containing all request details
    function getUnstakeRequest(bytes32 requestId)
        external
        view
        returns (BaseVaultTypes.UnstakeRequest memory unstakeRequest);

    /// @notice Returns the total pending stake amount
    /// @return Total pending stake amount
    function getTotalPendingStake() external view returns (uint256);

    /// @notice Returns the close state of a given batchId
    /// @param batchId_ the batchId to verify
    /// @return isClosed_ the state of the given batchId
    function isClosed(bytes32 batchId_) external view returns (bool isClosed_);
}
