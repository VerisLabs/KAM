// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kToken } from "../../src/kToken.sol";

import { MockToken } from "../helpers/MockToken.sol";
import { kTokenProxy } from "../helpers/kTokenProxy.sol";
import { BaseTest } from "../utils/BaseTest.sol";

import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, MINTER_ROLE, _1000_USDC, _100_USDC } from "../utils/Constants.sol";

/// @title kToken Real Contract Unit Tests
/// @notice Tests the actual kToken contract using minimal proxy pattern
contract kTokenRealTest is BaseTest {
    kToken internal token;
    kToken internal tokenImpl;
    kTokenProxy internal proxyDeployer;

    // Test constants
    string constant TOKEN_NAME = "Kintsugi USDC";
    string constant TOKEN_SYMBOL = "kUSDC";
    uint8 constant TOKEN_DECIMALS = 6;

    function setUp() public override {
        super.setUp();

        // Deploy implementation (with disabled initializers)
        tokenImpl = new kToken();

        // Deploy proxy deployer
        proxyDeployer = new kTokenProxy();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            kToken.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS,
            users.alice, // owner
            users.admin, // admin
            users.emergencyAdmin, // emergency admin
            users.institution // minter
        );

        // Deploy and initialize proxy
        address proxyAddress = proxyDeployer.deployAndInitialize(address(tokenImpl), initData);
        token = kToken(proxyAddress);

        vm.label(address(token), "kToken_Proxy");
        vm.label(address(tokenImpl), "kToken_Implementation");
        vm.label(address(proxyDeployer), "kTokenProxy");
    }

    /*//////////////////////////////////////////////////////////////
                          INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_constructor() public {
        // Implementation should have disabled initializers
        assertTrue(address(tokenImpl) != address(0));

        // Try to initialize implementation directly (should fail)
        vm.expectRevert();
        tokenImpl.initialize(
            TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, users.alice, users.admin, users.emergencyAdmin, users.institution
        );
    }

    function test_initialize_success() public {
        // Verify proxy was initialized correctly
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.decimals(), TOKEN_DECIMALS);
        assertEq(token.owner(), users.alice);
        assertTrue(token.hasAnyRole(users.admin, ADMIN_ROLE));
        assertTrue(token.hasAnyRole(users.emergencyAdmin, EMERGENCY_ADMIN_ROLE));
        assertTrue(token.hasAnyRole(users.institution, MINTER_ROLE));
        assertFalse(token.isPaused());
    }

    function test_initialize_revertsOnDoubleInit() public {
        // Try to initialize again (should fail)
        vm.expectRevert();
        token.initialize(
            TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS, users.alice, users.admin, users.emergencyAdmin, users.institution
        );
    }

    /*//////////////////////////////////////////////////////////////
                           CORE OPERATIONS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_mint_success() public {
        uint256 amount = _1000_USDC;

        vm.expectEmit(true, false, false, true);
        emit kToken.Minted(users.bob, amount);

        vm.prank(users.institution);
        token.mint(users.bob, amount);

        assertEq(token.balanceOf(users.bob), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_mint_revertsIfNotMinter() public {
        uint256 amount = _1000_USDC;

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.mint(users.bob, amount);
    }

    function test_mint_revertsIfPaused() public {
        uint256 amount = _1000_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.Paused.selector);
        vm.prank(users.institution);
        token.mint(users.bob, amount);
    }

    function test_burn_success() public {
        uint256 mintAmount = _1000_USDC;
        uint256 burnAmount = _100_USDC;

        // First mint tokens
        vm.prank(users.institution);
        token.mint(users.bob, mintAmount);

        vm.expectEmit(true, false, false, true);
        emit kToken.Burned(users.bob, burnAmount);

        vm.prank(users.institution);
        token.burn(users.bob, burnAmount);

        assertEq(token.balanceOf(users.bob), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function test_burn_revertsIfNotMinter() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.burn(users.bob, amount);
    }

    function test_burn_revertsIfPaused() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.Paused.selector);
        vm.prank(users.institution);
        token.burn(users.bob, amount);
    }

    function test_burnFrom_success() public {
        uint256 mintAmount = _1000_USDC;
        uint256 burnAmount = _100_USDC;

        // Mint tokens and approve
        vm.prank(users.institution);
        token.mint(users.bob, mintAmount);

        vm.prank(users.bob);
        token.approve(users.institution, burnAmount);

        vm.expectEmit(true, false, false, true);
        emit kToken.Burned(users.bob, burnAmount);

        vm.prank(users.institution);
        token.burnFrom(users.bob, burnAmount);

        assertEq(token.balanceOf(users.bob), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.allowance(users.bob, users.institution), 0);
    }

    function test_burnFrom_revertsIfInsufficientAllowance() public {
        uint256 mintAmount = _1000_USDC;
        uint256 burnAmount = _100_USDC;

        // Mint tokens but don't approve
        vm.prank(users.institution);
        token.mint(users.bob, mintAmount);

        vm.expectRevert(); // ERC20 insufficient allowance
        vm.prank(users.institution);
        token.burnFrom(users.bob, burnAmount);
    }

    function test_burnFrom_revertsIfNotMinter() public {
        uint256 amount = _100_USDC;

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.burnFrom(users.bob, amount);
    }

    function test_burnFrom_revertsIfPaused() public {
        uint256 mintAmount = _1000_USDC;
        uint256 burnAmount = _100_USDC;

        // Mint tokens and approve
        vm.prank(users.institution);
        token.mint(users.bob, mintAmount);

        vm.prank(users.bob);
        token.approve(users.institution, burnAmount);

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.Paused.selector);
        vm.prank(users.institution);
        token.burnFrom(users.bob, burnAmount);
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_transfer_success() public {
        uint256 amount = _1000_USDC;
        uint256 transferAmount = _100_USDC;

        // Mint tokens
        vm.prank(users.institution);
        token.mint(users.bob, amount);

        vm.prank(users.bob);
        bool success = token.transfer(users.charlie, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(users.bob), amount - transferAmount);
        assertEq(token.balanceOf(users.charlie), transferAmount);
    }

    function test_transfer_revertsIfPaused() public {
        uint256 amount = _1000_USDC;
        uint256 transferAmount = _100_USDC;

        // Mint tokens
        vm.prank(users.institution);
        token.mint(users.bob, amount);

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.Paused.selector);
        vm.prank(users.bob);
        token.transfer(users.charlie, transferAmount);
    }

    function test_transferFrom_success() public {
        uint256 amount = _1000_USDC;
        uint256 transferAmount = _100_USDC;

        // Mint tokens and approve
        vm.prank(users.institution);
        token.mint(users.bob, amount);

        vm.prank(users.bob);
        token.approve(users.alice, transferAmount);

        vm.prank(users.alice);
        bool success = token.transferFrom(users.bob, users.charlie, transferAmount);

        assertTrue(success);
        assertEq(token.balanceOf(users.bob), amount - transferAmount);
        assertEq(token.balanceOf(users.charlie), transferAmount);
        assertEq(token.allowance(users.bob, users.alice), 0);
    }

    function test_transferFrom_revertsIfPaused() public {
        uint256 amount = _1000_USDC;
        uint256 transferAmount = _100_USDC;

        // Mint tokens and approve
        vm.prank(users.institution);
        token.mint(users.bob, amount);

        vm.prank(users.bob);
        token.approve(users.alice, transferAmount);

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.Paused.selector);
        vm.prank(users.alice);
        token.transferFrom(users.bob, users.charlie, transferAmount);
    }

    /*//////////////////////////////////////////////////////////////
                         PAUSE/UNPAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_setPaused_pause() public {
        vm.expectEmit(true, false, false, true);
        emit kToken.PauseState(true);

        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        assertTrue(token.isPaused());
    }

    function test_setPaused_unpause() public {
        // First pause
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectEmit(true, false, false, true);
        emit kToken.PauseState(false);

        vm.prank(users.emergencyAdmin);
        token.setPaused(false);

        assertFalse(token.isPaused());
    }

    function test_setPaused_revertsIfNotEmergencyAdmin() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.setPaused(true);
    }

    /*//////////////////////////////////////////////////////////////
                         ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_grantAdminRole() public {
        vm.prank(users.alice); // owner
        token.grantAdminRole(users.bob);

        assertTrue(token.hasAnyRole(users.bob, ADMIN_ROLE));
    }

    function test_revokeAdminRole() public {
        // First grant role
        vm.prank(users.alice);
        token.grantAdminRole(users.bob);

        vm.prank(users.alice);
        token.revokeAdminRole(users.bob);

        assertFalse(token.hasAnyRole(users.bob, ADMIN_ROLE));
    }

    function test_grantEmergencyRole() public {
        vm.prank(users.admin);
        token.grantEmergencyRole(users.bob);

        assertTrue(token.hasAnyRole(users.bob, EMERGENCY_ADMIN_ROLE));
    }

    function test_revokeEmergencyRole() public {
        // First grant role
        vm.prank(users.admin);
        token.grantEmergencyRole(users.bob);

        vm.prank(users.admin);
        token.revokeEmergencyRole(users.bob);

        assertFalse(token.hasAnyRole(users.bob, EMERGENCY_ADMIN_ROLE));
    }

    function test_grantMinterRole() public {
        vm.prank(users.admin);
        token.grantMinterRole(users.bob);

        assertTrue(token.hasAnyRole(users.bob, MINTER_ROLE));
    }

    function test_revokeMinterRole() public {
        // First grant role
        vm.prank(users.admin);
        token.grantMinterRole(users.bob);

        vm.prank(users.admin);
        token.revokeMinterRole(users.bob);

        assertFalse(token.hasAnyRole(users.bob, MINTER_ROLE));
    }

    function test_grantAdminRole_revertsIfNotOwner() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.bob);
        token.grantAdminRole(users.charlie);
    }

    function test_grantEmergencyRole_revertsIfNotAdmin() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.grantEmergencyRole(users.bob);
    }

    function test_grantMinterRole_revertsIfNotAdmin() public {
        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.grantMinterRole(users.bob);
    }

    /*//////////////////////////////////////////////////////////////
                      EMERGENCY WITHDRAW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_emergencyWithdraw_ERC20_success() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        // Give contract some tokens
        mintTokens(asset, address(token), amount);

        vm.expectEmit(true, true, false, true);
        emit kToken.EmergencyWithdrawal(asset, users.treasury, amount, users.emergencyAdmin);

        vm.prank(users.emergencyAdmin);
        token.emergencyWithdraw(asset, users.treasury, amount);

        assertEq(MockToken(asset).balanceOf(address(token)), 0);
    }

    function test_emergencyWithdraw_ETH_success() public {
        uint256 amount = 1 ether;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        // Give contract ETH
        vm.deal(address(token), amount);

        uint256 treasuryBalanceBefore = users.treasury.balance;

        vm.expectEmit(true, true, false, true);
        emit kToken.EmergencyWithdrawal(address(0), users.treasury, amount, users.emergencyAdmin);

        vm.prank(users.emergencyAdmin);
        token.emergencyWithdraw(address(0), users.treasury, amount);

        assertEq(address(token).balance, 0);
        assertEq(users.treasury.balance, treasuryBalanceBefore + amount);
    }

    function test_emergencyWithdraw_revertsIfNotPaused() public {
        uint256 amount = _100_USDC;

        vm.expectRevert("Contract not paused");
        vm.prank(users.emergencyAdmin);
        token.emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfNotEmergencyAdmin() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(); // OwnableRoles revert
        vm.prank(users.alice);
        token.emergencyWithdraw(asset, users.treasury, amount);
    }

    function test_emergencyWithdraw_revertsIfZeroRecipient() public {
        uint256 amount = _100_USDC;

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.ZeroAddress.selector);
        vm.prank(users.emergencyAdmin);
        token.emergencyWithdraw(asset, address(0), amount);
    }

    function test_emergencyWithdraw_revertsIfZeroAmount() public {
        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        vm.expectRevert(kToken.ZeroAmount.selector);
        vm.prank(users.emergencyAdmin);
        token.emergencyWithdraw(asset, users.treasury, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_name() public {
        assertEq(token.name(), TOKEN_NAME);
    }

    function test_symbol() public {
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    function test_decimals() public {
        assertEq(token.decimals(), TOKEN_DECIMALS);
    }

    function test_isPaused() public {
        assertFalse(token.isPaused());

        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        assertTrue(token.isPaused());
    }

    function test_contractName() public {
        assertEq(token.contractName(), "kToken");
    }

    function test_contractVersion() public {
        assertEq(token.contractVersion(), "1.0.0");
    }

    /*//////////////////////////////////////////////////////////////
                           UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_authorizeUpgrade_success() public {
        kToken newImpl = new kToken();

        // Deploy new proxy with new implementation
        bytes memory initData = abi.encodeWithSelector(
            kToken.initialize.selector,
            "New Token",
            "NEW",
            18,
            users.alice,
            users.admin,
            users.emergencyAdmin,
            users.institution
        );

        address newProxy = proxyDeployer.deployAndInitialize(address(newImpl), initData);
        assertTrue(newProxy != address(0));

        // Verify new implementation works
        kToken newToken = kToken(newProxy);
        assertEq(newToken.name(), "New Token");
        assertEq(newToken.symbol(), "NEW");
        assertEq(newToken.decimals(), 18);
    }

    /*//////////////////////////////////////////////////////////////
                           ADVANCED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_beforeTokenTransfer_enforcement() public {
        uint256 amount = _1000_USDC;

        // Mint tokens
        vm.prank(users.institution);
        token.mint(users.bob, amount);

        // Pause contract
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);

        // All transfer operations should revert when paused
        vm.prank(users.bob);
        vm.expectRevert(kToken.Paused.selector);
        token.transfer(users.alice, _100_USDC);

        vm.prank(users.bob);
        token.approve(users.alice, _100_USDC);

        vm.prank(users.alice);
        vm.expectRevert(kToken.Paused.selector);
        token.transferFrom(users.bob, users.charlie, _100_USDC);
    }

    function test_storage_layout() public {
        // Test that storage layout is correct by verifying state persistence
        uint256 amount = _1000_USDC;

        vm.prank(users.institution);
        token.mint(users.bob, amount);

        // Pause and unpause
        vm.prank(users.emergencyAdmin);
        token.setPaused(true);
        assertTrue(token.isPaused());

        vm.prank(users.emergencyAdmin);
        token.setPaused(false);
        assertFalse(token.isPaused());

        // Verify balance persisted through pause/unpause
        assertEq(token.balanceOf(users.bob), amount);
        assertEq(token.totalSupply(), amount);
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_mint(address to, uint256 amount) public {
        vm.assume(to != address(0) && to.code.length == 0);
        vm.assume(amount > 0 && amount <= type(uint96).max);

        vm.prank(users.institution);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testFuzz_burn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint96).max);
        vm.assume(burnAmount <= mintAmount);

        // First mint
        vm.prank(users.institution);
        token.mint(users.bob, mintAmount);

        // Then burn
        vm.prank(users.institution);
        token.burn(users.bob, burnAmount);

        assertEq(token.balanceOf(users.bob), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
    }

    function testFuzz_transfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint96).max);
        vm.assume(transferAmount <= mintAmount);

        // First mint
        vm.prank(users.institution);
        token.mint(users.bob, mintAmount);

        // Then transfer
        vm.prank(users.bob);
        token.transfer(users.charlie, transferAmount);

        assertEq(token.balanceOf(users.bob), mintAmount - transferAmount);
        assertEq(token.balanceOf(users.charlie), transferAmount);
    }
}
