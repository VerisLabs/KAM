// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { _1_USDC } from "../utils/Constants.sol";

import { console2 } from "forge-std/console2.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";

import {
    KASSETROUTER_BATCH_ID_PROPOSED,
    KASSETROUTER_PROPOSAL_NOT_FOUND,
    KSTAKINGVAULT_BATCH_LIMIT_REACHED,
    KSTAKINGVAULT_MAX_TOTAL_ASSETS_REACHED,
    KSTAKINGVAULT_WRONG_ROLE,
    VAULTBATCHES_VAULT_CLOSED
} from "kam/src/errors/Errors.sol";
import { kStakingVault } from "kam/src/kStakingVault/kStakingVault.sol";

contract kStakingVaultBatchesTest is BaseVaultTest {
    using SafeTransferLib for address;

    function setUp() public override {
        DeploymentBaseTest.setUp();

        vault = IkStakingVault(address(alphaVault));

        BaseVaultTest.setUp();
    }

    /* //////////////////////////////////////////////////////////////
                        CREATE NEW BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateNewBatch_Success() public {
        bytes32 currentBatch = vault.getBatchId();

        vm.prank(users.relayer);
        vm.expectEmit(false, false, false, false);
        emit kStakingVault.BatchCreated(bytes32(0));
        vault.createNewBatch();

        bytes32 newBatch = vault.getBatchId();

        assertTrue(newBatch != currentBatch);
        assertTrue(newBatch != bytes32(0));
    }

    function test_CreateNewBatch_RequiresRelayerRole() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.createNewBatch();

        vm.prank(users.admin);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.createNewBatch();
    }

    function test_CreateNewBatch_Multiple() public {
        bytes32[] memory batches = new bytes32[](3);

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(users.relayer);
            vault.createNewBatch();
            batches[i] = vault.getBatchId();

            for (uint256 j = 0; j < i; j++) {
                assertTrue(batches[i] != batches[j]);
            }
        }
    }

    /* //////////////////////////////////////////////////////////////
                        CLOSE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CloseBatch_Success() public {
        // Get current batch
        bytes32 batchId = vault.getBatchId();

        // Close batch without creating new one
        vm.prank(users.relayer);
        vm.expectEmit(true, false, false, true);
        emit kStakingVault.BatchClosed(batchId);
        vault.closeBatch(batchId, false);

        // Try to close again should revert
        vm.prank(users.relayer);
        vm.expectRevert(bytes(VAULTBATCHES_VAULT_CLOSED));
        vault.closeBatch(batchId, false);
    }

    function test_CloseBatch_WithCreateNew() public {
        bytes32 batchId = vault.getBatchId();

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        bytes32 newBatch = vault.getBatchId();
        assertTrue(newBatch != batchId);
        assertTrue(newBatch != bytes32(0));
    }

    function test_CloseBatch_RequiresRelayerRole() public {
        bytes32 batchId = vault.getBatchId();

        // Non-relayer should fail
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.closeBatch(batchId, false);

        vm.prank(users.admin);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.closeBatch(batchId, false);
    }

    function test_CloseBatch_AlreadyClosed() public {
        bytes32 batchId = vault.getBatchId();

        // Close batch first time
        vm.prank(users.relayer);
        vault.closeBatch(batchId, false);

        // Try to close again
        vm.prank(users.relayer);
        vm.expectRevert(bytes(VAULTBATCHES_VAULT_CLOSED));
        vault.closeBatch(batchId, false);
    }

    /* //////////////////////////////////////////////////////////////
                        SETTLE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SettleBatch_Success() public {
        // Create a stake request to have a batch to settle
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        vault.requestStake(users.alice, 1000 * _1_USDC);

        // Close the batch
        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        // Settle batch through assetRouter (which calls settleBatch)
        uint256 lastTotalAssets = vault.totalAssets();

        vm.prank(users.relayer);
        bytes32 proposalId =
            assetRouter.proposeSettleBatch(tokens.usdc, address(vault), batchId, lastTotalAssets + 1000 * _1_USDC, 0, 0);

        // Execute settlement which internally calls settleBatch
        vm.expectEmit(true, false, false, true);
        emit kStakingVault.BatchSettled(batchId);
        assetRouter.executeSettleBatch(proposalId);
    }

    function test_SettleBatch_RequiresKAssetRouter() public {
        bytes32 batchId = vault.getBatchId();

        // Direct call should fail
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.settleBatch(batchId);

        vm.prank(users.relayer);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.settleBatch(batchId);

        vm.prank(users.admin);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.settleBatch(batchId);
    }

    function test_SettleBatch_AlreadySettled_Revert() public {
        // Create and settle a batch
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);

        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);

        bytes32 batchId = vault.getBatchId();

        vm.prank(users.alice);
        vault.requestStake(users.alice, 1000 * _1_USDC);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        // Settle batch
        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets);

        // Try to settle again through assetRouter
        vm.prank(users.relayer);
        vm.expectRevert(bytes(KASSETROUTER_BATCH_ID_PROPOSED));
        bytes32 proposalId =
            assetRouter.proposeSettleBatch(tokens.usdc, address(vault), batchId, lastTotalAssets + 1000 * _1_USDC, 0, 0);

        // Should revert with Settled error
        vm.expectRevert(bytes(KASSETROUTER_PROPOSAL_NOT_FOUND));
        assetRouter.executeSettleBatch(proposalId);
    }

    /* //////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BatchLifecycle_Complete() public {
        // 1. Get initial batch
        bytes32 batch1 = vault.getBatchId();

        // 2. User stakes in batch
        _mintKTokenToUser(users.alice, 1000 * _1_USDC, true);
        vm.prank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);
        vm.prank(users.alice);
        bytes32 requestId = vault.requestStake(users.alice, 1000 * _1_USDC);

        // 3. Close batch and create new one
        vm.prank(users.relayer);
        vault.closeBatch(batch1, true);

        vm.prank(users.relayer);
        bytes32 batch2 = vault.getBatchId();

        console2.logBytes32(batch1);
        console2.logBytes32(batch2);

        assertTrue(batch2 != batch1);

        // 4. Settle the closed batch
        uint256 lastTotalAssets = vault.totalAssets();
        _executeBatchSettlement(address(vault), batch1, lastTotalAssets);

        // 5. User can claim from settled batch
        vm.prank(users.alice);
        vault.claimStakedShares(requestId);

        // Verify user received stkTokens
        assertGt(vault.balanceOf(users.alice), 0);
    }

    function test_BatchOperations_WhenPaused() public {
        // Pause the vault
        vm.prank(users.emergencyAdmin);
        kStakingVault(payable(address(vault))).setPaused(true);

        // Batch operations should still work (they're admin functions)

        // Create new batch should work
        vm.prank(users.relayer);
        vault.createNewBatch();
        bytes32 newBatch = vault.getBatchId();
        assertTrue(newBatch != bytes32(0));

        // Close batch should work
        vm.prank(users.relayer);
        vault.closeBatch(newBatch, false);

        // Create another batch for testing
        vm.prank(users.relayer);
        vault.createNewBatch();
        bytes32 anotherBatch = vault.getBatchId();
    }

    /* //////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BatchOperations_ZeroBatchId() public {
        // Close batch with zero ID should still check role
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.closeBatch(bytes32(0), false);

        // Settle batch with zero ID
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.settleBatch(bytes32(0));
    }

    function test_BatchOperations_MaxBatchId() public {
        bytes32 maxBatchId = bytes32(type(uint256).max);

        // These should check role first before any other validation
        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.closeBatch(maxBatchId, false);

        vm.prank(users.alice);
        vm.expectRevert(bytes(KSTAKINGVAULT_WRONG_ROLE));
        vault.settleBatch(maxBatchId);
    }

    function test_reach_max_total_assets() public {
        vm.prank(users.admin);
        vault.setMaxTotalAssets(0);

        vm.startPrank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);
        vm.expectRevert(bytes(KSTAKINGVAULT_MAX_TOTAL_ASSETS_REACHED));
        vault.requestStake(users.alice, 1000 * _1_USDC);
        vm.stopPrank();
    }

    function test_exceed_batch_deposit_limit() public {
        vm.prank(users.admin);
        registry.setAssetBatchLimits(address(vault), 999 * _1_USDC, 0);

        vm.startPrank(users.alice);
        kUSD.approve(address(vault), 1000 * _1_USDC);
        vm.expectRevert(bytes(KSTAKINGVAULT_BATCH_LIMIT_REACHED));
        vault.requestStake(users.alice, 1000 * _1_USDC);
        vm.stopPrank();
    }
}
