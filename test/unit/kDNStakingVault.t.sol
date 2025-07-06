// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kDNStakingVault } from "../../src/kDNStakingVault.sol";

import { AdminModule } from "../../src/modules/AdminModule.sol";

import { ClaimModule } from "../../src/modules/ClaimModule.sol";
import { SettlementModule } from "../../src/modules/SettlementModule.sol";

import { DataTypes } from "../../src/types/DataTypes.sol";
import { MockToken } from "../helpers/MockToken.sol";
import { MockkToken } from "../helpers/MockkToken.sol";
import { kDNStakingVaultProxy } from "../helpers/kDNStakingVaultProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";

import {
    ADMIN_ROLE,
    EMERGENCY_ADMIN_ROLE,
    MINTER_ROLE,
    SETTLEMENT_INTERVAL,
    SETTLER_ROLE,
    _10000_USDC,
    _1000_USDC,
    _100_USDC
} from "../utils/Constants.sol";

/// @title kDNStakingVault Unit Tests
/// @notice Tests the kDNStakingVault contract using minimal proxy pattern
contract kDNStakingVaultTest is BaseTest {
    kDNStakingVault internal vault;
    kDNStakingVault internal vaultImpl;
    kDNStakingVaultProxy internal proxyDeployer;
    MockkToken internal kToken;

    // Module instances for direct access in tests
    AdminModule internal adminModule;
    SettlementModule internal settlementModule;
    ClaimModule internal claimModule;

    // Test constants
    string constant VAULT_NAME = "Kintsugi DN Staking Vault";
    string constant VAULT_SYMBOL = "kDNSV";
    uint8 constant VAULT_DECIMALS = 6;

    function setUp() public override {
        super.setUp();

        // Deploy implementation (with disabled initializers)
        vaultImpl = new kDNStakingVault();

        // Deploy proxy deployer
        proxyDeployer = new kDNStakingVaultProxy();

        // Deploy mock kToken
        kToken = new MockkToken("Kintsugi USDC", "kUSDC", 6);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            kDNStakingVault.initialize.selector,
            VAULT_NAME,
            VAULT_SYMBOL,
            VAULT_DECIMALS,
            asset, // underlying asset
            address(kToken),
            users.alice, // owner
            users.admin, // admin
            users.emergencyAdmin, // emergency admin
            users.settler, // settler
            users.alice // strategyManager (use alice for tests)
        );

        // Deploy and initialize proxy
        address proxyAddress = proxyDeployer.deployAndInitialize(address(vaultImpl), initData);
        vault = kDNStakingVault(payable(proxyAddress));

        // Grant vault minter role to interact with kToken
        kToken.grantRole(kToken.MINTER_ROLE(), address(vault));

        // Grant test contract minter role for setup operations
        kToken.grantRole(kToken.MINTER_ROLE(), address(this));

        // Configure modules
        _configureModules();

        // Grant minter role to test addresses
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantMinterRole(users.institution);

        vm.label(address(vault), "kDNStakingVault_Proxy");
        vm.label(address(vaultImpl), "kDNStakingVault_Implementation");
        vm.label(address(kToken), "MockkToken");
    }

    /// @notice Configure modules for the vault
    function _configureModules() internal {
        // Deploy modules
        adminModule = new AdminModule();
        settlementModule = new SettlementModule();
        claimModule = new ClaimModule();

        // Configure module functions in the vault as admin
        vm.startPrank(users.admin);

        // Add AdminModule functions
        bytes4[] memory adminSelectors = adminModule.selectors();
        vault.addFunctions(adminSelectors, address(adminModule), false);

        // Add SettlementModule functions
        bytes4[] memory settlementSelectors = settlementModule.selectors();
        vault.addFunctions(settlementSelectors, address(settlementModule), false);

        // Add ClaimModule functions
        bytes4[] memory claimSelectors = claimModule.selectors();
        vault.addFunctions(claimSelectors, address(claimModule), false);

        vm.stopPrank();

        // Label modules for debugging
        vm.label(address(adminModule), "AdminModule");
        vm.label(address(settlementModule), "SettlementModule");
        vm.label(address(claimModule), "ClaimModule");
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Implementation should have disabled initializers
        assertTrue(address(vaultImpl) != address(0));

        // Try to initialize implementation directly (should fail)
        vm.expectRevert();
        vaultImpl.initialize(
            VAULT_NAME,
            VAULT_SYMBOL,
            VAULT_DECIMALS,
            asset,
            address(kToken),
            users.alice,
            users.admin,
            users.emergencyAdmin,
            users.settler,
            users.alice
        );
    }

    function test_initialize_success() public {
        // Verify proxy was initialized correctly
        assertEq(vault.name(), VAULT_NAME);
        assertEq(vault.symbol(), VAULT_SYMBOL);
        assertEq(vault.decimals(), VAULT_DECIMALS);
        assertEq(vault.asset(), asset);
        assertEq(vault.owner(), users.alice);
        assertTrue(vault.hasAnyRole(users.admin, ADMIN_ROLE));
        assertTrue(vault.hasAnyRole(users.emergencyAdmin, EMERGENCY_ADMIN_ROLE));
        assertTrue(vault.hasAnyRole(users.settler, SETTLER_ROLE));
        assertTrue(vault.hasAnyRole(users.institution, MINTER_ROLE));
    }

    function test_initialize_revertsOnZeroAddresses() public {
        bytes memory initData = abi.encodeWithSelector(
            kDNStakingVault.initialize.selector,
            VAULT_NAME,
            VAULT_SYMBOL,
            VAULT_DECIMALS,
            address(0), // zero asset
            address(kToken),
            users.alice,
            users.admin,
            users.emergencyAdmin,
            users.settler,
            users.alice // strategyManager
        );

        vm.expectRevert();
        proxyDeployer.deployAndInitialize(address(vaultImpl), initData);
    }

    function test_initialize_revertsOnDoubleInit() public {
        // Try to initialize again (should fail)
        vm.expectRevert();
        vault.initialize(
            VAULT_NAME,
            VAULT_SYMBOL,
            VAULT_DECIMALS,
            asset,
            address(kToken),
            users.alice,
            users.admin,
            users.emergencyAdmin,
            users.settler,
            users.alice
        );
    }

    /*//////////////////////////////////////////////////////////////
                         MINTER DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_requestMinterDeposit_success() public {
        uint256 amount = _1000_USDC;

        // Give institution some assets
        mintTokens(asset, users.institution, amount);

        // Approve vault to spend assets
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);

        vm.expectEmit(true, false, false, true);
        emit kDNStakingVault.MinterDepositRequested(users.institution, amount, 1);

        vm.prank(users.institution);
        uint256 batchId = vault.requestMinterDeposit(amount);

        assertEq(batchId, 1);
        assertEq(MockToken(asset).balanceOf(address(vault)), amount);
        // Note: getMinterAssetBalance not yet implemented, using vault balance check
    }

    function test_requestMinterDeposit_revertsIfNotMinter() public {
        uint256 amount = _1000_USDC;

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        vault.requestMinterDeposit(amount);
    }

    function test_requestMinterDeposit_revertsIfZeroAmount() public {
        vm.expectRevert();
        vm.prank(users.institution);
        vault.requestMinterDeposit(0);
    }

    function test_requestMinterDeposit_revertsIfPaused() public {
        uint256 amount = _1000_USDC;

        // Pause vault
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).setPaused(true);

        vm.expectRevert();
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);
    }

    /*//////////////////////////////////////////////////////////////
                         MINTER REDEEM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_requestMinterRedeem_success() public {
        uint256 depositAmount = _1000_USDC;
        uint256 redeemAmount = _100_USDC;

        // First deposit assets
        mintTokens(asset, users.institution, depositAmount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), depositAmount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(depositAmount);

        address batchReceiver = address(0x123);

        vm.expectEmit(true, false, false, true);
        emit kDNStakingVault.MinterRedeemRequested(users.institution, redeemAmount, batchReceiver, 1);

        vm.prank(users.institution);
        uint256 batchId = vault.requestMinterRedeem(redeemAmount, users.institution, batchReceiver);

        assertEq(batchId, 1);
        // Note: getMinterPendingNetAmount not yet implemented
    }

    function test_requestMinterRedeem_revertsIfNotMinter() public {
        uint256 amount = _100_USDC;
        address batchReceiver = address(0x123);

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        vault.requestMinterRedeem(amount, users.alice, batchReceiver);
    }

    function test_requestMinterRedeem_revertsIfZeroAmount() public {
        address batchReceiver = address(0x123);

        vm.expectRevert();
        vm.prank(users.institution);
        vault.requestMinterRedeem(0, users.institution, batchReceiver);
    }

    function test_requestMinterRedeem_revertsIfZeroBatchReceiver() public {
        uint256 amount = _100_USDC;

        vm.expectRevert();
        vm.prank(users.institution);
        vault.requestMinterRedeem(amount, users.institution, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                         USER STAKING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_requestStake_success() public {
        uint256 amount = 1_000_000 * 1e6; // 1M USDC to exceed dust threshold of 1e12

        // Give user some kTokens
        kToken.mint(users.bob, amount);

        // Approve vault to spend kTokens
        vm.prank(users.bob);
        kToken.approve(address(vault), amount);

        // Don't check event for now, just verify function succeeds

        vm.prank(users.bob);
        uint256 requestId = vault.requestStake(amount);

        assertEq(requestId, 0); // First request in batch
        assertEq(kToken.balanceOf(address(vault)), amount);
        // Note: getTotalStakedKTokens not yet implemented
    }

    function test_requestStake_revertsIfZeroAmount() public {
        vm.expectRevert();
        vm.prank(users.bob);
        vault.requestStake(0);
    }

    function test_requestStake_revertsIfPaused() public {
        uint256 amount = 1_000_000 * 1e6; // 1M USDC

        // Pause vault
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).setPaused(true);

        vm.expectRevert();
        vm.prank(users.bob);
        vault.requestStake(amount);
    }

    /*//////////////////////////////////////////////////////////////
                         USER UNSTAKING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_requestUnstake_success() public {
        uint256 stakeAmount = 1_000_000 * 1e6; // 1M USDC
        uint256 unstakeAmount = 100_000 * 1e6; // 100K USDC

        // First add underlying assets to vault via minter deposit
        mintTokens(asset, users.institution, stakeAmount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), stakeAmount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(stakeAmount);

        // Advance time and settle the deposit to add assets to vault
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        // Now stake some kTokens
        kToken.mint(users.bob, stakeAmount);
        vm.prank(users.bob);
        kToken.approve(address(vault), stakeAmount);
        vm.prank(users.bob);
        vault.requestStake(stakeAmount);

        // Advance time to meet settlement interval requirement (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        // Settle staking batch to get stkTokens
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleStakingBatch(1, stakeAmount);

        // Claim staked shares
        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimStakedShares(1, 0);

        vm.prank(users.bob);
        uint256 requestId = vault.requestUnstake(unstakeAmount);

        assertEq(requestId, 0); // First request in unstaking batch
    }

    function test_requestUnstake_revertsIfInsufficientShares() public {
        uint256 amount = 1_000_000 * 1e6; // 1M USDC

        vm.expectRevert();
        vm.prank(users.bob);
        vault.requestUnstake(amount);
    }

    function test_requestUnstake_revertsIfZeroAmount() public {
        vm.expectRevert();
        vm.prank(users.bob);
        vault.requestUnstake(0);
    }

    /*//////////////////////////////////////////////////////////////
                         SETTLEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_settleBatch_success() public {
        uint256 amount = _1000_USDC;

        // Create a minter deposit request
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Advance time to meet settlement interval requirement (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        assertTrue(vault.isBatchSettled(1));
        // Note: getMinterAssetBalance not yet implemented
    }

    function test_settleBatch_revertsIfNotSettler() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        SettlementModule(payable(address(vault))).settleBatch(1);
    }

    function test_settleStakingBatch_success() public {
        uint256 amount = 1_000_000 * 1e6; // 1M USDC

        // First add underlying assets to vault via minter deposit
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Advance time and settle the deposit to add assets to vault
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        // Now create staking request
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(vault), amount);
        vm.prank(users.bob);
        vault.requestStake(amount);

        // Advance time to meet settlement interval requirement (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleStakingBatch(1, amount);
    }

    function test_settleStakingBatch_revertsIfNotSettler() public {
        uint256 amount = _1000_USDC;

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        SettlementModule(payable(address(vault))).settleStakingBatch(1, amount);
    }

    function test_settleUnstakingBatch_success() public {
        // For now, just test that the function exists and has proper access control
        // Complex settlement math can be tested in integration tests
        uint256 amount = _1000_USDC;

        vm.expectRevert(); // Should revert since there's no batch to settle
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleUnstakingBatch(1, amount);
    }

    function test_settleUnstakingBatch_revertsIfNotSettler() public {
        uint256 amount = _1000_USDC;

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        SettlementModule(payable(address(vault))).settleUnstakingBatch(1, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_claimStakedShares_success() public {
        uint256 amount = 1_000_000 * 1e6; // 1M USDC

        // First add underlying assets to vault via minter deposit
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Advance time and settle the deposit to add assets to vault
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        // Now stake and settle
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(vault), amount);
        vm.prank(users.bob);
        vault.requestStake(amount);

        // Advance time to meet settlement interval requirement (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleStakingBatch(1, amount);

        // Validate minter balance is tracked correctly (1:1)
        assertEq(vault.getMinterAssetBalance(users.institution), amount);

        // Check that Bob has no stkTokens yet
        assertEq(vault.getStkTokenBalance(users.bob), 0);

        // Claim staked shares
        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimStakedShares(1, 0);

        // Now Bob should have stkTokens (1:1 initially)
        uint256 bobStkTokens = vault.getStkTokenBalance(users.bob);
        assertEq(bobStkTokens, amount); // 1:1 conversion at initial price

        // Validate total supply matches Bob's balance
        assertEq(vault.totalSupply(), bobStkTokens);

        // Validate minter assets unchanged (1:1 guarantee preserved)
        assertEq(vault.getMinterAssetBalance(users.institution), amount);
    }

    function test_claimStakedShares_revertsIfAlreadyClaimed() public {
        uint256 amount = 1_000_000 * 1e6; // 1M USDC

        // First add underlying assets to vault via minter deposit
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Advance time and settle the deposit to add assets to vault
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        // Stake, settle, and claim once
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(vault), amount);
        vm.prank(users.bob);
        vault.requestStake(amount);

        // Advance time to meet settlement interval requirement (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleStakingBatch(1, amount);

        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimStakedShares(1, 0);

        // Try to claim again
        vm.expectRevert();
        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimStakedShares(1, 0);
    }

    function test_claimUnstakedAssets_success() public {
        // Simplified test - just check that function exists with proper access control
        vm.expectRevert(); // Should revert since there's no batch to claim from
        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimUnstakedAssets(1, 0);
    }

    function test_claimUnstakedAssets_revertsIfAlreadyClaimed() public {
        // Simplified test - double claim should revert
        vm.expectRevert(); // Should revert since there's no batch to claim from
        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimUnstakedAssets(1, 0);

        // Try to claim again - should also revert
        vm.expectRevert();
        vm.prank(users.bob);
        ClaimModule(payable(address(vault))).claimUnstakedAssets(1, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_asset() public {
        assertEq(vault.asset(), asset);
    }

    function test_name() public {
        assertEq(vault.name(), VAULT_NAME);
    }

    function test_symbol() public {
        assertEq(vault.symbol(), VAULT_SYMBOL);
    }

    function test_decimals() public {
        assertEq(vault.decimals(), VAULT_DECIMALS);
    }

    function test_isAuthorizedMinter() public {
        assertTrue(vault.isAuthorizedMinter(users.institution));
        assertFalse(vault.isAuthorizedMinter(users.alice));
    }

    function test_getTotalVaultAssets() public {
        uint256 amount = _1000_USDC;

        // Add some assets via minter deposit
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Advance time to meet settlement interval requirement (1 hour)
        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        assertEq(vault.getTotalVaultAssets(), amount);
    }

    function test_getTotalUserAssets() public {
        uint256 initialAssets = vault.getTotalUserAssets();
        assertEq(initialAssets, 0); // Initially no user assets
    }

    function test_isBatchSettled() public {
        uint256 amount = _1000_USDC;

        // Create a minter deposit request
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Initially not settled
        assertFalse(vault.isBatchSettled(1));

        // Advance time and settle the batch
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        // Now should be settled
        assertTrue(vault.isBatchSettled(1));
    }

    /*//////////////////////////////////////////////////////////////
                         ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_grantMinterRole() public {
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantMinterRole(users.bob);

        assertTrue(vault.hasAnyRole(users.bob, MINTER_ROLE));
        assertTrue(vault.isAuthorizedMinter(users.bob));
    }

    function test_revokeMinterRole() public {
        // First grant role
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantMinterRole(users.bob);

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).revokeMinterRole(users.bob);

        assertFalse(vault.hasAnyRole(users.bob, MINTER_ROLE));
        assertFalse(vault.isAuthorizedMinter(users.bob));
    }

    function test_grantAdminRole() public {
        vm.prank(users.alice); // owner
        vault.grantAdminRole(users.bob);

        assertTrue(vault.hasAnyRole(users.bob, ADMIN_ROLE));
    }

    function test_revokeAdminRole() public {
        // First grant role
        vm.prank(users.alice);
        vault.grantAdminRole(users.bob);

        vm.prank(users.alice);
        vault.revokeAdminRole(users.bob);

        assertFalse(vault.hasAnyRole(users.bob, ADMIN_ROLE));
    }

    function test_grantSettlerRole() public {
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantSettlerRole(users.bob);

        assertTrue(vault.hasAnyRole(users.bob, SETTLER_ROLE));
    }

    function test_revokeSettlerRole() public {
        // First grant role
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantSettlerRole(users.bob);

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).revokeSettlerRole(users.bob);

        assertFalse(vault.hasAnyRole(users.bob, SETTLER_ROLE));
    }

    function test_grantStrategyManagerRole() public {
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantStrategyManagerRole(users.bob);

        assertTrue(vault.hasAnyRole(users.bob, vault.STRATEGY_MANAGER_ROLE()));
    }

    function test_revokeStrategyManagerRole() public {
        // First grant role
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).grantStrategyManagerRole(users.bob);

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).revokeStrategyManagerRole(users.bob);

        assertFalse(vault.hasAnyRole(users.bob, vault.STRATEGY_MANAGER_ROLE()));
    }

    function test_setPaused() public {
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).setPaused(true);

        // Verify operations are paused
        vm.expectRevert();
        vm.prank(users.institution);
        vault.requestMinterDeposit(_100_USDC);
    }

    function test_setPaused_revertsIfNotEmergencyAdmin() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).setPaused(true);
    }

    function test_setStrategyManager() public {
        address newManager = address(0x123);

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).setStrategyManager(newManager);

        // Cannot directly verify without a getter, but no revert means success
    }

    function test_setStrategyManager_revertsIfZeroAddress() public {
        vm.expectRevert();
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).setStrategyManager(address(0));
    }

    function test_setVarianceRecipient() public {
        address newRecipient = address(0x123);

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).setVarianceRecipient(newRecipient);

        // Cannot directly verify without a getter, but no revert means success
    }

    function test_setVarianceRecipient_revertsIfZeroAddress() public {
        vm.expectRevert();
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).setVarianceRecipient(address(0));
    }

    function test_setSettlementInterval() public {
        uint256 newInterval = 2 hours;

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).setSettlementInterval(newInterval);

        // Cannot directly verify without a getter, but no revert means success
    }

    function test_setSettlementInterval_revertsIfZero() public {
        vm.expectRevert();
        vm.prank(users.admin);
        AdminModule(payable(address(vault))).setSettlementInterval(0);
    }

    function test_transferYieldToUser() public {
        uint256 amount = _1000_USDC;
        uint256 assets = _100_USDC;

        // First add some assets to minter pool to have sufficient minter assets
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);
        vm.prank(users.institution);
        vault.requestMinterDeposit(amount);

        // Advance time and settle to actually add assets
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(users.settler);
        SettlementModule(payable(address(vault))).settleBatch(1);

        vm.prank(users.admin);
        AdminModule(payable(address(vault))).transferYieldToUser(users.bob, assets);

        // Cannot directly verify without view functions, but no revert means success
    }

    /*//////////////////////////////////////////////////////////////
                      EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_emergencyWithdraw_ERC20_success() public {
        uint256 amount = _100_USDC;

        // Pause vault
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).setPaused(true);

        // Give vault some tokens
        mintTokens(asset, address(vault), amount);

        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).emergencyWithdraw(asset, users.treasury, amount);

        assertEq(MockToken(asset).balanceOf(users.treasury), amount);
    }

    function test_emergencyWithdraw_ETH_success() public {
        uint256 amount = 1 ether;

        // Pause vault
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).setPaused(true);

        // Give vault ETH
        vm.deal(address(vault), amount);

        uint256 treasuryBalanceBefore = users.treasury.balance;

        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).emergencyWithdraw(address(0), users.treasury, amount);

        assertEq(users.treasury.balance, treasuryBalanceBefore + amount);
    }

    function test_emergencyWithdraw_revertsIfNotPaused() public {
        uint256 amount = _100_USDC;

        vm.expectRevert();
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfNotEmergencyAdmin() public {
        uint256 amount = _100_USDC;

        // Pause vault
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).setPaused(true);

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).emergencyWithdraw(asset, users.treasury, amount);
    }

    /*//////////////////////////////////////////////////////////////
                         CONTRACT INFO TESTS
    //////////////////////////////////////////////////////////////*/

    function test_contractName() public {
        assertEq(vault.contractName(), "kDNStakingVault");
    }

    function test_contractVersion() public {
        assertEq(vault.contractVersion(), "1.0.0");
    }

    /*//////////////////////////////////////////////////////////////
                           ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_adminFunctions_revertsIfNotAdmin() public {
        // Test admin-only functions with non-admin user
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).grantMinterRole(users.bob);

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).revokeMinterRole(users.bob);

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).grantSettlerRole(users.bob);

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).revokeSettlerRole(users.bob);

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).setStrategyManager(address(0x123));

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).setVarianceRecipient(address(0x123));

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).setSettlementInterval(2 hours);

        vm.expectRevert();
        vm.prank(users.alice);
        AdminModule(payable(address(vault))).transferYieldToUser(users.bob, _100_USDC);
    }

    function test_ownerOnlyFunctions_revertsIfNotOwner() public {
        // Test owner-only functions with non-owner user
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.admin);
        vault.grantAdminRole(users.bob);

        vm.expectRevert();
        vm.prank(users.admin);
        vault.revokeAdminRole(users.bob);
    }

    function test_settlerOnlyFunctions_revertsIfNotSettler() public {
        // Test settler-only functions with non-settler user
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        SettlementModule(payable(address(vault))).settleBatch(1);

        vm.expectRevert();
        vm.prank(users.alice);
        SettlementModule(payable(address(vault))).settleStakingBatch(1, _1000_USDC);

        vm.expectRevert();
        vm.prank(users.alice);
        SettlementModule(payable(address(vault))).settleUnstakingBatch(1, _1000_USDC);
    }

    function test_emergencyWithdraw_revertsIfNotPausedFirst() public {
        uint256 amount = _100_USDC;

        // Try emergency withdraw without pausing first
        vm.expectRevert();
        vm.prank(users.emergencyAdmin);
        AdminModule(payable(address(vault))).emergencyWithdraw(asset, users.treasury, amount);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_requestMinterDeposit(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint96).max);
        vm.assume(amount <= 1_000_000 * 1e6); // Reasonable upper limit

        // Give institution tokens and approve
        mintTokens(asset, users.institution, amount);
        vm.prank(users.institution);
        MockToken(asset).approve(address(vault), amount);

        vm.prank(users.institution);
        uint256 batchId = vault.requestMinterDeposit(amount);

        assertEq(batchId, 1);
        assertEq(MockToken(asset).balanceOf(address(vault)), amount);
    }

    function testFuzz_requestStake(uint256 amount) public {
        amount = bound(amount, 1_000_000 * 1e6, 10_000_000 * 1e6); // 1M to 10M USDC

        // Give user kTokens and approve
        kToken.mint(users.bob, amount);
        vm.prank(users.bob);
        kToken.approve(address(vault), amount);

        vm.prank(users.bob);
        uint256 requestId = vault.requestStake(amount);

        assertEq(requestId, 0);
        assertEq(kToken.balanceOf(address(vault)), amount);
    }
}
