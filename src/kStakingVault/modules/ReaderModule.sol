// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";
import { Extsload } from "uniswap/Extsload.sol";

import {
    KSTAKINGVAULT_NOT_INITIALIZED,
    KSTAKINGVAULT_VAULT_CLOSED,
    KSTAKINGVAULT_VAULT_SETTLED
} from "src/errors/Errors.sol";

import { IVersioned } from "src/interfaces/IVersioned.sol";
import { IModule } from "src/interfaces/modules/IModule.sol";
import { IVaultReader } from "src/interfaces/modules/IVaultReader.sol";
import { BaseVault } from "src/kStakingVault/base/BaseVault.sol";

/// @title ReaderModule
/// @notice Contains all the public getters for the Staking Vault
contract ReaderModule is BaseVault, Extsload, IVaultReader, IModule {
    using OptimizedFixedPointMathLib for uint256;

    /// @notice Interval for management fee (1 month)
    uint256 constant MANAGEMENT_FEE_INTERVAL = 657_436;
    /// @notice Interval for performance fee (3 months)
    uint256 constant PERFORMANCE_FEE_INTERVAL = 7_889_238;

    /// @notice Maximum basis points
    uint256 constant MAX_BPS = 10_000;
    /// @notice Number of seconds in a year
    uint256 constant SECS_PER_YEAR = 31_556_952;

    /// GENERAL
    /// @inheritdoc IVaultReader
    function registry() external view returns (address) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(_getInitialized($), KSTAKINGVAULT_NOT_INITIALIZED);
        return $.registry;
    }

    /// @inheritdoc IVaultReader
    function asset() external view returns (address) {
        return _getBaseVaultStorage().kToken;
    }

    /// @inheritdoc IVaultReader
    function underlyingAsset() external view returns (address) {
        return _getBaseVaultStorage().underlyingAsset;
    }

    /// FEES

    /// @inheritdoc IVaultReader
    function computeLastBatchFees()
        external
        view
        returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees)
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
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
                    performanceFees = (excessReturn * _getPerformanceFee($)) / MAX_BPS;
                } else {
                    performanceFees = (totalReturn * _getPerformanceFee($)) / MAX_BPS;
                }
            }

            // Calculate total fees
            totalFees += performanceFees;
        }

        return (managementFees, performanceFees, totalFees);
    }

    /// @inheritdoc IVaultReader
    function lastFeesChargedManagement() public view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getLastFeesChargedManagement($);
    }

    /// @inheritdoc IVaultReader
    function lastFeesChargedPerformance() public view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getLastFeesChargedPerformance($);
    }

    /// @inheritdoc IVaultReader
    function hurdleRate() external view returns (uint16) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getHurdleRate($);
    }

    /// @inheritdoc IVaultReader
    function performanceFee() external view returns (uint16) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getPerformanceFee($);
    }

    /// @inheritdoc IVaultReader
    function nextPerformanceFeeTimestamp() external view returns (uint256) {
        return lastFeesChargedPerformance() + PERFORMANCE_FEE_INTERVAL;
    }

    /// @inheritdoc IVaultReader
    function nextManagementFeeTimestamp() external view returns (uint256) {
        return lastFeesChargedManagement() + MANAGEMENT_FEE_INTERVAL;
    }

    /// @inheritdoc IVaultReader
    function managementFee() external view returns (uint16) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getManagementFee($);
    }

    /// @inheritdoc IVaultReader
    function sharePriceWatermark() external view returns (uint256) {
        return _getBaseVaultStorage().sharePriceWatermark;
    }

    /// @inheritdoc IVaultReader
    function isBatchClosed() external view returns (bool) {
        return _getBaseVaultStorage().batches[_getBaseVaultStorage().currentBatchId].isClosed;
    }

    /// @inheritdoc IVaultReader
    function isBatchSettled() external view returns (bool) {
        return _getBaseVaultStorage().batches[_getBaseVaultStorage().currentBatchId].isSettled;
    }

    /// @inheritdoc IVaultReader
    function getBatchIdInfo()
        external
        view
        returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled)
    {
        return (
            _getBaseVaultStorage().currentBatchId,
            _getBaseVaultStorage().batches[_getBaseVaultStorage().currentBatchId].batchReceiver,
            _getBaseVaultStorage().batches[_getBaseVaultStorage().currentBatchId].isClosed,
            _getBaseVaultStorage().batches[_getBaseVaultStorage().currentBatchId].isSettled
        );
    }

    /// @inheritdoc IVaultReader
    function getBatchReceiver(bytes32 batchId) external view returns (address) {
        return _getBaseVaultStorage().batches[batchId].batchReceiver;
    }

    /// @inheritdoc IVaultReader
    function getSafeBatchReceiver(bytes32 batchId) external view returns (address) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(!$.batches[batchId].isSettled, KSTAKINGVAULT_VAULT_SETTLED);
        return $.batches[batchId].batchReceiver;
    }

    /// @inheritdoc IVaultReader
    function sharePrice() external view returns (uint256) {
        return _sharePrice();
    }

    /// @inheritdoc IVaultReader
    function netSharePrice() external view returns (uint256) {
        return _netSharePrice();
    }

    /// @inheritdoc IVaultReader
    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    /// @inheritdoc IVaultReader
    function totalNetAssets() external view returns (uint256) {
        return _totalNetAssets();
    }

    /// @inheritdoc IVaultReader
    function getBatchId() public view returns (bytes32) {
        return _getBaseVaultStorage().currentBatchId;
    }

    /// @inheritdoc IVaultReader
    function getSafeBatchId() external view returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        bytes32 batchId = getBatchId();
        require(!$.batches[batchId].isClosed, KSTAKINGVAULT_VAULT_CLOSED);
        require(!$.batches[batchId].isSettled, KSTAKINGVAULT_VAULT_SETTLED);
        return batchId;
    }

    /// @inheritdoc IVaultReader
    function convertToShares(uint256 shares) external view returns (uint256) {
        return _convertToShares(shares);
    }

    /// @inheritdoc IVaultReader
    function convertToAssets(uint256 assets) external view returns (uint256) {
        return _convertToAssets(assets);
    }
    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVersioned
    function contractName() external pure returns (string memory) {
        return "kStakingVault";
    }

    /// @inheritdoc IVersioned
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    /// @inheritdoc IModule
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](27);
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
        moduleSelectors[18] = this.netSharePrice.selector;
        moduleSelectors[19] = this.totalAssets.selector;
        moduleSelectors[20] = this.totalNetAssets.selector;
        moduleSelectors[21] = this.getBatchId.selector;
        moduleSelectors[22] = this.getSafeBatchId.selector;
        moduleSelectors[23] = this.convertToShares.selector;
        moduleSelectors[24] = this.convertToAssets.selector;
        moduleSelectors[25] = this.contractName.selector;
        moduleSelectors[26] = this.contractVersion.selector;
        return moduleSelectors;
    }
}
