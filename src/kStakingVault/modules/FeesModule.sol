// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";

/// @title FeesModule
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract FeesModule is BaseVaultModule {
    using FixedPointMathLib for uint256;

    /// @notice Interval for management fee (1 month)
    uint256 constant MANAGEMENT_FEE_INTERVAL = 657_436;
    /// @notice Interval for performance fee (3 months)
    uint256 constant PERFORMANCE_FEE_INTERVAL = 7_889_238;

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

    /// @notice Emitted when the hard hurdle rate is updated
    /// @param newRate New hard hurdle rate in basis points
    event HardHurdleRateUpdated(bool newRate);

    /// @notice Emitted when management fees are charged
    /// @param timestamp Timestamp of the fee charge
    event ManagementFeesCharged(uint256 timestamp);

    /// @notice Emitted when performance fees are charged
    /// @param timestamp Timestamp of the fee charge
    event PerformanceFeesCharged(uint256 timestamp);

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
    function setHurdleRate(uint16 _hurdleRate) external {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        if (_hurdleRate > MAX_BPS) revert("Fee exceeds maximum");
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        $.hurdleRate = _hurdleRate;
        emit HurdleRateUpdated(_hurdleRate);
    }

    /// @notice Sets the hard hurdle rate
    /// @param _isHard Whether the hard hurdle rate is enabled
    /// @dev If true, performance fees will only be charged to the excess return
    function setHardHurdleRate(bool _isHard) external {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        $.isHardHurdleRate = _isHard;
        emit HardHurdleRateUpdated(_isHard);
    }

    /// @notice Sets the management fee
    /// @param _managementFee The new management fee
    /// @dev Fee is a basis point (1% = 100)
    function setManagementFee(uint16 _managementFee) external {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        if (_managementFee > MAX_BPS) revert("Fee exceeds maximum");
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        uint16 oldFee = $.managementFee;
        $.managementFee = _managementFee;
        emit ManagementFeeUpdated(oldFee, _managementFee);
    }

    /// @notice Sets the performance fee
    /// @param _performanceFee The new performance fee
    /// @dev Fee is a basis point (1% = 100)
    function setPerformanceFee(uint16 _performanceFee) external {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        if (_performanceFee > MAX_BPS) revert("Fee exceeds maximum");
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        uint16 oldFee = $.performanceFee;
        $.performanceFee = _performanceFee;
        emit PerformanceFeeUpdated(oldFee, _performanceFee);
    }

    /// @notice Notifies the module that management fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyManagementFeesCharged(uint64 _timestamp) external {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        if (_timestamp < $.lastFeesChargedManagement || _timestamp > block.timestamp) revert("Invalid timestamp");
        $.lastFeesChargedManagement = _timestamp;
        _updateGlobalWatermark();
        emit ManagementFeesCharged(_timestamp);
    }

    /// @notice Notifies the module that performance fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyPerformanceFeesCharged(uint64 _timestamp) external {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        if (_timestamp < $.lastFeesChargedPerformance || _timestamp > block.timestamp) revert("Invalid timestamp");
        $.lastFeesChargedPerformance = _timestamp;
        _updateGlobalWatermark();
        emit PerformanceFeesCharged(_timestamp);
    }

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

        uint256 lastFeesChargedManagement = $.lastFeesChargedManagement;
        uint256 lastFeesChargedPerformance = $.lastFeesChargedPerformance;

        uint256 durationManagement = block.timestamp - lastFeesChargedManagement;
        uint256 durationPerformance = block.timestamp - lastFeesChargedPerformance;
        uint256 currentTotalAssets = _totalAssets();
        uint256 lastTotalAssets = totalSupply().fullMulDiv(lastSharePrice, 10 ** $.decimals);

        // Calculate time-based fees (management)
        // These are charged on total assets, prorated for the time period
        managementFees = (currentTotalAssets * durationManagement).fullMulDiv($.managementFee, SECS_PER_YEAR) / MAX_BPS;
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
                (lastTotalAssets * $.hurdleRate).fullMulDiv(durationPerformance, SECS_PER_YEAR) / MAX_BPS;

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
                if ($.isHardHurdleRate) {
                    performanceFees = excessReturn * $.performanceFee / MAX_BPS;
                } else {
                    performanceFees = totalReturn * $.performanceFee / MAX_BPS;
                }
            }

            // Calculate total fees
            totalFees += performanceFees;
        }

        return (managementFees, performanceFees, totalFees);
    }

    /// @notice Updates the share price watermark
    /// @dev Updates the high water mark if the current share price exceeds the previous mark
    function _updateGlobalWatermark() private {
        uint256 sp = _sharePrice();
        if (sp > _getBaseVaultModuleStorage().sharePriceWatermark) {
            _getBaseVaultModuleStorage().sharePriceWatermark = sp;
        }
    }

    /// @notice Returns the last time management fees were charged
    /// @return lastFeesChargedManagement Timestamp of last management fee charge
    function lastFeesChargedManagement() public view returns (uint256) {
        return _getBaseVaultModuleStorage().lastFeesChargedManagement;
    }

    /// @notice Returns the last time performance fees were charged
    /// @return lastFeesChargedPerformance Timestamp of last performance fee charge
    function lastFeesChargedPerformance() public view returns (uint256) {
        return _getBaseVaultModuleStorage().lastFeesChargedPerformance;
    }

    /// @notice Returns the current hurdle rate used for performance fee calculations
    /// @return The hurdle rate in basis points (e.g., 500 = 5%)
    function hurdleRate() external view returns (uint16) {
        return _getBaseVaultModuleStorage().hurdleRate;
    }

    /// @notice Returns the current performance fee percentage
    /// @return The performance fee in basis points (e.g., 2000 = 20%)
    function performanceFee() external view returns (uint16) {
        return _getBaseVaultModuleStorage().performanceFee;
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
        return _getBaseVaultModuleStorage().managementFee;
    }

    /// @notice Returns the address that receives collected fees
    /// @return The fee receiver address
    function feeReceiver() external view returns (address) {
        return _getBaseVaultModuleStorage().feeReceiver;
    }

    /// @notice Returns the high watermark for share price used in performance fee calculations
    /// @return The share price watermark value
    function sharePriceWatermark() external view returns (uint256) {
        return _getBaseVaultModuleStorage().sharePriceWatermark;
    }

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](16);
        moduleSelectors[0] = this.setHurdleRate.selector;
        moduleSelectors[1] = this.setHardHurdleRate.selector;
        moduleSelectors[2] = this.setManagementFee.selector;
        moduleSelectors[3] = this.setPerformanceFee.selector;
        moduleSelectors[4] = this.computeLastBatchFees.selector;
        moduleSelectors[5] = this.lastFeesChargedManagement.selector;
        moduleSelectors[6] = this.lastFeesChargedPerformance.selector;
        moduleSelectors[7] = this.hurdleRate.selector;
        moduleSelectors[8] = this.performanceFee.selector;
        moduleSelectors[9] = this.managementFee.selector;
        moduleSelectors[10] = this.feeReceiver.selector;
        moduleSelectors[11] = this.sharePriceWatermark.selector;
        moduleSelectors[12] = this.nextPerformanceFeeTimestamp.selector;
        moduleSelectors[13] = this.nextManagementFeeTimestamp.selector;
        moduleSelectors[14] = this.notifyManagementFeesCharged.selector;
        moduleSelectors[15] = this.notifyPerformanceFeesCharged.selector;
        return moduleSelectors;
    }
}
