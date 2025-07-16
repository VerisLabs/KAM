// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kMinterDataProvider } from "../../src/dataProviders/kMinterDataProvider.sol";
import { kBatchReceiver } from "../../src/kBatchReceiver.sol";
import { kMinter } from "../../src/kMinter.sol";
import { DataTypes } from "../../src/types/DataTypes.sol";
import { MockToken } from "../helpers/MockToken.sol";
import { MockkDNStaking } from "../helpers/MockkDNStaking.sol";
import { MockkToken } from "../helpers/MockkToken.sol";
import { kMinterProxy } from "../helpers/kMinterProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";

import {
    ADMIN_ROLE,
    BATCH_CUTOFF_TIME,
    EMERGENCY_ADMIN_ROLE,
    INSTITUTION_ROLE,
    SETTLEMENT_INTERVAL,
    SETTLER_ROLE,
    _10000_USDC,
    _1000_USDC,
    _100_USDC
} from "../utils/Constants.sol";

/// @title kMinter Unit Tests
/// @notice Tests the kMinter contract using minimal proxy pattern
contract kMinterTest is BaseTest {
    kMinter internal minter;
    kMinter internal minterImpl;
    kMinterDataProvider internal minterDataProvider;
    kMinterProxy internal proxyDeployer;
    MockkDNStaking internal mockStaking;
    MockkToken internal kToken;

    function setUp() public override {
        super.setUp();

        // Deploy implementation (with disabled initializers)
        minterImpl = new kMinter();

        // Deploy proxy deployer
        proxyDeployer = new kMinterProxy();

        // Deploy mock dependencies
        mockStaking = new MockkDNStaking();
        mockStaking.setAsset(asset); // Set the asset address
        kToken = new MockkToken("KAM USDC", "kUSDC", 6);

        // Set up kToken mint/burn capabilities for minter
        kToken.grantRole(kToken.MINTER_ROLE(), address(this));

        // Prepare initialization parameters
        DataTypes.InitParams memory params = DataTypes.InitParams({
            kToken: address(kToken),
            underlyingAsset: asset,
            owner: users.alice,
            admin: users.admin,
            emergencyAdmin: users.emergencyAdmin,
            institution: users.institution,
            settler: users.settler,
            manager: address(mockStaking),
            settlementInterval: SETTLEMENT_INTERVAL
        });

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, params);

        // Deploy and initialize proxy
        address proxyAddress = proxyDeployer.deployAndInitialize(address(minterImpl), initData);
        minter = kMinter(payable(proxyAddress));

        // Grant minter role to kMinter contract
        kToken.grantRole(kToken.MINTER_ROLE(), address(minter));

        // Set kMinter as authorized minter in mock staking
        // Note: This needs to be done after minter is deployed
        mockStaking.setAuthorizedMinter(address(minter), true);

        // Re-register to update the isAuthorizedMinter flag
        vm.prank(users.admin);
        minter.setKDNStaking(address(mockStaking));

        // Deploy data provider
        minterDataProvider = new kMinterDataProvider(address(minter));

        vm.label(address(minter), "kMinter_Proxy");
        vm.label(address(minterImpl), "kMinter_Implementation");
        vm.label(address(mockStaking), "MockkDNStaking");
        vm.label(address(kToken), "MockkToken");
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Implementation should have disabled initializers
        assertTrue(address(minterImpl) != address(0));

        // Try to initialize implementation directly (should fail)
        DataTypes.InitParams memory params = DataTypes.InitParams({
            kToken: address(kToken),
            underlyingAsset: asset,
            owner: users.alice,
            admin: users.admin,
            emergencyAdmin: users.emergencyAdmin,
            institution: users.institution,
            settler: users.settler,
            manager: address(mockStaking),
            settlementInterval: SETTLEMENT_INTERVAL
        });

        vm.expectRevert();
        minterImpl.initialize(params);
    }

    function test_initialize_success() public {
        // Verify proxy was initialized correctly
        assertEq(minter.asset(), asset);
        assertEq(minter.kToken(), address(kToken));
        assertEq(minter.kDNStaking(), address(mockStaking));
        assertEq(minter.owner(), users.alice);
        assertTrue(minter.hasAnyRole(users.admin, ADMIN_ROLE));
        assertTrue(minter.hasAnyRole(users.emergencyAdmin, EMERGENCY_ADMIN_ROLE));
        assertTrue(minter.hasAnyRole(users.institution, INSTITUTION_ROLE));
        assertTrue(minter.hasAnyRole(users.settler, SETTLER_ROLE));
        assertTrue(minter.isAuthorizedMinter());
    }

    function test_initialize_revertsOnZeroAddresses() public {
        DataTypes.InitParams memory params = DataTypes.InitParams({
            kToken: address(0), // zero address
            underlyingAsset: asset,
            owner: users.alice,
            admin: users.admin,
            emergencyAdmin: users.emergencyAdmin,
            institution: users.institution,
            settler: users.settler,
            manager: address(mockStaking),
            settlementInterval: SETTLEMENT_INTERVAL
        });

        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, params);

        vm.expectRevert(kMinter.ZeroAddress.selector);
        proxyDeployer.deployAndInitialize(address(minterImpl), initData);
    }

    function test_initialize_revertsOnDoubleInit() public {
        // Try to initialize again (should fail)
        DataTypes.InitParams memory params = DataTypes.InitParams({
            kToken: address(kToken),
            underlyingAsset: asset,
            owner: users.alice,
            admin: users.admin,
            emergencyAdmin: users.emergencyAdmin,
            institution: users.institution,
            settler: users.settler,
            manager: address(mockStaking),
            settlementInterval: SETTLEMENT_INTERVAL
        });

        vm.expectRevert();
        minter.initialize(params);
    }

    /*//////////////////////////////////////////////////////////////
                           MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mint_success() public {
        uint256 amount = _1000_USDC;

        // Get initial balance
        uint256 initialBalance = MockToken(asset).balanceOf(users.institution);

        // Approve minter to spend tokens
        vm.prank(users.institution);
        MockToken(asset).approve(address(minter), amount);

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: users.bob });

        vm.expectEmit(true, false, false, true);
        emit kMinter.Minted(users.bob, amount, 1); // First batch ID

        vm.prank(users.institution);
        minter.mint(request);

        // Verify tokens were minted
        assertEq(kToken.balanceOf(users.bob), amount);
        assertEq(kToken.totalSupply(), amount);

        // Verify underlying assets were transferred (institution balance decreased by amount)
        assertEq(MockToken(asset).balanceOf(users.institution), initialBalance - amount);
        assertEq(MockToken(asset).balanceOf(address(mockStaking)), amount);
    }

    function test_mint_revertsIfNotInstitution() public {
        uint256 amount = _1000_USDC;

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: users.bob });

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.mint(request);
    }

    function test_mint_revertsIfPaused() public {
        uint256 amount = _1000_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: users.bob });

        vm.expectRevert(kMinter.Paused.selector);
        vm.prank(users.institution);
        minter.mint(request);
    }

    function test_mint_revertsIfZeroAmount() public {
        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: 0, beneficiary: users.bob });

        vm.expectRevert(kMinter.ZeroAmount.selector);
        vm.prank(users.institution);
        minter.mint(request);
    }

    function test_mint_revertsIfZeroBeneficiary() public {
        uint256 amount = _1000_USDC;

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: address(0) });

        vm.expectRevert(kMinter.ZeroAddress.selector);
        vm.prank(users.institution);
        minter.mint(request);
    }

    function test_mint_revertsIfNotAuthorizedMinter() public {
        uint256 amount = _1000_USDC;

        // Remove authorization and trigger re-registration
        mockStaking.setAuthorizedMinter(address(minter), false);
        vm.prank(users.admin);
        minter.setKDNStaking(address(mockStaking));

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: users.bob });

        vm.expectRevert(kMinter.NotAuthorizedMinter.selector);
        vm.prank(users.institution);
        minter.mint(request);
    }

    function test_mint_revertsIfKDNStakingNotSet() public {
        // Deploy new minter without kDNStaking
        DataTypes.InitParams memory params = DataTypes.InitParams({
            kToken: address(kToken),
            underlyingAsset: asset,
            owner: users.alice,
            admin: users.admin,
            emergencyAdmin: users.emergencyAdmin,
            institution: users.institution,
            settler: users.settler,
            manager: address(0), // No manager
            settlementInterval: SETTLEMENT_INTERVAL
        });

        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, params);
        address newMinter = proxyDeployer.deployAndInitialize(address(minterImpl), initData);

        uint256 amount = _1000_USDC;
        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: users.bob });

        vm.expectRevert(kMinter.KDNStakingNotSet.selector);
        vm.prank(users.institution);
        kMinter(payable(newMinter)).mint(request);
    }

    /*//////////////////////////////////////////////////////////////
                         REDEMPTION REQUEST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_requestRedeem_success() public {
        uint256 amount = _1000_USDC;

        // First mint some tokens to user
        kToken.mint(users.bob, amount);

        // Approve minter to burn tokens
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        bytes32 requestId = minter.requestRedeem(request);

        // Verify tokens were burned
        assertEq(kToken.balanceOf(users.bob), 0);

        // Verify batch receiver was deployed
        address batchReceiver = minterDataProvider.getBatchReceiver(2);
        if (!(batchReceiver != address(0))) revert BatchReceiverNotDeployed();

        // Verify request ID is not zero
        assertTrue(requestId != bytes32(0));
    }

    function test_requestRedeem_revertsIfNotInstitution() public {
        uint256 amount = _1000_USDC;

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.requestRedeem(request);
    }

    function test_requestRedeem_revertsIfInsufficientBalance() public {
        uint256 amount = _1000_USDC;

        // Don't mint tokens to user

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.expectRevert(kMinter.InsufficientBalance.selector);
        vm.prank(users.institution);
        minter.requestRedeem(request);
    }

    function test_requestRedeem_revertsIfZeroAmount() public {
        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: 0, user: users.bob, recipient: users.charlie });

        vm.expectRevert(kMinter.ZeroAmount.selector);
        vm.prank(users.institution);
        minter.requestRedeem(request);
    }

    function test_requestRedeem_revertsIfZeroAddresses() public {
        uint256 amount = _1000_USDC;

        DataTypes.RedeemRequest memory request = DataTypes.RedeemRequest({
            amount: amount,
            user: address(0), // Zero user
            recipient: users.charlie
        });

        vm.expectRevert(kMinter.ZeroAddress.selector);
        vm.prank(users.institution);
        minter.requestRedeem(request);
    }

    /*//////////////////////////////////////////////////////////////
                           REDEMPTION EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_redeem_success() public {
        uint256 amount = _1000_USDC;

        // Setup: mint tokens and create redemption request
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        bytes32 requestId = minter.requestRedeem(request);

        // Get the actual batch receiver that was deployed (should be batch 2 since initial batch is 1)
        address batchReceiver = minterDataProvider.getBatchReceiver(2);
        if (!(batchReceiver != address(0))) revert BatchReceiverNotDeployed();

        // Give batch receiver assets
        mintTokens(asset, batchReceiver, amount);

        // Mark kDN batch as settled
        mockStaking.setBatchSettled(1, true);

        vm.expectEmit(true, true, false, true);
        emit kMinter.RedemptionExecuted(requestId, users.charlie, amount);

        // Execute redemption
        minter.redeem(requestId);

        // Verify assets were transferred to recipient
        assertEq(MockToken(asset).balanceOf(users.charlie), amount);
    }

    function test_redeem_revertsIfRequestNotFound() public {
        bytes32 invalidRequestId = keccak256("invalid");

        vm.expectRevert(kMinter.RequestNotFound.selector);
        minter.redeem(invalidRequestId);
    }

    function test_redeem_revertsIfAlreadyProcessed() public {
        uint256 amount = _1000_USDC;

        // Setup redemption request
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        bytes32 requestId = minter.requestRedeem(request);

        // Setup for execution
        address batchReceiver = minterDataProvider.getBatchReceiver(2);
        if (!(batchReceiver != address(0))) revert BatchReceiverNotDeployed();
        mintTokens(asset, batchReceiver, amount);
        mockStaking.setBatchSettled(1, true);

        // Execute once
        minter.redeem(requestId);

        // Try to execute again
        vm.expectRevert(kMinter.RequestAlreadyProcessed.selector);
        minter.redeem(requestId);
    }

    function test_redeem_revertsIfBatchNotSettled() public {
        uint256 amount = _1000_USDC;

        // Setup redemption request
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        bytes32 requestId = minter.requestRedeem(request);

        // Don't mark batch as settled

        vm.expectRevert(kMinter.BatchNotSettled.selector);
        minter.redeem(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                         CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_cancelRequest_success() public {
        uint256 amount = _1000_USDC;

        // Setup redemption request
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        bytes32 requestId = minter.requestRedeem(request);

        // Verify tokens were burned
        assertEq(kToken.balanceOf(users.bob), 0);

        vm.expectEmit(true, true, false, true);
        emit kMinter.RedemptionCancelled(requestId, users.bob, amount);

        // Cancel request
        vm.prank(users.institution);
        minter.cancelRequest(requestId);

        // Verify tokens were returned
        assertEq(kToken.balanceOf(users.bob), amount);
    }

    function test_cancelRequest_revertsIfNotInstitution() public {
        bytes32 requestId = keccak256("test");

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.cancelRequest(requestId);
    }

    function test_cancelRequest_revertsIfRequestNotFound() public {
        bytes32 invalidRequestId = keccak256("invalid");

        vm.expectRevert(kMinter.RequestNotFound.selector);
        vm.prank(users.institution);
        minter.cancelRequest(invalidRequestId);
    }

    /*//////////////////////////////////////////////////////////////
                         SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_notifyKDNBatchAssetsReceived_success() public {
        uint256 amount = _1000_USDC;
        uint256 kdnBatchId = 1;

        // Create a redemption request to deploy batch receiver
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        minter.requestRedeem(request);

        address batchReceiver = minterDataProvider.getBatchReceiver(2);
        if (!(batchReceiver != address(0))) revert BatchReceiverNotDeployed();

        // Give the minter contract assets and let it transfer to batch receiver properly
        mintTokens(asset, address(minter), amount);

        // Call receiveAssets as kMinter with proper amount
        vm.prank(address(minter));
        MockToken(asset).approve(batchReceiver, amount);

        vm.prank(address(minter));
        kBatchReceiver(batchReceiver).receiveAssets(amount);

        vm.prank(users.settler);
        minter.notifyKDNBatchAssetsReceived(kdnBatchId, batchReceiver, amount);

        // No revert means success
    }

    function test_notifyKDNBatchAssetsReceived_revertsIfNotSettler() public {
        uint256 amount = _1000_USDC;
        uint256 kdnBatchId = 1;
        address batchReceiver = address(0x123);

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.notifyKDNBatchAssetsReceived(kdnBatchId, batchReceiver, amount);
    }

    function test_notifyKDNBatchAssetsReceived_revertsIfInvalidReceiver() public {
        uint256 amount = _1000_USDC;
        uint256 kdnBatchId = 1;

        vm.expectRevert(kMinter.InvalidBatchReceiver.selector);
        vm.prank(users.settler);
        minter.notifyKDNBatchAssetsReceived(kdnBatchId, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_asset() public {
        assertEq(minter.asset(), asset);
    }

    function test_kToken() public {
        assertEq(minter.kToken(), address(kToken));
    }

    function test_kDNStaking() public {
        assertEq(minter.kDNStaking(), address(mockStaking));
    }

    function test_isAuthorizedMinter() public {
        assertTrue(minter.isAuthorizedMinter());

        // Test after removing authorization
        mockStaking.setAuthorizedMinter(address(minter), false);

        // Need to trigger re-registration to update the cached value
        vm.prank(users.admin);
        minter.setKDNStaking(address(mockStaking));

        assertFalse(minter.isAuthorizedMinter());
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_grantAdminRole() public {
        vm.prank(users.alice); // owner
        minter.grantAdminRole(users.bob);

        assertTrue(minter.hasAnyRole(users.bob, ADMIN_ROLE));
    }

    function test_revokeAdminRole() public {
        // First grant role
        vm.prank(users.alice);
        minter.grantAdminRole(users.bob);

        vm.prank(users.alice);
        minter.revokeAdminRole(users.bob);

        assertFalse(minter.hasAnyRole(users.bob, ADMIN_ROLE));
    }

    function test_setKDNStaking() public {
        // Deploy a new mock staking for testing
        MockkDNStaking newMockStaking = new MockkDNStaking();
        newMockStaking.setAsset(asset);
        newMockStaking.setAuthorizedMinter(address(minter), true);

        vm.expectEmit(true, false, false, true);
        emit kMinter.KDNStakingUpdated(address(newMockStaking));

        vm.prank(users.admin);
        minter.setKDNStaking(address(newMockStaking));

        assertEq(minter.kDNStaking(), address(newMockStaking));
    }

    function test_setKDNStaking_revertsIfZeroAddress() public {
        vm.expectRevert(kMinter.ZeroAddress.selector);
        vm.prank(users.admin);
        minter.setKDNStaking(address(0));
    }

    function test_setKDNStaking_revertsIfNotAdmin() public {
        address newStaking = address(0x123);

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.setKDNStaking(newStaking);
    }

    function test_forceCreateNewBatch() public {
        vm.prank(users.admin);
        minter.forceCreateNewBatch();

        // Should create batch ID 2 (1 was created during initialization)
        // We can't directly verify this without view functions, but no revert means success
    }

    function test_setkStrategyManager_success() public {
        address newStrategyManager = makeAddr("newStrategyManager");

        vm.expectEmit(true, true, false, false);
        emit kMinter.kStrategyManagerUpdated(address(0), newStrategyManager);

        vm.prank(users.admin);
        minter.setkStrategyManager(newStrategyManager);

        assertEq(minter.kStrategyManager(), newStrategyManager);
    }

    function test_setkStrategyManager_revertsIfZeroAddress() public {
        vm.expectRevert(kMinter.ZeroAddress.selector);
        vm.prank(users.admin);
        minter.setkStrategyManager(address(0));
    }

    function test_setkStrategyManager_revertsIfNotAdmin() public {
        address newStrategyManager = makeAddr("newStrategyManager");

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.setkStrategyManager(newStrategyManager);
    }

    function test_kStrategyManager_view() public {
        // Initially should be zero address
        assertEq(minter.kStrategyManager(), address(0));

        // Set strategy manager
        address strategyManager = makeAddr("strategyManager");
        vm.prank(users.admin);
        minter.setkStrategyManager(strategyManager);

        // Verify view function
        assertEq(minter.kStrategyManager(), strategyManager);
    }

    function test_grantEmergencyRole() public {
        vm.prank(users.admin);
        minter.grantEmergencyRole(users.bob);

        assertTrue(minter.hasAnyRole(users.bob, EMERGENCY_ADMIN_ROLE));
    }

    function test_revokeEmergencyRole() public {
        // First grant role
        vm.prank(users.admin);
        minter.grantEmergencyRole(users.bob);

        vm.prank(users.admin);
        minter.revokeEmergencyRole(users.bob);

        assertFalse(minter.hasAnyRole(users.bob, EMERGENCY_ADMIN_ROLE));
    }

    function test_grantInstitutionRole() public {
        vm.prank(users.admin);
        minter.grantInstitutionRole(users.bob);

        assertTrue(minter.hasAnyRole(users.bob, INSTITUTION_ROLE));
    }

    function test_revokeInstitutionRole() public {
        // First grant role
        vm.prank(users.admin);
        minter.grantInstitutionRole(users.bob);

        vm.prank(users.admin);
        minter.revokeInstitutionRole(users.bob);

        assertFalse(minter.hasAnyRole(users.bob, INSTITUTION_ROLE));
    }

    function test_grantSettlerRole() public {
        vm.prank(users.admin);
        minter.grantSettlerRole(users.bob);

        assertTrue(minter.hasAnyRole(users.bob, SETTLER_ROLE));
    }

    function test_revokeSettlerRole() public {
        // First grant role
        vm.prank(users.admin);
        minter.grantSettlerRole(users.bob);

        vm.prank(users.admin);
        minter.revokeSettlerRole(users.bob);

        assertFalse(minter.hasAnyRole(users.bob, SETTLER_ROLE));
    }

    function test_setPaused() public {
        vm.expectEmit(true, false, false, true);
        emit kMinter.PauseState(true);

        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);
    }

    function test_setPaused_revertsIfNotEmergencyAdmin() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.setPaused(true);
    }

    /*//////////////////////////////////////////////////////////////
                      EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_emergencyWithdraw_ERC20_success() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        // Give contract some tokens
        mintTokens(asset, address(minter), amount);

        vm.expectEmit(true, true, false, true);
        emit kMinter.EmergencyWithdrawal(asset, users.treasury, amount, users.emergencyAdmin);

        vm.prank(users.emergencyAdmin);
        minter.emergencyWithdraw(asset, users.treasury, amount);

        assertEq(MockToken(asset).balanceOf(address(minter)), 0);
        assertEq(MockToken(asset).balanceOf(users.treasury), amount);
    }

    function test_emergencyWithdraw_ETH_success() public {
        uint256 amount = 1 ether;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        // Give contract ETH
        vm.deal(address(minter), amount);

        uint256 treasuryBalanceBefore = users.treasury.balance;

        vm.expectEmit(true, true, false, true);
        emit kMinter.EmergencyWithdrawal(address(0), users.treasury, amount, users.emergencyAdmin);

        vm.prank(users.emergencyAdmin);
        minter.emergencyWithdraw(address(0), users.treasury, amount);

        assertEq(address(minter).balance, 0);
        assertEq(users.treasury.balance, treasuryBalanceBefore + amount);
    }

    function test_emergencyWithdraw_revertsIfNotPaused() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(kMinter.ContractNotPaused.selector);
        vm.prank(users.emergencyAdmin);
        minter.emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfNotEmergencyAdmin() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        minter.emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfZeroRecipient() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.expectRevert(kMinter.ZeroAddress.selector);
        vm.prank(users.emergencyAdmin);
        minter.emergencyWithdraw(asset, address(0), amount);
    }

    function test_emergencyWithdraw_revertsIfZeroAmount() public {
        // Pause contract
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.expectRevert(kMinter.ZeroAmount.selector);
        vm.prank(users.emergencyAdmin);
        minter.emergencyWithdraw(asset, users.treasury, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         CONTRACT INFO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_contractName() public {
        (string memory name,) = minterDataProvider.getContractMetadata();
        assertEq(name, "kMinter");
    }

    function test_contractVersion() public {
        (, string memory version) = minterDataProvider.getContractMetadata();
        assertEq(version, "1.0.0");
    }

    /*//////////////////////////////////////////////////////////////
                           BATCH RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getBatchReceiver() public {
        // Initially should be zero for batch 2 (batch 1 is created at initialization)
        assertEq(minterDataProvider.getBatchReceiver(2), address(0));

        // Create a redemption request to deploy batch receiver
        uint256 amount = _1000_USDC;
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        minter.requestRedeem(request);

        // Now should have batch receiver for batch 2 (the new batch created)
        address batchReceiver = minterDataProvider.getBatchReceiver(2);
        if (!(batchReceiver != address(0))) revert BatchReceiverNotDeployed();

        // Verify it's a valid kBatchReceiver
        assertEq(kBatchReceiver(batchReceiver).asset(), asset);
    }

    /*//////////////////////////////////////////////////////////////
                         RECEIVE ETH TESTS
    //////////////////////////////////////////////////////////////*/

    function test_receiveETH() public {
        uint256 amount = 1 ether;

        uint256 balanceBefore = address(minter).balance;

        // Send ETH to contract
        (bool success,) = address(minter).call{ value: amount }("");
        assertTrue(success);

        assertEq(address(minter).balance, balanceBefore + amount);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_mint(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint96).max);
        vm.assume(amount <= 1_000_000 * 1e6); // Reasonable upper limit

        // Give institution tokens and approve
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(minter), amount);

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: users.bob });

        vm.prank(users.institution);
        minter.mint(request);

        assertEq(kToken.balanceOf(users.bob), amount);
        assertEq(kToken.totalSupply(), amount);
    }

    function testFuzz_requestRedeem(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint96).max);
        vm.assume(amount <= 1_000_000 * 1e6); // Reasonable upper limit

        // Setup: mint tokens to user
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: users.bob, recipient: users.charlie });

        vm.prank(users.institution);
        bytes32 requestId = minter.requestRedeem(request);

        assertTrue(requestId != bytes32(0));
        assertEq(kToken.balanceOf(users.bob), 0);
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error BatchReceiverNotDeployed();
}
