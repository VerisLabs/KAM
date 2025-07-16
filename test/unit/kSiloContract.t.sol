// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kSiloContract } from "../../src/kSiloContract.sol";
import { MockToken } from "../helpers/MockToken.sol";

import { kDNStakingVaultProxy } from "../helpers/kDNStakingVaultProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";
import { _100_USDC, _200_USDC, _50_USDC } from "../utils/Constants.sol";

/// @title kSiloContract Unit Tests
/// @notice Tests secure custodial asset management and distribution
contract kSiloContractTest is BaseTest {
    kSiloContract internal silo;
    kSiloContract internal siloImpl;
    kDNStakingVaultProxy internal proxyDeployer;

    // Test constants
    address internal strategyManager = makeAddr("strategyManager");
    address internal custodialWallet = makeAddr("custodialWallet");
    address internal batchReceiver1 = makeAddr("batchReceiver1");
    address internal batchReceiver2 = makeAddr("batchReceiver2");
    address internal sourceStrategy = makeAddr("sourceStrategy");

    function setUp() public override {
        super.setUp();

        // Deploy proxy deployer
        proxyDeployer = new kDNStakingVaultProxy();

        // Deploy kSiloContract implementation
        siloImpl = new kSiloContract();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            kSiloContract.initialize.selector, asset, strategyManager, users.owner, users.admin, users.emergencyAdmin
        );

        // Deploy and initialize proxy
        address proxyAddress = proxyDeployer.deployAndInitialize(address(siloImpl), initData);
        silo = kSiloContract(payable(proxyAddress));

        // Setup labels
        vm.label(address(silo), "kSiloContract_Proxy");
        vm.label(address(siloImpl), "kSiloContract_Implementation");
        vm.label(strategyManager, "MockStrategyManager");
        vm.label(custodialWallet, "MockCustodialWallet");
        vm.label(sourceStrategy, "MockSourceStrategy");
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_success() public {
        assertEq(silo.asset(), asset);
        (uint256 totalReceived, uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalReceived, 0);
        assertEq(totalDistributed, 0);
        assertEq(currentBalance, 0);
    }

    function test_initialize_revertsZeroAddresses() public {
        // Deploy new implementation
        kSiloContract newSiloImpl = new kSiloContract();

        // Test zero asset
        bytes memory initData1 = abi.encodeWithSelector(
            kSiloContract.initialize.selector,
            address(0), // zero asset
            strategyManager,
            users.owner,
            users.admin,
            users.emergencyAdmin
        );

        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        proxyDeployer.deployAndInitialize(address(newSiloImpl), initData1);

        // Test zero strategy manager
        bytes memory initData2 = abi.encodeWithSelector(
            kSiloContract.initialize.selector,
            asset,
            address(0), // zero strategy manager
            users.owner,
            users.admin,
            users.emergencyAdmin
        );

        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        proxyDeployer.deployAndInitialize(address(newSiloImpl), initData2);
    }

    /*//////////////////////////////////////////////////////////////
                    CUSTODIAL OPERATIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_receiveFromCustodial_success() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give custodial wallet tokens and approve
        mintTokens(asset, custodialWallet, amount);
        vm.prank(custodialWallet);
        MockToken(asset).approve(address(silo), amount);

        vm.expectEmit(true, true, true, true);
        emit kSiloContract.CustodialDeposit(operationId, custodialWallet, sourceStrategy, amount, "funding");

        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId, sourceStrategy, amount, "funding");

        // Verify state
        (uint256 totalReceived, uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalReceived, amount);
        assertEq(totalDistributed, 0);
        assertEq(currentBalance, amount);
        assertEq(silo.getCustodialBalance(custodialWallet), amount);

        // Verify operation was recorded
        kSiloContract.CustodialOperation memory operation = silo.getOperation(operationId);
        assertEq(operation.operationId, operationId);
        assertEq(operation.sourceStrategy, sourceStrategy);
        assertEq(operation.custodialAddress, custodialWallet);
        assertEq(operation.amount, amount);
        assertTrue(operation.status == kSiloContract.OperationStatus.RECEIVED);
    }

    function test_receiveFromCustodial_revertsZeroOperationId() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(kSiloContract.InvalidOperation.selector);
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(bytes32(0), sourceStrategy, amount, "funding");
    }

    function test_receiveFromCustodial_revertsZeroAmount() public {
        bytes32 operationId = keccak256("test_operation");

        vm.expectRevert(kSiloContract.ZeroAmount.selector);
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId, sourceStrategy, 0, "funding");
    }

    function test_receiveFromCustodial_revertsOperationAlreadyProcessed() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give custodial wallet tokens and approve
        mintTokens(asset, custodialWallet, amount * 2);
        vm.prank(custodialWallet);
        MockToken(asset).approve(address(silo), amount * 2);

        // First call - should succeed
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId, sourceStrategy, amount, "funding");

        // Second call with same operationId - should revert
        vm.expectRevert(kSiloContract.OperationAlreadyProcessed.selector);
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId, sourceStrategy, amount, "funding");
    }

    function test_receiveFromCustodial_multipleOperations() public {
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _50_USDC;
        bytes32 operationId1 = keccak256("operation_1");
        bytes32 operationId2 = keccak256("operation_2");

        // Setup: Give custodial wallet tokens and approve
        mintTokens(asset, custodialWallet, amount1 + amount2);
        vm.prank(custodialWallet);
        MockToken(asset).approve(address(silo), amount1 + amount2);

        // First operation
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId1, sourceStrategy, amount1, "funding");

        // Second operation
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId2, sourceStrategy, amount2, "shorts");

        // Verify total state
        (uint256 totalReceived,, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalReceived, amount1 + amount2);
        assertEq(currentBalance, amount1 + amount2);
        assertEq(silo.getCustodialBalance(custodialWallet), amount1 + amount2);

        // Verify individual operations
        kSiloContract.CustodialOperation memory op1 = silo.getOperation(operationId1);
        kSiloContract.CustodialOperation memory op2 = silo.getOperation(operationId2);
        assertEq(op1.amount, amount1);
        assertEq(op2.amount, amount2);
    }

    /*//////////////////////////////////////////////////////////////
                      DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transferToDestination_success() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Silo has assets
        _setupSiloWithAssets(amount);

        vm.expectEmit(true, true, false, true);
        emit kSiloContract.AssetDistribution(operationId, batchReceiver1, amount, "redemption");

        vm.prank(strategyManager);
        silo.transferToDestination(batchReceiver1, amount, operationId, "redemption");

        // Verify transfer
        assertEq(MockToken(asset).balanceOf(batchReceiver1), amount);
        (uint256 totalReceived, uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, amount);
        assertEq(currentBalance, 0);
    }

    function test_transferToDestination_revertsIfNotStrategyManager() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        _setupSiloWithAssets(amount);

        vm.expectRevert(); // Should revert with role check
        vm.prank(users.alice);
        silo.transferToDestination(batchReceiver1, amount, operationId, "redemption");
    }

    function test_transferToDestination_revertsInsufficientBalance() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Silo has no assets
        vm.expectRevert(kSiloContract.InsufficientBalance.selector);
        vm.prank(strategyManager);
        silo.transferToDestination(batchReceiver1, amount, operationId, "redemption");
    }

    function test_batchTransferToDestinations_success() public {
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _50_USDC;
        uint256 totalAmount = amount1 + amount2;

        // Setup: Silo has assets
        _setupSiloWithAssets(totalAmount);

        address[] memory destinations = new address[](2);
        destinations[0] = batchReceiver1;
        destinations[1] = batchReceiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes32[] memory operationIds = new bytes32[](2);
        operationIds[0] = keccak256("operation_1");
        operationIds[1] = keccak256("operation_2");

        vm.expectEmit(true, true, false, true);
        emit kSiloContract.AssetDistribution(operationIds[0], destinations[0], amounts[0], "batch_redemption");
        vm.expectEmit(true, true, false, true);
        emit kSiloContract.AssetDistribution(operationIds[1], destinations[1], amounts[1], "batch_redemption");

        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "batch_redemption");

        // Verify transfers
        assertEq(MockToken(asset).balanceOf(batchReceiver1), amount1);
        assertEq(MockToken(asset).balanceOf(batchReceiver2), amount2);

        (uint256 totalReceived, uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, totalAmount);
        assertEq(currentBalance, 0);
    }

    function test_batchTransferToDestinations_revertsArrayLengthMismatch() public {
        address[] memory destinations = new address[](2);
        destinations[0] = batchReceiver1;
        destinations[1] = batchReceiver2;

        uint256[] memory amounts = new uint256[](1); // Wrong length
        amounts[0] = _100_USDC;

        bytes32[] memory operationIds = new bytes32[](2);
        operationIds[0] = keccak256("operation_1");
        operationIds[1] = keccak256("operation_2");

        vm.expectRevert(kSiloContract.InvalidOperation.selector);
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "batch_redemption");
    }

    function test_batchTransferToDestinations_skipsZeroAmounts() public {
        uint256 amount = _100_USDC;

        // Setup: Silo has assets
        _setupSiloWithAssets(amount);

        address[] memory destinations = new address[](2);
        destinations[0] = batchReceiver1;
        destinations[1] = batchReceiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = 0; // Zero amount - should be skipped

        bytes32[] memory operationIds = new bytes32[](2);
        operationIds[0] = keccak256("operation_1");
        operationIds[1] = keccak256("operation_2");

        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "batch_redemption");

        // Verify only first transfer happened
        assertEq(MockToken(asset).balanceOf(batchReceiver1), amount);
        assertEq(MockToken(asset).balanceOf(batchReceiver2), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setStrategyManager_success() public {
        address newManager = makeAddr("newManager");

        vm.expectEmit(true, true, false, false);
        emit kSiloContract.StrategyManagerUpdated(strategyManager, newManager);

        vm.prank(users.admin);
        silo.setStrategyManager(newManager);

        // Verify new manager has role and old manager doesn't
        assertTrue(silo.hasAnyRole(newManager, silo.STRATEGY_MANAGER_ROLE()));
        assertFalse(silo.hasAnyRole(strategyManager, silo.STRATEGY_MANAGER_ROLE()));
    }

    function test_setStrategyManager_revertsZeroAddress() public {
        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        vm.prank(users.admin);
        silo.setStrategyManager(address(0));
    }

    function test_setPaused_success() public {
        vm.prank(users.emergencyAdmin);
        silo.setPaused(true);

        // Verify operations are paused
        vm.expectRevert(kSiloContract.Paused.selector);
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(bytes32(uint256(1)), sourceStrategy, _100_USDC, "funding");
    }

    /*//////////////////////////////////////////////////////////////
                      EMERGENCY FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_emergencyWithdraw_success() public {
        uint256 amount = _100_USDC;

        // Setup: Silo has assets and is paused
        _setupSiloWithAssets(amount);
        vm.prank(users.emergencyAdmin);
        silo.setPaused(true);

        vm.expectEmit(true, true, false, true);
        emit kSiloContract.EmergencyWithdrawal(asset, users.treasury, amount, users.emergencyAdmin);

        vm.prank(users.emergencyAdmin);
        silo.emergencyWithdraw(asset, users.treasury, amount);

        // Verify withdrawal
        assertEq(MockToken(asset).balanceOf(users.treasury), amount);
        assertEq(MockToken(asset).balanceOf(address(silo)), 0);
    }

    function test_emergencyWithdraw_revertsIfNotPaused() public {
        uint256 amount = _100_USDC;

        _setupSiloWithAssets(amount);

        vm.expectRevert(kSiloContract.ContractNotPaused.selector);
        vm.prank(users.emergencyAdmin);
        silo.emergencyWithdraw(asset, users.treasury, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getAllOperationIds_success() public {
        bytes32 operationId1 = keccak256("operation_1");
        bytes32 operationId2 = keccak256("operation_2");

        // Setup: Create operations
        mintTokens(asset, custodialWallet, _200_USDC);
        vm.prank(custodialWallet);
        MockToken(asset).approve(address(silo), _200_USDC);

        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId1, sourceStrategy, _100_USDC, "funding");

        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId2, sourceStrategy, _100_USDC, "shorts");

        // Test view function
        bytes32[] memory operationIds = silo.getAllOperationIds();
        assertEq(operationIds.length, 2);
        assertEq(operationIds[0], operationId1);
        assertEq(operationIds[1], operationId2);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _setupSiloWithAssets(uint256 amount) internal {
        bytes32 operationId = keccak256("setup_operation");

        // Setup: Give custodial wallet tokens and approve
        mintTokens(asset, custodialWallet, amount);
        vm.prank(custodialWallet);
        MockToken(asset).approve(address(silo), amount);

        // Deposit to silo
        vm.prank(custodialWallet);
        silo.receiveFromCustodial(operationId, sourceStrategy, amount, "setup");
    }
}
