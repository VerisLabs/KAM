// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseModule } from "src/kStakingVault/modules/base/BaseModule.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

/// @title FeesModule
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract FeesModule is BaseModule {
    using FixedPointMathLib for uint256;

    event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
    event AssessFees(uint256 managementFees, uint256 performanceFees);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum basis points
    uint256 constant MAX_BPS = 10_000;
    /// @notice Number of seconds in a year
    uint256 constant SECS_PER_YEAR = 31_556_952;

    /// @notice Modifier to update the share price water-mark after running a function
    /// @dev Updates the high water mark if the current share price exceeds the previous mark
    modifier updateGlobalWatermark() {
        _;
        uint256 sp = _sharePrice();
        _getBaseModuleStorage().sharePriceWatermark = sp;
    }

    /// @notice Sets the management fee
    /// @param _managementFee The new management fee
    /// @dev Fee is a basis point (1% = 100)
    function setManagementFee(uint16 _managementFee) external onlyRoles(ADMIN_ROLE) {
        if (_managementFee > MAX_BPS) revert("Fee exceeds maximum");
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint16 oldFee = $.managementFee;
        $.managementFee = _managementFee;
        emit ManagementFeeUpdated(oldFee, _managementFee);
    }

    /// @notice Sets the performance fee
    /// @param _performanceFee The new performance fee
    /// @dev Fee is a basis point (1% = 100)
    function setPerformanceFee(uint16 _performanceFee) external onlyRoles(ADMIN_ROLE) {
        if (_performanceFee > MAX_BPS) revert("Fee exceeds maximum");
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint16 oldFee = $.performanceFee;
        $.performanceFee = _performanceFee;
        emit PerformanceFeeUpdated(oldFee, _performanceFee);
    }

    /// @notice Charges management and performance fees
    /// @return totalFees Total fees charged
    /// @dev Charges fees based on time-based management fee and performance fee
    function chargeGlobalFees() public returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint256 currentSharePrice = _sharePrice();
        uint256 lastSharePrice = $.sharePriceWatermark;
        uint256 duration = block.timestamp - $.lastFeesCharged;
        uint256 currentTotalAssets = _totalAssets();
        uint256 lastTotalAssets = totalSupply().fullMulDiv(lastSharePrice, 10 ** $.decimals);

        // Calculate time-based fees (management)
        // These are charged on total assets, prorated for the time period
        uint256 managementFees = (currentTotalAssets * duration).fullMulDiv($.managementFee, SECS_PER_YEAR) / MAX_BPS;
        uint256 performanceFees = 0;
        uint256 totalFees = managementFees;

        $.lastFeesCharged = block.timestamp;

        // Calculate the asset's value change since entry
        // This gives us the raw profit/loss in asset terms
        int256 assetsDelta = int256(currentTotalAssets) - int256(lastTotalAssets);

        // Only calculate fees if there's a profit
        if (assetsDelta > 0) {
            // Calculate returns relative to hurdle rate
            uint256 totalReturn = uint256(assetsDelta);

            performanceFees = totalReturn * $.performanceFee / MAX_BPS;

            // Calculate total fees
            totalFees += performanceFees;
        }
        // Transfer fees to feeReceiver if any were charged
        if (totalFees > 0) {
            _mint($.feeReceiver, _convertToShares(totalFees));
        }
        emit AssessFees(managementFees, performanceFees);
        return totalFees;
    }

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](3);
        moduleSelectors[0] = this.setManagementFee.selector;
        moduleSelectors[1] = this.setPerformanceFee.selector;
        moduleSelectors[2] = this.chargeGlobalFees.selector;
        return moduleSelectors;
    }
}
