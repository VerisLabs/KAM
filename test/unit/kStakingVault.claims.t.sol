// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { _1_USDC } from "../utils/Constants.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";

import {
    KSTAKINGVAULT_IS_PAUSED,
    VAULTCLAIMS_BATCH_NOT_SETTLED,
    VAULTCLAIMS_NOT_BENEFICIARY,
    VAULTCLAIMS_REQUEST_NOT_PENDING
} from "kam/src/errors/Errors.sol";
import { kStakingVault } from "kam/src/kStakingVault/kStakingVault.sol";

contract kStakingVaultClaimsTest is BaseVaultTest {
    using SafeTransferLib for address;

    function setUp() public override {
        DeploymentBaseTest.setUp();

        vault = IkStakingVault(address(alphaVault));

        BaseVaultTest.setUp();
    }

    /* //////////////////////////////////////////////////////////////
                        CLAIM STAKED SHARES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimStakedShares_Success() public {
        // Setup: Create and settle a staking request
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Get balance before claim
        uint256 balanceBefore = vault.balanceOf(users.alice);

        // Claim staked shares
        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit kStakingVault.StakingSharesClaimed(batchId, requestId, users.alice, 1000 * _1_USDC);
        vault.claimStakedShares(requestId);

        // Verify user received stkTokens
        uint256 balanceAfter = vault.balanceOf(users.alice);
        assertGt(balanceAfter, balanceBefore);
        assertEq(balanceAfter - balanceBefore, 1000 * _1_USDC);
    }

    function test_ClaimStakedShares_BatchNotSettled() public {
        // Setup: Create staking request but don't settle
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Try to claim without settling
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_RequestNotPending() public {
        // Setup: Create and settle a staking request
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Claim once successfully
        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        // Try to claim again
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_REQUEST_NOT_PENDING));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_NotBeneficiary() public {
        // Setup: Create and settle a staking request for Alice
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Bob tries to claim Alice's request
        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_NOT_BENEFICIARY));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_WhenPaused() public {
        // Setup: Create and settle a staking request
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Pause the vault
        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        // Try to claim while paused
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_IS_PAUSED));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_MultipleUsers() public {
        // Setup: Create staking requests for multiple users
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);
        _mintKTokenToUser(users.bob, 500 * _1_USDC, true);
        _mintKTokenToUser(users.charlie, 750 * _1_USDC, true);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);
        vm.prank(users.alice);
        bytes32 requestIdAlice = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.bob);
        kUSD.approve(address(vault), 500 * _1_USDC);
        vm.prank(users.bob);
        bytes32 requestIdBob = vault.requestStake(users.bob, 500 * _1_USDC);

        vm.prank(users.charlie);
        kUSD.approve(address(vault), 750 * _1_USDC);
        vm.prank(users.charlie);
        bytes32 requestIdCharlie = vault.requestStake(users.charlie, 750 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        uint256 totalAmount = 1000 * _1_USDC + 500 * _1_USDC + 750 * _1_USDC;
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // All users claim their shares
        vm.prank(users.alice);
        vault.claimStakedShares(requestIdAlice);
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);

        vm.prank(users.bob);
        vault.claimStakedShares(requestIdBob);
        assertEq(vault.balanceOf(users.bob), 500 * _1_USDC);

        vm.prank(users.charlie);
        vault.claimStakedShares(requestIdCharlie);
        assertEq(vault.balanceOf(users.charlie), 750 * _1_USDC);
    }

    /* //////////////////////////////////////////////////////////////
                    CLAIM UNSTAKED ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimUnstakedAssets_Success_tests() public {
        uint256 aliceDeposit = 1000 * _1_USDC;

        // Setup: First stake to get stkTokens
        _mintKTokenToUser(users.alice, aliceDeposit, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), aliceDeposit);

        bytes32 stakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 stakeRequestId = vault.requestStake(users.alice, aliceDeposit);

        // Close and settle staking batch
        vm.prank(users.relayer);
        vault.closeBatch(stakeBatchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), stakeBatchId, lastTotalAssets);

        // Claim staked shares to get stkTokens
        vm.prank(users.alice);
        vault.claimStakedShares(stakeRequestId);

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, aliceDeposit);

        // Now request unstaking
        bytes32 unstakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        // Close and settle unstaking batch
        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets);

        // Get kToken balance before claim
        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        // Claim unstaked assets
        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit kStakingVault.UnstakingAssetsClaimed(unstakeBatchId, unstakeRequestId, users.alice, aliceDeposit);
        vault.claimUnstakedAssets(unstakeRequestId);

        // Verify user received kTokens back
        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, aliceDeposit);

        // Verify stkTokens were burned from vault
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function test_ClaimUnstakedAssets_WithFees_Success() public {
        _setupTestFees();

        uint256 aliceDeposit = 1000 * _1_USDC;

        // Setup: First stake to get stkTokens
        _mintKTokenToUser(users.alice, aliceDeposit, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), aliceDeposit);

        bytes32 stakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 stakeRequestId = vault.requestStake(users.alice, aliceDeposit);

        // Close and settle staking batch
        vm.prank(users.relayer);
        vault.closeBatch(stakeBatchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), stakeBatchId, lastTotalAssets);

        uint256 sharePrice = vault.sharePrice();
        uint256 netSharePrice = vault.netSharePrice();

        // Claim staked shares to get stkTokens
        vm.prank(users.alice);
        vault.claimStakedShares(stakeRequestId);

        assertEq(vault.sharePrice(), sharePrice);
        assertEq(vault.netSharePrice(), netSharePrice);

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, aliceDeposit);

        // Now request unstaking
        bytes32 unstakeBatchId = vault.getBatchId();

        // Time passes and fees accumulate
        vm.warp(block.timestamp + 30 days);

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        sharePrice = vault.sharePrice();
        netSharePrice = vault.netSharePrice();

        // Close and settle unstaking batch
        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets);

        assertApproxEqRel(vault.sharePrice(), sharePrice, 0.001 ether);
        assertApproxEqRel(vault.netSharePrice(), netSharePrice, 0.001 ether);

        // Get kToken balance before claim
        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        // Claim unstaked assets
        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit kStakingVault.UnstakingAssetsClaimed(unstakeBatchId, unstakeRequestId, users.alice, 999_178_000);
        vault.claimUnstakedAssets(unstakeRequestId);

        assertApproxEqRel(vault.sharePrice(), sharePrice, 0.001 ether);
        assertApproxEqRel(vault.netSharePrice(), netSharePrice, 0.001 ether);

        // Verify user received kTokens back
        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, 999_178_000);

        // Verify stkTokens were burned from vault
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function test_ClaimUnstakedAssets_BatchNotSettled() public {
        // Setup: Get stkTokens first
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Try to claim without settling
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(requestId);
    }

    function test_ClaimUnstakedAssets_RequestNotPending() public {
        // Setup: Get stkTokens and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Claim once successfully
        vm.prank(users.alice);
        vault.claimUnstakedAssets(requestId);

        // Try to claim again
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_REQUEST_NOT_PENDING));
        vault.claimUnstakedAssets(requestId);
    }

    function test_ClaimUnstakedAssets_NotBeneficiary() public {
        // Setup: Get stkTokens for Alice and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Bob tries to claim Alice's request
        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_NOT_BENEFICIARY));
        vault.claimUnstakedAssets(requestId);
    }

    function test_ClaimUnstakedAssets_WhenPaused() public {
        // Setup: Get stkTokens and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Pause the vault
        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        // Try to claim while paused
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_IS_PAUSED));
        vault.claimUnstakedAssets(requestId);
    }

    /* //////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimFlow_CompleteStakingLifecycle() public {
        uint256 balanceBefore = kUSD.balanceOf(users.alice);

        // Setup: Mint kTokens for user
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        // 1. Request staking
        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Verify kTokens were transferred from user
        assertEq(kUSD.balanceOf(users.alice), balanceBefore);

        // 2. Close batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        // 3. Settle batch
        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // 4. Claim staked shares
        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        // Verify user received stkTokens
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);
    }

    function test_ClaimFlow_CompleteUnstakingLifecycle() public {
        // First complete a staking cycle to get stkTokens
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        uint256 sharePrice = vault.sharePrice();
        uint256 netSharePrice = vault.netSharePrice();

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, 1000 * _1_USDC);

        // 1. Request unstaking
        bytes32 unstakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        // Share prices should stay the same
        assertEq(vault.sharePrice(), sharePrice);
        assertEq(vault.netSharePrice(), netSharePrice);

        // Verify stkTokens were transferred to vault
        assertEq(vault.balanceOf(users.alice), 0);
        assertEq(vault.balanceOf(address(vault)), stkBalance);

        // 2. Close unstaking batch
        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        // 3. Settle unstaking batch
        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets);

        // Share prices should stay the same
        assertEq(vault.sharePrice(), sharePrice);
        assertEq(vault.netSharePrice(), netSharePrice);

        // 4. Claim unstaked assets
        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        vm.prank(users.alice);
        vault.claimUnstakedAssets(unstakeRequestId);

        // Share prices should stay the same
        assertEq(vault.sharePrice(), sharePrice);
        assertEq(vault.netSharePrice(), netSharePrice);

        // Verify user received kTokens back
        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, 1000 * _1_USDC);

        // // Verify stkTokens were burned
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function test_ClaimFlow_MultipleBatches() public {
        // Batch 1: Alice stakes 1000
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batch1Id = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 request1Id = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batch1Id, true);

        // Batch 2: Bob stakes 500
        _mintKTokenToUser(users.bob, 500 * _1_USDC, true);

        vm.prank(users.bob);
        kUSD.approve(address(vault), 500 * _1_USDC);

        bytes32 batch2Id = vault.getBatchId();

        vm.prank(users.bob);
        bytes32 request2Id = vault.requestStake(users.bob, 500 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batch2Id, true);

        // Settle batch 1
        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batch1Id, lastTotalAssets);

        // Alice can claim from batch 1
        vm.prank(users.alice);
        vault.claimStakedShares(request1Id);
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);

        // Bob cannot claim yet (batch 2 not settled)
        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(request2Id);

        // Settle batch 2
        lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batch2Id, lastTotalAssets);

        // Now Bob can claim
        vm.prank(users.bob);
        vault.claimStakedShares(request2Id);
        assertEq(vault.balanceOf(users.bob), 500 * _1_USDC);
    }

    /* //////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimStakedShares_SmallAmount() public {
        // Setup: Create and settle a small staking request (1 USDC)
        _mintKTokenToUser(users.alice, 1 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Claim small amount
        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        // Verify user received the small amount
        assertEq(vault.balanceOf(users.alice), 1 * _1_USDC);
    }

    /* //////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupUserWithStkTokens(address user, uint256 amount) internal {
        // Mint kTokens
        _mintKTokenToUser(user, amount, true);

        // Request staking
        vm.prank(user);
        kUSD.approve(address(vault), amount);

        bytes32 batchId = vault.getBatchId();

        vm.prank(user);
        bytes32 requestId = vault.requestStake(user, amount);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Claim staked shares to get stkTokens
        vm.prank(user);
        vault.claimStakedShares(requestId);
    }
}
