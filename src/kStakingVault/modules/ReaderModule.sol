// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Extsload } from "src/abstracts/Extsload.sol";
import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";

import { NOT_INITIALIZED, VAULT_SETTLED } from "src/errors/Errors.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title ReaderModule
/// @notice Contains all the public getters for the Staking Vault
contract ReaderModule is BaseVaultModule, Extsload {
    using FixedPointMathLib for uint256;

    /// @notice Interval for management fee (1 month)
    uint256 constant MANAGEMENT_FEE_INTERVAL = 657_436;
    /// @notice Interval for performance fee (3 months)
    uint256 constant PERFORMANCE_FEE_INTERVAL = 7_889_238;

    /// @notice Maximum basis points
    uint256 constant MAX_BPS = 10_000;
    /// @notice Number of seconds in a year
    uint256 constant SECS_PER_YEAR = 31_556_952;

    /// GENERAL
    function registry() external view returns (address) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        require(_getInitialized($), NOT_INITIALIZED);
        return $.registry;
    }

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
        return _getBaseVaultModuleStorage().kToken;
    }

    /// @notice Returns the underlying asset address
    /// @return Asset address
    function underlyingAsset() external view returns (address) {
        return _getBaseVaultModuleStorage().underlyingAsset;
    }

    /// FEES

    /// @notice Computes the last fee batch
    /// @return managementFees The management fees for the last batch
    /// @return performanceFees The performance fees for the last batch
    /// @return totalFees The total fees for the last batch
    function computeLastBatchFees()
        external
        view
        returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees)
    {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        uint256 lastSharePrice = $.sharePriceWatermark;

        uint256 lastFeesChargedManagement = _getLastFeesChargedManagement($);
        uint256 lastFeesChargedPerformance = _getLastFeesChargedPerformance($);

        uint256 durationManagement = block.timestamp - lastFeesChargedManagement;
        uint256 durationPerformance = block.timestamp - lastFeesChargedPerformance;
        uint256 currentTotalAssets = _totalAssets();
        uint256 lastTotalAssets = totalSupply().fullMulDiv(lastSharePrice, 10 ** _getDecimals($));

        // Calculate time-based fees (management)
        // These are charged on total assets, prorated for the time period
        managementFees =
            (currentTotalAssets * durationManagement).fullMulDiv(_getManagementFee($), SECS_PER_YEAR) / MAX_BPS;
        currentTotalAssets -= managementFees;
        totalFees = managementFees;

        // Calculate the asset's value change since entry
        // This gives us the raw profit/loss in asset terms after management fees
        int256 assetsDelta = int256(currentTotalAssets) - int256(lastTotalAssets);

        // Only calculate fees if there's a profit
        if (assetsDelta > 0) {
            uint256 excessReturn;

            // Calculate returns relative to hurdle rate
            uint256 hurdleReturn =
                (lastTotalAssets * _getHurdleRate($)).fullMulDiv(durationPerformance, SECS_PER_YEAR) / MAX_BPS;

            // Calculate returns relative to hurdle rate
            uint256 totalReturn = uint256(assetsDelta);

            // Only charge performance fees if:
            // 1. Current share price is not below
            // 2. Returns exceed hurdle rate
            if (totalReturn > hurdleReturn) {
                // Only charge performance fees on returns above hurdle rate
                excessReturn = totalReturn - hurdleReturn;

                // If its a hard hurdle rate, only charge fees above the hurdle performance
                // Otherwise, charge fees to all return if its above hurdle return
                if (_getIsHardHurdleRate($)) {
                    performanceFees = excessReturn * _getPerformanceFee($) / MAX_BPS;
                } else {
                    performanceFees = totalReturn * _getPerformanceFee($) / MAX_BPS;
                }
            }

            // Calculate total fees
            totalFees += performanceFees;
        }

        return (managementFees, performanceFees, totalFees);
    }

    /// @notice Returns the last time management fees were charged
    /// @return lastFeesChargedManagement Timestamp of last management fee charge
    function lastFeesChargedManagement() public view returns (uint256) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        return _getLastFeesChargedManagement($);
    }

    /// @notice Returns the last time performance fees were charged
    /// @return lastFeesChargedPerformance Timestamp of last performance fee charge
    function lastFeesChargedPerformance() public view returns (uint256) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        return _getLastFeesChargedPerformance($);
    }

    /// @notice Returns the current hurdle rate used for performance fee calculations
    /// @return The hurdle rate in basis points (e.g., 500 = 5%)
    function hurdleRate() external view returns (uint16) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        return _getHurdleRate($);
    }

    /// @notice Returns the current performance fee percentage
    /// @return The performance fee in basis points (e.g., 2000 = 20%)
    function performanceFee() external view returns (uint16) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        return _getPerformanceFee($);
    }

    /// @notice Returns the next performance fee timestamp so the backend can schedule the fee collection
    /// @return The next performance fee timestamp
    function nextPerformanceFeeTimestamp() external view returns (uint256) {
        return lastFeesChargedPerformance() + PERFORMANCE_FEE_INTERVAL;
    }

    /// @notice Returns the next management fee timestamp so the backend can schedule the fee collection
    /// @return The next management fee timestamp
    function nextManagementFeeTimestamp() external view returns (uint256) {
        return lastFeesChargedManagement() + MANAGEMENT_FEE_INTERVAL;
    }

    /// @notice Returns the current management fee percentage
    /// @return The management fee in basis points (e.g., 100 = 1%)
    function managementFee() external view returns (uint16) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        return _getManagementFee($);
    }

    /// @notice Returns the high watermark for share price used in performance fee calculations
    /// @return The share price watermark value
    function sharePriceWatermark() external view returns (uint256) {
        return _getBaseVaultModuleStorage().sharePriceWatermark;
    }

    /// @notice Returns whether the current batch is closed
    /// @return Whether the current batch is closed
    function isBatchClosed() external view returns (bool) {
        return _getBaseVaultModuleStorage().batches[_getBaseVaultModuleStorage().currentBatchId].isClosed;
    }

    /// @notice Returns whether the current batch is settled
    /// @return Whether the current batch is settled
    function isBatchSettled() external view returns (bool) {
        return _getBaseVaultModuleStorage().batches[_getBaseVaultModuleStorage().currentBatchId].isSettled;
    }

    /// @notice Returns the current batch ID, whether it is closed, and whether it is settled
    /// @return batchId Current batch ID
    /// @return batchReceiver Current batch receiver
    /// @return isClosed Whether the current batch is closed
    /// @return isSettled Whether the current batch is settled
    function getBatchIdInfo()
        external
        view
        returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled)
    {
        return (
            _getBaseVaultModuleStorage().currentBatchId,
            _getBaseVaultModuleStorage().batches[_getBaseVaultModuleStorage().currentBatchId].batchReceiver,
            _getBaseVaultModuleStorage().batches[_getBaseVaultModuleStorage().currentBatchId].isClosed,
            _getBaseVaultModuleStorage().batches[_getBaseVaultModuleStorage().currentBatchId].isSettled
        );
    }

    /// @notice Returns the batch receiver for the current batch
    /// @return Batch receiver
    function getBatchIdReceiver(bytes32 batchId) external view returns (address) {
        return _getBaseVaultModuleStorage().batches[batchId].batchReceiver;
    }

    /// @notice Returns the batch receiver for a given batch (alias for getBatchIdReceiver)
    /// @return Batch receiver
    function getBatchReceiver(bytes32 batchId) external view returns (address) {
        return _getBaseVaultModuleStorage().batches[batchId].batchReceiver;
    }

    /// @notice Returns the batch receiver for a given batch (alias for getBatchIdReceiver)
    /// @return Batch receiver
    /// @dev Throws if the batch is settled
    function getSafeBatchReceiver(bytes32 batchId) external view returns (address) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        require(!$.batches[batchId].isSettled, VAULT_SETTLED);
        return $.batches[batchId].batchReceiver;
    }

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() public pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](20);
        moduleSelectors[0] = this.registry.selector;
        moduleSelectors[1] = this.asset.selector;
        moduleSelectors[2] = this.underlyingAsset.selector;
        moduleSelectors[3] = this.name.selector;
        moduleSelectors[4] = this.symbol.selector;
        moduleSelectors[5] = this.computeLastBatchFees.selector;
        moduleSelectors[6] = this.lastFeesChargedManagement.selector;
        moduleSelectors[7] = this.lastFeesChargedPerformance.selector;
        moduleSelectors[8] = this.hurdleRate.selector;
        moduleSelectors[9] = this.performanceFee.selector;
        moduleSelectors[10] = this.managementFee.selector;
        moduleSelectors[11] = this.sharePriceWatermark.selector;
        moduleSelectors[12] = this.nextPerformanceFeeTimestamp.selector;
        moduleSelectors[13] = this.nextManagementFeeTimestamp.selector;
        moduleSelectors[14] = this.isBatchClosed.selector;
        moduleSelectors[15] = this.isBatchSettled.selector;
        moduleSelectors[16] = this.getBatchIdInfo.selector;
        moduleSelectors[17] = this.getBatchIdReceiver.selector;
        moduleSelectors[18] = this.getBatchReceiver.selector;
        moduleSelectors[19] = this.getSafeBatchReceiver.selector;
        return moduleSelectors;
    }
}
