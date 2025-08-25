// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";

import { console } from "forge-std/console.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title kStakingVaultAccountingTest
/// @notice Tests for core accounting mechanics in kStakingVault
/// @dev Focuses on share price calculations, asset conversions, and balance tracking
contract kStakingVaultAccountingTest is BaseVaultTest {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

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
                        INITIAL STATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialState() public view {
        // Vault should start with zero assets and shares
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalNetAssets(), 0);

        // Share price should be 1:1 initially (1e6 for 6 decimals)
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_InitialSharePriceWith6Decimals() public view {
        // Vault uses 6 decimals to match USDC
        assertEq(vault.decimals(), 6);

        // Initial share price should be 1 USDC (1e6)
        assertEq(vault.sharePrice(), 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                      SINGLE DEPOSIT ACCOUNTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FirstDeposit_SharePriceRemains1to1() public {
        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Total assets should equal deposit
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT);

        // // Alice should receive 1:1 shares (1M stkTokens)
        assertEq(vault.balanceOf(users.alice), INITIAL_DEPOSIT);

        // // Total supply should equal deposit
        assertEq(vault.totalSupply(), INITIAL_DEPOSIT);

        // // Share price should remain 1:1
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_SharePriceCalculation_AfterYield() public {
        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Simulate 10% yield by adding 100K USDC to vault
        bytes32 batchId = vault.getBatchId();
        uint256 lastTotalAssets = vault.totalAssets();
        uint256 yield = 100_000 * _1_USDC;

        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + yield, 0, yield, true);

        // Total assets should now be 1.1M USDC
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT + yield);

        // Total supply remains 1M stkTokens
        assertEq(vault.totalSupply(), INITIAL_DEPOSIT);

        // Share price should be 1.1 USDC per stkToken
        uint256 expectedSharePrice = 1.1e6; // 1.1 USDC
        assertEq(vault.sharePrice(), expectedSharePrice);
    }

    function test_SharePriceCalculation_AfterLoss() public {
        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Simulate 5% loss by burning 50K USDC from vault
        bytes32 batchId = vault.getBatchId();
        uint256 lastTotalAssets = vault.totalAssets();
        uint256 lossAmount = 50_000 * _1_USDC;

        _executeBatchSettlement(address(vault), batchId, lastTotalAssets - lossAmount, 0, lossAmount, false);

        // Total assets should now be 950K USDC
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT - lossAmount);

        // Share price should be 0.95 USDC per stkToken
        uint256 expectedSharePrice = 0.95e6; // 0.95 USDC
        assertEq(vault.sharePrice(), expectedSharePrice);
    }

    /*//////////////////////////////////////////////////////////////
                      MULTIPLE DEPOSIT ACCOUNTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SecondDeposit_SameSharePrice() public {
        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Bob deposits 500K USDC at same share price
        uint256 bobDeposit = 500_000 * _1_USDC;

        // Approve kUSD for staking
        vm.prank(users.bob);
        kUSD.approve(address(vault), bobDeposit);

        bytes32 batchId = vault.getBatchId();
        // Request stake
        vm.prank(users.bob);
        bytes32 requestId = vault.requestStake(users.bob, bobDeposit);

        vm.prank(users.settler);
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            USDC_MAINNET, address(vault), batchId, INITIAL_DEPOSIT + bobDeposit, bobDeposit, 0, false
        );
        vm.prank(users.settler);
        assetRouter.executeSettleBatch(proposalId);

        vm.prank(users.settler);
        vault.closeBatch(batchId, true);

        vm.prank(users.bob);
        vault.claimStakedShares(batchId, requestId);

        // Total assets should be 1.5M USDC
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT + bobDeposit);

        // Alice should have 1M stkTokens, Bob should have 500K stkTokens
        assertEq(vault.balanceOf(users.alice), INITIAL_DEPOSIT);
        assertEq(vault.balanceOf(users.bob), bobDeposit);

        // Total supply should be 1.5M stkTokens
        assertEq(vault.totalSupply(), INITIAL_DEPOSIT + bobDeposit);

        // Share price should remain 1:1
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_SecondDeposit_AfterYield() public {
        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Add 20% yield (200K USDC)
        bytes32 batchId = vault.getBatchId();
        uint256 lastTotalAssets = vault.totalAssets();
        uint256 yield = 200_000 * _1_USDC;

        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + yield, 0, yield, true);

        // Share price is now 1.2 USDC per stkToken
        assertEq(vault.sharePrice(), 1.2e6);

        // Bob deposits 600K USDC (should get 500K stkTokens)
        uint256 bobDeposit = 600_000 * _1_USDC;
        _performStakeAndSettle(users.bob, bobDeposit);

        // Calculate expected stkTokens for Bob
        uint256 expectedBobShares = bobDeposit * 1e6 / 1.2e6; // 500K stkTokens

        // Verify Bob's share balance
        assertApproxEqAbs(vault.balanceOf(users.bob), expectedBobShares, 1); // 1 wei tolerance

        // Total assets should be 1.8M USDC (1.2M + 600K)
        assertEq(vault.totalAssets(), 1.8e6 * _1_USDC);

        // Share price should remain approximately 1.2 USDC
        assertApproxEqRel(vault.sharePrice(), 1.2e6, 0.001e18); // 0.1% tolerance
    }

    function test_MultipleDeposits_DifferentSharePrices() public {
        uint256[] memory deposits = new uint256[](3);
        deposits[0] = 1_000_000 * _1_USDC; // Alice: 1M USDC
        deposits[1] = 500_000 * _1_USDC; // Bob: 500K USDC
        deposits[2] = 250_000 * _1_USDC; // Charlie: 250K USDC

        address[] memory _users = new address[](3);
        _users[0] = users.alice;
        _users[1] = users.bob;
        _users[2] = users.charlie;

        uint256[] memory expectedShares = new uint256[](3);

        for (uint256 i = 0; i < 3; i++) {
            // Record share price before deposit
            uint256 sharePrice = vault.sharePrice();

            // Perform deposit
            _performStakeAndSettle(_users[i], deposits[i]);

            // Calculate expected shares
            expectedShares[i] = deposits[i] * 1e6 / sharePrice;

            // Verify user's share balance
            assertApproxEqAbs(vault.balanceOf(_users[i]), expectedShares[i], 10); // 10 wei tolerance

            // Add some yield before next deposit (10% each time)
            if (i < 2) {
                uint256 currentAssets = vault.totalAssets();
                uint256 yieldAmount = currentAssets / 10; // 10% yield
                vm.prank(address(minter));
                kUSD.mint(address(vault), yieldAmount);
            }
        }

        // Verify total supply equals sum of individual shares
        uint256 totalExpectedShares = expectedShares[0] + expectedShares[1] + expectedShares[2];
        assertApproxEqAbs(vault.totalSupply(), totalExpectedShares, 30); // 30 wei tolerance
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET CONVERSION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ConvertToShares_ZeroTotalSupply() public {
        // With zero total supply, conversion should be 1:1
        uint256 assets = 1000 * _1_USDC;

        // Use internal function via low-level call (testing internal logic)
        // In practice, this is tested through deposit functionality
        _performStakeAndSettle(users.alice, assets);

        // First deposit should always be 1:1
        assertEq(vault.balanceOf(users.alice), assets);
    }

    function test_ConvertToAssets_ZeroTotalSupply() public {
        // With zero total supply, assets per share should be 1:1
        // This is implicitly tested in initial share price
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_ConvertToShares_WithExistingSupply() public {
        // Setup: Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Add yield to change share price
        uint256 yieldAmount = 500_000 * _1_USDC; // 50% yield
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Share price should now be 1.5 USDC per stkToken
        assertEq(vault.sharePrice(), 1.5e6);

        // Bob deposits 750K USDC (should get 500K stkTokens)
        uint256 bobDeposit = 750_000 * _1_USDC;
        _performStakeAndSettle(users.bob, bobDeposit);

        uint256 expectedBobShares = bobDeposit * 1e6 / 1.5e6; // 500K stkTokens
        assertApproxEqAbs(vault.balanceOf(users.bob), expectedBobShares, 1);
    }

    function test_ConvertToAssets_WithExistingSupply() public {
        // Setup: Alice deposits 1M USDC, gets 1M stkTokens
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Add yield
        uint256 yieldAmount = 200_000 * _1_USDC; // 20% yield
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Alice's 1M stkTokens should now be worth 1.2M USDC
        uint256 aliceShares = vault.balanceOf(users.alice);
        uint256 expectedAssetValue = aliceShares * vault.sharePrice() / 1e6;

        assertEq(expectedAssetValue, 1.2e6 * _1_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                        PRECISION AND ROUNDING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SmallDeposit_Precision() public {
        // Test very small deposits to check precision handling
        uint256 smallAmount = 1 * _1_USDC; // 1 USDC

        _performStakeAndSettle(users.alice, smallAmount);

        // Should receive exactly 1 stkToken (1e6 wei)
        assertEq(vault.balanceOf(users.alice), smallAmount);
        assertEq(vault.totalAssets(), smallAmount);
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_DustAmount_Handling() public {
        // Test deposits smaller than dust threshold should fail
        uint256 dustAmount = 999; // Less than 1000 (DEFAULT_DUST_AMOUNT)

        vm.prank(users.alice);
        kUSD.approve(address(vault), dustAmount);

        vm.expectRevert(); // Should revert due to dust threshold
        vm.prank(users.alice);
        vault.requestStake(users.alice, dustAmount);
    }

    function test_LargeNumbers_Precision() public {
        // Test with very large numbers to check for overflow/precision issues
        uint256 largeAmount = 1_000_000_000 * _1_USDC; // 1B USDC

        // Mint large amount to Alice
        _mintKTokenToUser(users.alice, largeAmount, true);

        _performStakeAndSettle(users.alice, largeAmount);

        // Verify no precision loss
        assertEq(vault.balanceOf(users.alice), largeAmount);
        assertEq(vault.totalAssets(), largeAmount);
        assertEq(vault.sharePrice(), 1e6);
    }

    /*//////////////////////////////////////////////////////////////
                        NET ASSETS WITH FEES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_TotalNetAssets_WithoutFees() public {
        // Setup: Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Without any time passing, net assets should equal total assets
        assertEq(vault.totalNetAssets(), vault.totalAssets());
    }

    function test_TotalNetAssets_WithAccruedManagementFees() public {
        // Setup vault with fees
        _setupTestFees();

        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Fast forward time to accrue management fees
        vm.warp(block.timestamp + 365 days);

        // Net assets should be less than total assets due to accrued fees
        uint256 totalAssets = vault.totalAssets();
        uint256 netAssets = vault.totalNetAssets();

        assertLt(netAssets, totalAssets);

        // Difference should be approximately 1% (management fee)
        uint256 feeAmount = totalAssets - netAssets;
        uint256 expectedFeeAmount = totalAssets / 100; // 1%
        assertApproxEqRel(feeAmount, expectedFeeAmount, 0.1e18); // 10% tolerance
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ZeroDeposit_ShouldRevert() public {
        vm.prank(users.alice);
        kUSD.approve(address(vault), 0);

        vm.expectRevert(); // Should revert for zero amount
        vm.prank(users.alice);
        vault.requestStake(users.alice, 0);
    }

    function test_InsufficientBalance_ShouldRevert() public {
        uint256 excessiveAmount = kUSD.balanceOf(users.alice) + 1;

        vm.prank(users.alice);
        kUSD.approve(address(vault), excessiveAmount);

        vm.expectRevert(); // Should revert for insufficient balance
        vm.prank(users.alice);
        vault.requestStake(users.alice, excessiveAmount);
    }

    function test_SharePrice_WithZeroTotalSupply() public view {
        // Edge case: what happens with zero total supply
        // Should maintain 1:1 ratio (1e6 for 6 decimals)
        assertEq(vault.sharePrice(), 1e6);
    }
}
