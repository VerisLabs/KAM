// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { _1_USDC } from "../utils/Constants.sol";

import { console } from "forge-std/console.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

import {
    KSTAKINGVAULT_WRONG_ROLE, VAULTFEES_FEE_EXCEEDS_MAXIMUM, VAULTFEES_INVALID_TIMESTAMP
} from "src/errors/Errors.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

/// @title kStakingVaultFeesTest
/// @notice Tests for fee mechanics in kStakingVault
/// @dev Focuses on fee calculations, watermarks, hurdle rates, and fee notifications
contract kStakingVaultFeesTest is BaseVaultTest {
    using OptimizedFixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant SECS_PER_YEAR = 31_556_952;
    uint256 constant MAX_BPS = 10_000;
    uint256 constant MANAGEMENT_FEE_INTERVAL = 657_436; // 1 month
    uint256 constant PERFORMANCE_FEE_INTERVAL = 7_889_238; // 3 months

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        DeploymentBaseTest.setUp();

        // Use Alpha vault for testing
        vault = IkStakingVault(address(alphaVault));

        BaseVaultTest.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        FEE CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialFeeState() public view {
        // Fees should start at zero
        assertEq(vault.managementFee(), 0);
        assertEq(vault.performanceFee(), 0);
        assertEq(vault.hurdleRate(), 0);

        // Watermark should be initial share price (1e6)
        assertEq(vault.sharePriceWatermark(), 1e6);

        // Fee timestamps should be set to deployment time
        assertTrue(vault.lastFeesChargedManagement() > 0);
        assertTrue(vault.lastFeesChargedPerformance() > 0);
    }

    function test_SetManagementFee() public {
        vm.prank(users.admin);
        vault.setManagementFee(TEST_MANAGEMENT_FEE);

        assertEq(vault.managementFee(), TEST_MANAGEMENT_FEE);
    }

    function test_SetManagementFee_ExceedsMaximum() public {
        vm.expectRevert(bytes(VAULTFEES_FEE_EXCEEDS_MAXIMUM));
        vm.prank(users.admin);
        vault.setManagementFee(uint16(MAX_BPS + 1));
    }

    function test_SetManagementFee_OnlyAdmin() public {
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vm.prank(users.alice);
        vault.setManagementFee(TEST_MANAGEMENT_FEE);
    }

    function test_SetPerformanceFee() public {
        vm.prank(users.admin);
        vault.setPerformanceFee(TEST_PERFORMANCE_FEE);

        assertEq(vault.performanceFee(), TEST_PERFORMANCE_FEE);
    }

    function test_SetPerformanceFee_ExceedsMaximum() public {
        vm.expectRevert(bytes(VAULTFEES_FEE_EXCEEDS_MAXIMUM));
        vm.prank(users.admin);
        vault.setPerformanceFee(uint16(MAX_BPS + 1));
    }

    function test_SetHardHurdleRate() public {
        vm.prank(users.admin);
        vault.setHardHurdleRate(true);

        // No direct getter, but we can test behavior in fee calculation
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGEMENT FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ManagementFee_NoTimeElapsed() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        (uint256 managementFees,,) = vault.computeLastBatchFees();

        // No time elapsed, should be minimal fees
        assertEq(managementFees, 0);
    }

    function test_ManagementFee_OneYear() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        (uint256 managementFees,,) = vault.computeLastBatchFees();

        // Should be approximately 1% of total assets
        uint256 expectedFee = (INITIAL_DEPOSIT * TEST_MANAGEMENT_FEE) / MAX_BPS;
        assertApproxEqRel(managementFees, expectedFee, 0.01e18); // 1% tolerance for time precision
    }

    function test_ManagementFee_PartialYear() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Fast forward 6 months
        uint256 sixMonths = 180 days;
        vm.warp(block.timestamp + sixMonths);

        (uint256 managementFees,,) = vault.computeLastBatchFees();

        // Should be approximately 0.5% of total assets
        uint256 expectedFee = (INITIAL_DEPOSIT * TEST_MANAGEMENT_FEE * sixMonths) / (365 days * MAX_BPS);
        assertApproxEqRel(managementFees, expectedFee, 0.02e18); // 2% tolerance
    }

    function test_ManagementFee_IncreasedAssets() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add yield to increase total assets
        uint256 yieldAmount = 200_000 * _1_USDC; // 20% yield
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        (uint256 managementFees,,) = vault.computeLastBatchFees();

        // Management fee should be based on current total assets (including yield)
        uint256 expectedFee = ((INITIAL_DEPOSIT + yieldAmount) * TEST_MANAGEMENT_FEE) / MAX_BPS;
        assertApproxEqRel(managementFees, expectedFee, 0.01e18);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORMANCE FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PerformanceFee_NoProfit() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Fast forward time but no profit
        vm.warp(block.timestamp + 365 days);

        (, uint256 performanceFees,) = vault.computeLastBatchFees();

        // No profit, no performance fees
        assertEq(performanceFees, 0);
    }

    function test_PerformanceFee_WithProfit_SoftHurdle() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Set soft hurdle (default)
        vm.prank(users.admin);
        vault.setHardHurdleRate(false);

        // Add significant yield (20%)
        uint256 yieldAmount = 200_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        (uint256 managementFees, uint256 performanceFees,) = vault.computeLastBatchFees();

        // NOTE: we deduct management fees first
        // Expected: hurdle return = INITIAL_DEPOSIT * 5% = 50K USDC
        // Total return = 200K USDC (exceeds hurdle)
        // With soft hurdle: performance fee on entire return (200K * 20% = 40K USDC)
        uint256 expectedFee = ((yieldAmount - managementFees) * TEST_PERFORMANCE_FEE) / MAX_BPS;
        assertApproxEqRel(performanceFees, expectedFee, 0.02e18); // 2% tolerance
    }

    function test_PerformanceFee_WithProfit_HardHurdle() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Set hard hurdle
        vm.prank(users.admin);
        vault.setHardHurdleRate(true);

        // Add significant yield (20%)
        uint256 yieldAmount = 200_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        (uint256 managementFees, uint256 performanceFees,) = vault.computeLastBatchFees();

        // NOTE: we deduct management fees first
        yieldAmount -= managementFees;

        // Expected: hurdle return = INITIAL_DEPOSIT * 5% = 50K USDC
        // Excess return = 200K - 50K = 150K USDC
        // With hard hurdle: performance fee only on excess (150K * 20% = 30K USDC)
        uint256 hurdleReturn = (INITIAL_DEPOSIT * TEST_HURDLE_RATE) / MAX_BPS;
        uint256 excessReturn = yieldAmount - hurdleReturn;
        uint256 expectedFee = (excessReturn * TEST_PERFORMANCE_FEE) / MAX_BPS;
        assertApproxEqRel(performanceFees, expectedFee, 0.02e18);
    }

    function test_PerformanceFee_BelowHurdle() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add small yield (2% - below 5% hurdle)
        uint256 smallYield = 20_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), smallYield);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        (, uint256 performanceFees,) = vault.computeLastBatchFees();

        // Return below hurdle rate, no performance fees
        assertEq(performanceFees, 0);
    }

    function test_PerformanceFee_Loss() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Simulate loss by reducing vault's kToken balance
        uint256 lossAmount = 100_000 * _1_USDC;
        vm.prank(address(vault));
        kUSD.transfer(users.treasury, lossAmount);

        // Fast forward time
        vm.warp(block.timestamp + 365 days);

        (, uint256 performanceFees,) = vault.computeLastBatchFees();

        // Loss scenario, no performance fees
        assertEq(performanceFees, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        SHARE PRICE WATERMARK TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SharePriceWatermark_InitialValue() public view {
        // Initial watermark should be 1e6 (1:1 share price)
        assertEq(vault.sharePriceWatermark(), 1e6);
    }

    function test_SharePriceWatermark_UpdateAfterProfit() public {
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        uint256 initialWatermark = vault.sharePriceWatermark();

        vm.warp(block.timestamp + 2);

        // Add yield to increase share price
        uint256 yieldAmount = 200_000 * _1_USDC;

        // Trigger watermark update by notifying fee charge
        vm.startPrank(users.relayer);
        bytes32 batchId = vault.getBatchId();
        vault.closeBatch(batchId, true);

        bytes32 proposalId = assetRouter.proposeSettleBatch(
            getUSDC(),
            address(vault),
            batchId,
            vault.totalAssets() + yieldAmount,
            uint64(block.timestamp - 1),
            uint64(block.timestamp - 1)
        );

        assetRouter.executeSettleBatch(proposalId);

        uint256 newWatermark = vault.sharePriceWatermark();

        // Watermark should have increased
        assertGt(newWatermark, initialWatermark);
        assertEq(newWatermark, vault.netSharePrice());
    }

    function test_SharePriceWatermark_NoUpdateAfterLoss() public {
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Now simulate loss
        uint256 lossAmount = 300_000 * _1_USDC; // Bigger than yield
        bytes32 batchId = vault.getBatchId();

        // Trigger watermark update by notifying fee charge
        vm.startPrank(users.relayer);
        vault.closeBatch(batchId, true);
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            getUSDC(),
            address(vault),
            batchId,
            vault.totalAssets() - lossAmount,
            uint64(block.timestamp - 1),
            uint64(block.timestamp - 1)
        );

        assetRouter.executeSettleBatch(proposalId);

        uint256 highWatermark = vault.sharePriceWatermark();

        // Watermark should not decrease
        assertEq(vault.sharePriceWatermark(), highWatermark);
        assertGt(vault.sharePriceWatermark(), vault.netSharePrice());
    }

    /*//////////////////////////////////////////////////////////////
                        FEE NOTIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_NotifyManagementFeesCharged() public {
        uint64 timestamp = uint64(block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit ManagementFeesCharged(timestamp);

        vm.prank(users.admin);
        vault.notifyManagementFeesCharged(timestamp);

        assertEq(vault.lastFeesChargedManagement(), timestamp);
    }

    function test_NotifyManagementFeesCharged_InvalidTimestamp() public {
        // set a management fee timestamp
        // we warped so we can go back in time
        vm.warp(5000);
        vm.prank(users.admin);
        vault.notifyManagementFeesCharged(uint64(block.timestamp));

        // set timestamp in the past (before the last timestamp)
        uint64 pastTimestamp = uint64(block.timestamp - 1000);

        vm.expectRevert(bytes(VAULTFEES_INVALID_TIMESTAMP));
        vm.prank(users.admin);
        vault.notifyManagementFeesCharged(pastTimestamp);
    }

    function test_NotifyManagementFeesCharged_FutureTimestamp() public {
        // Try to set timestamp in the future
        uint64 futureTimestamp = uint64(block.timestamp + 1000);

        vm.expectRevert(bytes(VAULTFEES_INVALID_TIMESTAMP));
        vm.prank(users.admin);
        vault.notifyManagementFeesCharged(futureTimestamp);
    }

    function test_NotifyPerformanceFeesCharged() public {
        uint64 timestamp = uint64(block.timestamp);

        vm.expectEmit(true, false, false, true);
        emit PerformanceFeesCharged(timestamp);

        vm.prank(users.admin);
        vault.notifyPerformanceFeesCharged(timestamp);

        assertEq(vault.lastFeesChargedPerformance(), timestamp);
    }

    function test_NotifyPerformanceFeesCharged_OnlyAdmin() public {
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vm.prank(users.alice);
        vault.notifyPerformanceFeesCharged(uint64(block.timestamp));
    }

    /*//////////////////////////////////////////////////////////////
                        COMBINED FEE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ComputeLastBatchFees_BothFees() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add yield
        uint256 yieldAmount = 300_000 * _1_USDC; // 30% yield
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Fast forward one year
        vm.warp(block.timestamp + 365 days);

        (uint256 managementFees, uint256 performanceFees, uint256 totalFees) = vault.computeLastBatchFees();

        // Both fees should be positive
        assertGt(managementFees, 0);
        assertGt(performanceFees, 0);
        assertEq(totalFees, managementFees + performanceFees);

        // Management fee should be ~1% of total assets
        uint256 totalAssets = INITIAL_DEPOSIT + yieldAmount;
        uint256 expectedManagementFee = (totalAssets * TEST_MANAGEMENT_FEE) / MAX_BPS;
        assertApproxEqRel(managementFees, expectedManagementFee, 0.02e18);

        // Performance fee calculation (after management fees)
        uint256 assetsAfterManagementFee = totalAssets - managementFees;
        int256 assetsDelta = int256(assetsAfterManagementFee) - int256(INITIAL_DEPOSIT);
        uint256 hurdleReturn = (totalAssets * TEST_HURDLE_RATE) / MAX_BPS;
        uint256 excessReturn = uint256(assetsDelta) - hurdleReturn;
        // If the hurdle rate is soft apply fees to all return
        uint256 expectedPerformanceFee = (uint256(assetsDelta) * TEST_PERFORMANCE_FEE) / MAX_BPS;
        assertApproxEqRel(performanceFees, expectedPerformanceFee, 0.05e18); // 5% tolerance
    }

    function test_NextFeeTimestamps() public {
        uint256 currentTime = block.timestamp;

        uint256 nextManagement = vault.nextManagementFeeTimestamp();
        uint256 nextPerformance = vault.nextPerformanceFeeTimestamp();

        // Should be current + interval
        assertApproxEqAbs(nextManagement, currentTime + MANAGEMENT_FEE_INTERVAL, 10);
        assertApproxEqAbs(nextPerformance, currentTime + PERFORMANCE_FEE_INTERVAL, 10);
    }

    /*//////////////////////////////////////////////////////////////
                        NET ASSETS CALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TotalNetAssets_WithAccruedFees() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add yield
        uint256 yieldAmount = 200_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Fast forward time to accrue fees
        vm.warp(block.timestamp + 365 days);

        uint256 totalAssets = vault.totalAssets();
        uint256 totalNetAssets = vault.totalNetAssets();

        (,, uint256 accruedFees) = vault.computeLastBatchFees();

        // Net assets should equal total assets minus accrued fees
        assertEq(totalNetAssets, totalAssets - accruedFees);
        assertLt(totalNetAssets, totalAssets);
    }

    function test_SharePrice_vs_NetSharePrice() public {
        _setupTestFees();
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add yield
        uint256 yieldAmount = 200_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Fast forward time
        vm.warp(block.timestamp + 365 days);

        uint256 totalSupply = vault.totalSupply();
        uint256 totalAssets = vault.totalAssets();
        uint256 netAssets = vault.totalNetAssets();

        uint256 netSharePrice = vault.netSharePrice();
        uint256 sharePrice = (totalAssets * 1e6) / totalSupply;

        // Net share price should be lower than gross share price
        assertLt(netSharePrice, sharePrice);

        // The difference should be the accrued fees per share
        (,, uint256 accruedFees) = vault.computeLastBatchFees();
        uint256 feesPerShare = (accruedFees * 1e6) / totalSupply;
        assertApproxEqAbs(sharePrice - netSharePrice, feesPerShare, 10);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASES AND ERROR HANDLING
    //////////////////////////////////////////////////////////////*/

    function test_ZeroHurdleRate() public {
        vm.prank(users.admin);
        vault.setPerformanceFee(TEST_PERFORMANCE_FEE);

        vm.prank(users.relayer);
        registry.setHurdleRate(getUSDC(), 0); // No hurdle

        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add small yield
        uint256 smallYield = 10_000 * _1_USDC; // 1%
        vm.prank(address(minter));
        kUSD.mint(address(vault), smallYield);

        vm.warp(block.timestamp + 365 days);

        (, uint256 performanceFees,) = vault.computeLastBatchFees();

        // With zero hurdle, any profit should generate performance fees
        uint256 expectedFee = (smallYield * TEST_PERFORMANCE_FEE) / MAX_BPS;
        assertApproxEqRel(performanceFees, expectedFee, 0.02e18);
    }

    function test_ZeroPerformanceFee() public {
        vm.startPrank(users.admin);
        vault.setManagementFee(TEST_MANAGEMENT_FEE);
        vault.setPerformanceFee(0); // No performance fee
        vm.stopPrank();

        vm.prank(users.relayer);
        registry.setHurdleRate(getUSDC(), TEST_HURDLE_RATE);

        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT, 0);

        // Add significant yield
        uint256 yieldAmount = 500_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        vm.warp(block.timestamp + 365 days);

        (uint256 managementFees, uint256 performanceFees, uint256 totalFees) = vault.computeLastBatchFees();

        // Should have management fees but no performance fees
        assertGt(managementFees, 0);
        assertEq(performanceFees, 0);
        assertEq(totalFees, managementFees);
    }

    function test_ComputeFeesWithZeroAssets() public view {
        // Vault with no deposits
        (uint256 managementFees, uint256 performanceFees, uint256 totalFees) = vault.computeLastBatchFees();

        // All fees should be zero
        assertEq(managementFees, 0);
        assertEq(performanceFees, 0);
        assertEq(totalFees, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        EVENT EMISSION TESTS
    //////////////////////////////////////////////////////////////*/

    event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
    event HurdleRateUpdated(uint16 newRate);
    event HardHurdleRateUpdated(bool newRate);
    event ManagementFeesCharged(uint256 timestamp);
    event PerformanceFeesCharged(uint256 timestamp);

    function test_ManagementFeeUpdated_Event() public {
        uint16 oldFee = vault.managementFee();

        vm.expectEmit(true, true, false, true);
        emit ManagementFeeUpdated(oldFee, TEST_MANAGEMENT_FEE);

        vm.prank(users.admin);
        vault.setManagementFee(TEST_MANAGEMENT_FEE);
    }

    function test_PerformanceFeeUpdated_Event() public {
        uint16 oldFee = vault.performanceFee();

        vm.expectEmit(true, true, false, true);
        emit PerformanceFeeUpdated(oldFee, TEST_PERFORMANCE_FEE);

        vm.prank(users.admin);
        vault.setPerformanceFee(TEST_PERFORMANCE_FEE);
    }

    function test_HardHurdleRateUpdated_Event() public {
        vm.expectEmit(false, false, false, true);
        emit HardHurdleRateUpdated(true);

        vm.prank(users.admin);
        vault.setHardHurdleRate(true);
    }
}
