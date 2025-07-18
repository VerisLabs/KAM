// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kSiloContract } from "../../src/kSiloContract.sol";
import { MockToken } from "../helpers/MockToken.sol";

import { kDNStakingVaultProxy } from "../helpers/kDNStakingVaultProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";
import { _100_USDC, _200_USDC, _50_USDC } from "../utils/Constants.sol";

/// @title kSiloContract Unit Tests
/// @notice Tests simplified custodial asset management and distribution
contract kSiloContractTest is BaseTest {
    kSiloContract internal silo;
    kSiloContract internal siloImpl;
    kDNStakingVaultProxy internal proxyDeployer;

    // Test constants
    address internal strategyManager = makeAddr("strategyManager");
    address internal batchReceiver1 = makeAddr("batchReceiver1");
    address internal batchReceiver2 = makeAddr("batchReceiver2");

    function setUp() public override {
        super.setUp();

        // Deploy proxy deployer
        proxyDeployer = new kDNStakingVaultProxy();

        // Deploy silo implementation
        siloImpl = new kSiloContract();

        // Deploy silo proxy
        bytes memory initData = abi.encodeWithSelector(
            kSiloContract.initialize.selector, asset, strategyManager, users.admin, users.admin, users.emergencyAdmin
        );

        address siloProxy = proxyDeployer.deployAndInitialize(address(siloImpl), initData);
        silo = kSiloContract(payable(siloProxy));
    }

    function test_transferToDestination_success() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give silo tokens directly (simulate custodial transfer)
        mintTokens(asset, address(silo), amount);

        // Execute transfer
        vm.prank(strategyManager);
        silo.transferToDestination(batchReceiver1, amount, operationId, "redemption");

        // Verify state
        (uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, amount);
        assertEq(currentBalance, 0);
        assertEq(MockToken(asset).balanceOf(batchReceiver1), amount);
    }

    function test_transferToDestination_revertsInsufficientBalance() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // No tokens in silo
        vm.expectRevert(kSiloContract.InsufficientBalance.selector);
        vm.prank(strategyManager);
        silo.transferToDestination(batchReceiver1, amount, operationId, "redemption");
    }

    function test_transferToDestination_revertsZeroAddress() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        vm.prank(strategyManager);
        silo.transferToDestination(address(0), amount, operationId, "redemption");
    }

    function test_transferToDestination_revertsZeroAmount() public {
        bytes32 operationId = keccak256("test_operation");

        vm.expectRevert(kSiloContract.ZeroAmount.selector);
        vm.prank(strategyManager);
        silo.transferToDestination(batchReceiver1, 0, operationId, "redemption");
    }

    function test_transferToDestination_revertsUnauthorized() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give silo tokens
        mintTokens(asset, address(silo), amount);

        // Try to transfer without proper role
        vm.expectRevert();
        vm.prank(users.alice);
        silo.transferToDestination(batchReceiver1, amount, operationId, "redemption");
    }

    function test_batchTransferToDestinations_success() public {
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _50_USDC;
        uint256 totalAmount = amount1 + amount2;

        address[] memory destinations = new address[](2);
        destinations[0] = batchReceiver1;
        destinations[1] = batchReceiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes32[] memory operationIds = new bytes32[](2);
        operationIds[0] = keccak256("operation1");
        operationIds[1] = keccak256("operation2");

        // Setup: Give silo tokens
        mintTokens(asset, address(silo), totalAmount);

        // Execute batch transfer
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");

        // Verify state
        (uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, totalAmount);
        assertEq(currentBalance, 0);
        assertEq(MockToken(asset).balanceOf(batchReceiver1), amount1);
        assertEq(MockToken(asset).balanceOf(batchReceiver2), amount2);
    }

    function test_batchTransferToDestinations_revertsInsufficientBalance() public {
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _50_USDC;

        address[] memory destinations = new address[](2);
        destinations[0] = batchReceiver1;
        destinations[1] = batchReceiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes32[] memory operationIds = new bytes32[](2);
        operationIds[0] = keccak256("operation1");
        operationIds[1] = keccak256("operation2");

        // Give silo less than required
        mintTokens(asset, address(silo), amount1); // Only partial amount

        vm.expectRevert(kSiloContract.InsufficientBalance.selector);
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");
    }

    function test_batchTransferToDestinations_revertsInvalidArrayLengths() public {
        address[] memory destinations = new address[](2);
        destinations[0] = batchReceiver1;
        destinations[1] = batchReceiver2;

        uint256[] memory amounts = new uint256[](1); // Wrong length
        amounts[0] = _100_USDC;

        bytes32[] memory operationIds = new bytes32[](2);
        operationIds[0] = keccak256("operation1");
        operationIds[1] = keccak256("operation2");

        vm.expectRevert(kSiloContract.InvalidOperation.selector);
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");
    }

    function test_getTotalAmounts() public {
        uint256 amount = _100_USDC;

        // Setup: Give silo tokens and transfer some
        mintTokens(asset, address(silo), amount);

        vm.prank(strategyManager);
        silo.transferToDestination(batchReceiver1, amount / 2, keccak256("op1"), "test");

        (uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, amount / 2);
        assertEq(currentBalance, amount / 2);
    }

    function test_asset() public {
        assertEq(silo.asset(), asset);
    }

    function test_setStrategyManager() public {
        address newManager = makeAddr("newManager");

        vm.prank(users.admin);
        silo.setStrategyManager(newManager);

        // Verify new manager has role
        assertTrue(silo.hasAnyRole(newManager, silo.STRATEGY_MANAGER_ROLE()));
    }

    function test_setStrategyManager_revertsZeroAddress() public {
        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        vm.prank(users.admin);
        silo.setStrategyManager(address(0));
    }

    function test_emergencyWithdraw() public {
        uint256 amount = _100_USDC;

        // Setup: Give silo tokens and pause contract
        mintTokens(asset, address(silo), amount);
        vm.prank(users.emergencyAdmin);
        silo.setPaused(true);

        // Execute emergency withdrawal
        vm.prank(users.emergencyAdmin);
        silo.emergencyWithdraw(asset, users.admin, amount);

        assertEq(MockToken(asset).balanceOf(users.admin), amount);
    }

    function test_emergencyWithdraw_revertsContractNotPaused() public {
        uint256 amount = _100_USDC;

        // Setup: Give silo tokens but don't pause
        mintTokens(asset, address(silo), amount);

        vm.expectRevert(kSiloContract.ContractNotPaused.selector);
        vm.prank(users.emergencyAdmin);
        silo.emergencyWithdraw(asset, users.admin, amount);
    }
}
