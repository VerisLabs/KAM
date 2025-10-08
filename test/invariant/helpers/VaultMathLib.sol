// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";
import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";

library VaultMathLib {
    /// @notice Maximum basis points
    uint256 constant MAX_BPS = 10_000;
    /// @notice Number of seconds in a year
    uint256 constant SECS_PER_YEAR = 31_556_952;

    using OptimizedFixedPointMathLib for uint256;

    function computeLastBatchFeesWithAssetsAndSupply(IkStakingVault vault, uint256 _totalAssets, uint256 _totalSupply)
        internal
        view
        returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees)
    {
        uint256 lastSharePrice = vault.sharePriceWatermark();

        uint256 lastFeesChargedManagement_ = vault.lastFeesChargedManagement();
        uint256 lastFeesChargedPerformance_ = vault.lastFeesChargedPerformance();

        uint256 durationManagement = block.timestamp - lastFeesChargedManagement_;
        uint256 durationPerformance = block.timestamp - lastFeesChargedPerformance_;
        uint256 currentTotalAssets = _totalAssets;
        uint256 lastTotalAssets = _totalSupply.fullMulDiv(lastSharePrice, 10 ** vault.decimals());

        // Calculate time-based fees (management)
        // These are charged on total assets, prorated for the time period
        managementFees =
            (currentTotalAssets * durationManagement).fullMulDiv(vault.managementFee(), SECS_PER_YEAR) / MAX_BPS;
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
                (lastTotalAssets * vault.hurdleRate()).fullMulDiv(durationPerformance, SECS_PER_YEAR) / MAX_BPS;

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
                if (vault.isHardHurdleRate()) {
                    performanceFees = (excessReturn * vault.performanceFee()) / MAX_BPS;
                } else {
                    performanceFees = (totalReturn * vault.performanceFee()) / MAX_BPS;
                }
            }

            // Calculate total fees
            totalFees += performanceFees;
        }

        return (managementFees, performanceFees, totalFees);
    }

    function convertToAssetsWithAssetsAndSupply(uint256 _shares, uint256 _totalAssets, uint256 _totalSupply)
        internal
        view
        returns (uint256)
    {
        if (_totalSupply == 0) return _shares;
        return _shares.fullMulDiv(_totalAssets, _totalSupply);
    }

    function convertToSharesWithAssetsAndSupply(uint256 _assets, uint256 _totalAssets, uint256 _totalSupply)
        internal
        view
        returns (uint256)
    {
        if (_totalSupply == 0) return _assets;
        return _assets.fullMulDiv(_totalSupply, _totalAssets);
    }
}
