// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVaultModule } from "src/kStakingVault/modules/base/BaseVaultModule.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title FeesModule
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract FeesModule is BaseVaultModule {
    using FixedPointMathLib for uint256;

    uint256 constant MANAGEMENT_FEE_INTERVAL = 657436; // 1 month
    uint256 constant PERFORMANCE_FEE_INTERVAL = 7889238; // 3 months

    /// @notice Emitted when the management fee is updated
    /// @param oldFee Previous management fee in basis points
    /// @param newFee New management fee in basis points
    event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);
    
    /// @notice Emitted when the performance fee is updated
    /// @param oldFee Previous performance fee in basis points
    /// @param newFee New performance fee in basis points
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
    
    /// @notice Emitted when fees are charged to the vault
    /// @param managementFees Amount of management fees collected
    /// @param performanceFees Amount of performance fees collected
    event FeesAssesed(uint256 managementFees, uint256 performanceFees);
    
    /// @notice Emitted when the hurdle rate is updated
    /// @param newRate New hurdle rate in basis points
    event HurdleRateUpdated(uint16 newRate);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum basis points
    uint256 constant MAX_BPS = 10_000;
    /// @notice Number of seconds in a year
    uint256 constant SECS_PER_YEAR = 31_556_952;

    /// @notice Sets the yearly hurdle rate for the underlying asset
    /// @param _hurdleRate The new yearly hurdle rate
    /// @dev Fee is a basis point (1% = 100)
    function setHurdleRate(uint16 _hurdleRate) external onlyRoles(ADMIN_ROLE) {
        if (_hurdleRate > MAX_BPS) revert("Fee exceeds maximum");
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        $.hurdleRate = _hurdleRate;
        emit HurdleRateUpdated(_hurdleRate);
    }

    /// @notice Sets the management fee
    /// @param _managementFee The new management fee
    /// @dev Fee is a basis point (1% = 100)
    function setManagementFee(uint16 _managementFee) external onlyRoles(ADMIN_ROLE) {
        if (_managementFee > MAX_BPS) revert("Fee exceeds maximum");
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        uint16 oldFee = $.managementFee;
        $.managementFee = _managementFee;
        emit ManagementFeeUpdated(oldFee, _managementFee);
    }

    /// @notice Sets the performance fee
    /// @param _performanceFee The new performance fee
    /// @dev Fee is a basis point (1% = 100)
    function setPerformanceFee(uint16 _performanceFee) external onlyRoles(ADMIN_ROLE) {
        if (_performanceFee > MAX_BPS) revert("Fee exceeds maximum");
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        uint16 oldFee = $.performanceFee;
        $.performanceFee = _performanceFee;
        emit PerformanceFeeUpdated(oldFee, _performanceFee);
    }

    /// @notice Computes the last fee batch
    /// @return managementFees The management fees for the last batch
    /// @return performanceFees The performance fees for the last batch
    /// @return totalFees The total fees for the last batch
    function computeLastBatchFees() public view returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        uint256 currentSharePrice = _sharePrice();
        uint256 lastSharePrice = $.sharePriceWatermark;
    
        uint256 lastFeesChargedManagement = _lastFeesChargedManagement($);
        uint256 lastFeesChargedPerformance = _lastFeesChargedPerformance($);
        
        uint256 durationManagement = block.timestamp - lastFeesChargedManagement;
        uint256 durationPerformance = block.timestamp - lastFeesChargedPerformance;
        uint256 currentTotalAssets = _totalAssetsVirtual();
        uint256 lastTotalAssets = totalSupply().fullMulDiv(lastSharePrice, 10 ** $.decimals);
        
        // Calculate time-based fees (management)
        // These are charged on total assets, prorated for the time period
        managementFees = (currentTotalAssets * durationManagement).fullMulDiv($.managementFee, SECS_PER_YEAR) / MAX_BPS;
        totalFees = managementFees;

        // Calculate the asset's value change since entry
        // This gives us the raw profit/loss in asset terms
        int256 assetsDelta = int256(currentTotalAssets) - int256(lastTotalAssets);

        // Only calculate fees if there's a profit
        if (assetsDelta > 0) {
            uint256 excessReturn;

            // Calculate returns relative to hurdle rate
            uint256 hurdleReturn = (lastTotalAssets * $.hurdleRate).fullMulDiv(durationPerformance, SECS_PER_YEAR) / MAX_BPS;
            
            // Calculate returns relative to hurdle rate
            uint256 totalReturn = uint256(assetsDelta);

            // Only charge performance fees if:
            // 1. Current share price is not below
            // 2. Returns exceed hurdle rate
            if (currentSharePrice > lastSharePrice && totalReturn > hurdleReturn) {
                // Only charge performance fees on returns above hurdle rate
                excessReturn = totalReturn - hurdleReturn;

                performanceFees = excessReturn * $.performanceFee / MAX_BPS;
            }

            // Calculate total fees
            totalFees += performanceFees;
        }
        return (managementFees, performanceFees, totalFees);
    }

    /// @notice Updates the share price watermark
    /// @dev Updates the high water mark if the current share price exceeds the previous mark
    function updateGlobalWatermark() public {
        uint256 sp = _sharePrice();
        if (sp > _getBaseVaultModuleStorage().sharePriceWatermark) {
            _getBaseVaultModuleStorage().sharePriceWatermark = sp;
        }
    }

    /// @notice Returns the last time management fees were charged
    /// @return lastFeesChargedManagement Timestamp of last management fee charge
    function lastFeesChargedManagement() public view returns (uint256) {
        return _lastFeesChargedManagement(_getBaseVaultModuleStorage());
    }

    /// @notice Returns the last time performance fees were charged
    /// @return lastFeesChargedPerformance Timestamp of last performance fee charge
    function lastFeesChargedPerformance() public view returns (uint256) {
        return _lastFeesChargedPerformance(_getBaseVaultModuleStorage());
    }

    /// @dev Helper function to calculate the last time management fees were charged
    /// @return lastFeesChargedManagement Timestamp of last management fee charge
    function _lastFeesChargedManagement(BaseVaultModuleStorage storage $) private view returns(uint256) {
       uint256 currentTimestamp = block.timestamp;
        uint256 initTimestamp = $.initTimestamp;
        uint256 numIntervals = (currentTimestamp - initTimestamp) / MANAGEMENT_FEE_INTERVAL;
        return initTimestamp + numIntervals * MANAGEMENT_FEE_INTERVAL;
    }
    
    /// @dev Helper function to calculate the last time performance fees were charged
    /// @return lastFeesChargedPerformance Timestamp of last performance fee charge
    function _lastFeesChargedPerformance(BaseVaultModuleStorage storage $) private view returns(uint256) {
        uint256 currentTimestamp = block.timestamp;
        uint256 initTimestamp = $.initTimestamp;
        uint256 numIntervals = (currentTimestamp - initTimestamp) / PERFORMANCE_FEE_INTERVAL;
        return initTimestamp + numIntervals * PERFORMANCE_FEE_INTERVAL;
    }

    /// @notice Returns the current hurdle rate used for performance fee calculations
    /// @return The hurdle rate in basis points (e.g., 500 = 5%)
    function hurdleRate() public view returns (uint16) {
        return _getBaseVaultModuleStorage().hurdleRate;
    }

    /// @notice Returns the current performance fee percentage
    /// @return The performance fee in basis points (e.g., 2000 = 20%)
    function performanceFee() public view returns (uint16) {
        return _getBaseVaultModuleStorage().performanceFee;
    }

    /// @notice Returns the current management fee percentage
    /// @return The management fee in basis points (e.g., 100 = 1%)
    function managementFee() public view returns (uint16) {
        return _getBaseVaultModuleStorage().managementFee;
    }

    /// @notice Returns the address that receives collected fees
    /// @return The fee receiver address
    function feeReceiver() public view returns (address) {
        return _getBaseVaultModuleStorage().feeReceiver;
    }

    /// @notice Returns the high watermark for share price used in performance fee calculations
    /// @return The share price watermark value
    function sharePriceWatermark() public view returns (uint256) {
        return _getBaseVaultModuleStorage().sharePriceWatermark;
    }

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](13);
        moduleSelectors[0] = this.setHurdleRate.selector;
        moduleSelectors[1] = this.setManagementFee.selector;
        moduleSelectors[2] = this.setPerformanceFee.selector;
        moduleSelectors[3] = this.computeLastBatchFees.selector;
        moduleSelectors[4] = this.lastFeesChargedManagement.selector;
        moduleSelectors[5] = this.lastFeesChargedPerformance.selector;
        moduleSelectors[6] = this.hurdleRate.selector;
        moduleSelectors[7] = this.performanceFee.selector;
        moduleSelectors[8] = this.managementFee.selector;
        moduleSelectors[9] = this.feeReceiver.selector;
        moduleSelectors[10] = this.sharePriceWatermark.selector;
        moduleSelectors[11] = this.selectors.selector;
        moduleSelectors[12] = this.updateGlobalWatermark.selector;
        return moduleSelectors;
    }
}
