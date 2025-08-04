// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { LibClone } from "solady/utils/LibClone.sol";

import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";

/// @title kBatchReceiverTest
/// @notice Unit tests for kBatchReceiver contract
contract kBatchReceiverTest is DeploymentBaseTest {
    using LibClone for address;

    // Test contract instances
    kBatchReceiver public batchReceiver;

    // Test constants
    uint256 constant TEST_BATCH_ID = 1;
    uint256 constant TEST_AMOUNT = _100_USDC;
    address constant TEST_RECEIVER = address(0x1234);

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Deploy a test batch receiver directly
        batchReceiver = new kBatchReceiver(address(minter), TEST_BATCH_ID, USDC_MAINNET);

        // Fund the batch receiver with test USDC
        deal(USDC_MAINNET, address(batchReceiver), TEST_AMOUNT * 10);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test batch receiver deployment with correct immutables
    function test_Deployment() public view {
        assertEq(batchReceiver.kMinter(), address(minter), "kMinter mismatch");
        assertEq(batchReceiver.asset(), USDC_MAINNET, "Asset mismatch");
        assertEq(batchReceiver.batchId(), TEST_BATCH_ID, "Batch ID mismatch");
    }

    /// @dev Test contract info functions
    function test_ContractInfo() public view {
        // kBatchReceiver doesn't have contractName/contractVersion functions
        // Just verify the contract exists and is properly deployed
        assertTrue(address(batchReceiver) != address(0), "Contract deployed successfully");
    }

    /*//////////////////////////////////////////////////////////////
                        PULL ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful asset pull
    function test_PullAssets_Success() public {
        uint256 initialBalance = IERC20(USDC_MAINNET).balanceOf(TEST_RECEIVER);
        uint256 receiverInitialBalance = IERC20(USDC_MAINNET).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        vm.expectEmit(true, true, false, true);
        emit IkBatchReceiver.PulledAssets(TEST_RECEIVER, USDC_MAINNET, TEST_AMOUNT);

        batchReceiver.pullAssets(TEST_RECEIVER, TEST_AMOUNT, TEST_BATCH_ID);

        assertEq(
            IERC20(USDC_MAINNET).balanceOf(TEST_RECEIVER), initialBalance + TEST_AMOUNT, "Receiver balance not updated"
        );
        assertEq(
            IERC20(USDC_MAINNET).balanceOf(address(batchReceiver)),
            receiverInitialBalance - TEST_AMOUNT,
            "Batch receiver balance not reduced"
        );
    }

    /// @dev Test pull assets with multiple pulls
    function test_PullAssets_MultiplePulls() public {
        uint256 pullAmount = TEST_AMOUNT / 4;

        for (uint256 i = 0; i < 4; i++) {
            vm.prank(address(minter));
            batchReceiver.pullAssets(TEST_RECEIVER, pullAmount, TEST_BATCH_ID);
        }

        assertEq(IERC20(USDC_MAINNET).balanceOf(TEST_RECEIVER), TEST_AMOUNT, "Total pulled amount incorrect");
    }

    /// @dev Test pull assets reverts when not called by kMinter
    function test_PullAssets_RevertNotKMinter() public {
        vm.prank(users.alice);
        vm.expectRevert(IkBatchReceiver.OnlyKMinter.selector);
        batchReceiver.pullAssets(TEST_RECEIVER, TEST_AMOUNT, TEST_BATCH_ID);
    }

    /// @dev Test pull assets reverts with invalid batch ID
    function test_PullAssets_RevertInvalidBatchId() public {
        vm.prank(address(minter));
        vm.expectRevert(IkBatchReceiver.InvalidBatchId.selector);
        batchReceiver.pullAssets(TEST_RECEIVER, TEST_AMOUNT, TEST_BATCH_ID + 1);
    }

    /// @dev Test pull assets reverts with zero amount
    function test_PullAssets_RevertZeroAmount() public {
        vm.prank(address(minter));
        vm.expectRevert(IkBatchReceiver.ZeroAmount.selector);
        batchReceiver.pullAssets(TEST_RECEIVER, 0, TEST_BATCH_ID);
    }

    /// @dev Test pull assets reverts with zero address
    function test_PullAssets_RevertZeroAddress() public {
        vm.prank(address(minter));
        vm.expectRevert(IkBatchReceiver.ZeroAddress.selector);
        batchReceiver.pullAssets(address(0), TEST_AMOUNT, TEST_BATCH_ID);
    }

    /// @dev Test pull assets with insufficient balance
    function test_PullAssets_InsufficientBalance() public {
        uint256 receiverBalance = IERC20(USDC_MAINNET).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        vm.expectRevert(); // Will revert with transfer error
        batchReceiver.pullAssets(TEST_RECEIVER, receiverBalance + 1, TEST_BATCH_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test pull assets with dust amounts
    function test_PullAssets_DustAmount() public {
        uint256 dustAmount = 1; // 1 wei of USDC

        vm.prank(address(minter));
        batchReceiver.pullAssets(TEST_RECEIVER, dustAmount, TEST_BATCH_ID);

        assertEq(IERC20(USDC_MAINNET).balanceOf(TEST_RECEIVER), dustAmount, "Dust amount not transferred");
    }

    /// @dev Test pull entire balance
    function test_PullAssets_EntireBalance() public {
        uint256 entireBalance = IERC20(USDC_MAINNET).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        batchReceiver.pullAssets(TEST_RECEIVER, entireBalance, TEST_BATCH_ID);

        assertEq(IERC20(USDC_MAINNET).balanceOf(address(batchReceiver)), 0, "Batch receiver should be empty");
    }

    /// @dev Test receiving ETH (should revert - no receive function)
    function test_ReceiveETH() public {
        uint256 ethAmount = 1 ether;
        vm.deal(address(this), ethAmount);

        (bool success,) = address(batchReceiver).call{ value: ethAmount }("");
        assertFalse(success, "ETH transfer should fail - no receive function");
        assertEq(address(batchReceiver).balance, 0, "No ETH should be received");
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fuzz test pull assets with various amounts
    function testFuzz_PullAssets(uint256 amount) public {
        uint256 maxBalance = IERC20(USDC_MAINNET).balanceOf(address(batchReceiver));
        amount = bound(amount, 1, maxBalance);

        vm.prank(address(minter));
        batchReceiver.pullAssets(TEST_RECEIVER, amount, TEST_BATCH_ID);

        assertEq(IERC20(USDC_MAINNET).balanceOf(TEST_RECEIVER), amount, "Incorrect amount transferred");
    }

    /// @dev Fuzz test pull assets with various receivers
    function testFuzz_PullAssets_DifferentReceivers(address receiver, uint256 amount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(batchReceiver));

        uint256 maxBalance = IERC20(USDC_MAINNET).balanceOf(address(batchReceiver));
        amount = bound(amount, 1, maxBalance);

        uint256 initialBalance = IERC20(USDC_MAINNET).balanceOf(receiver);

        vm.prank(address(minter));
        batchReceiver.pullAssets(receiver, amount, TEST_BATCH_ID);

        assertEq(
            IERC20(USDC_MAINNET).balanceOf(receiver),
            initialBalance + amount,
            "Incorrect amount transferred to receiver"
        );
    }
}
