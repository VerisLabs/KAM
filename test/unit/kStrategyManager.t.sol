// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kSiloContract } from "../../src/kSiloContract.sol";
import { kStrategyManager } from "../../src/kStrategyManager.sol";

import { DataTypes } from "../../src/types/DataTypes.sol";
import { MockToken } from "../helpers/MockToken.sol";

import { kDNStakingVaultProxy } from "../helpers/kDNStakingVaultProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";
import { _100_USDC, _200_USDC, _50_USDC } from "../utils/Constants.sol";

/// @title kStrategyManager Unit Tests
/// @notice Tests settlement orchestration and multi-destination asset management
contract kStrategyManagerTest is BaseTest {
    kStrategyManager internal strategyManager;
    kStrategyManager internal strategyManagerImpl;
    kSiloContract internal siloContract;
    kSiloContract internal siloContractImpl;
    kDNStakingVaultProxy internal proxyDeployer;

    // Test constants
    address internal kDNStakingVault = makeAddr("kDNStakingVault");
    address internal kSStakingVault = makeAddr("kSStakingVault");
    address internal kMinter = makeAddr("kMinter");
    address internal mockMetavault = makeAddr("mockMetavault");
    address internal mockCustodial = makeAddr("mockCustodial");
    address internal mockBatchReceiver1 = makeAddr("mockBatchReceiver1");
    address internal mockBatchReceiver2 = makeAddr("mockBatchReceiver2");

    function setUp() public override {
        super.setUp();

        // Deploy proxy deployer
        proxyDeployer = new kDNStakingVaultProxy();

        // First, we need to deploy implementations
        siloContractImpl = new kSiloContract();
        strategyManagerImpl = new kStrategyManager();

        // Use a temporary address for strategyManager in kSiloContract initialization
        // We'll update it after deploying the actual strategyManager
        address tempStrategyManager = makeAddr("tempStrategyManager");

        // Deploy kSiloContract proxy
        bytes memory siloInitData = abi.encodeWithSelector(
            kSiloContract.initialize.selector,
            asset,
            tempStrategyManager, // temporary address
            users.owner,
            users.admin,
            users.emergencyAdmin
        );
        address siloProxyAddress = proxyDeployer.deployAndInitialize(address(siloContractImpl), siloInitData);
        siloContract = kSiloContract(payable(siloProxyAddress));

        // Deploy kStrategyManager proxy
        bytes memory strategyInitData = abi.encodeWithSelector(
            kStrategyManager.initialize.selector,
            kDNStakingVault,
            kSStakingVault,
            asset,
            address(siloContract),
            kMinter,
            users.owner,
            users.admin,
            users.emergencyAdmin,
            users.settler
        );
        address strategyProxyAddress = proxyDeployer.deployAndInitialize(address(strategyManagerImpl), strategyInitData);
        strategyManager = kStrategyManager(payable(strategyProxyAddress));

        // Now update strategyManager in siloContract to the actual address
        vm.prank(users.admin);
        siloContract.setStrategyManager(address(strategyManager));

        // Setup labels
        vm.label(address(strategyManager), "kStrategyManager_Proxy");
        vm.label(address(strategyManagerImpl), "kStrategyManager_Implementation");
        vm.label(address(siloContract), "kSiloContract_Proxy");
        vm.label(address(siloContractImpl), "kSiloContract_Implementation");
        vm.label(kDNStakingVault, "MockkDNStakingVault");
        vm.label(kSStakingVault, "MockkSStakingVault");
        vm.label(kMinter, "MockkMinter");
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_initialize_success() public {
        // Verify addresses are set correctly
        assertEq(strategyManager.kSiloContractAddress(), address(siloContract));
        assertEq(strategyManager.settlementCounter(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                      SETTLEMENT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_validateSettlement_success() public {
        uint256 totalWithdrawals = _200_USDC;
        uint256 totalDeposits = _100_USDC; // withdrawals > deposits ✓

        address[] memory destinations = new address[](2);
        destinations[0] = mockBatchReceiver1;
        destinations[1] = mockBatchReceiver2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = _50_USDC;
        amounts[1] = _50_USDC;

        bytes32[] memory batchReceiverIds = new bytes32[](2);
        batchReceiverIds[0] = bytes32(uint256(1));
        batchReceiverIds[1] = bytes32(uint256(2));

        vm.expectEmit(true, false, false, true);
        emit kStrategyManager.SettlementValidated(1, totalWithdrawals, totalDeposits);

        vm.expectEmit(false, false, false, true);
        emit kStrategyManager.WithdrawalsDepositsMismatch(totalWithdrawals, totalDeposits, _100_USDC);

        vm.prank(users.settler);
        uint256 operationId = strategyManager.validateSettlement(
            totalWithdrawals, totalDeposits, destinations, amounts, batchReceiverIds, "test_settlement"
        );

        assertEq(operationId, 1);
        assertEq(strategyManager.settlementCounter(), 1);

        // Verify operation was stored
        kStrategyManager.SettlementOperation memory operation = strategyManager.getSettlementOperation(operationId);
        assertEq(operation.operationId, operationId);
        assertEq(operation.totalWithdrawals, totalWithdrawals);
        assertEq(operation.totalDeposits, totalDeposits);
        assertTrue(operation.validated);
        assertFalse(operation.executed);
    }

    function test_validateSettlement_revertsInsufficientWithdrawals() public {
        uint256 totalWithdrawals = _100_USDC;
        uint256 totalDeposits = _200_USDC; // withdrawals <= deposits ✗

        address[] memory destinations = new address[](1);
        destinations[0] = mockBatchReceiver1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _100_USDC;

        bytes32[] memory batchReceiverIds = new bytes32[](1);
        batchReceiverIds[0] = bytes32(uint256(1));

        vm.expectRevert(kStrategyManager.InsufficientWithdrawals.selector);
        vm.prank(users.settler);
        strategyManager.validateSettlement(
            totalWithdrawals, totalDeposits, destinations, amounts, batchReceiverIds, "test_settlement"
        );
    }

    function test_validateSettlement_revertsArrayLengthMismatch() public {
        uint256 totalWithdrawals = _200_USDC;
        uint256 totalDeposits = _100_USDC;

        address[] memory destinations = new address[](2);
        destinations[0] = mockBatchReceiver1;
        destinations[1] = mockBatchReceiver2;

        uint256[] memory amounts = new uint256[](1); // Wrong length
        amounts[0] = _100_USDC;

        bytes32[] memory batchReceiverIds = new bytes32[](2);
        batchReceiverIds[0] = bytes32(uint256(1));
        batchReceiverIds[1] = bytes32(uint256(2));

        vm.expectRevert(kStrategyManager.InvalidSettlementOperation.selector);
        vm.prank(users.settler);
        strategyManager.validateSettlement(
            totalWithdrawals, totalDeposits, destinations, amounts, batchReceiverIds, "test_settlement"
        );
    }

    function test_validateSettlement_revertsIfNotSettler() public {
        uint256 totalWithdrawals = _200_USDC;
        uint256 totalDeposits = _100_USDC;

        address[] memory destinations = new address[](1);
        destinations[0] = mockBatchReceiver1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _100_USDC;

        bytes32[] memory batchReceiverIds = new bytes32[](1);
        batchReceiverIds[0] = bytes32(uint256(1));

        vm.expectRevert(); // Should revert with role check
        vm.prank(users.alice);
        strategyManager.validateSettlement(
            totalWithdrawals, totalDeposits, destinations, amounts, batchReceiverIds, "test_settlement"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setkSiloContract_success() public {
        address newSilo = makeAddr("newSilo");

        vm.expectEmit(true, true, false, false);
        emit kStrategyManager.kSiloContractUpdated(address(siloContract), newSilo);

        vm.prank(users.admin);
        strategyManager.setkSiloContract(newSilo);

        assertEq(strategyManager.kSiloContractAddress(), newSilo);
    }

    function test_setkSiloContract_revertsZeroAddress() public {
        vm.expectRevert(kStrategyManager.ZeroAddress.selector);
        vm.prank(users.admin);
        strategyManager.setkSiloContract(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getSettlementOperation_success() public {
        // First create a settlement operation
        uint256 totalWithdrawals = _200_USDC;
        uint256 totalDeposits = _100_USDC;

        address[] memory destinations = new address[](1);
        destinations[0] = mockBatchReceiver1;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _100_USDC;

        bytes32[] memory batchReceiverIds = new bytes32[](1);
        batchReceiverIds[0] = bytes32(uint256(1));

        vm.prank(users.settler);
        uint256 operationId = strategyManager.validateSettlement(
            totalWithdrawals, totalDeposits, destinations, amounts, batchReceiverIds, "test_settlement"
        );

        // Test view function
        kStrategyManager.SettlementOperation memory operation = strategyManager.getSettlementOperation(operationId);
        assertEq(operation.operationId, operationId);
        assertEq(operation.totalWithdrawals, totalWithdrawals);
        assertEq(operation.totalDeposits, totalDeposits);
        assertTrue(operation.validated);
        assertFalse(operation.executed);
    }

    function test_getSettlementOperation_nonExistent() public {
        kStrategyManager.SettlementOperation memory operation = strategyManager.getSettlementOperation(999);
        assertEq(operation.operationId, 0); // Should return empty operation
    }

    function test_settleAndAllocate_interfaceUpdated() public {
        // Test that the function signature has been updated to include destination/source arrays

        // This test verifies that the function signature change was successful
        // and that the function exists with the correct parameters

        // Create empty arrays for destinations/sources
        address[] memory emptyAddresses = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);

        // Create a minimal allocation order
        DataTypes.Allocation[] memory allocations = new DataTypes.Allocation[](0);
        DataTypes.AllocationOrder memory order = DataTypes.AllocationOrder({
            totalAmount: 0,
            allocations: allocations,
            nonce: 0,
            deadline: block.timestamp + 1 hours
        });

        // This should compile and call the function with the new signature
        // We expect it to revert with SettlementTooEarly since we haven't advanced time
        DataTypes.SettlementParams memory params = DataTypes.SettlementParams({
            stakingBatchId: 0,
            unstakingBatchId: 0,
            totalKTokensStaked: 0,
            totalStkTokensUnstaked: 0,
            totalKTokensToReturn: 0,
            totalYieldToMinter: 0,
            stakingDestinations: emptyAddresses,
            stakingAmounts: emptyAmounts,
            unstakingSources: emptyAddresses,
            unstakingAmounts: emptyAmounts
        });
        vm.prank(users.settler);
        vm.expectRevert(); // TODO: Add revert reason
        strategyManager.settleAndAllocate(params, order, "");
    }
}
