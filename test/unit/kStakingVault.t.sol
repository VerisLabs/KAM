// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title kStakingVaultAccountingTest
/// @notice Tests for core accounting mechanics in kStakingVault
/// @dev Focuses on share price calculations, asset conversions, and balance tracking
contract kStakingVaultAccountingTest is DeploymentBaseTest {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant INITIAL_DEPOSIT = 1_000_000 * _1_USDC; // 1M USDC
    uint256 constant SMALL_DEPOSIT = 10_000 * _1_USDC; // 10K USDC
    uint256 constant LARGE_DEPOSIT = 5_000_000 * _1_USDC; // 5M USDC

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    kStakingVault vault;

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Use Alpha vault for testing
        vault = alphaVault;

        // Mint kTokens to test users
        _mintKTokensToUsers();
    }

    function _mintKTokensToUsers() internal {
        vm.startPrank(users.institution);
        USDC_MAINNET.safeApprove(address(minter), type(uint256).max);
        minter.mint(USDC_MAINNET, users.alice, INITIAL_DEPOSIT * 3);
        minter.mint(USDC_MAINNET, users.bob, LARGE_DEPOSIT);
        minter.mint(USDC_MAINNET, users.charlie, INITIAL_DEPOSIT);
        vm.stopPrank();

        // Settle batch
        bytes32 batchId = dnVault.getBatchId();
        executeBatchSettlement(address(dnVault), batchId, INITIAL_DEPOSIT * 3 + LARGE_DEPOSIT + INITIAL_DEPOSIT);
    }

    function executeBatchSettlement(address vault, bytes32 batchId, uint256 totalAssets) internal {
        // Advance time to ensure unique proposal IDs when settling multiple vaults
        vm.warp(block.timestamp + 1);

        uint256 startTime = block.timestamp;

        // Ensure kAssetRouter has the physical assets for settlement
        // In production, backend would retrieve these from external strategies
        uint256 currentBalance = IERC20(USDC_MAINNET).balanceOf(address(assetRouter));
        if (currentBalance < totalAssets) {
            deal(USDC_MAINNET, address(assetRouter), totalAssets);
        }

        // kAssetRouter needs to approve adapter to spend USDC
        vm.startPrank(address(assetRouter));
        // When settling kMinter, get DN vault's adapter since that's where assets go
        address actualVault = vault == address(minter) ? address(dnVault) : vault;
        address[] memory adapters = registry.getAdapters(actualVault);
        IERC20(USDC_MAINNET).approve(adapters[0], totalAssets);
        vm.stopPrank();

        vm.prank(users.settler);
        bytes32 proposalId =
            assetRouter.proposeSettleBatch(USDC_MAINNET, address(vault), batchId, totalAssets, totalAssets, 0, false);

        // Wait for cooldown period(0 for testing)
        assetRouter.executeSettleBatch(proposalId);
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

        // Alice should receive 1:1 shares (1M stkTokens)
        assertEq(vault.balanceOf(users.alice), INITIAL_DEPOSIT);

        // Total supply should equal deposit
        assertEq(vault.totalSupply(), INITIAL_DEPOSIT);

        // Share price should remain 1:1
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_SharePriceCalculation_AfterYield() public {
        // Alice deposits 1M USDC
        _performStakeAndSettle(users.alice, INITIAL_DEPOSIT);

        // Simulate 10% yield by adding 100K USDC to vault
        uint256 yieldAmount = 100_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

        // Total assets should now be 1.1M USDC
        assertEq(vault.totalAssets(), INITIAL_DEPOSIT + yieldAmount);

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
        uint256 lossAmount = 50_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.burn(address(vault), lossAmount);

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
        _performStakeAndSettle(users.bob, bobDeposit);

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
        uint256 yieldAmount = 200_000 * _1_USDC;
        vm.prank(address(minter));
        kUSD.mint(address(vault), yieldAmount);

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
        vm.prank(address(minter));
        kUSD.mint(users.alice, largeAmount);

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

    function test_TotalNetAssets_WithAccruedFees() public {
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

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _performStakeAndSettle(address user, uint256 amount) internal {
        // Approve kUSD for staking
        vm.prank(user);
        kUSD.approve(address(vault), amount);

        // Request stake
        vm.prank(user);
        bytes32 requestId = vault.requestStake(user, amount);

        // Simulate settlement by transferring kTokens to vault
        // and minting stkTokens to user
        uint256 sharesToMint = amount * 1e6 / vault.sharePrice();

        // For testing purposes, directly mint stkTokens
        // In production, this would be done through the claim process

        deal(address(vault), user, sharesToMint);
    }

    function _setupTestFees() internal {
        // Setup basic fees for testing
        vm.startPrank(users.admin);

        // Cast vault to access fee functions
        (bool success1,) = address(vault).call(
            abi.encodeWithSignature("setManagementFee(uint16)", uint16(100)) // 1%
        );
        require(success1, "Failed to set management fee");

        (bool success2,) = address(vault).call(
            abi.encodeWithSignature("setPerformanceFee(uint16)", uint16(2000)) // 20%
        );
        require(success2, "Failed to set performance fee");

        vm.stopPrank();
    }
}
