// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, MINTER_ROLE, _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { KTOKEN_IS_PAUSED, KTOKEN_ZERO_ADDRESS, KTOKEN_ZERO_AMOUNT } from "kam/src/errors/Errors.sol";
import { kToken } from "kam/src/kToken.sol";

contract kTokenTest is DeploymentBaseTest {
    // Test constants
    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
    address internal constant TEST_ZERO_ADDRESS = address(0);

    /* //////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(kUSD.name(), KUSD_NAME, "Name incorrect");
        assertEq(kUSD.symbol(), KUSD_SYMBOL, "Symbol incorrect");
        assertEq(kUSD.decimals(), 6, "Decimals incorrect");

        assertEq(kUSD.owner(), users.owner, "Owner not set correctly");
        assertTrue(kUSD.hasAnyRole(users.admin, ADMIN_ROLE), "Admin role not granted");
        assertTrue(kUSD.hasAnyRole(users.emergencyAdmin, EMERGENCY_ADMIN_ROLE), "Emergency admin role not granted");
        assertTrue(kUSD.hasAnyRole(address(minter), MINTER_ROLE), "Minter role not granted");

        assertFalse(kUSD.isPaused(), "Should be unpaused initially");
        assertEq(kUSD.totalSupply(), 0, "Total supply should be zero initially");
    }

    /* //////////////////////////////////////////////////////////////
                        MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint_Success() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.alice;

        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit kToken.Minted(recipient, amount);

        kUSD.mint(recipient, amount);

        assertEq(kUSD.balanceOf(recipient), amount, "Balance should equal minted amount");
        assertEq(kUSD.totalSupply(), amount, "Total supply should equal minted amount");
    }

    function test_Mint_OnlyMinter() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.mint(users.alice, TEST_AMOUNT);
    }

    function test_Mint_RevertWhenPaused() public {
        // Pause token
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(address(minter));
        vm.expectRevert(bytes(KTOKEN_IS_PAUSED));
        kUSD.mint(users.alice, TEST_AMOUNT);
    }

    function test_Mint_ZeroAddress_Allowed() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit kToken.Minted(TEST_ZERO_ADDRESS, amount);

        kUSD.mint(TEST_ZERO_ADDRESS, amount);

        assertEq(kUSD.balanceOf(TEST_ZERO_ADDRESS), amount, "Zero address should have balance");
        assertEq(kUSD.totalSupply(), amount, "Total supply should include zero address mint");
    }

    /* //////////////////////////////////////////////////////////////
                        BURNING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Burn_Success() public {
        uint256 amount = TEST_AMOUNT;
        address account = users.alice;

        // First mint some tokens
        vm.prank(address(minter));
        kUSD.mint(account, amount);

        // Then burn them
        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit kToken.Burned(account, amount);

        kUSD.burn(account, amount);

        assertEq(kUSD.balanceOf(account), 0, "Balance should be zero after burn");
        assertEq(kUSD.totalSupply(), 0, "Total supply should be zero after burn");
    }

    function test_Burn_OnlyMinter() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.burn(users.alice, TEST_AMOUNT);
    }

    function test_Burn_RevertWhenPaused() public {
        // Pause token
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(address(minter));
        vm.expectRevert(bytes(KTOKEN_IS_PAUSED));
        kUSD.burn(users.alice, TEST_AMOUNT);
    }

    function test_Burn_RevertInsufficientBalance() public {
        vm.prank(address(minter));
        vm.expectRevert();
        kUSD.burn(users.alice, TEST_AMOUNT);
    }

    /* //////////////////////////////////////////////////////////////
                        BURN FROM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_BurnFrom_Success() public {
        uint256 amount = TEST_AMOUNT;
        address account = users.alice;

        vm.prank(address(minter));
        kUSD.mint(account, amount);

        vm.prank(account);
        kUSD.approve(address(minter), amount);

        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit kToken.Burned(account, amount);

        kUSD.burnFrom(account, amount);

        assertEq(kUSD.balanceOf(account), 0, "Balance should be zero after burn");
        assertEq(kUSD.allowance(account, address(minter)), 0, "Allowance should be consumed");
        assertEq(kUSD.totalSupply(), 0, "Total supply should be zero after burn");
    }

    function test_BurnFrom_OnlyMinter() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.burnFrom(users.bob, TEST_AMOUNT);
    }

    function test_BurnFrom_RevertInsufficientAllowance() public {
        uint256 amount = TEST_AMOUNT;
        address account = users.alice;

        vm.prank(address(minter));
        kUSD.mint(account, amount);

        vm.prank(address(minter));
        vm.expectRevert();
        kUSD.burnFrom(account, amount);
    }

    /* //////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AdminRole_Management() public {
        address newAdmin = users.bob;

        vm.prank(users.owner);
        kUSD.grantAdminRole(newAdmin);
        assertTrue(kUSD.hasAnyRole(newAdmin, ADMIN_ROLE), "Admin role should be granted");

        vm.prank(users.owner);
        kUSD.revokeAdminRole(newAdmin);
        assertFalse(kUSD.hasAnyRole(newAdmin, ADMIN_ROLE), "Admin role should be revoked");
    }

    function test_AdminRole_OnlyOwner() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.grantAdminRole(users.bob);

        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.revokeAdminRole(users.admin);
    }

    function test_EmergencyRole_Management() public {
        address newEmergency = users.bob;

        vm.prank(users.admin);
        kUSD.grantEmergencyRole(newEmergency);
        assertTrue(kUSD.hasAnyRole(newEmergency, EMERGENCY_ADMIN_ROLE), "Emergency role should be granted");

        vm.prank(users.admin);
        kUSD.revokeEmergencyRole(newEmergency);
        assertFalse(kUSD.hasAnyRole(newEmergency, EMERGENCY_ADMIN_ROLE), "Emergency role should be revoked");
    }

    function test_EmergencyRole_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.grantEmergencyRole(users.bob);

        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.revokeEmergencyRole(users.emergencyAdmin);
    }

    function test_MinterRole_Management() public {
        address newMinter = users.bob;

        vm.prank(users.admin);
        kUSD.grantMinterRole(newMinter);
        assertTrue(kUSD.hasAnyRole(newMinter, MINTER_ROLE), "Minter role should be granted");

        vm.prank(users.admin);
        kUSD.revokeMinterRole(newMinter);
        assertFalse(kUSD.hasAnyRole(newMinter, MINTER_ROLE), "Minter role should be revoked");
    }

    function test_MinterRole_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.grantMinterRole(users.bob);

        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.revokeMinterRole(address(minter));
    }

    /* //////////////////////////////////////////////////////////////
                        PAUSE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetPaused_Success() public {
        assertFalse(kUSD.isPaused(), "Should be unpaused initially");

        vm.prank(users.emergencyAdmin);
        vm.expectEmit(false, false, false, true);
        emit kToken.PauseState(true);

        kUSD.setPaused(true);
        assertTrue(kUSD.isPaused(), "Should be paused");

        vm.prank(users.emergencyAdmin);
        vm.expectEmit(false, false, false, true);
        emit kToken.PauseState(false);

        kUSD.setPaused(false);
        assertFalse(kUSD.isPaused(), "Should be unpaused");
    }

    function test_SetPaused_OnlyEmergencyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.setPaused(true);
    }

    function test_Transfer_RevertWhenPaused() public {
        vm.prank(address(minter));
        kUSD.mint(users.alice, TEST_AMOUNT);

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.alice);
        vm.expectRevert(bytes(KTOKEN_IS_PAUSED));
        kUSD.transfer(users.bob, TEST_AMOUNT);
    }

    /* //////////////////////////////////////////////////////////////
                    EMERGENCY WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/
    /// @dev Test emergency withdrawal of ETH
    function test_EmergencyWithdraw_ETH_Success() public {
        uint256 amount = 1 ether;

        vm.deal(address(kUSD), amount);

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        uint256 recipientBalanceBefore = users.treasury.balance;

        vm.prank(users.emergencyAdmin);
        vm.expectEmit(true, true, true, true);
        emit kToken.EmergencyWithdrawal(TEST_ZERO_ADDRESS, users.treasury, amount, users.emergencyAdmin);

        kUSD.emergencyWithdraw(TEST_ZERO_ADDRESS, users.treasury, amount);

        assertEq(users.treasury.balance - recipientBalanceBefore, amount, "ETH not withdrawn correctly");
        assertEq(address(kUSD).balance, 0, "Contract should have no ETH");
    }

    function test_EmergencyWithdraw_Token_Success() public {
        uint256 amount = TEST_AMOUNT;

        mockUSDC.mint(address(kUSD), amount);

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        uint256 recipientBalanceBefore = IERC20(tokens.usdc).balanceOf(users.treasury);

        vm.prank(users.emergencyAdmin);
        vm.expectEmit(true, true, true, true);
        emit kToken.EmergencyWithdrawal(tokens.usdc, users.treasury, amount, users.emergencyAdmin);

        kUSD.emergencyWithdraw(tokens.usdc, users.treasury, amount);

        assertEq(
            IERC20(tokens.usdc).balanceOf(users.treasury) - recipientBalanceBefore,
            amount,
            "Tokens not withdrawn correctly"
        );
        assertEq(IERC20(tokens.usdc).balanceOf(address(kUSD)), 0, "Contract should have no tokens");
    }

    function test_EmergencyWithdraw_OnlyEmergencyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.emergencyWithdraw(TEST_ZERO_ADDRESS, users.treasury, 1 ether);
    }

    function test_EmergencyWithdraw_RevertZeroAddress() public {
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.emergencyAdmin);
        vm.expectRevert(bytes(KTOKEN_ZERO_ADDRESS));
        kUSD.emergencyWithdraw(TEST_ZERO_ADDRESS, TEST_ZERO_ADDRESS, 1 ether);
    }

    function test_EmergencyWithdraw_RevertZeroAmount() public {
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.emergencyAdmin);
        vm.expectRevert(bytes(KTOKEN_ZERO_AMOUNT));
        kUSD.emergencyWithdraw(TEST_ZERO_ADDRESS, users.treasury, 0);
    }

    /* //////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test isPaused view function
    function test_IsPaused() public {
        assertFalse(kUSD.isPaused(), "Should be unpaused initially");

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        assertTrue(kUSD.isPaused(), "Should return true when paused");
    }

    /* //////////////////////////////////////////////////////////////
                        ERC20 STANDARD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Transfer_Success() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(address(minter));
        kUSD.mint(users.alice, amount);

        vm.prank(users.alice);
        bool success = kUSD.transfer(users.bob, amount);

        assertTrue(success, "Transfer should succeed");
        assertEq(kUSD.balanceOf(users.alice), 0, "Sender balance incorrect");
        assertEq(kUSD.balanceOf(users.bob), amount, "Recipient balance incorrect");
    }

    function test_TransferFrom_Success() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(address(minter));
        kUSD.mint(users.alice, amount);

        vm.prank(users.alice);
        kUSD.approve(users.bob, amount);

        vm.prank(users.bob);
        bool success = kUSD.transferFrom(users.alice, users.charlie, amount);

        assertTrue(success, "TransferFrom should succeed");
        assertEq(kUSD.balanceOf(users.alice), 0, "Sender balance incorrect");
        assertEq(kUSD.balanceOf(users.charlie), amount, "Recipient balance incorrect");
        assertEq(kUSD.allowance(users.alice, users.bob), 0, "Allowance should be consumed");
    }

    function test_Approve_Success() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(users.alice);
        bool success = kUSD.approve(users.bob, amount);

        assertTrue(success, "Approve should succeed");
        assertEq(kUSD.allowance(users.alice, users.bob), amount, "Allowance incorrect");
    }

    /* //////////////////////////////////////////////////////////////
                        RECEIVE FUNCTION TEST
    //////////////////////////////////////////////////////////////*/

    function test_ContractCanHoldETH() public {
        uint256 amount = 1 ether;

        vm.deal(address(kUSD), amount);

        assertEq(address(kUSD).balance, amount, "Contract should hold ETH");

        // Verify it can be withdrawn via emergencyWithdraw
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.emergencyAdmin);
        kUSD.emergencyWithdraw(TEST_ZERO_ADDRESS, users.treasury, amount);

        assertEq(address(kUSD).balance, 0, "ETH should be withdrawn");
    }
}
