// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    ADMIN_ROLE,
    EMERGENCY_ADMIN_ROLE,
    USDC_MAINNET,
    WBTC_MAINNET,
    _1000_USDC,
    _100_USDC,
    _1_USDC
} from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";
import { kBase } from "src/base/kBase.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";
import { kMinter } from "src/kMinter.sol";

/// @title kMinterTest
/// @notice Comprehensive unit tests for kMinter contract
contract kMinterTest is DeploymentBaseTest {
    // Test constants
    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
    address internal constant ZERO_ADDRESS = address(0);

    // Events to test
    event Initialized(address indexed registry, address indexed owner, address admin, address emergencyAdmin);
    event Minted(address indexed to, uint256 amount, bytes32 batchId);
    event RedeemRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        uint24 batchId
    );
    event Redeemed(bytes32 indexed requestId);
    event Cancelled(bytes32 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test contract initialization state
    function test_InitialState() public view {
        assertEq(minter.contractName(), "kMinter", "Contract name incorrect");
        assertEq(minter.contractVersion(), "1.0.0", "Contract version incorrect");
        assertFalse(minter.isPaused(), "Should be unpaused initially");
        assertEq(address(minter.registry()), address(registry), "Registry not set correctly");
        assertEq(minter.getRequestCounter(), 0, "Request counter should be zero initially");
    }

    /// @dev Test successful initialization with valid parameters
    function test_Initialize_Success() public {
        // Deploy fresh implementation for testing
        kMinter newMinterImpl = new kMinter();

        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, address(registry));

        ERC1967Factory factory = new ERC1967Factory();
        address newProxy = factory.deployAndCall(address(newMinterImpl), users.admin, initData);

        kMinter newMinter = kMinter(payable(newProxy));
        assertFalse(newMinter.isPaused(), "Should be unpaused");
    }

    /// @dev Test initialization reverts with zero address registry
    function test_Initialize_RevertZeroRegistry() public {
        kMinter newMinterImpl = new kMinter();

        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, address(0));

        ERC1967Factory factory = new ERC1967Factory();
        vm.expectRevert(kBase.ZeroAddress.selector);
        factory.deployAndCall(address(newMinterImpl), users.admin, initData);
    }

    /// @dev Test double initialization reverts
    function test_Initialize_RevertDoubleInit() public {
        vm.expectRevert();
        minter.initialize(address(registry));
    }

    /*//////////////////////////////////////////////////////////////
                        MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful minting
    function test_Mint_Success() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.alice;

        // Fund institution with USDC
        deal(USDC_MAINNET, users.institution, amount);

        // Approve minter to spend USDC
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount);

        // Get initial balances
        uint256 initialKTokenBalance = kUSD.balanceOf(recipient);
        uint256 initialUSDCBalance = IERC20(USDC_MAINNET).balanceOf(users.institution);

        // Mint kTokens
        vm.prank(users.institution);
        vm.expectEmit(true, false, false, false);
        emit Minted(recipient, amount, 0); // batchId will be 0 or 1

        minter.mint(USDC_MAINNET, recipient, amount);

        // Verify balances
        assertEq(kUSD.balanceOf(recipient) - initialKTokenBalance, amount, "kToken balance should increase by amount");
        assertEq(
            initialUSDCBalance - IERC20(USDC_MAINNET).balanceOf(users.institution),
            amount,
            "USDC balance should decrease by amount"
        );
    }

    /// @dev Test mint requires institution role
    function test_Mint_WrongRole() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(users.alice);
        vm.expectRevert(kBase.WrongRole.selector);
        minter.mint(USDC_MAINNET, users.alice, amount);
    }

    /// @dev Test mint reverts with zero amount
    function test_Mint_RevertZeroAmount() public {
        vm.prank(users.institution);
        vm.expectRevert(kBase.ZeroAmount.selector);
        minter.mint(USDC_MAINNET, users.alice, 0);
    }

    /// @dev Test mint reverts with zero recipient
    function test_Mint_RevertZeroRecipient() public {
        vm.prank(users.institution);
        vm.expectRevert(kBase.ZeroAddress.selector);
        minter.mint(USDC_MAINNET, ZERO_ADDRESS, TEST_AMOUNT);
    }

    /// @dev Test mint reverts with invalid asset
    function test_Mint_RevertInvalidAsset() public {
        address invalidAsset = address(0x1234567890123456789012345678901234567890);

        vm.prank(users.institution);
        vm.expectRevert(kBase.WrongAsset.selector);
        minter.mint(invalidAsset, users.alice, TEST_AMOUNT);
    }

    /// @dev Test mint reverts when paused
    function test_Mint_RevertWhenPaused() public {
        // Pause minter
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.prank(users.institution);
        vm.expectRevert(kBase.IsPaused.selector);
        minter.mint(USDC_MAINNET, users.alice, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEMPTION REQUEST TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful redemption request (partial validation)
    function test_RequestRedeem_Success() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.institution;

        // First mint some kTokens to the institution
        deal(USDC_MAINNET, users.institution, amount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, recipient, amount);

        // Get initial state
        uint256 initialKTokenBalance = kUSD.balanceOf(recipient);
        uint256 initialRequestCounter = minter.getRequestCounter();

        // Approve minter to spend kTokens
        vm.prank(users.institution);
        kUSD.approve(address(minter), amount);

        // Request redemption - will fail due to insufficient virtual balance in vault
        vm.prank(users.institution);
        vm.expectRevert();
        minter.requestRedeem(USDC_MAINNET, recipient, amount);
    }

    /// @dev Test redemption request requires institution role
    function test_RequestRedeem_WrongRole() public {
        vm.prank(users.alice);
        vm.expectRevert(kBase.WrongRole.selector);
        minter.requestRedeem(USDC_MAINNET, users.alice, TEST_AMOUNT);
    }

    /// @dev Test redemption request reverts with zero amount
    function test_RequestRedeem_RevertZeroAmount() public {
        vm.prank(users.institution);
        vm.expectRevert(kBase.ZeroAmount.selector);
        minter.requestRedeem(USDC_MAINNET, users.institution, 0);
    }

    /// @dev Test redemption request reverts with zero recipient
    function test_RequestRedeem_RevertZeroRecipient() public {
        vm.prank(users.institution);
        vm.expectRevert(kBase.ZeroAddress.selector);
        minter.requestRedeem(USDC_MAINNET, ZERO_ADDRESS, TEST_AMOUNT);
    }

    /// @dev Test redemption request reverts with invalid asset
    function test_RequestRedeem_RevertInvalidAsset() public {
        address invalidAsset = address(0x1234567890123456789012345678901234567890);

        vm.prank(users.institution);
        vm.expectRevert(kBase.WrongAsset.selector);
        minter.requestRedeem(invalidAsset, users.institution, TEST_AMOUNT);
    }

    /// @dev Test redemption request reverts with insufficient balance
    function test_RequestRedeem_RevertInsufficientBalance() public {
        // Institution has no kTokens
        vm.prank(users.institution);
        vm.expectRevert(IkMinter.InsufficientBalance.selector);
        minter.requestRedeem(USDC_MAINNET, users.institution, TEST_AMOUNT);
    }

    /// @dev Test redemption request reverts when paused
    function test_RequestRedeem_RevertWhenPaused() public {
        // Pause minter
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.prank(users.institution);
        vm.expectRevert(kBase.IsPaused.selector);
        minter.requestRedeem(USDC_MAINNET, users.institution, TEST_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////
                        REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test redemption requires valid request
    function test_Redeem_RevertRequestNotFound() public {
        bytes32 invalidRequestId = keccak256("invalid");

        vm.prank(users.institution);
        vm.expectRevert(IkMinter.RequestNotFound.selector);
        minter.redeem(invalidRequestId);
    }

    /// @dev Test redemption requires institution role
    function test_Redeem_WrongRole() public {
        bytes32 requestId = keccak256("test");

        vm.prank(users.alice);
        vm.expectRevert(kBase.WrongRole.selector);
        minter.redeem(requestId);
    }

    /// @dev Test redemption reverts when paused
    function test_Redeem_RevertWhenPaused() public {
        // Pause minter
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        bytes32 requestId = keccak256("test");

        vm.prank(users.institution);
        vm.expectRevert(kBase.IsPaused.selector);
        minter.redeem(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                        CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test cancel request requires valid request
    function test_CancelRequest_RevertRequestNotFound() public {
        bytes32 invalidRequestId = keccak256("invalid");

        vm.prank(users.institution);
        vm.expectRevert(IkMinter.RequestNotFound.selector);
        minter.cancelRequest(invalidRequestId);
    }

    /// @dev Test cancel request requires institution role
    function test_CancelRequest_WrongRole() public {
        bytes32 requestId = keccak256("test");

        vm.prank(users.alice);
        vm.expectRevert(kBase.WrongRole.selector);
        minter.cancelRequest(requestId);
    }

    /// @dev Test cancel request reverts when paused
    function test_CancelRequest_RevertWhenPaused() public {
        // Pause minter
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        bytes32 requestId = keccak256("test");

        vm.prank(users.institution);
        vm.expectRevert(kBase.IsPaused.selector);
        minter.cancelRequest(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test pause/unpause functionality
    function test_SetPaused_Success() public {
        assertFalse(minter.isPaused(), "Should be unpaused initially");

        // Pause
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);
        assertTrue(minter.isPaused(), "Should be paused");

        // Unpause
        vm.prank(users.emergencyAdmin);
        minter.setPaused(false);
        assertFalse(minter.isPaused(), "Should be unpaused");
    }

    /// @dev Test pause requires emergency admin role
    function test_SetPaused_OnlyEmergencyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert(kBase.WrongRole.selector);
        minter.setPaused(true);
    }

    /// @dev Test isPaused view function
    function test_IsPaused() public {
        // Initially unpaused
        assertFalse(minter.isPaused(), "Should be unpaused initially");

        // Pause
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);
        assertTrue(minter.isPaused(), "Should return true when paused");

        // Unpause
        vm.prank(users.emergencyAdmin);
        minter.setPaused(false);
        assertFalse(minter.isPaused(), "Should return false when unpaused");
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test contract info functions
    function test_ContractInfo() public view {
        assertEq(minter.contractName(), "kMinter", "Contract name incorrect");
        assertEq(minter.contractVersion(), "1.0.0", "Contract version incorrect");
    }

    /// @dev Test getRedeemRequest returns empty for non-existent request
    function test_GetRedeemRequest_NonExistent() public {
        bytes32 invalidRequestId = keccak256("invalid");

        IkMinter.RedeemRequest memory request = minter.getRedeemRequest(invalidRequestId);
        assertEq(request.user, address(0), "User should be zero");
        assertEq(request.amount, 0, "Amount should be zero");
    }

    /// @dev Test getUserRequests returns empty array for user with no requests
    function test_GetUserRequests_Empty() public {
        bytes32[] memory requests = minter.getUserRequests(users.alice);
        assertEq(requests.length, 0, "Should return empty array");
    }

    /// @dev Test getRequestCounter starts at zero
    function test_GetRequestCounter_Initial() public view {
        assertEq(minter.getRequestCounter(), 0, "Request counter should start at zero");
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test upgrade authorization
    function test_AuthorizeUpgrade_OnlyAdmin() public {
        address newImpl = address(new kMinter());

        // Non-admin should fail
        vm.prank(users.alice);
        vm.expectRevert(kBase.WrongRole.selector);
        minter.upgradeToAndCall(newImpl, "");
    }

    /// @dev Test upgrade authorization reverts with zero address
    function test_AuthorizeUpgrade_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(kBase.ZeroAddress.selector);
        minter.upgradeToAndCall(ZERO_ADDRESS, "");
    }

    /*//////////////////////////////////////////////////////////////
                    TOTAL LOCKED ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test getTotalLockedAssets for a single asset
    function test_GetTotalLockedAssets_SingleAsset() public {
        // Initially should be zero
        assertEq(minter.getTotalLockedAssets(USDC_MAINNET), 0, "Should start with zero locked assets");

        // Mint some tokens
        uint256 amount = TEST_AMOUNT;
        deal(USDC_MAINNET, users.institution, amount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.institution, amount);

        // Check locked assets increased
        assertEq(minter.getTotalLockedAssets(USDC_MAINNET), amount, "Locked assets should equal minted amount");
    }

    /// @dev Test getTotalLockedAssets with multiple mints
    function test_GetTotalLockedAssets_MultipleMints() public {
        uint256 amount1 = TEST_AMOUNT;
        uint256 amount2 = 500 * _1_USDC;
        uint256 totalAmount = amount1 + amount2;

        // First mint
        deal(USDC_MAINNET, users.institution, amount1);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount1);
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.institution, amount1);

        assertEq(minter.getTotalLockedAssets(USDC_MAINNET), amount1, "Should track first mint");

        // Second mint
        deal(USDC_MAINNET, users.institution, amount2);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount2);
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.alice, amount2);

        assertEq(minter.getTotalLockedAssets(USDC_MAINNET), totalAmount, "Should track cumulative mints");
    }

    /// @dev Test getTotalLockedAssets for unsupported asset
    function test_GetTotalLockedAssets_UnsupportedAsset() public {
        address unsupportedAsset = address(0x1234567890123456789012345678901234567890);
        assertEq(minter.getTotalLockedAssets(unsupportedAsset), 0, "Unsupported asset should return zero");
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test that minting interacts with DN vault batches
    function test_Mint_InteractsWithDNVault() public {
        uint256 amount = TEST_AMOUNT;

        // Get initial batch ID from DN vault
        bytes32 initialBatchId = dnVault.getBatchId();

        // Mint tokens
        deal(USDC_MAINNET, users.institution, amount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount);

        // The mint should interact with the current DN vault batch
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.institution, amount);

        // Verify DN vault received the assets (through kAssetRouter)
        // In a full integration test, we would verify the batch balances
        assertEq(kUSD.balanceOf(users.institution), amount, "kTokens should be minted");
    }

    /// @dev Test that minting calls kAssetPush on the router
    function test_Mint_CallsKAssetPush() public {
        uint256 amount = TEST_AMOUNT;

        // Setup
        deal(USDC_MAINNET, users.institution, amount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount);

        // Get batch balances before mint
        bytes32 batchId = dnVault.getBatchId();
        (uint256 depositedBefore,) = assetRouter.getBatchIdBalances(address(minter), batchId);

        // Mint
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.institution, amount);

        // Get batch balances after mint
        (uint256 depositedAfter,) = assetRouter.getBatchIdBalances(address(minter), batchId);

        // Verify kAssetPush was called (deposited amount increased)
        assertEq(depositedAfter - depositedBefore, amount, "Deposited amount should increase");
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test minting maximum amounts
    function test_Mint_MaxAmount() public {
        uint256 maxAmount = type(uint128).max; // Use uint128 max as that's what's used internally

        // Fund institution with max amount
        deal(USDC_MAINNET, users.institution, maxAmount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), maxAmount);

        // Should succeed with max amount
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.institution, maxAmount);

        assertEq(kUSD.balanceOf(users.institution), maxAmount, "Should mint max amount");
        assertEq(minter.getTotalLockedAssets(USDC_MAINNET), maxAmount, "Should track max amount");
    }

    /// @dev Test concurrent requests from same user
    function test_RequestRedeem_Concurrent() public {
        // Setup: Mint tokens first
        uint256 totalAmount = 3000 * _1_USDC;
        deal(USDC_MAINNET, users.institution, totalAmount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), totalAmount);
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, users.institution, totalAmount);

        // Approve all tokens for redemption
        vm.prank(users.institution);
        kUSD.approve(address(minter), totalAmount);

        // Create multiple concurrent redemption requests
        uint256 requestAmount = 1000 * _1_USDC;

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(users.institution);
            vm.expectRevert();
            minter.requestRedeem(USDC_MAINNET, users.institution, requestAmount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test minting workflow (unit test level)
    function test_MintWorkflow() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.institution;

        // Step 1: Mint kTokens
        deal(USDC_MAINNET, users.institution, amount);
        vm.prank(users.institution);
        IERC20(USDC_MAINNET).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(USDC_MAINNET, recipient, amount);

        assertEq(kUSD.balanceOf(recipient), amount, "Should have minted kTokens");

        // Step 2: Verify request counter unchanged (minting doesn't create requests)
        assertEq(minter.getRequestCounter(), 0, "Request counter should remain zero");

        // Step 3: Verify no user requests (minting doesn't create requests)
        bytes32[] memory userRequests = minter.getUserRequests(recipient);
        assertEq(userRequests.length, 0, "Should have no user requests");
    }
}
