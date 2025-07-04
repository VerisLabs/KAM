// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {BaseTest} from "../utils/BaseTest.sol";
import {kBatchReceiver} from "../../src/kBatchReceiver.sol";
import {MockToken} from "../helpers/MockToken.sol";
import {_100_USDC, _50_USDC, _60_USDC, _40_USDC} from "../utils/Constants.sol";

/// @title kBatchReceiver Unit Tests
/// @notice Tests individual functions of kBatchReceiver without external integrations
contract kBatchReceiverTest is BaseTest {
    kBatchReceiver internal receiver;
    kBatchReceiver internal receiverProxy;

    // Test constants
    address internal kMinter = makeAddr("kMinter");
    uint256 internal constant BATCH_ID = 1;

    function setUp() public override {
        super.setUp();

        // Deploy implementation
        receiver = new kBatchReceiver();

        // Deploy proxy for testing
        receiverProxy = new kBatchReceiver();

        vm.label(address(receiver), "kBatchReceiver_Implementation");
        vm.label(address(receiverProxy), "kBatchReceiver_Proxy");
        vm.label(kMinter, "MockkMinter");
    }

    /*//////////////////////////////////////////////////////////////
                           INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Implementation should not be initializable
        assertTrue(address(receiver) != address(0));
    }

    function test_initialize_success() public {
        vm.expectEmit(true, true, true, true);
        emit kBatchReceiver.Initialized(kMinter, asset, BATCH_ID);

        receiverProxy.initialize(kMinter, asset, BATCH_ID);

        // Verify state
        assertEq(receiverProxy.kMinter(), kMinter);
        assertEq(receiverProxy.asset(), asset);
        assertEq(receiverProxy.batchId(), BATCH_ID);
        assertTrue(receiverProxy.initialized());
        assertEq(receiverProxy.totalReceived(), 0);
    }

    function test_initialize_revertsIfAlreadyInitialized() public {
        receiverProxy.initialize(kMinter, asset, BATCH_ID);

        vm.expectRevert(kBatchReceiver.AlreadyInitialized.selector);
        receiverProxy.initialize(kMinter, asset, BATCH_ID);
    }

    function test_initialize_revertsIfZeroMinter() public {
        vm.expectRevert(kBatchReceiver.InvalidAddress.selector);
        receiverProxy.initialize(address(0), asset, BATCH_ID);
    }

    function test_initialize_revertsIfZeroAsset() public {
        vm.expectRevert(kBatchReceiver.InvalidAddress.selector);
        receiverProxy.initialize(kMinter, address(0), BATCH_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_receiveAssets_successFromkMinter() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        // Setup: Give kMinter tokens and approve
        mintTokens(asset, kMinter, amount);
        vm.prank(kMinter);
        MockToken(asset).approve(address(receiverProxy), amount);

        vm.expectEmit(true, false, false, true);
        emit kBatchReceiver.AssetsReceived(amount);

        vm.prank(kMinter);
        receiverProxy.receiveAssets(amount);

        // Verify state
        assertEq(receiverProxy.totalReceived(), amount);
        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), amount);
    }

    function test_receiveAssets_successWithDirectTransfer() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        // Setup: kMinter has tokens
        mintTokens(asset, kMinter, amount);
        vm.prank(kMinter);
        MockToken(asset).approve(address(receiverProxy), amount);

        // kMinter calls receiveAssets, transferring from itself
        vm.expectEmit(true, false, false, true);
        emit kBatchReceiver.AssetsReceived(amount);

        vm.prank(kMinter);
        receiverProxy.receiveAssets(amount);

        // Verify state
        assertEq(receiverProxy.totalReceived(), amount);
        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), amount);
        assertEq(MockToken(asset).balanceOf(kMinter), 0);
    }

    function test_receiveAssets_revertsIfNotInitialized() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.NotInitialized.selector);
        vm.prank(kMinter);
        receiverProxy.receiveAssets(amount);
    }

    function test_receiveAssets_revertsIfUnauthorized() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.OnlyAuthorized.selector);
        vm.prank(users.alice);
        receiverProxy.receiveAssets(amount);
    }

    function test_receiveAssets_multipleDeposits() public {
        _initializeProxy();
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _50_USDC;
        uint256 totalAmount = amount1 + amount2;

        // Setup tokens
        mintTokens(asset, kMinter, totalAmount);
        vm.startPrank(kMinter);
        MockToken(asset).approve(address(receiverProxy), totalAmount);

        // First deposit
        receiverProxy.receiveAssets(amount1);
        assertEq(receiverProxy.totalReceived(), amount1);

        // Second deposit
        receiverProxy.receiveAssets(amount2);
        assertEq(receiverProxy.totalReceived(), totalAmount);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW FOR REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_withdrawForRedemption_success() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        // Setup: Receiver has tokens
        uint256 aliceInitialBalance = getBalance(asset, users.alice);
        mintTokens(asset, address(receiverProxy), amount);

        vm.expectEmit(true, true, false, true);
        emit kBatchReceiver.WithdrawnForRedemption(users.alice, amount);

        vm.prank(kMinter);
        receiverProxy.withdrawForRedemption(users.alice, amount);

        // Verify transfer
        assertEq(MockToken(asset).balanceOf(users.alice), aliceInitialBalance + amount);
        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), 0);
    }

    function test_withdrawForRedemption_revertsIfNotInitialized() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.NotInitialized.selector);
        vm.prank(kMinter);
        receiverProxy.withdrawForRedemption(users.alice, amount);
    }

    function test_withdrawForRedemption_revertsIfNotFromkMinter() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.OnlyKMinter.selector);
        vm.prank(users.alice);
        receiverProxy.withdrawForRedemption(users.alice, amount);
    }

    function test_withdrawForRedemption_multipleWithdrawals() public {
        _initializeProxy();
        uint256 totalAmount = _100_USDC;
        uint256 amount1 = _60_USDC;
        uint256 amount2 = _40_USDC;

        // Setup: Receiver has tokens
        mintTokens(asset, address(receiverProxy), totalAmount);

        vm.startPrank(kMinter);

        // First withdrawal
        receiverProxy.withdrawForRedemption(users.alice, amount1);
        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), amount2);

        // Second withdrawal
        receiverProxy.withdrawForRedemption(users.bob, amount2);
        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), 0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                      EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_emergencyWithdraw_ERC20_success() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        // Setup: Receiver has tokens
        mintTokens(asset, address(receiverProxy), amount);

        vm.expectEmit(true, true, false, true);
        emit kBatchReceiver.EmergencyWithdrawal(asset, users.treasury, amount, kMinter);

        vm.prank(kMinter);
        receiverProxy.emergencyWithdraw(asset, users.treasury, amount);

        // Verify transfer
        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), 0);
    }

    function test_emergencyWithdraw_ETH_success() public {
        _initializeProxy();
        uint256 amount = 1 ether;

        // Setup: Give receiver ETH
        vm.deal(address(receiverProxy), amount);

        uint256 treasuryBalanceBefore = users.treasury.balance;

        vm.expectEmit(true, true, false, true);
        emit kBatchReceiver.EmergencyWithdrawal(address(0), users.treasury, amount, kMinter);

        vm.prank(kMinter);
        receiverProxy.emergencyWithdraw(address(0), users.treasury, amount);

        // Verify ETH transfer
        assertEq(address(receiverProxy).balance, 0);
        assertEq(users.treasury.balance, treasuryBalanceBefore + amount);
    }

    function test_emergencyWithdraw_revertsIfNotInitialized() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.NotInitialized.selector);
        vm.prank(kMinter);
        receiverProxy.emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfNotFromkMinter() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.OnlyKMinter.selector);
        vm.prank(users.alice);
        receiverProxy.emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfZeroRecipient() public {
        _initializeProxy();
        uint256 amount = _100_USDC;

        vm.expectRevert(kBatchReceiver.InvalidAddress.selector);
        vm.prank(kMinter);
        receiverProxy.emergencyWithdraw(asset, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_contractName() public {
        assertEq(receiver.contractName(), "kBatchReceiver");
    }

    function test_contractVersion() public {
        assertEq(receiver.contractVersion(), "1.0.0");
    }

    function test_getStorageAfterInitialization() public {
        _initializeProxy();

        assertEq(receiverProxy.kMinter(), kMinter);
        assertEq(receiverProxy.asset(), asset);
        assertEq(receiverProxy.batchId(), BATCH_ID);
        assertTrue(receiverProxy.initialized());
        assertEq(receiverProxy.totalReceived(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_receiveAssets(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint96).max);

        _initializeProxy();

        // Setup tokens
        mintTokens(asset, kMinter, amount);
        vm.prank(kMinter);
        MockToken(asset).approve(address(receiverProxy), amount);

        vm.prank(kMinter);
        receiverProxy.receiveAssets(amount);

        assertEq(receiverProxy.totalReceived(), amount);
    }

    function testFuzz_withdrawForRedemption(uint256 amount, address recipient) public {
        vm.assume(amount > 0 && amount <= type(uint96).max);
        vm.assume(recipient != address(0) && recipient.code.length == 0);

        _initializeProxy();

        // Setup tokens
        mintTokens(asset, address(receiverProxy), amount);

        vm.prank(kMinter);
        receiverProxy.withdrawForRedemption(recipient, amount);

        assertEq(MockToken(asset).balanceOf(address(receiverProxy)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initializeProxy() internal {
        receiverProxy.initialize(kMinter, asset, BATCH_ID);
    }
}
