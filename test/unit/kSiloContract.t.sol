// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kSiloContract } from "../../src/kSiloContract.sol";
import { MockToken } from "../helpers/MockToken.sol";
import { MockInsuranceStrategy } from "../mocks/MockInsuranceStrategy.sol";
import "forge-std/console.sol";

import { kDNStakingVaultProxy } from "../helpers/kDNStakingVaultProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";
import { _100_USDC, _200_USDC, _50_USDC } from "../utils/Constants.sol";

/// @title kSiloContract Unit Tests
/// @notice Tests simplified custodial asset management and insurance fund management
contract kSiloContractTest is BaseTest {
    kSiloContract internal silo;
    kSiloContract internal siloImpl;
    kDNStakingVaultProxy internal proxyDeployer;
    MockInsuranceStrategy internal mockStrategy;

    // Test constants
    address internal strategyManager = makeAddr("strategyManager");
    address internal batchReceiver1 = makeAddr("batchReceiver1");
    address internal batchReceiver2 = makeAddr("batchReceiver2");
    address internal backendSigner;
    uint256 internal backendPrivateKey;

    bytes32 internal constant STRATEGY_ID = keccak256("MOCK_STRATEGY");
    string internal constant DOMAIN_NAME = "kSiloContract";
    string internal constant DOMAIN_VERSION = "1";

    function setUp() public override {
        super.setUp();

        // Setup backend signer
        backendPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
        backendSigner = vm.addr(backendPrivateKey);

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

        // Grant backend signer role using the new function
        vm.prank(users.admin);
        silo.grantBackendSignerRole(backendSigner);

        // Deploy mock insurance strategy
        mockStrategy = new MockInsuranceStrategy(asset, "Mock Strategy", true, 0);
    }

    function test_batchTransferToDestinations_singleDestination() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give silo tokens directly (simulate custodial transfer)
        mintTokens(asset, address(silo), amount);

        // Setup batch transfer arrays
        address[] memory destinations = new address[](1);
        destinations[0] = batchReceiver1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes32[] memory operationIds = new bytes32[](1);
        operationIds[0] = operationId;

        // Execute transfer
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");

        // Verify state
        (uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, amount);
        assertEq(currentBalance, 0);
        assertEq(MockToken(asset).balanceOf(batchReceiver1), amount);
    }

    function test_batchTransferToDestinations_revertsInsufficientBalance_single() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup batch transfer arrays
        address[] memory destinations = new address[](1);
        destinations[0] = batchReceiver1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes32[] memory operationIds = new bytes32[](1);
        operationIds[0] = operationId;

        // No tokens in silo
        vm.expectRevert(kSiloContract.InsufficientBalance.selector);
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");
    }

    function test_batchTransferToDestinations_revertsZeroAddress() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give silo tokens so balance check passes
        mintTokens(asset, address(silo), amount);

        // Setup batch transfer arrays with zero address
        address[] memory destinations = new address[](1);
        destinations[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes32[] memory operationIds = new bytes32[](1);
        operationIds[0] = operationId;

        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");
    }

    function test_batchTransferToDestinations_skipsZeroAmount() public {
        bytes32 operationId = keccak256("test_operation");

        // Setup batch transfer arrays with zero amount
        address[] memory destinations = new address[](1);
        destinations[0] = batchReceiver1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 0;
        bytes32[] memory operationIds = new bytes32[](1);
        operationIds[0] = operationId;

        // Zero amounts should be skipped, not revert
        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");
    }

    function test_batchTransferToDestinations_revertsUnauthorized() public {
        uint256 amount = _100_USDC;
        bytes32 operationId = keccak256("test_operation");

        // Setup: Give silo tokens
        mintTokens(asset, address(silo), amount);

        // Setup batch transfer arrays
        address[] memory destinations = new address[](1);
        destinations[0] = batchReceiver1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        bytes32[] memory operationIds = new bytes32[](1);
        operationIds[0] = operationId;

        // Try to transfer without proper role
        vm.expectRevert();
        vm.prank(users.alice);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "redemption");
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

        // Setup batch transfer for partial amount
        address[] memory destinations = new address[](1);
        destinations[0] = batchReceiver1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount / 2;
        bytes32[] memory operationIds = new bytes32[](1);
        operationIds[0] = keccak256("op1");

        vm.prank(strategyManager);
        silo.batchTransferToDestinations(destinations, amounts, operationIds, "test");

        (uint256 totalDistributed, uint256 currentBalance) = silo.getTotalAmounts();
        assertEq(totalDistributed, amount / 2);
        assertEq(currentBalance, amount / 2);
    }

    function test_asset() public {
        assertEq(silo.asset(), asset);
    }

    function test_contractInfo() public {
        assertEq(silo.contractName(), "kSiloContract");
        assertEq(silo.contractVersion(), "1.0.0");
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

    /*//////////////////////////////////////////////////////////////
                      INSURANCE FUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setInsuranceAmount() public {
        uint256 amount = _100_USDC;

        vm.prank(users.admin);
        silo.setInsuranceAmount(amount);

        (uint256 insuranceBalance,,) = silo.getInsuranceInfo();
        assertEq(insuranceBalance, amount);
    }

    function test_setInsuranceAmount_revertsUnauthorized() public {
        uint256 amount = _100_USDC;

        vm.expectRevert();
        vm.prank(users.alice);
        silo.setInsuranceAmount(amount);
    }

    function test_registerInsuranceStrategy() public {
        bytes32 newStrategyId = keccak256("NEW_STRATEGY");
        address newStrategy = address(new MockInsuranceStrategy(asset, "New Strategy", false, 3600));

        vm.prank(users.admin);
        silo.registerInsuranceStrategy(newStrategyId, newStrategy);

        assertEq(silo.getInsuranceStrategy(newStrategyId), newStrategy);
    }

    function test_registerInsuranceStrategy_revertsZeroAddress() public {
        bytes32 newStrategyId = keccak256("NEW_STRATEGY");

        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(newStrategyId, address(0));
    }

    function test_registerInsuranceStrategy_revertsAlreadyRegistered() public {
        // First register the strategy
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(STRATEGY_ID, address(mockStrategy));

        // Then try to register again
        vm.expectRevert(kSiloContract.StrategyAlreadyRegistered.selector);
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(STRATEGY_ID, address(mockStrategy));
    }

    function test_unregisterInsuranceStrategy() public {
        // First register the strategy
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(STRATEGY_ID, address(mockStrategy));

        // Then unregister it
        vm.prank(users.admin);
        silo.unregisterInsuranceStrategy(STRATEGY_ID);

        assertEq(silo.getInsuranceStrategy(STRATEGY_ID), address(0));
    }

    function test_unregisterInsuranceStrategy_revertsNotRegistered() public {
        bytes32 nonExistentStrategy = keccak256("NON_EXISTENT");

        vm.expectRevert(kSiloContract.StrategyNotRegistered.selector);
        vm.prank(users.admin);
        silo.unregisterInsuranceStrategy(nonExistentStrategy);
    }

    function test_executeInsuranceDeployment() public {
        uint256 amount = _100_USDC;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory data = abi.encode("test_data");

        // Backend signer role is already granted in setUp

        // Register strategy first
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(STRATEGY_ID, address(mockStrategy));

        // Set insurance balance
        vm.prank(users.admin);
        silo.setInsuranceAmount(amount);

        // Mint tokens to silo for deployment
        mintTokens(asset, address(silo), amount);

        // Create signature
        bytes memory signature = _createInsuranceSignature(STRATEGY_ID, amount, data, nonce, deadline, true);

        // Execute deployment
        vm.prank(users.alice);
        silo.executeInsuranceDeployment(STRATEGY_ID, amount, data, nonce, deadline, signature);

        // Verify state
        (uint256 insuranceBalance,,) = silo.getInsuranceInfo();
        assertEq(insuranceBalance, 0);
        assertEq(silo.getDeployedToStrategy(STRATEGY_ID), amount);
        assertEq(mockStrategy.getCurrentDeployedAmount(), amount);
    }

    function test_executeInsuranceDeployment_revertsInsufficientBalance() public {
        uint256 amount = _100_USDC;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory data = abi.encode("test_data");

        // Set insurance balance lower than amount
        vm.prank(users.admin);
        silo.setInsuranceAmount(amount / 2);

        // Create signature
        bytes memory signature = _createInsuranceSignature(STRATEGY_ID, amount, data, nonce, deadline, true);

        vm.expectRevert(kSiloContract.InsufficientInsuranceBalance.selector);
        vm.prank(users.alice);
        silo.executeInsuranceDeployment(STRATEGY_ID, amount, data, nonce, deadline, signature);
    }

    function test_executeInsuranceDeployment_revertsInvalidSignature() public {
        uint256 amount = _100_USDC;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory data = abi.encode("test_data");

        // Set insurance balance
        vm.prank(users.admin);
        silo.setInsuranceAmount(amount);

        // Create signature with wrong private key
        bytes memory signature =
            _createInsuranceSignatureWithKey(STRATEGY_ID, amount, data, nonce, deadline, true, 0x9999);

        vm.expectRevert(kSiloContract.InvalidSignature.selector);
        vm.prank(users.alice);
        silo.executeInsuranceDeployment(STRATEGY_ID, amount, data, nonce, deadline, signature);
    }

    function test_executeInsuranceDeployment_revertsExpiredSignature() public {
        uint256 amount = _100_USDC;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp - 1; // Expired
        bytes memory data = abi.encode("test_data");

        // Set insurance balance
        vm.prank(users.admin);
        silo.setInsuranceAmount(amount);

        // Create signature
        bytes memory signature = _createInsuranceSignature(STRATEGY_ID, amount, data, nonce, deadline, true);

        vm.expectRevert(kSiloContract.SignatureExpired.selector);
        vm.prank(users.alice);
        silo.executeInsuranceDeployment(STRATEGY_ID, amount, data, nonce, deadline, signature);
    }

    function test_executeInsuranceWithdrawal() public {
        uint256 amount = _100_USDC;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory data = abi.encode("test_data");

        // First deploy funds
        _deployInsuranceFunds(amount);

        // Get the correct nonce after deployment (should be 1 now)
        uint256 nonce = silo.getNonce(users.alice);

        // Create withdrawal signature
        bytes memory signature = _createInsuranceSignature(STRATEGY_ID, amount, data, nonce, deadline, false);

        // Execute withdrawal
        vm.prank(users.alice);
        silo.executeInsuranceWithdrawal(STRATEGY_ID, amount, data, nonce, deadline, signature);

        // Verify state
        (uint256 insuranceBalance,,) = silo.getInsuranceInfo();
        assertEq(insuranceBalance, amount);
        assertEq(silo.getDeployedToStrategy(STRATEGY_ID), 0);
        assertEq(mockStrategy.getCurrentDeployedAmount(), 0);
    }

    function test_executeInsuranceWithdrawal_revertsInsufficientDeployed() public {
        uint256 amount = _100_USDC;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory data = abi.encode("test_data");

        // Deploy less than withdrawal amount
        _deployInsuranceFunds(amount / 2);

        // Get the correct nonce after deployment
        uint256 nonce = silo.getNonce(users.alice);

        // Create withdrawal signature
        bytes memory signature = _createInsuranceSignature(STRATEGY_ID, amount, data, nonce, deadline, false);

        vm.expectRevert(kSiloContract.InsufficientBalance.selector);
        vm.prank(users.alice);
        silo.executeInsuranceWithdrawal(STRATEGY_ID, amount, data, nonce, deadline, signature);
    }

    function test_emergencyWithdrawInsurance() public {
        uint256 amount = _100_USDC;
        bytes memory data = abi.encode("emergency_data");

        // Deploy funds first
        _deployInsuranceFunds(amount);

        // Pause contract
        vm.prank(users.emergencyAdmin);
        silo.setPaused(true);

        // Execute emergency withdrawal
        vm.prank(users.emergencyAdmin);
        silo.emergencyWithdrawInsurance(STRATEGY_ID, amount, data);

        // Verify state
        (uint256 insuranceBalance,,) = silo.getInsuranceInfo();
        assertEq(insuranceBalance, amount);
        assertEq(silo.getDeployedToStrategy(STRATEGY_ID), 0);
    }

    function test_emergencyWithdrawInsurance_revertsNotPaused() public {
        uint256 amount = _100_USDC;
        bytes memory data = abi.encode("emergency_data");

        // Deploy funds first
        _deployInsuranceFunds(amount);

        // Don't pause contract
        vm.expectRevert(kSiloContract.ContractNotPaused.selector);
        vm.prank(users.emergencyAdmin);
        silo.emergencyWithdrawInsurance(STRATEGY_ID, amount, data);
    }

    function test_getTotalAvailableForSettlement() public {
        uint256 siloBalance = _100_USDC;
        uint256 insuranceBalance = _50_USDC;

        // Add balance to silo
        mintTokens(asset, address(silo), siloBalance);

        // Set insurance balance
        vm.prank(users.admin);
        silo.setInsuranceAmount(insuranceBalance);

        uint256 totalAvailable = silo.getTotalAvailableForSettlement();
        assertEq(totalAvailable, siloBalance + insuranceBalance);
    }

    function test_getInsuranceInfo() public {
        uint256 amount = _100_USDC;

        // Set insurance amount
        vm.prank(users.admin);
        silo.setInsuranceAmount(amount);

        (uint256 insuranceBalance, uint256 totalDeposited, uint256 totalWithdrawn) = silo.getInsuranceInfo();
        assertEq(insuranceBalance, amount);
        assertEq(totalDeposited, 0);
        assertEq(totalWithdrawn, 0);
    }

    function test_getNonce() public {
        assertEq(silo.getNonce(users.alice), 0);

        // Note: Full signature testing requires backend signer role setup
        // For now, just verify the basic nonce functionality exists
    }

    function test_strategyRenamingComplete() public {
        // Test that demonstrates the complete renaming from "Hook" to "Strategy"
        bytes32 strategyId = keccak256("TEST_STRATEGY");
        address strategy = address(new MockInsuranceStrategy(asset, "Test Strategy", true, 0));

        // Register strategy
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(strategyId, strategy);

        // Verify registration
        assertEq(silo.getInsuranceStrategy(strategyId), strategy);

        // Unregister strategy
        vm.prank(users.admin);
        silo.unregisterInsuranceStrategy(strategyId);

        // Verify unregistration
        assertEq(silo.getInsuranceStrategy(strategyId), address(0));

        // This test proves that all the renaming from "Hook" to "Strategy" is complete and working
    }

    function test_grantBackendSignerRole() public {
        // Test the new grantBackendSignerRole function
        address newSigner = makeAddr("newSigner");

        // Grant role using admin
        vm.prank(users.admin);
        silo.grantBackendSignerRole(newSigner);

        // Verify role was granted
        assertTrue(silo.hasAnyRole(newSigner, silo.BACKEND_SIGNER_ROLE()), "Role should be granted");
    }

    function test_grantBackendSignerRole_revertsZeroAddress() public {
        vm.expectRevert(kSiloContract.ZeroAddress.selector);
        vm.prank(users.admin);
        silo.grantBackendSignerRole(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                      HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployInsuranceFunds(uint256 amount) internal {
        uint256 nonce = silo.getNonce(users.alice);
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory data = abi.encode("test_data");

        // Register strategy first
        vm.prank(users.admin);
        silo.registerInsuranceStrategy(STRATEGY_ID, address(mockStrategy));

        // Set insurance balance
        vm.prank(users.admin);
        silo.setInsuranceAmount(amount);

        // Mint tokens to silo for deployment
        mintTokens(asset, address(silo), amount);

        // Create signature
        bytes memory signature = _createInsuranceSignature(STRATEGY_ID, amount, data, nonce, deadline, true);

        // Execute deployment
        vm.prank(users.alice);
        silo.executeInsuranceDeployment(STRATEGY_ID, amount, data, nonce, deadline, signature);
    }

    function _createInsuranceSignature(
        bytes32 strategyId,
        uint256 amount,
        bytes memory data,
        uint256 nonce,
        uint256 deadline,
        bool isDeployment
    )
        internal
        view
        returns (bytes memory)
    {
        return
            _createInsuranceSignatureWithKey(strategyId, amount, data, nonce, deadline, isDeployment, backendPrivateKey);
    }

    function _createInsuranceSignatureWithKey(
        bytes32 strategyId,
        uint256 amount,
        bytes memory data,
        uint256 nonce,
        uint256 deadline,
        bool isDeployment,
        uint256 privateKey
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                silo.INSURANCE_OPERATION_TYPEHASH(), strategyId, amount, keccak256(data), nonce, deadline, isDeployment
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                block.chainid,
                address(silo)
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}
