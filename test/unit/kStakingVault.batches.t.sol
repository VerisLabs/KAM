// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";

import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";
import {
    WRONG_ROLE,
    VAULT_CLOSED
} from "src/kStakingVault/errors/BaseVaultErrors.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";

/// @title kStakingVaultBatchesTest
/// @notice Tests for batch management functionality in kStakingVault
contract kStakingVaultBatchesTest is BaseVaultTest {
    using SafeTransferLib for address;

    event BatchCreated(bytes32 indexed batchId);
    event BatchReceiverCreated(address indexed receiver, bytes32 indexed batchId);
    event BatchSettled(bytes32 indexed batchId);
    event BatchClosed(bytes32 indexed batchId);

    function setUp() public override {
        DeploymentBaseTest.setUp();

        vault = IkStakingVault(address(alphaVault));

        BaseVaultTest.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE NEW BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateNewBatch_Success() public {
        bytes32 currentBatch = vault.getBatchId();

        vm.prank(users.relayer);
        vm.expectEmit(false, false, false, false);
        emit BatchCreated(bytes32(0));
        vault.createNewBatch();

        bytes32 newBatch = vault.getBatchId();

        assertTrue(newBatch != currentBatch);
        assertTrue(newBatch != bytes32(0));
    }

    function test_CreateNewBatch_RequiresRelayerRole() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.createNewBatch();

        vm.prank(users.admin);
        vm.expectRevert(bytes(WRONG_ROLE));
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

    /*//////////////////////////////////////////////////////////////
                        CLOSE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test closeBatch function
    function test_CloseBatch_Success() public {
        // Get current batch
        bytes32 batchId = vault.getBatchId();

        // Close batch without creating new one
        vm.prank(users.relayer);
        vm.expectEmit(true, false, false, true);
        emit BatchClosed(batchId);
        vault.closeBatch(batchId, false);

        // Try to close again should revert
        vm.prank(users.relayer);
        vm.expectRevert(bytes(VAULT_CLOSED));
        vault.closeBatch(batchId, false);
    }

    /// @dev Test closeBatch with create flag
    function test_CloseBatch_WithCreateNew() public {
        bytes32 batchId = vault.getBatchId();

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        bytes32 newBatch = vault.getBatchId();
        assertTrue(newBatch != batchId);
        assertTrue(newBatch != bytes32(0));
    }

    /// @dev Test closeBatch requires relayer role
    function test_CloseBatch_RequiresRelayerRole() public {
        bytes32 batchId = vault.getBatchId();

        // Non-relayer should fail
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.closeBatch(batchId, false);

        vm.prank(users.admin);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.closeBatch(batchId, false);
    }

    /// @dev Test closeBatch on already closed batch
    function test_CloseBatch_AlreadyClosed() public {
        bytes32 batchId = vault.getBatchId();

        // Close batch first time
        vm.prank(users.relayer);
        vault.closeBatch(batchId, false);

        // Try to close again
        vm.prank(users.relayer);
        vm.expectRevert(bytes(VAULT_CLOSED));
        vault.closeBatch(batchId, false);
    }

    /*//////////////////////////////////////////////////////////////
                        SETTLE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test settleBatch function
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
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            USDC_MAINNET, address(vault), batchId, lastTotalAssets + 1000 * _1_USDC, 1000 * _1_USDC, 0, false
        );

        // Execute settlement which internally calls settleBatch
        vm.expectEmit(true, false, false, true);
        emit BatchSettled(batchId);
        assetRouter.executeSettleBatch(proposalId);
    }

    /// @dev Test settleBatch requires kAssetRouter
    function test_SettleBatch_RequiresKAssetRouter() public {
        bytes32 batchId = vault.getBatchId();

        // Direct call should fail
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.settleBatch(batchId);

        vm.prank(users.relayer);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.settleBatch(batchId);

        vm.prank(users.admin);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.settleBatch(batchId);
    }

    /// @dev Test settleBatch on already settled batch
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
        _executeBatchSettlement(address(vault), batchId, lastTotalAssets + 1000 * _1_USDC, 1000 * _1_USDC, 0, false);

        // Try to settle again through assetRouter
        vm.prank(users.relayer);
        vm.expectRevert(IkAssetRouter.BatchIdAlreadyProposed.selector);
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            USDC_MAINNET, address(vault), batchId, lastTotalAssets + 1000 * _1_USDC, 1000 * _1_USDC, 0, false
        );

        // Should revert with Settled error
        vm.expectRevert(IkAssetRouter.ProposalNotFound.selector);
        assetRouter.executeSettleBatch(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                    CREATE BATCH RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test createBatchReceiver deployment
    function test_CreateBatchReceiver_Success() public {
        // Create a batch
        vm.prank(users.relayer);
        vault.createNewBatch();
        bytes32 batchId = vault.getBatchId();

        // Deploy batch receiver as kAssetRouter
        vm.prank(address(assetRouter));
        vm.expectEmit(false, true, false, true);
        emit BatchReceiverCreated(address(0), batchId); // Don't know exact address
        address receiver = vault.createBatchReceiver(batchId);

        // Verify receiver was deployed
        assertTrue(receiver != address(0));
        assertTrue(receiver.code.length > 0);

        // Verify receiver is initialized correctly
        kBatchReceiver batchReceiver = kBatchReceiver(receiver);
        assertEq(batchReceiver.batchId(), batchId);
        assertEq(batchReceiver.asset(), USDC_MAINNET);
    }

    /// @dev Test createBatchReceiver returns existing if already deployed
    function test_CreateBatchReceiver_ReturnsExisting() public {
        // Create a batch
        vm.prank(users.relayer);
        vault.createNewBatch();
        bytes32 batchId = vault.getBatchId();

        // Deploy batch receiver first time
        vm.prank(address(assetRouter));
        address receiver1 = vault.createBatchReceiver(batchId);

        // Deploy again should return same address
        vm.prank(address(assetRouter));
        address receiver2 = vault.createBatchReceiver(batchId);

        assertEq(receiver1, receiver2);
    }

    /// @dev Test createBatchReceiver requires kAssetRouter role
    function test_CreateBatchReceiver_RequiresKAssetRouter() public {
        bytes32 batchId = vault.getBatchId();

        // Non-kAssetRouter should fail
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.createBatchReceiver(batchId);

        vm.prank(users.relayer);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.createBatchReceiver(batchId);

        vm.prank(users.admin);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.createBatchReceiver(batchId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test full batch lifecycle
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
        _executeBatchSettlement(address(vault), batch1, lastTotalAssets + 1000 * _1_USDC, 1000 * _1_USDC, 0, false);

        // 5. User can claim from settled batch
        vm.prank(users.alice);
        vault.claimStakedShares(batch1, requestId);

        // Verify user received stkTokens
        assertGt(vault.balanceOf(users.alice), 0);
    }

    /// @dev Test batch operations when paused
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

        // Create batch receiver should work
        vm.prank(address(assetRouter));
        address receiver = vault.createBatchReceiver(anotherBatch);
        assertTrue(receiver != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test batch operations with zero batch ID
    function test_BatchOperations_ZeroBatchId() public {
        // Close batch with zero ID should still check role
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.closeBatch(bytes32(0), false);

        // Settle batch with zero ID
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.settleBatch(bytes32(0));

        // Create receiver for zero ID
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.createBatchReceiver(bytes32(0));
    }

    /// @dev Test batch operations with max batch ID
    function test_BatchOperations_MaxBatchId() public {
        bytes32 maxBatchId = bytes32(type(uint256).max);

        // These should check role first before any other validation
        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.closeBatch(maxBatchId, false);

        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.settleBatch(maxBatchId);

        vm.prank(users.alice);
        vm.expectRevert(bytes(WRONG_ROLE));
        vault.createBatchReceiver(maxBatchId);
    }
}
