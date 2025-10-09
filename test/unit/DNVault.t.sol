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

contract DNVaultTest is BaseVaultTest {
    using SafeTransferLib for address;

    function setUp() public override {
        DeploymentBaseTest.setUp();

        vault = IkStakingVault(address(dnVault));

        BaseVaultTest.setUp();
    }

    /* //////////////////////////////////////////////////////////////
                        CLAIM STAKED SHARES TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimStakedShares_Success() public {
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        uint256 balanceBefore = vault.balanceOf(users.alice);

        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit kStakingVault.StakingSharesClaimed(batchId, requestId, users.alice, 1000 * _1_USDC);
        vault.claimStakedShares(requestId);

        uint256 balanceAfter = vault.balanceOf(users.alice);
        assertGt(balanceAfter, balanceBefore);
        assertEq(balanceAfter - balanceBefore, 1000 * _1_USDC);
    }

    function test_ClaimStakedShares_BatchNotSettled() public {
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_RequestNotPending() public {
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_REQUEST_NOT_PENDING));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_NotBeneficiary() public {
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_NOT_BENEFICIARY));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_WhenPaused() public {
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_IS_PAUSED));
        vault.claimStakedShares(requestId);
    }

    function test_ClaimStakedShares_MultipleUsers() public {
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

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        uint256 totalAmount = 1000 * _1_USDC + 500 * _1_USDC + 750 * _1_USDC;
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + totalAmount);

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

    function test_ClaimUnstakedAssets_Success() public {
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, 1000 * _1_USDC);

        bytes32 unstakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets - stkBalance);

        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit kStakingVault.KTokenUnstaked(users.alice, stkBalance, stkBalance);
        vault.claimUnstakedAssets(unstakeRequestId);

        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, 1000 * _1_USDC);

        assertEq(vault.balanceOf(address(vault)), 0);
    }

    function test_ClaimUnstakedAssets_BatchNotSettled() public {
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(requestId);
    }

    function test_ClaimUnstakedAssets_RequestNotPending() public {
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        vm.prank(users.alice);
        vault.claimUnstakedAssets(requestId);

        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_REQUEST_NOT_PENDING));
        vault.claimUnstakedAssets(requestId);
    }

    function test_ClaimUnstakedAssets_NotBeneficiary() public {
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_NOT_BENEFICIARY));
        vault.claimUnstakedAssets(requestId);
    }

    function test_ClaimUnstakedAssets_WhenPaused() public {
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_IS_PAUSED));
        vault.claimUnstakedAssets(requestId);
    }

    /* //////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimFlow_CompleteStakingLifecycle() public {
        uint256 balanceBefore = kUSD.balanceOf(users.alice);

        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        assertEq(kUSD.balanceOf(users.alice), balanceBefore);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);
    }

    function test_ClaimFlow_CompleteUnstakingLifecycle() public {
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, 1000 * _1_USDC);

        bytes32 unstakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        assertEq(vault.balanceOf(users.alice), 0);
        assertEq(vault.balanceOf(address(vault)), stkBalance);

        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets - stkBalance);

        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        vm.prank(users.alice);
        vault.claimUnstakedAssets(unstakeRequestId);

        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, 1000 * _1_USDC, "balance");

        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.netSharePrice(), 1e6);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_ClaimFlow_MultipleBatches() public {
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batch1Id = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 request1Id = vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batch1Id, true);

        _mintKTokenToUser(users.bob, 500 * _1_USDC, true);

        vm.prank(users.bob);
        kUSD.approve(address(vault), 500 * _1_USDC);

        bytes32 batch2Id = vault.getBatchId();

        vm.prank(users.bob);
        bytes32 request2Id = vault.requestStake(users.bob, 500 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batch2Id, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batch1Id, lastTotalAssets + 1000 * _1_USDC);

        vm.prank(users.alice);
        vault.claimStakedShares(request1Id);
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);

        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(request2Id);

        lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batch2Id, lastTotalAssets + 500 * _1_USDC);

        vm.prank(users.bob);
        vault.claimStakedShares(request2Id);
        assertEq(vault.balanceOf(users.bob), 500 * _1_USDC);
    }

    /* //////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimStakedShares_SmallAmount() public {
        _mintKTokenToUser(users.alice, 1 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1 * _1_USDC);

        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        assertEq(vault.balanceOf(users.alice), 1 * _1_USDC);
    }

    /* //////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupUserWithStkTokens(address user, uint256 amount) internal {
        _mintKTokenToUser(user, amount, true);

        vm.prank(user);
        kUSD.approve(address(vault), amount);

        bytes32 batchId = vault.getBatchId();

        vm.prank(user);
        bytes32 requestId = vault.requestStake(user, amount);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), tokens.usdc);
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + amount);

        vm.prank(user);
        vault.claimStakedShares(requestId);
    }
}
