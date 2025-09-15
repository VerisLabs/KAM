// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { _1_USDC } from "../utils/Constants.sol";

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

import {
    KSTAKINGVAULT_IS_PAUSED,
    VAULTCLAIMS_BATCH_NOT_SETTLED,
    VAULTCLAIMS_NOT_BENEFICIARY,
    VAULTCLAIMS_REQUEST_NOT_PENDING
} from "src/errors/Errors.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
/// @title DNVaultTest
/// @notice Tests DNVault

contract DNVaultTest is BaseVaultTest {
    using SafeTransferLib for address;

    event StakingSharesClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 shares);
    event UnstakingAssetsClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
    event StakeRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        bytes32 batchId
    );
    event UnstakeRequestCreated(
        bytes32 indexed requestId, address indexed user, uint256 amount, address recipient, bytes32 batchId
    );

    function setUp() public override {
        DeploymentBaseTest.setUp();

        vault = IkStakingVault(address(dnVault));

        BaseVaultTest.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM STAKED SHARES TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful claim of staked shares
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
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        // Get balance before claim
        uint256 balanceBefore = vault.balanceOf(users.alice);

        // Claim staked shares
        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit StakingSharesClaimed(batchId, requestId, users.alice, 1000 * _1_USDC);
        vault.claimStakedShares(batchId, requestId);

        // Verify user received stkTokens
        uint256 balanceAfter = vault.balanceOf(users.alice);
        assertGt(balanceAfter, balanceBefore);
        assertEq(balanceAfter - balanceBefore, 1000 * _1_USDC);
    }

    /// @dev Test claiming from non-settled batch reverts
    function test_ClaimStakedShares_BatchNotSettled() public {
        // Setup: Create staking request but don't settle
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // Try to claim without settling
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimStakedShares(batchId, requestId);
    }

    /// @dev Test claiming with wrong batch ID reverts
    function test_ClaimStakedShares_InvalidBatchId() public {
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
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        // Try to claim with wrong batch ID
        bytes32 wrongBatchId = keccak256("wrong");
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimStakedShares(wrongBatchId, requestId);
    }

    /// @dev Test claiming already claimed request reverts
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
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        // Claim once successfully
        vm.prank(users.alice);
        vault.claimStakedShares(batchId, requestId);

        // Try to claim again
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_REQUEST_NOT_PENDING));
        vault.claimStakedShares(batchId, requestId);
    }

    /// @dev Test non-beneficiary cannot claim
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
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        // Bob tries to claim Alice's request
        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_NOT_BENEFICIARY));
        vault.claimStakedShares(batchId, requestId);
    }

    /// @dev Test claiming when paused reverts
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
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        // Pause the vault
        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        // Try to claim while paused
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_IS_PAUSED));
        vault.claimStakedShares(batchId, requestId);
    }

    /// @dev Test multiple users claiming from same batch
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

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        uint256 totalAmount = 1000 * _1_USDC + 500 * _1_USDC + 750 * _1_USDC;
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + totalAmount);

        // All users claim their shares
        vm.prank(users.alice);
        vault.claimStakedShares(batchId, requestIdAlice);
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);

        vm.prank(users.bob);
        vault.claimStakedShares(batchId, requestIdBob);
        assertEq(vault.balanceOf(users.bob), 500 * _1_USDC);

        vm.prank(users.charlie);
        vault.claimStakedShares(batchId, requestIdCharlie);
        assertEq(vault.balanceOf(users.charlie), 750 * _1_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                    CLAIM UNSTAKED ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful claim of unstaked assets
    function test_ClaimUnstakedAssets_Success() public {
        // First complete a staking cycle to get stkTokens
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, 1000 * _1_USDC);

        // 1. Request unstaking
        bytes32 unstakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        // Close and settle unstaking batch
        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets - stkBalance);

        // Get kToken balance before claim
        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        // Claim unstaked assets
        vm.prank(users.alice);
        vm.expectEmit(true, false, true, true);
        emit KTokenUnstaked(users.alice, stkBalance, stkBalance);
        vault.claimUnstakedAssets(unstakeBatchId, unstakeRequestId);

        // Verify user received kTokens back
        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, 1000 * _1_USDC);

        // Verify stkTokens were burned from vault
        assertEq(vault.balanceOf(address(vault)), 0);
    }

    /// @dev Test claiming unstaked assets from non-settled batch
    function test_ClaimUnstakedAssets_BatchNotSettled() public {
        // Setup: Get stkTokens first
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        // Request unstaking but don't settle
        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Try to claim without settling
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(batchId, requestId);
    }

    /// @dev Test claiming with invalid batch ID
    function test_ClaimUnstakedAssets_InvalidBatchId() public {
        // Setup: Get stkTokens and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Try to claim with wrong batch ID
        bytes32 wrongBatchId = keccak256("wrong");
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(wrongBatchId, requestId);
    }

    /// @dev Test claiming already claimed unstaking request
    function test_ClaimUnstakedAssets_RequestNotPending() public {
        // Setup: Get stkTokens and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Claim once successfully
        vm.prank(users.alice);
        vault.claimUnstakedAssets(batchId, requestId);

        // Try to claim again
        vm.prank(users.alice);
        vm.expectRevert(bytes(VAULTCLAIMS_REQUEST_NOT_PENDING));
        vault.claimUnstakedAssets(batchId, requestId);
    }

    /// @dev Test non-beneficiary cannot claim unstaking
    function test_ClaimUnstakedAssets_NotBeneficiary() public {
        // Setup: Get stkTokens for Alice and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Bob tries to claim Alice's request
        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_NOT_BENEFICIARY));
        vault.claimUnstakedAssets(batchId, requestId);
    }

    /// @dev Test claiming unstaked assets when paused
    function test_ClaimUnstakedAssets_WhenPaused() public {
        // Setup: Get stkTokens and create unstaking request
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 requestId = vault.requestUnstake(users.alice, 1000 * _1_USDC);

        // Close and settle batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Pause the vault
        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        // Try to claim while paused
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_IS_PAUSED));
        vault.claimUnstakedAssets(batchId, requestId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test complete staking lifecycle: request → settle → claim
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
        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC);

        // 4. Claim staked shares
        vm.prank(users.alice);
        vault.claimStakedShares(batchId, requestId);

        // Verify user received stkTokens
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);
    }

    /// @dev Test complete unstaking lifecycle: stake → unstake → settle → claim
    function test_ClaimFlow_CompleteUnstakingLifecycle() public {
        // First complete a staking cycle to get stkTokens
        _setupUserWithStkTokens(users.alice, 1000 * _1_USDC);

        uint256 stkBalance = vault.balanceOf(users.alice);
        assertEq(stkBalance, 1000 * _1_USDC);

        // 1. Request unstaking
        bytes32 unstakeBatchId = vault.getBatchId();

        vm.prank(users.alice);
        bytes32 unstakeRequestId = vault.requestUnstake(users.alice, stkBalance);

        // Verify stkTokens were transferred to vault
        assertEq(vault.balanceOf(users.alice), 0);
        assertEq(vault.balanceOf(address(vault)), stkBalance);

        // 2. Close unstaking batch
        vm.prank(users.relayer);
        vault.closeBatch(unstakeBatchId, true);

        // 3. Settle unstaking batch
        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), unstakeBatchId, lastTotalAssets - stkBalance);

        // 4. Claim unstaked assets
        uint256 kTokenBalanceBefore = kUSD.balanceOf(users.alice);

        vm.prank(users.alice);
        vault.claimUnstakedAssets(unstakeBatchId, unstakeRequestId);

        // Verify user received kTokens back
        uint256 kTokenBalanceAfter = kUSD.balanceOf(users.alice);
        assertEq(kTokenBalanceAfter - kTokenBalanceBefore, 1000 * _1_USDC, "balance");

        // Verify stkTokens were burned
        assertEq(vault.balanceOf(address(vault)), 0);
        assertEq(vault.netSharePrice(), 1e6);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    /// @dev Test claims across multiple batches
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
        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batch1Id, lastTotalAssets + 1000 * _1_USDC);

        // Alice can claim from batch 1
        vm.prank(users.alice);
        vault.claimStakedShares(batch1Id, request1Id);
        assertEq(vault.balanceOf(users.alice), 1000 * _1_USDC);

        // Bob cannot claim yet (batch 2 not settled)
        vm.prank(users.bob);
        vm.expectRevert(bytes(VAULTCLAIMS_BATCH_NOT_SETTLED));
        vault.claimUnstakedAssets(batch2Id, request2Id);

        // Settle batch 2
        lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batch2Id, lastTotalAssets + 500 * _1_USDC);

        // Now Bob can claim
        vm.prank(users.bob);
        vault.claimStakedShares(batch2Id, request2Id);
        assertEq(vault.balanceOf(users.bob), 500 * _1_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claiming with very small amounts
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

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1 * _1_USDC);

        // Claim small amount
        vm.prank(users.alice);
        vault.claimStakedShares(batchId, requestId);

        // Verify user received the small amount
        assertEq(vault.balanceOf(users.alice), 1 * _1_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Helper to setup a user with stkTokens
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

        uint256 lastTotalAssets = assetRouter.virtualBalance(address(vault), getUSDC());
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + amount);

        // Claim staked shares to get stkTokens
        vm.prank(user);
        vault.claimStakedShares(batchId, requestId);
    }
}
