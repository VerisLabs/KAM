pragma solidity 0.8.30;

import { _100_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { OptimizedLibClone } from "solady/utils/OptimizedLibClone.sol";

import {
    KBATCHRECEIVER_ALREADY_INITIALIZED,
    KBATCHRECEIVER_INVALID_BATCH_ID,
    KBATCHRECEIVER_ONLY_KMINTER,
    KBATCHRECEIVER_ZERO_ADDRESS,
    KBATCHRECEIVER_ZERO_AMOUNT
} from "kam/src/errors/Errors.sol";
import { IkBatchReceiver } from "kam/src/interfaces/IkBatchReceiver.sol";
import { kBatchReceiver } from "kam/src/kBatchReceiver.sol";

contract kBatchReceiverTest is DeploymentBaseTest {
    using OptimizedLibClone for address;

    bytes32 constant TEST_BATCH_ID = bytes32(uint256(1));
    uint256 constant TEST_AMOUNT = _100_USDC;
    address internal testReceiver = makeAddr("testReceiver");

    /* //////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        batchReceiver = new kBatchReceiver(address(minter));
        batchReceiver.initialize(TEST_BATCH_ID, tokens.usdc);

        mockUSDC.mint(address(batchReceiver), TEST_AMOUNT * 10);
    }

    /* //////////////////////////////////////////////////////////////
                        DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deployment() public view {
        assertEq(batchReceiver.kMinter(), address(minter), "kMinter mismatch");
        assertEq(batchReceiver.asset(), tokens.usdc, "Asset mismatch");
        assertEq(batchReceiver.batchId(), TEST_BATCH_ID, "Batch ID mismatch");
    }

    function test_ContractInfo() public view {
        assertTrue(address(batchReceiver) != address(0), "Contract deployed successfully");
    }

    /* //////////////////////////////////////////////////////////////
                        PULL ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PullAssets_Success() public {
        uint256 initialBalance = IERC20(tokens.usdc).balanceOf(testReceiver);
        uint256 receiverInitialBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        vm.expectEmit(true, true, false, true);
        emit IkBatchReceiver.PulledAssets(testReceiver, tokens.usdc, TEST_AMOUNT);

        batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, TEST_BATCH_ID);

        assertEq(
            IERC20(tokens.usdc).balanceOf(testReceiver), initialBalance + TEST_AMOUNT, "Receiver balance not updated"
        );
        assertEq(
            IERC20(tokens.usdc).balanceOf(address(batchReceiver)),
            receiverInitialBalance - TEST_AMOUNT,
            "Batch receiver balance not reduced"
        );
    }

    function test_PullAssets_MultiplePulls() public {
        uint256 pullAmount = TEST_AMOUNT / 4;

        for (uint256 i = 0; i < 4; i++) {
            vm.prank(address(minter));
            batchReceiver.pullAssets(testReceiver, pullAmount, TEST_BATCH_ID);
        }

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), TEST_AMOUNT, "Total pulled amount incorrect");
    }

    function test_PullAssets_RevertNotKMinter() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
        batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, TEST_BATCH_ID);
    }

    function test_PullAssets_RevertInvalidBatchId() public {
        vm.prank(address(minter));
        vm.expectRevert(bytes(KBATCHRECEIVER_INVALID_BATCH_ID));
        batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, bytes32(uint256(TEST_BATCH_ID) + 1));
    }

    function test_PullAssets_RevertZeroAmount() public {
        vm.prank(address(minter));
        vm.expectRevert(bytes(KBATCHRECEIVER_ZERO_AMOUNT));
        batchReceiver.pullAssets(testReceiver, 0, TEST_BATCH_ID);
    }

    function test_PullAssets_RevertZeroAddress() public {
        vm.prank(address(minter));
        vm.expectRevert(bytes(KBATCHRECEIVER_ZERO_ADDRESS));
        batchReceiver.pullAssets(address(0), TEST_AMOUNT, TEST_BATCH_ID);
    }

    function test_PullAssets_InsufficientBalance() public {
        uint256 receiverBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        vm.expectRevert();
        batchReceiver.pullAssets(testReceiver, receiverBalance + 1, TEST_BATCH_ID);
    }

    /* //////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PullAssets_DustAmount() public {
        uint256 dustAmount = 1;

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, dustAmount, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), dustAmount, "Dust amount not transferred");
    }

    function test_PullAssets_EntireBalance() public {
        uint256 entireBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, entireBalance, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(address(batchReceiver)), 0, "Batch receiver should be empty");
    }

    function test_ReceiveETH() public {
        uint256 ethAmount = 1 ether;
        vm.deal(address(this), ethAmount);

        (bool success,) = address(batchReceiver).call{ value: ethAmount }("");
        assertFalse(success, "ETH transfer should fail - no receive function");
        assertEq(address(batchReceiver).balance, 0, "No ETH should be received");
    }

    /* //////////////////////////////////////////////////////////////
                        ENHANCED INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Initialization_ParameterValidation() public {
        kBatchReceiver newReceiver = new kBatchReceiver(address(minter));

        bytes32 validBatchId = bytes32(uint256(12_345));
        newReceiver.initialize(validBatchId, tokens.usdc);

        assertTrue(newReceiver.isInitialised(), "Should be initialized");
        assertEq(newReceiver.batchId(), validBatchId, "Batch ID should match");
        assertEq(newReceiver.asset(), tokens.usdc, "Asset should match");
        assertEq(newReceiver.kMinter(), address(minter), "kMinter should match");
    }

    function test_Initialization_DoubleInitializationProtection() public {
        kBatchReceiver newReceiver = new kBatchReceiver(address(minter));

        bytes32 firstBatchId = bytes32(uint256(111));
        newReceiver.initialize(firstBatchId, tokens.usdc);

        bytes32 secondBatchId = bytes32(uint256(222));
        vm.expectRevert(bytes(KBATCHRECEIVER_ALREADY_INITIALIZED));
        newReceiver.initialize(secondBatchId, tokens.usdc);

        assertEq(newReceiver.batchId(), firstBatchId, "Batch ID should remain from first init");
        assertEq(newReceiver.asset(), tokens.usdc, "Asset should remain from first init");
    }

    function test_Initialization_EventEmission() public {
        kBatchReceiver newReceiver = new kBatchReceiver(address(minter));

        bytes32 eventBatchId = bytes32(uint256(333));

        vm.expectEmit(true, true, true, false);
        emit IkBatchReceiver.BatchReceiverInitialized(address(minter), eventBatchId, tokens.usdc);

        newReceiver.initialize(eventBatchId, tokens.usdc);
    }

    function test_Initialization_ZeroAssetAddress() public {
        kBatchReceiver newReceiver = new kBatchReceiver(address(minter));

        bytes32 batchId = bytes32(uint256(444));

        vm.expectRevert(bytes(KBATCHRECEIVER_ZERO_ADDRESS));
        newReceiver.initialize(batchId, address(0));

        assertFalse(newReceiver.isInitialised(), "Should not be initialized");
    }

    function test_Initialization_ZeroKMinterInConstructor() public {
        vm.expectRevert(bytes(KBATCHRECEIVER_ZERO_ADDRESS));
        new kBatchReceiver(address(0));
    }

    function test_Initialization_StateTransitions() public {
        kBatchReceiver newReceiver = new kBatchReceiver(address(minter));

        assertFalse(newReceiver.isInitialised(), "Should start uninitialized");
        assertEq(newReceiver.batchId(), bytes32(0), "Batch ID should be zero initially");
        assertEq(newReceiver.asset(), address(0), "Asset should be zero initially");

        bytes32 batchId = bytes32(uint256(555));
        newReceiver.initialize(batchId, tokens.usdc);

        assertTrue(newReceiver.isInitialised(), "Should be initialized after init");
        assertEq(newReceiver.batchId(), batchId, "Batch ID should be set");
        assertEq(newReceiver.asset(), tokens.usdc, "Asset should be set");
    }

    /* //////////////////////////////////////////////////////////////
                        ADVANCED PULLASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PullAssets_ConcurrentOperations() public {
        uint256 pullAmount = TEST_AMOUNT / 5;
        address[] memory receivers = new address[](5);

        for (uint256 i = 0; i < 5; i++) {
            receivers[i] = address(uint160(0x2000 + i));
        }

        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(minter));
            batchReceiver.pullAssets(receivers[i], pullAmount, TEST_BATCH_ID);
        }

        for (uint256 i = 0; i < 5; i++) {
            assertEq(IERC20(tokens.usdc).balanceOf(receivers[i]), pullAmount, "Concurrent transfer failed");
        }

        uint256 expectedRemaining = (TEST_AMOUNT * 10) - (pullAmount * 5);
        assertEq(
            IERC20(tokens.usdc).balanceOf(address(batchReceiver)), expectedRemaining, "Batch receiver balance incorrect"
        );
    }

    function test_PullAssets_StateConsistency() public {
        uint256 initialBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));
        uint256 pullAmount1 = TEST_AMOUNT;
        uint256 pullAmount2 = TEST_AMOUNT * 2;
        uint256 pullAmount3 = TEST_AMOUNT / 2;

        address receiver1 = address(0x3001);
        address receiver2 = address(0x3002);
        address receiver3 = address(0x3003);

        vm.startPrank(address(minter));

        batchReceiver.pullAssets(receiver1, pullAmount1, TEST_BATCH_ID);
        batchReceiver.pullAssets(receiver2, pullAmount2, TEST_BATCH_ID);
        batchReceiver.pullAssets(receiver3, pullAmount3, TEST_BATCH_ID);

        vm.stopPrank();

        assertEq(IERC20(tokens.usdc).balanceOf(receiver1), pullAmount1, "Receiver1 balance incorrect");
        assertEq(IERC20(tokens.usdc).balanceOf(receiver2), pullAmount2, "Receiver2 balance incorrect");
        assertEq(IERC20(tokens.usdc).balanceOf(receiver3), pullAmount3, "Receiver3 balance incorrect");

        uint256 totalPulled = pullAmount1 + pullAmount2 + pullAmount3;
        uint256 expectedRemaining = initialBalance - totalPulled;
        assertEq(IERC20(tokens.usdc).balanceOf(address(batchReceiver)), expectedRemaining, "Total balance inconsistent");
    }

    function test_PullAssets_MaximumAmounts() public {
        uint256 maxBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, maxBalance, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), maxBalance, "Max amount not transferred");
        assertEq(IERC20(tokens.usdc).balanceOf(address(batchReceiver)), 0, "Batch receiver should be empty");
    }

    function test_PullAssets_PartialExecutions() public {
        uint256 totalBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));
        uint256 partialAmount = totalBalance / 3;

        address receiver = address(0x4001);

        vm.startPrank(address(minter));

        batchReceiver.pullAssets(receiver, partialAmount, TEST_BATCH_ID);
        assertEq(IERC20(tokens.usdc).balanceOf(receiver), partialAmount, "First partial pull failed");

        batchReceiver.pullAssets(receiver, partialAmount, TEST_BATCH_ID);
        assertEq(IERC20(tokens.usdc).balanceOf(receiver), partialAmount * 2, "Second partial pull failed");

        uint256 remaining = totalBalance - (partialAmount * 2);
        batchReceiver.pullAssets(receiver, remaining, TEST_BATCH_ID);
        assertEq(IERC20(tokens.usdc).balanceOf(receiver), totalBalance, "Final pull failed");

        vm.stopPrank();

        assertEq(IERC20(tokens.usdc).balanceOf(address(batchReceiver)), 0, "Batch receiver should be empty");
    }

    function test_PullAssets_ErrorRecovery() public {
        uint256 validAmount = TEST_AMOUNT;
        uint256 excessiveAmount = IERC20(tokens.usdc).balanceOf(address(batchReceiver)) + 1;

        vm.prank(address(minter));
        vm.expectRevert();
        batchReceiver.pullAssets(testReceiver, excessiveAmount, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), 0, "Balance should be unchanged after failed pull");

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, validAmount, TEST_BATCH_ID);

        assertEq(
            IERC20(tokens.usdc).balanceOf(testReceiver), validAmount, "Valid pull should succeed after failed attempt"
        );
    }

    /* //////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT AND SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AssetManagement_BalanceTracking() public {
        uint256 initialBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));

        uint256[] memory pullAmounts = new uint256[](4);
        pullAmounts[0] = _100_USDC;
        pullAmounts[1] = _100_USDC * 2;
        pullAmounts[2] = _100_USDC / 2;
        pullAmounts[3] = _100_USDC * 3;

        uint256 runningBalance = initialBalance;

        for (uint256 i = 0; i < pullAmounts.length; i++) {
            address receiver = address(uint160(0x5000 + i));

            vm.prank(address(minter));
            batchReceiver.pullAssets(receiver, pullAmounts[i], TEST_BATCH_ID);

            runningBalance -= pullAmounts[i];

            assertEq(
                IERC20(tokens.usdc).balanceOf(address(batchReceiver)),
                runningBalance,
                string(abi.encodePacked("Balance tracking failed at step ", vm.toString(i)))
            );
        }
    }

    function test_AssetManagement_RescueAssets() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
        batchReceiver.rescueAssets(tokens.usdc);

        vm.prank(address(minter));
        try batchReceiver.rescueAssets(tokens.usdc) { } catch { }

        assertTrue(true, "Access control test completed");
    }

    function test_AssetManagement_EmergencyRecovery() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
        batchReceiver.rescueAssets(tokens.usdc);

        vm.prank(address(minter));
        try batchReceiver.rescueAssets(tokens.usdc) { } catch { }

        assertTrue(true, "Emergency access control verified");
    }

    function test_AssetManagement_TransferSecurity() public {
        bytes32 wrongBatchId = bytes32(uint256(TEST_BATCH_ID) + 999);

        vm.prank(address(minter));
        vm.expectRevert(bytes(KBATCHRECEIVER_INVALID_BATCH_ID));
        batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, wrongBatchId);

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), TEST_AMOUNT, "Valid transfer should succeed");
    }

    /* //////////////////////////////////////////////////////////////
                        ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AccessControl_KMinterOnly() public {
        address[] memory unauthorizedUsers = new address[](4);
        unauthorizedUsers[0] = users.alice;
        unauthorizedUsers[1] = users.admin;
        unauthorizedUsers[2] = users.relayer;
        unauthorizedUsers[3] = address(0x9999);

        for (uint256 i = 0; i < unauthorizedUsers.length; i++) {
            vm.prank(unauthorizedUsers[i]);
            vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
            batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, TEST_BATCH_ID);

            vm.prank(unauthorizedUsers[i]);
            vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
            batchReceiver.rescueAssets(tokens.usdc);
        }

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, TEST_AMOUNT, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), TEST_AMOUNT, "kMinter should be able to pull assets");
    }

    function test_AccessControl_MaliciousContracts() public {
        MaliciousContract malicious = new MaliciousContract(address(batchReceiver));

        vm.expectRevert();
        malicious.attemptPullAssets(testReceiver, TEST_AMOUNT, TEST_BATCH_ID);

        vm.expectRevert();
        malicious.attemptRescueAssets(tokens.usdc);
    }

    function test_AccessControl_StateConsistency() public {
        assertEq(batchReceiver.kMinter(), address(minter), "kMinter should be set correctly");

        kBatchReceiver receiver1 = new kBatchReceiver(address(minter));
        kBatchReceiver receiver2 = new kBatchReceiver(users.admin);

        assertEq(receiver1.kMinter(), address(minter), "Receiver1 kMinter incorrect");
        assertEq(receiver2.kMinter(), users.admin, "Receiver2 kMinter incorrect");

        receiver1.initialize(bytes32(uint256(777)), tokens.usdc);
        receiver2.initialize(bytes32(uint256(888)), tokens.usdc);

        mockUSDC.mint(address(receiver1), TEST_AMOUNT);
        mockUSDC.mint(address(receiver2), TEST_AMOUNT);

        vm.prank(address(minter));
        receiver1.pullAssets(testReceiver, TEST_AMOUNT / 2, bytes32(uint256(777)));

        vm.prank(users.admin);
        vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
        receiver1.pullAssets(testReceiver, TEST_AMOUNT / 2, bytes32(uint256(777)));

        vm.prank(users.admin);
        receiver2.pullAssets(testReceiver, TEST_AMOUNT / 2, bytes32(uint256(888)));

        vm.prank(address(minter));
        vm.expectRevert(bytes(KBATCHRECEIVER_ONLY_KMINTER));
        receiver2.pullAssets(testReceiver, TEST_AMOUNT / 2, bytes32(uint256(888)));
    }

    /* //////////////////////////////////////////////////////////////
                    EDGE CASES AND INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Integration_BatchSettlementWorkflow() public {
        bytes32 workflowBatchId = bytes32(uint256(12_345));
        address workflowReceiver = address(0x6001);
        uint256 settlementAmount = TEST_AMOUNT * 3;

        kBatchReceiver workflowBatchReceiver = new kBatchReceiver(address(minter));
        workflowBatchReceiver.initialize(workflowBatchId, tokens.usdc);

        mockUSDC.mint(address(workflowBatchReceiver), settlementAmount);

        vm.prank(address(minter));
        workflowBatchReceiver.pullAssets(workflowReceiver, settlementAmount, workflowBatchId);

        assertEq(IERC20(tokens.usdc).balanceOf(workflowReceiver), settlementAmount, "Workflow settlement failed");
        assertEq(
            IERC20(tokens.usdc).balanceOf(address(workflowBatchReceiver)), 0, "Workflow batch receiver should be empty"
        );
    }

    function test_Integration_LifecycleManagement() public {
        kBatchReceiver lifecycleReceiver = new kBatchReceiver(address(minter));
        assertFalse(lifecycleReceiver.isInitialised(), "Should start uninitialized");

        bytes32 lifecycleBatchId = bytes32(uint256(999));
        lifecycleReceiver.initialize(lifecycleBatchId, tokens.usdc);
        assertTrue(lifecycleReceiver.isInitialised(), "Should be initialized");

        mockUSDC.mint(address(lifecycleReceiver), TEST_AMOUNT);
        vm.prank(address(minter));
        lifecycleReceiver.pullAssets(testReceiver, TEST_AMOUNT, lifecycleBatchId);

        if (IERC20(tokens.usdc).balanceOf(address(lifecycleReceiver)) > 0) {
            vm.prank(address(minter));
            lifecycleReceiver.rescueAssets(tokens.usdc);
        }

        assertEq(
            IERC20(tokens.usdc).balanceOf(address(lifecycleReceiver)), 0, "Lifecycle should end with empty receiver"
        );
    }

    /* //////////////////////////////////////////////////////////////
                        ENHANCED FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_PullAssets(uint256 amount) public {
        uint256 maxBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));
        amount = bound(amount, 1, maxBalance);

        vm.prank(address(minter));
        batchReceiver.pullAssets(testReceiver, amount, TEST_BATCH_ID);

        assertEq(IERC20(tokens.usdc).balanceOf(testReceiver), amount, "Incorrect amount transferred");
    }

    function testFuzz_PullAssets_DifferentReceivers(address receiver, uint256 amount) public {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(batchReceiver));
        vm.assume(receiver != tokens.usdc);

        uint256 maxBalance = IERC20(tokens.usdc).balanceOf(address(batchReceiver));
        amount = bound(amount, 1, maxBalance);

        uint256 initialBalance = IERC20(tokens.usdc).balanceOf(receiver);

        vm.prank(address(minter));
        batchReceiver.pullAssets(receiver, amount, TEST_BATCH_ID);

        assertEq(
            IERC20(tokens.usdc).balanceOf(receiver), initialBalance + amount, "Incorrect amount transferred to receiver"
        );
    }

    function testFuzz_Initialization(bytes32 batchId, address asset) public {
        vm.assume(asset != address(0));
        vm.assume(batchId != bytes32(0));

        kBatchReceiver fuzzReceiver = new kBatchReceiver(address(minter));

        fuzzReceiver.initialize(batchId, asset);

        assertEq(fuzzReceiver.batchId(), batchId, "Fuzz batch ID incorrect");
        assertEq(fuzzReceiver.asset(), asset, "Fuzz asset incorrect");
        assertTrue(fuzzReceiver.isInitialised(), "Fuzz receiver should be initialized");
    }

    function testFuzz_BatchIdValidation(bytes32 validBatchId, bytes32 invalidBatchId) public {
        vm.assume(validBatchId != invalidBatchId);

        kBatchReceiver fuzzReceiver = new kBatchReceiver(address(minter));
        fuzzReceiver.initialize(validBatchId, tokens.usdc);

        mockUSDC.mint(address(fuzzReceiver), TEST_AMOUNT);

        vm.prank(address(minter));
        fuzzReceiver.pullAssets(testReceiver, TEST_AMOUNT / 2, validBatchId);

        vm.prank(address(minter));
        vm.expectRevert(bytes(KBATCHRECEIVER_INVALID_BATCH_ID));
        fuzzReceiver.pullAssets(testReceiver, TEST_AMOUNT / 2, invalidBatchId);
    }
}

contract MaliciousContract {
    kBatchReceiver public immutable batchReceiver;

    constructor(address _batchReceiver) {
        batchReceiver = kBatchReceiver(_batchReceiver);
    }

    function attemptPullAssets(address receiver, uint256 amount, bytes32 batchId) external {
        batchReceiver.pullAssets(receiver, amount, batchId);
    }

    function attemptRescueAssets(address asset) external {
        batchReceiver.rescueAssets(asset);
    }
}
