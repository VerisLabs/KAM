// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    ADMIN_ROLE,
    EMERGENCY_ADMIN_ROLE,
    MINTER_ROLE,
    USDC_MAINNET,
    _1000_USDC,
    _100_USDC,
    _1_USDC
} from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { IkToken } from "src/interfaces/IkToken.sol";
import { kToken } from "src/kToken.sol";

/// @title kTokenTest
/// @notice Comprehensive unit tests for kToken contract
contract kTokenTest is DeploymentBaseTest {
    using LibClone for address;

    // Test constants
    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
    address internal constant ZERO_ADDRESS = address(0);

    // Events to test
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event UpgradeAuthorized(address indexed newImplementation, address indexed sender);
    event TokenInitialized(string name, string symbol, uint8 decimals);
    event PauseState(bool isPaused);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test contract initialization state
    function test_InitialState() public view {
        // Check basic properties
        assertEq(kUSD.name(), KUSD_NAME, "Name incorrect");
        assertEq(kUSD.symbol(), KUSD_SYMBOL, "Symbol incorrect");
        assertEq(kUSD.decimals(), 6, "Decimals incorrect");

        // Check role assignments
        assertEq(kUSD.owner(), users.owner, "Owner not set correctly");
        assertTrue(kUSD.hasAnyRole(users.admin, ADMIN_ROLE), "Admin role not granted");
        assertTrue(kUSD.hasAnyRole(users.emergencyAdmin, EMERGENCY_ADMIN_ROLE), "Emergency admin role not granted");
        assertTrue(kUSD.hasAnyRole(address(minter), MINTER_ROLE), "Minter role not granted");

        // Check initial state
        assertFalse(kUSD.isPaused(), "Should be unpaused initially");
        assertEq(kUSD.totalSupply(), 0, "Total supply should be zero initially");
    }

    /// @dev Test successful initialization with valid parameters
    function test_Initialize_Success() public {
        // Deploy fresh implementation for testing
        kToken newTokenImpl = new kToken();

        bytes memory initData = abi.encodeWithSelector(
            kToken.initialize.selector,
            users.owner,
            users.admin,
            users.emergencyAdmin,
            users.admin, // temporary minter
            6 // decimals
        );

        address newProxy = address(newTokenImpl).clone();
        (bool success,) = newProxy.call(initData);

        assertTrue(success, "Initialization should succeed");

        kToken newToken = kToken(payable(newProxy));
        assertEq(newToken.owner(), users.owner, "Owner not set");
        assertTrue(newToken.hasAnyRole(users.admin, ADMIN_ROLE), "Admin role not granted");
        assertEq(newToken.decimals(), 6, "Decimals not set");
    }

    /// @dev Test initialization reverts with zero addresses
    function test_Initialize_RevertZeroAddresses() public {
        kToken newTokenImpl = new kToken();

        // Test zero owner
        bytes memory initData = abi.encodeWithSelector(
            kToken.initialize.selector,
            ZERO_ADDRESS, // zero owner
            users.admin,
            users.emergencyAdmin,
            users.admin,
            6
        );

        address newProxy = address(newTokenImpl).clone();
        (bool success,) = newProxy.call(initData);
        assertFalse(success, "Should revert with zero owner");

        // Test zero admin
        initData = abi.encodeWithSelector(
            kToken.initialize.selector,
            users.owner,
            ZERO_ADDRESS, // zero admin
            users.emergencyAdmin,
            users.admin,
            6
        );

        newProxy = address(newTokenImpl).clone();
        (success,) = newProxy.call(initData);
        assertFalse(success, "Should revert with zero admin");
    }

    /// @dev Test double initialization reverts
    function test_Initialize_RevertDoubleInit() public {
        vm.expectRevert();
        kUSD.initialize(users.owner, users.admin, users.emergencyAdmin, users.admin, 6);
    }

    /// @dev Test setupMetadata function
    function test_SetupMetadata_Success() public {
        // Deploy new token without metadata
        kToken newTokenImpl = new kToken();
        bytes memory initData = abi.encodeWithSelector(
            kToken.initialize.selector, users.owner, users.admin, users.emergencyAdmin, users.admin, 6
        );

        address newProxy = address(newTokenImpl).clone();
        (bool success,) = newProxy.call(initData);
        require(success, "Init failed");

        kToken newToken = kToken(payable(newProxy));

        // Setup metadata
        vm.prank(users.admin);
        vm.expectEmit(false, false, false, true);
        emit TokenInitialized("Test Token", "TEST", 6);

        newToken.setupMetadata("Test Token", "TEST");

        assertEq(newToken.name(), "Test Token", "Name not set");
        assertEq(newToken.symbol(), "TEST", "Symbol not set");
    }

    /// @dev Test setupMetadata requires admin role
    function test_SetupMetadata_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.setupMetadata("New Name", "NEW");
    }

    /*//////////////////////////////////////////////////////////////
                        MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful minting
    function test_Mint_Success() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.alice;

        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit Minted(recipient, amount);

        kUSD.mint(recipient, amount);

        assertEq(kUSD.balanceOf(recipient), amount, "Balance should equal minted amount");
        assertEq(kUSD.totalSupply(), amount, "Total supply should equal minted amount");
    }

    /// @dev Test mint requires minter role
    function test_Mint_OnlyMinter() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.mint(users.alice, TEST_AMOUNT);
    }

    /// @dev Test mint reverts when paused
    function test_Mint_RevertWhenPaused() public {
        // Pause token
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(address(minter));
        vm.expectRevert(IkToken.Paused.selector);
        kUSD.mint(users.alice, TEST_AMOUNT);
    }

    /// @dev Test minting to zero address succeeds (Solady ERC20 allows it)
    function test_Mint_ZeroAddress_Allowed() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit Minted(ZERO_ADDRESS, amount);

        kUSD.mint(ZERO_ADDRESS, amount);

        assertEq(kUSD.balanceOf(ZERO_ADDRESS), amount, "Zero address should have balance");
        assertEq(kUSD.totalSupply(), amount, "Total supply should include zero address mint");
    }

    /*//////////////////////////////////////////////////////////////
                        BURNING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful burning
    function test_Burn_Success() public {
        uint256 amount = TEST_AMOUNT;
        address account = users.alice;

        // First mint some tokens
        vm.prank(address(minter));
        kUSD.mint(account, amount);

        // Then burn them
        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit Burned(account, amount);

        kUSD.burn(account, amount);

        assertEq(kUSD.balanceOf(account), 0, "Balance should be zero after burn");
        assertEq(kUSD.totalSupply(), 0, "Total supply should be zero after burn");
    }

    /// @dev Test burn requires minter role
    function test_Burn_OnlyMinter() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.burn(users.alice, TEST_AMOUNT);
    }

    /// @dev Test burn reverts when paused
    function test_Burn_RevertWhenPaused() public {
        // Pause token
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(address(minter));
        vm.expectRevert(IkToken.Paused.selector);
        kUSD.burn(users.alice, TEST_AMOUNT);
    }

    /// @dev Test burn reverts with insufficient balance
    function test_Burn_RevertInsufficientBalance() public {
        vm.prank(address(minter));
        vm.expectRevert();
        kUSD.burn(users.alice, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        BURN FROM TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful burnFrom with allowance
    function test_BurnFrom_Success() public {
        uint256 amount = TEST_AMOUNT;
        address account = users.alice;

        // First mint some tokens
        vm.prank(address(minter));
        kUSD.mint(account, amount);

        // Approve minter to burn
        vm.prank(account);
        kUSD.approve(address(minter), amount);

        // Burn using allowance
        vm.prank(address(minter));
        vm.expectEmit(true, false, false, true);
        emit Burned(account, amount);

        kUSD.burnFrom(account, amount);

        assertEq(kUSD.balanceOf(account), 0, "Balance should be zero after burn");
        assertEq(kUSD.allowance(account, address(minter)), 0, "Allowance should be consumed");
        assertEq(kUSD.totalSupply(), 0, "Total supply should be zero after burn");
    }

    /// @dev Test burnFrom requires minter role
    function test_BurnFrom_OnlyMinter() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.burnFrom(users.bob, TEST_AMOUNT);
    }

    /// @dev Test burnFrom reverts with insufficient allowance
    function test_BurnFrom_RevertInsufficientAllowance() public {
        uint256 amount = TEST_AMOUNT;
        address account = users.alice;

        // Mint tokens
        vm.prank(address(minter));
        kUSD.mint(account, amount);

        // Try to burn without allowance
        vm.prank(address(minter));
        vm.expectRevert();
        kUSD.burnFrom(account, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test admin role management
    function test_AdminRole_Management() public {
        address newAdmin = users.bob;

        // Grant admin role (requires owner)
        vm.prank(users.owner);
        kUSD.grantAdminRole(newAdmin);
        assertTrue(kUSD.hasAnyRole(newAdmin, ADMIN_ROLE), "Admin role should be granted");

        // Revoke admin role (requires owner)
        vm.prank(users.owner);
        kUSD.revokeAdminRole(newAdmin);
        assertFalse(kUSD.hasAnyRole(newAdmin, ADMIN_ROLE), "Admin role should be revoked");
    }

    /// @dev Test admin role functions require owner
    function test_AdminRole_OnlyOwner() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.grantAdminRole(users.bob);

        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.revokeAdminRole(users.admin);
    }

    /// @dev Test emergency role management
    function test_EmergencyRole_Management() public {
        address newEmergency = users.bob;

        // Grant emergency role (requires admin)
        vm.prank(users.admin);
        kUSD.grantEmergencyRole(newEmergency);
        assertTrue(kUSD.hasAnyRole(newEmergency, EMERGENCY_ADMIN_ROLE), "Emergency role should be granted");

        // Revoke emergency role (requires admin)
        vm.prank(users.admin);
        kUSD.revokeEmergencyRole(newEmergency);
        assertFalse(kUSD.hasAnyRole(newEmergency, EMERGENCY_ADMIN_ROLE), "Emergency role should be revoked");
    }

    /// @dev Test emergency role functions require admin
    function test_EmergencyRole_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.grantEmergencyRole(users.bob);

        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.revokeEmergencyRole(users.emergencyAdmin);
    }

    /// @dev Test minter role management
    function test_MinterRole_Management() public {
        address newMinter = users.bob;

        // Grant minter role (requires admin)
        vm.prank(users.admin);
        kUSD.grantMinterRole(newMinter);
        assertTrue(kUSD.hasAnyRole(newMinter, MINTER_ROLE), "Minter role should be granted");

        // Revoke minter role (requires admin)
        vm.prank(users.admin);
        kUSD.revokeMinterRole(newMinter);
        assertFalse(kUSD.hasAnyRole(newMinter, MINTER_ROLE), "Minter role should be revoked");
    }

    /// @dev Test minter role functions require admin
    function test_MinterRole_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.grantMinterRole(users.bob);

        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.revokeMinterRole(address(minter));
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test pause/unpause functionality
    function test_SetPaused_Success() public {
        assertFalse(kUSD.isPaused(), "Should be unpaused initially");

        // Pause
        vm.prank(users.emergencyAdmin);
        vm.expectEmit(false, false, false, true);
        emit PauseState(true);

        kUSD.setPaused(true);
        assertTrue(kUSD.isPaused(), "Should be paused");

        // Unpause
        vm.prank(users.emergencyAdmin);
        vm.expectEmit(false, false, false, true);
        emit PauseState(false);

        kUSD.setPaused(false);
        assertFalse(kUSD.isPaused(), "Should be unpaused");
    }

    /// @dev Test pause requires emergency admin role
    function test_SetPaused_OnlyEmergencyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.setPaused(true);
    }

    /// @dev Test pause affects transfers
    function test_Transfer_RevertWhenPaused() public {
        // Mint tokens
        vm.prank(address(minter));
        kUSD.mint(users.alice, TEST_AMOUNT);

        // Pause
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        // Try to transfer
        vm.prank(users.alice);
        vm.expectRevert(IkToken.Paused.selector);
        kUSD.transfer(users.bob, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                    EMERGENCY WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test emergency withdrawal of ETH
    function test_EmergencyWithdraw_ETH_Success() public {
        uint256 amount = 1 ether;

        // Force send ETH to contract (since it doesn't have receive)
        vm.deal(address(kUSD), amount);

        // Pause contract (required for emergency withdrawal)
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        // Emergency withdraw ETH
        uint256 recipientBalanceBefore = users.treasury.balance;

        vm.prank(users.emergencyAdmin);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(ZERO_ADDRESS, users.treasury, amount, users.emergencyAdmin);

        kUSD.emergencyWithdraw(ZERO_ADDRESS, users.treasury, amount);

        assertEq(users.treasury.balance - recipientBalanceBefore, amount, "ETH not withdrawn correctly");
        assertEq(address(kUSD).balance, 0, "Contract should have no ETH");
    }

    /// @dev Test emergency withdrawal of ERC20 tokens
    function test_EmergencyWithdraw_Token_Success() public {
        uint256 amount = TEST_AMOUNT;

        // Send USDC to contract (simulating stuck tokens)
        deal(USDC_MAINNET, address(kUSD), amount);

        // Pause contract
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        // Emergency withdraw tokens
        uint256 recipientBalanceBefore = IERC20(USDC_MAINNET).balanceOf(users.treasury);

        vm.prank(users.emergencyAdmin);
        vm.expectEmit(true, true, true, true);
        emit EmergencyWithdrawal(USDC_MAINNET, users.treasury, amount, users.emergencyAdmin);

        kUSD.emergencyWithdraw(USDC_MAINNET, users.treasury, amount);

        assertEq(
            IERC20(USDC_MAINNET).balanceOf(users.treasury) - recipientBalanceBefore,
            amount,
            "Tokens not withdrawn correctly"
        );
        assertEq(IERC20(USDC_MAINNET).balanceOf(address(kUSD)), 0, "Contract should have no tokens");
    }

    /// @dev Test emergency withdrawal requires emergency admin role
    function test_EmergencyWithdraw_OnlyEmergencyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.emergencyWithdraw(ZERO_ADDRESS, users.treasury, 1 ether);
    }

    /// @dev Test emergency withdrawal requires paused state
    function test_EmergencyWithdraw_RequiresPaused() public {
        // Should revert when not paused
        vm.prank(users.emergencyAdmin);
        vm.expectRevert(IkToken.ContractNotPaused.selector);
        kUSD.emergencyWithdraw(ZERO_ADDRESS, users.treasury, 1 ether);
    }

    /// @dev Test emergency withdrawal reverts with zero address recipient
    function test_EmergencyWithdraw_RevertZeroAddress() public {
        // Pause contract
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.emergencyAdmin);
        vm.expectRevert(IkToken.ZeroAddress.selector);
        kUSD.emergencyWithdraw(ZERO_ADDRESS, ZERO_ADDRESS, 1 ether);
    }

    /// @dev Test emergency withdrawal reverts with zero amount
    function test_EmergencyWithdraw_RevertZeroAmount() public {
        // Pause contract
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.emergencyAdmin);
        vm.expectRevert(IkToken.ZeroAmount.selector);
        kUSD.emergencyWithdraw(ZERO_ADDRESS, users.treasury, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test contract info functions
    function test_ContractInfo() public view {
        assertEq(kUSD.contractName(), "kToken", "Contract name incorrect");
        assertEq(kUSD.contractVersion(), "1.0.0", "Contract version incorrect");
    }

    /// @dev Test isPaused view function
    function test_IsPaused() public {
        assertFalse(kUSD.isPaused(), "Should be unpaused initially");

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        assertTrue(kUSD.isPaused(), "Should return true when paused");
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test upgrade authorization
    function test_AuthorizeUpgrade_OnlyAdmin() public {
        address newImpl = address(new kToken());

        // Non-admin should fail
        vm.prank(users.alice);
        vm.expectRevert();
        kUSD.upgradeToAndCall(newImpl, "");

        // Admin should succeed with upgrade authorization
        vm.prank(users.admin);
        vm.expectEmit(true, true, false, false);
        emit UpgradeAuthorized(newImpl, users.admin);

        kUSD.upgradeToAndCall(newImpl, "");
    }

    /// @dev Test upgrade authorization reverts with zero address
    function test_AuthorizeUpgrade_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert();
        kUSD.upgradeToAndCall(ZERO_ADDRESS, "");
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 STANDARD TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test basic transfer functionality
    function test_Transfer_Success() public {
        uint256 amount = TEST_AMOUNT;

        // Mint tokens
        vm.prank(address(minter));
        kUSD.mint(users.alice, amount);

        // Transfer
        vm.prank(users.alice);
        bool success = kUSD.transfer(users.bob, amount);

        assertTrue(success, "Transfer should succeed");
        assertEq(kUSD.balanceOf(users.alice), 0, "Sender balance incorrect");
        assertEq(kUSD.balanceOf(users.bob), amount, "Recipient balance incorrect");
    }

    /// @dev Test transferFrom with allowance
    function test_TransferFrom_Success() public {
        uint256 amount = TEST_AMOUNT;

        // Mint tokens
        vm.prank(address(minter));
        kUSD.mint(users.alice, amount);

        // Approve
        vm.prank(users.alice);
        kUSD.approve(users.bob, amount);

        // TransferFrom
        vm.prank(users.bob);
        bool success = kUSD.transferFrom(users.alice, users.charlie, amount);

        assertTrue(success, "TransferFrom should succeed");
        assertEq(kUSD.balanceOf(users.alice), 0, "Sender balance incorrect");
        assertEq(kUSD.balanceOf(users.charlie), amount, "Recipient balance incorrect");
        assertEq(kUSD.allowance(users.alice, users.bob), 0, "Allowance should be consumed");
    }

    /// @dev Test approve functionality
    function test_Approve_Success() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(users.alice);
        bool success = kUSD.approve(users.bob, amount);

        assertTrue(success, "Approve should succeed");
        assertEq(kUSD.allowance(users.alice, users.bob), amount, "Allowance incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE FUNCTION TEST
    //////////////////////////////////////////////////////////////*/

    /// @dev Test contract can hold ETH (even without receive function)
    function test_ContractCanHoldETH() public {
        uint256 amount = 1 ether;

        // Force send ETH to contract using deal
        vm.deal(address(kUSD), amount);

        assertEq(address(kUSD).balance, amount, "Contract should hold ETH");

        // Verify it can be withdrawn via emergencyWithdraw
        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        vm.prank(users.emergencyAdmin);
        kUSD.emergencyWithdraw(ZERO_ADDRESS, users.treasury, amount);

        assertEq(address(kUSD).balance, 0, "ETH should be withdrawn");
    }
}
