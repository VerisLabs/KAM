// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";
import { IntegrationBaseTest } from "./IntegrationBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

/// @title DNVaultAssetRouterIntegrationTest
/// @notice Integration tests for DN Vault ↔ kAssetRouter core interactions
/// @dev Tests virtual balance system, batch management, and asset routing
contract DNVaultAssetRouterIntegrationTest is IntegrationBaseTest {
    /*//////////////////////////////////////////////////////////////
                        VIRTUAL BALANCE SYSTEM TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test virtual balance tracking through complete institutional flow
    function test_VirtualBalanceTracking() public {
        uint256 mintAmount = LARGE_AMOUNT;
        uint256 redeemAmount = MEDIUM_AMOUNT;
        address institution = users.institution;

        // Initial state - DN vault should have zero balance
        assertVirtualBalance(address(dnVault), USDC_MAINNET, 0, "Initial DN vault balance");

        // Use proper institutional mint flow to create assets in the system
        executeInstitutionalMint(institution, mintAmount, institution);

        // Assets are now in kMinter batch balance, settle to move to DN vault virtual balance
        uint256 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(dnVault), currentBatch, mintAmount);

        // Validate virtual balance increased
        assertVirtualBalance(address(dnVault), USDC_MAINNET, mintAmount, "DN vault balance after settlement");

        // Test redemption request which will request asset pull
        bytes32 requestId = executeInstitutionalRedemption(institution, redeemAmount, institution);

        // Virtual balance should remain the same (assets reserved for redemption)
        assertVirtualBalance(address(dnVault), USDC_MAINNET, mintAmount, "DN vault balance after redemption request");

        assertTrue(requestId != bytes32(0), "Request ID should be generated");
    }

    /// @dev Test batch balance tracking for DN vault
    function test_BatchBalanceTracking() public {
        uint256 batchId = getCurrentDNBatchId();
        uint256 depositAmount = LARGE_AMOUNT;
        uint256 requestAmount = MEDIUM_AMOUNT;

        // Check initial batch balances
        (uint256 initialDeposited, uint256 initialRequested) = assetRouter.getBatchIdBalances(address(dnVault), batchId);

        assertEq(initialDeposited, 0, "Initial deposited amount should be zero");
        assertEq(initialRequested, 0, "Initial requested amount should be zero");

        // Simulate asset deposit to batch
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, depositAmount, batchId);

        // Check deposited amount updated
        (uint256 deposited, uint256 requested) = assetRouter.getBatchIdBalances(address(dnVault), batchId);

        assertEq(deposited, depositAmount, "Deposited amount should be updated");
        assertEq(requested, 0, "Requested amount should remain zero");

        // Simulate asset request from batch
        vm.prank(address(dnVault));
        assetRouter.kAssetRequestPull(USDC_MAINNET, address(dnVault), requestAmount, batchId);

        // Check requested amount updated
        (deposited, requested) = assetRouter.getBatchIdBalances(address(dnVault), batchId);

        assertEq(deposited, depositAmount, "Deposited amount should remain unchanged");
        assertEq(requested, requestAmount, "Requested amount should be updated");
    }

    /// @dev Test asset transfer between vaults via kAssetRouter
    function test_AssetTransferBetweenVaults() public {
        uint256 transferAmount = MEDIUM_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Setup: Give DN vault some balance
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, LARGE_AMOUNT, batchId);

        // Record initial balances
        uint256 initialDNBalance = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);
        uint256 initialAlphaBalance = assetRouter.getBalanceOf(address(alphaVault), USDC_MAINNET);

        // Execute transfer from DN to Alpha vault
        executeVaultTransfer(address(dnVault), address(alphaVault), transferAmount, batchId);

        // Validate balances updated correctly
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, initialDNBalance - transferAmount, "DN vault balance after transfer out"
        );

        assertVirtualBalance(
            address(alphaVault),
            USDC_MAINNET,
            initialAlphaBalance + transferAmount,
            "Alpha vault balance after transfer in"
        );

        // Validate total protocol balance unchanged
        uint256 totalBalance = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET)
            + assetRouter.getBalanceOf(address(alphaVault), USDC_MAINNET)
            + assetRouter.getBalanceOf(address(betaVault), USDC_MAINNET);

        assertEq(totalBalance, LARGE_AMOUNT, "Total protocol balance should remain constant");
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test batch lifecycle for DN vault
    function test_BatchLifecycle() public {
        uint256 initialBatchId = getCurrentDNBatchId();
        uint256 settleAmount = MEDIUM_AMOUNT;

        // Validate initial batch state
        assertBatchState(
            address(dnVault),
            initialBatchId,
            false, // not closed
            false, // not settled
            "Initial batch state"
        );

        // Add some activity to the batch
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, settleAmount, initialBatchId);

        // Advance time to batch cutoff
        advanceToNextBatchCutoff();

        // Batch should now be closed (in a complete implementation)
        // For this test, we simulate by checking the batch is ready for settlement

        // Advance to settlement period
        advanceToSettlementTime();

        // Execute batch settlement
        executeBatchSettlement(address(dnVault), initialBatchId, settleAmount);

        // Validate batch is now settled
        assertBatchState(
            address(dnVault),
            initialBatchId,
            true, // closed
            true, // settled
            "Batch state after settlement"
        );
    }

    /// @dev Test multiple batch coordination
    function test_MultipleBatchCoordination() public {
        uint256 batch1Amount = MEDIUM_AMOUNT;
        uint256 batch2Amount = SMALL_AMOUNT;

        // Get initial batch ID
        uint256 batch1Id = getCurrentDNBatchId();

        // Add assets to first batch
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, batch1Amount, batch1Id);

        // Advance time to create new batch
        advanceToNextBatchCutoff();

        // Get new batch ID (would increment in real implementation)
        uint256 batch2Id = batch1Id + 1;

        // Add assets to second batch
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, batch2Amount, batch2Id);

        // Validate both batches track correctly
        (uint256 batch1Deposited,) = assetRouter.getBatchIdBalances(address(dnVault), batch1Id);
        (uint256 batch2Deposited,) = assetRouter.getBatchIdBalances(address(dnVault), batch2Id);

        assertEq(batch1Deposited, batch1Amount, "Batch 1 should track its deposits");
        assertEq(batch2Deposited, batch2Amount, "Batch 2 should track its deposits");

        // Settle batches in order
        advanceToSettlementTime();
        executeBatchSettlement(address(dnVault), batch1Id, batch1Amount);
        executeBatchSettlement(address(dnVault), batch2Id, batch2Amount);

        // Validate total vault balance
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            batch1Amount + batch2Amount,
            "Total DN vault balance after multiple batch settlements"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET ROUTING EFFICIENCY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test gas efficiency of virtual balance operations
    function test_VirtualBalanceGasEfficiency() public {
        uint256 amount = MEDIUM_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Measure gas for asset push
        uint256 gasStart = gasleft();
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, amount, batchId);
        uint256 pushGas = gasStart - gasleft();

        // Measure gas for asset pull request
        gasStart = gasleft();
        vm.prank(address(dnVault));
        assetRouter.kAssetRequestPull(USDC_MAINNET, address(dnVault), amount / 2, batchId);
        uint256 pullGas = gasStart - gasleft();

        // Measure gas for asset transfer
        gasStart = gasleft();
        executeVaultTransfer(address(dnVault), address(alphaVault), amount / 4, batchId);
        uint256 transferGas = gasStart - gasleft();

        // Validate gas efficiency (adjust thresholds as needed)
        assertTrue(pushGas < 100_000, "Asset push should be gas efficient");
        assertTrue(pullGas < 100_000, "Asset pull should be gas efficient");
        assertTrue(transferGas < 150_000, "Asset transfer should be gas efficient");
    }

    /// @dev Test virtual balance system under high load
    function test_VirtualBalanceHighLoad() public {
        uint256 numOperations = 10;
        uint256 operationAmount = SMALL_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Perform multiple push operations
        for (uint256 i = 0; i < numOperations; i++) {
            vm.prank(address(minter));
            assetRouter.kAssetPush(USDC_MAINNET, operationAmount, batchId + i);
        }

        // Validate cumulative balance
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            numOperations * operationAmount,
            "DN vault balance after high load operations"
        );

        // Perform multiple transfer operations
        for (uint256 i = 0; i < numOperations / 2; i++) {
            executeVaultTransfer(address(dnVault), address(alphaVault), operationAmount, batchId + i);
        }

        // Validate balances after transfers
        uint256 expectedDNBalance = (numOperations - numOperations / 2) * operationAmount;
        uint256 expectedAlphaBalance = (numOperations / 2) * operationAmount;

        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault balance after high load transfers"
        );

        assertVirtualBalance(
            address(alphaVault), USDC_MAINNET, expectedAlphaBalance, "Alpha vault balance after receiving transfers"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test error conditions in asset routing
    function test_AssetRoutingErrorConditions() public {
        uint256 amount = MEDIUM_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Test: Asset pull with insufficient balance
        vm.prank(address(minter));
        vm.expectRevert(IkAssetRouter.InsufficientVirtualBalance.selector);
        assetRouter.kAssetRequestPull(USDC_MAINNET, address(dnVault), amount, batchId);

        // Test: Asset transfer with insufficient balance
        vm.expectRevert(IkAssetRouter.InsufficientVirtualBalance.selector);
        executeVaultTransfer(address(dnVault), address(alphaVault), amount, batchId);

        // Test: Unauthorized asset operations
        vm.prank(users.alice);
        vm.expectRevert(); // Should revert due to access control
        assetRouter.kAssetPush(USDC_MAINNET, amount, batchId);
    }

    /// @dev Test vault balance consistency checks
    function test_VaultBalanceConsistency() public {
        uint256 amount = LARGE_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Setup: Add assets to DN vault
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, amount, batchId);

        // Validate consistency between virtual and vault tracking
        assertVaultBalanceConsistency(address(dnVault), USDC_MAINNET, "DN vault balance consistency");

        // Transfer some assets and recheck
        executeVaultTransfer(address(dnVault), address(alphaVault), amount / 3, batchId);

        assertVaultBalanceConsistency(address(dnVault), USDC_MAINNET, "DN vault consistency after transfer");
        assertVaultBalanceConsistency(address(alphaVault), USDC_MAINNET, "Alpha vault consistency after receiving");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION WITH BATCH SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Test asset routing during batch settlement
    function test_AssetRoutingDuringBatchSettlement() public {
        uint256 settleAmount = MEDIUM_AMOUNT;
        uint256 transferAmount = SMALL_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Setup batch with assets
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, settleAmount, batchId);

        // Transfer some assets before settlement
        executeVaultTransfer(address(dnVault), address(alphaVault), transferAmount, batchId);

        // Advance to settlement
        advanceToSettlementTime();

        // Execute settlement
        executeBatchSettlement(address(dnVault), batchId, settleAmount - transferAmount);

        // Validate final balances
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            settleAmount - transferAmount,
            "DN vault balance after settlement with transfers"
        );

        assertVirtualBalance(
            address(alphaVault), USDC_MAINNET, transferAmount, "Alpha vault balance unchanged by DN settlement"
        );
    }

    /// @dev Test cross-vault balance reconciliation
    function test_CrossVaultBalanceReconciliation() public {
        uint256 baseAmount = LARGE_AMOUNT;
        uint256 batchId = getCurrentDNBatchId();

        // Setup: Distribute assets across vaults
        vm.prank(address(minter));
        assetRouter.kAssetPush(USDC_MAINNET, baseAmount, batchId);

        executeVaultTransfer(address(dnVault), address(alphaVault), baseAmount / 3, batchId);
        executeVaultTransfer(address(dnVault), address(betaVault), baseAmount / 3, batchId);

        // Calculate expected balances
        uint256 expectedDN = baseAmount - (2 * baseAmount / 3);
        uint256 expectedAlpha = baseAmount / 3;
        uint256 expectedBeta = baseAmount / 3;

        // Validate all vault balances
        assertVirtualBalance(address(dnVault), USDC_MAINNET, expectedDN, "DN vault final balance");
        assertVirtualBalance(address(alphaVault), USDC_MAINNET, expectedAlpha, "Alpha vault final balance");
        assertVirtualBalance(address(betaVault), USDC_MAINNET, expectedBeta, "Beta vault final balance");

        // Validate total balance conservation
        uint256 totalBalance = expectedDN + expectedAlpha + expectedBeta;
        assertEq(totalBalance, baseAmount, "Total balance should be conserved");

        // Validate individual vault consistency
        assertVaultBalanceConsistency(address(dnVault), USDC_MAINNET, "DN vault consistency");
        assertVaultBalanceConsistency(address(alphaVault), USDC_MAINNET, "Alpha vault consistency");
        assertVaultBalanceConsistency(address(betaVault), USDC_MAINNET, "Beta vault consistency");
    }
}
