// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Extsload} from "src/abstracts/Extsload.sol";
import {BaseVault} from "src/kStakingVault/base/BaseVault.sol";
import {BaseVaultTypes} from "src/kStakingVault/types/BaseVaultTypes.sol";
import {NOT_INITIALIZED, VAULT_SETTLED, VAULT_CLOSED} from "src/errors/Errors.sol";

/// @title ReaderModule
/// @notice Contains all the public getters for the Staking Vault
contract ReaderModule is BaseVault, Extsload {
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
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(_getInitialized($), NOT_INITIALIZED);
        return $.registry;
    }

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
        return _getBaseVaultStorage().kToken;
    }

    /// @notice Returns the underlying asset address
    /// @return Asset address
    function underlyingAsset() external view returns (address) {
        return _getBaseVaultStorage().underlyingAsset;
    }

    /// FEES

    /// @notice Computes the last fee batch
    /// @return managementFees The management fees for the last batch
    /// @return performanceFees The performance fees for the last batch
    /// @return totalFees The total fees for the last batch
    function computeLastBatchFees()
        external
        view
        returns (
            uint256 managementFees,
            uint256 performanceFees,
            uint256 totalFees
        )
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint256 lastSharePrice = $.sharePriceWatermark;

        uint256 lastFeesChargedManagement = _getLastFeesChargedManagement($);
        uint256 lastFeesChargedPerformance = _getLastFeesChargedPerformance($);

        uint256 durationManagement = block.timestamp -
            lastFeesChargedManagement;
        uint256 durationPerformance = block.timestamp -
            lastFeesChargedPerformance;
        uint256 currentTotalAssets = _totalAssets();
        uint256 lastTotalAssets = totalSupply().fullMulDiv(
            lastSharePrice,
            10 ** _getDecimals($)
        );

        // Calculate time-based fees (management)
        // These are charged on total assets, prorated for the time period
        managementFees =
            (currentTotalAssets * durationManagement).fullMulDiv(
                _getManagementFee($),
                SECS_PER_YEAR
            ) /
            MAX_BPS;
        currentTotalAssets -= managementFees;
        totalFees = managementFees;

        // Calculate the asset's value change since entry
        // This gives us the raw profit/loss in asset terms after management fees
        int256 assetsDelta = int256(currentTotalAssets) -
            int256(lastTotalAssets);

        // Only calculate fees if there's a profit
        if (assetsDelta > 0) {
            uint256 excessReturn;

            // Calculate returns relative to hurdle rate
            uint256 hurdleReturn = (lastTotalAssets * _getHurdleRate($))
                .fullMulDiv(durationPerformance, SECS_PER_YEAR) / MAX_BPS;

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
                    performanceFees =
                        (excessReturn * _getPerformanceFee($)) /
                        MAX_BPS;
                } else {
                    performanceFees =
                        (totalReturn * _getPerformanceFee($)) /
                        MAX_BPS;
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
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getLastFeesChargedManagement($);
    }

    /// @notice Returns the last time performance fees were charged
    /// @return lastFeesChargedPerformance Timestamp of last performance fee charge
    function lastFeesChargedPerformance() public view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getLastFeesChargedPerformance($);
    }

    /// @notice Returns the current hurdle rate used for performance fee calculations
    /// @return The hurdle rate in basis points (e.g., 500 = 5%)
    function hurdleRate() external view returns (uint16) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getHurdleRate($);
    }

    /// @notice Returns the current performance fee percentage
    /// @return The performance fee in basis points (e.g., 2000 = 20%)
    function performanceFee() external view returns (uint16) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
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
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getManagementFee($);
    }

    /// @notice Returns the high watermark for share price used in performance fee calculations
    /// @return The share price watermark value
    function sharePriceWatermark() external view returns (uint256) {
        return _getBaseVaultStorage().sharePriceWatermark;
    }

    /// @notice Returns whether the current batch is closed
    /// @return Whether the current batch is closed
    function isBatchClosed() external view returns (bool) {
        return
            _getBaseVaultStorage()
                .batches[_getBaseVaultStorage().currentBatchId]
                .isClosed;
    }

    /// @notice Returns whether the current batch is settled
    /// @return Whether the current batch is settled
    function isBatchSettled() external view returns (bool) {
        return
            _getBaseVaultStorage()
                .batches[_getBaseVaultStorage().currentBatchId]
                .isSettled;
    }

    /// @notice Returns the current batch ID, whether it is closed, and whether it is settled
    /// @return batchId Current batch ID
    /// @return batchReceiver Current batch receiver
    /// @return isClosed Whether the current batch is closed
    /// @return isSettled Whether the current batch is settled
    function getBatchIdInfo()
        external
        view
        returns (
            bytes32 batchId,
            address batchReceiver,
            bool isClosed,
            bool isSettled
        )
    {
        return (
            _getBaseVaultStorage().currentBatchId,
            _getBaseVaultStorage()
                .batches[_getBaseVaultStorage().currentBatchId]
                .batchReceiver,
            _getBaseVaultStorage()
                .batches[_getBaseVaultStorage().currentBatchId]
                .isClosed,
            _getBaseVaultStorage()
                .batches[_getBaseVaultStorage().currentBatchId]
                .isSettled
        );
    }

    /// @notice Returns the batch receiver for a given batch (alias for getBatchIdReceiver)
    /// @return Batch receiver
    function getBatchReceiver(bytes32 batchId) external view returns (address) {
        return _getBaseVaultStorage().batches[batchId].batchReceiver;
    }

    /// @notice Returns the batch receiver for a given batch (alias for getBatchIdReceiver)
    /// @return Batch receiver
    /// @dev Throws if the batch is settled
    function getSafeBatchReceiver(
        bytes32 batchId
    ) external view returns (address) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(!$.batches[batchId].isSettled, VAULT_SETTLED);
        return $.batches[batchId].batchReceiver;
    }

    /// @notice Calculates the price of stkTokens in underlying asset terms
    /// @dev Uses the last total assets and total supply to calculate the price
    /// @return price Price per stkToken in underlying asset terms
    function sharePrice() external view returns (uint256) {
        return _netSharePrice();
    }

    /// @notice Returns the current total assets
    /// @return Total assets currently deployed in strategies
    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    /// @notice Returns the current total assets after fees
    /// @return Total net assets currently deployed in strategies
    function totalNetAssets() external view returns (uint256) {
        return _totalNetAssets();
    }

    /// @notice Returns the current batch
    /// @return Batch
    function getBatchId() public view returns (bytes32) {
        return _getBaseVaultStorage().currentBatchId;
    }

    /// @notice Returns the safe batch
    /// @return Batch
    function getSafeBatchId() external view returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        bytes32 batchId = getBatchId();
        require(!$.batches[batchId].isClosed, VAULT_CLOSED);
        require(!$.batches[batchId].isSettled, VAULT_SETTLED);
        return batchId;
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kStakingVault";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() public pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](24);
        moduleSelectors[0] = this.registry.selector;
        moduleSelectors[1] = this.asset.selector;
        moduleSelectors[2] = this.underlyingAsset.selector;
        moduleSelectors[3] = this.computeLastBatchFees.selector;
        moduleSelectors[4] = this.lastFeesChargedManagement.selector;
        moduleSelectors[5] = this.lastFeesChargedPerformance.selector;
        moduleSelectors[6] = this.hurdleRate.selector;
        moduleSelectors[7] = this.performanceFee.selector;
        moduleSelectors[8] = this.managementFee.selector;
        moduleSelectors[9] = this.sharePriceWatermark.selector;
        moduleSelectors[10] = this.nextPerformanceFeeTimestamp.selector;
        moduleSelectors[11] = this.nextManagementFeeTimestamp.selector;
        moduleSelectors[12] = this.isBatchClosed.selector;
        moduleSelectors[13] = this.isBatchSettled.selector;
        moduleSelectors[14] = this.getBatchIdInfo.selector;
        moduleSelectors[15] = this.getBatchReceiver.selector;
        moduleSelectors[16] = this.getSafeBatchReceiver.selector;
        moduleSelectors[17] = this.sharePrice.selector;
        moduleSelectors[18] = this.totalAssets.selector;
        moduleSelectors[19] = this.totalNetAssets.selector;
        moduleSelectors[20] = this.getBatchId.selector;
        moduleSelectors[21] = this.getSafeBatchId.selector;
        moduleSelectors[22] = this.contractName.selector;
        moduleSelectors[23] = this.contractVersion.selector;
        return moduleSelectors;
    }
}
