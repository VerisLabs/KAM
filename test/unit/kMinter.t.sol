pragma solidity 0.8.30;

import { _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

import {
    KBASE_WRONG_ROLE,
    KMINTER_BATCH_MINT_REACHED,
    KMINTER_BATCH_NOT_SET,
    KMINTER_BATCH_NOT_SET,
    KMINTER_BATCH_REDEEM_REACHED,
    KMINTER_IS_PAUSED,
    KMINTER_REQUEST_NOT_FOUND,
    KMINTER_WRONG_ASSET,
    KMINTER_WRONG_ROLE,
    KMINTER_ZERO_ADDRESS,
    KMINTER_ZERO_AMOUNT
} from "kam/src/errors/Errors.sol";
import { IkMinter } from "kam/src/interfaces/IkMinter.sol";
import { kMinter } from "kam/src/kMinter.sol";

contract kMinterTest is DeploymentBaseTest {
    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
    address internal constant ZERO_ADDRESS = address(0);

    /* //////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(minter.contractName(), "kMinter", "Contract name incorrect");
        assertEq(minter.contractVersion(), "1.0.0", "Contract version incorrect");
        assertFalse(minter.isPaused(), "Should be unpaused initially");
        assertEq(address(minter.registry()), address(registry), "Registry not set correctly");
        assertEq(minter.getRequestCounter(), 0, "Request counter should be zero initially");
    }

    function test_Initialize_Success() public {
        kMinter newMinterImpl = new kMinter();

        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, address(registry));

        ERC1967Factory factory = new ERC1967Factory();
        address newProxy = factory.deployAndCall(address(newMinterImpl), users.admin, initData);

        kMinter newMinter = kMinter(payable(newProxy));
        assertFalse(newMinter.isPaused(), "Should be unpaused");
    }

    function test_Initialize_RevertZeroRegistry() public {
        kMinter newMinterImpl = new kMinter();

        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, address(0));

        ERC1967Factory factory = new ERC1967Factory();
        vm.expectRevert(bytes(KMINTER_ZERO_ADDRESS));
        factory.deployAndCall(address(newMinterImpl), users.admin, initData);
    }

    function test_Initialize_RevertDoubleInit() public {
        vm.expectRevert();
        minter.initialize(address(registry));
    }

    /* //////////////////////////////////////////////////////////////
                        MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint_Success() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.alice;

        mockUSDC.mint(users.institution, amount);

        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);

        uint256 initialKTokenBalance = kUSD.balanceOf(recipient);
        uint256 initialUSDCBalance = IERC20(tokens.usdc).balanceOf(users.institution);

        vm.prank(users.institution);
        vm.expectEmit(true, false, false, false);
        emit IkMinter.Minted(recipient, amount, 0);

        minter.mint(tokens.usdc, recipient, amount);

        assertEq(kUSD.balanceOf(recipient) - initialKTokenBalance, amount, "kToken balance should increase by amount");
        assertEq(
            initialUSDCBalance - IERC20(tokens.usdc).balanceOf(users.institution),
            amount,
            "USDC balance should decrease by amount"
        );
    }

    function test_Mint_LimitExceeded() public {
        uint256 amount = TEST_AMOUNT;
        vm.prank(users.admin);
        registry.setAssetBatchLimits(tokens.usdc, 0, 0);

        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_BATCH_MINT_REACHED));
        minter.mint(tokens.usdc, users.alice, amount);
    }

    function test_Mint_WrongRole() public {
        uint256 amount = TEST_AMOUNT;

        vm.prank(users.alice);
        vm.expectRevert(bytes(KMINTER_WRONG_ROLE));
        minter.mint(tokens.usdc, users.alice, amount);
    }

    function test_Mint_RevertZeroAmount() public {
        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_ZERO_AMOUNT));
        minter.mint(tokens.usdc, users.alice, 0);
    }

    function test_Mint_RevertZeroRecipient() public {
        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_ZERO_ADDRESS));
        minter.mint(tokens.usdc, ZERO_ADDRESS, TEST_AMOUNT);
    }

    function test_Mint_RevertInvalidAsset() public {
        address invalidAsset = address(0x1234567890123456789012345678901234567890);

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_WRONG_ASSET));
        minter.mint(invalidAsset, users.alice, TEST_AMOUNT);
    }

    function test_Mint_RevertWhenPaused() public {
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_IS_PAUSED));
        minter.mint(tokens.usdc, users.alice, TEST_AMOUNT);
    }

    /* //////////////////////////////////////////////////////////////
                    REDEMPTION REQUEST TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RequestBurn_Success() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.institution;

        mockUSDC.mint(users.institution, amount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, recipient, amount);

        vm.prank(users.institution);
        kUSD.approve(address(minter), amount);

        vm.prank(users.institution);
        vm.expectRevert();
        minter.requestBurn(tokens.usdc, recipient, amount);
    }

    function test_RequestBurn_WrongRole() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(KMINTER_WRONG_ROLE));
        minter.requestBurn(tokens.usdc, users.alice, TEST_AMOUNT);
    }

    function test_RequestBurn_RevertZeroAmount() public {
        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_ZERO_AMOUNT));
        minter.requestBurn(tokens.usdc, users.institution, 0);
    }

    function test_RequestBurn_RevertZeroRecipient() public {
        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_ZERO_ADDRESS));
        minter.requestBurn(tokens.usdc, ZERO_ADDRESS, TEST_AMOUNT);
    }

    function test_RequestBurn_RevertBatchLimitReached() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.institution;

        mockUSDC.mint(users.institution, amount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, recipient, amount);

        vm.prank(users.admin);
        registry.setAssetBatchLimits(tokens.usdc, 0, 0);

        vm.prank(users.institution);
        kUSD.approve(address(minter), amount);

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_BATCH_REDEEM_REACHED));
        minter.requestBurn(tokens.usdc, recipient, amount);
    }

    function test_RequestBurn_RevertInvalidAsset() public {
        address invalidAsset = address(0x1234567890123456789012345678901234567890);

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_WRONG_ASSET));
        minter.requestBurn(invalidAsset, users.institution, TEST_AMOUNT);
    }

    function test_RequestBurn_RevertBatchNotSet() public {
        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_BATCH_NOT_SET));
        minter.requestBurn(tokens.usdc, users.institution, TEST_AMOUNT);
    }

    function test_RequestBurn_RevertWhenPaused() public {
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_IS_PAUSED));
        minter.requestBurn(tokens.usdc, users.institution, TEST_AMOUNT);
    }

    /* //////////////////////////////////////////////////////////////
                        REDEMPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Burn_RevertRequestNotFound() public {
        bytes32 invalidRequestId = keccak256("invalid");

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_REQUEST_NOT_FOUND));
        minter.burn(invalidRequestId);
    }

    function test_Burn_WrongRole() public {
        bytes32 requestId = keccak256("test");

        vm.prank(users.alice);
        vm.expectRevert(bytes(KMINTER_WRONG_ROLE));
        minter.burn(requestId);
    }

    function test_Burn_RevertWhenPaused() public {
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        bytes32 requestId = keccak256("test");

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_IS_PAUSED));
        minter.burn(requestId);
    }

    /* //////////////////////////////////////////////////////////////
                        CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelRequest_RevertRequestNotFound() public {
        bytes32 invalidRequestId = keccak256("invalid");

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_REQUEST_NOT_FOUND));
        minter.cancelRequest(invalidRequestId);
    }

    function test_CancelRequest_WrongRole() public {
        bytes32 requestId = keccak256("test");

        vm.prank(users.alice);
        vm.expectRevert(bytes(KMINTER_WRONG_ROLE));
        minter.cancelRequest(requestId);
    }

    function test_CancelRequest_RevertWhenPaused() public {
        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);

        bytes32 requestId = keccak256("test");

        vm.prank(users.institution);
        vm.expectRevert(bytes(KMINTER_IS_PAUSED));
        minter.cancelRequest(requestId);
    }

    /* //////////////////////////////////////////////////////////////
                        PAUSE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetPaused_Success() public {
        assertFalse(minter.isPaused(), "Should be unpaused initially");

        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);
        assertTrue(minter.isPaused(), "Should be paused");

        vm.prank(users.emergencyAdmin);
        minter.setPaused(false);
        assertFalse(minter.isPaused(), "Should be unpaused");
    }

    function test_SetPaused_OnlyEmergencyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert(bytes(KBASE_WRONG_ROLE));
        minter.setPaused(true);
    }

    function test_IsPaused() public {
        assertFalse(minter.isPaused(), "Should be unpaused initially");

        vm.prank(users.emergencyAdmin);
        minter.setPaused(true);
        assertTrue(minter.isPaused(), "Should return true when paused");

        vm.prank(users.emergencyAdmin);
        minter.setPaused(false);
        assertFalse(minter.isPaused(), "Should return false when unpaused");
    }

    /* //////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ContractInfo() public view {
        assertEq(minter.contractName(), "kMinter", "Contract name incorrect");
        assertEq(minter.contractVersion(), "1.0.0", "Contract version incorrect");
    }

    function test_GetBurnRequest_NonExistent() public view {
        bytes32 invalidRequestId = keccak256("invalid");

        IkMinter.BurnRequest memory request = minter.getBurnRequest(invalidRequestId);
        assertEq(request.user, address(0), "User should be zero");
        assertEq(request.amount, 0, "Amount should be zero");
    }

    function test_GetUserRequests_Empty() public view {
        bytes32[] memory requests = minter.getUserRequests(users.alice);
        assertEq(requests.length, 0, "Should return empty array");
    }

    function test_GetRequestCounter_Initial() public view {
        assertEq(minter.getRequestCounter(), 0, "Request counter should start at zero");
    }

    /* //////////////////////////////////////////////////////////////
                        UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AuthorizeUpgrade_OnlyAdmin() public {
        address newImpl = address(new kMinter());

        vm.prank(users.alice);
        vm.expectRevert(bytes(KMINTER_WRONG_ROLE));
        minter.upgradeToAndCall(newImpl, "");
    }

    function test_AuthorizeUpgrade_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KMINTER_ZERO_ADDRESS));
        minter.upgradeToAndCall(ZERO_ADDRESS, "");
    }

    /* //////////////////////////////////////////////////////////////
                    TOTAL LOCKED ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetTotalLockedAssets_SingleAsset() public {
        assertEq(minter.getTotalLockedAssets(tokens.usdc), 0, "Should start with zero locked assets");

        uint256 amount = TEST_AMOUNT;
        mockUSDC.mint(users.institution, amount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, users.institution, amount);

        assertEq(minter.getTotalLockedAssets(tokens.usdc), amount, "Locked assets should equal minted amount");
    }

    function test_GetTotalLockedAssets_MultipleMints() public {
        uint256 amount1 = TEST_AMOUNT;
        uint256 amount2 = 500 * _1_USDC;
        uint256 totalAmount = amount1 + amount2;

        mockUSDC.mint(users.institution, amount1);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount1);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, users.institution, amount1);

        assertEq(minter.getTotalLockedAssets(tokens.usdc), amount1, "Should track first mint");

        mockUSDC.mint(users.institution, amount2);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount2);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, users.alice, amount2);

        assertEq(minter.getTotalLockedAssets(tokens.usdc), totalAmount, "Should track cumulative mints");
    }

    function test_GetTotalLockedAssets_UnsupportedAsset() public view {
        address unsupportedAsset = address(0x1234567890123456789012345678901234567890);
        assertEq(minter.getTotalLockedAssets(unsupportedAsset), 0, "Unsupported asset should return zero");
    }

    /* //////////////////////////////////////////////////////////////
                    BATCH INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint_InteractsWithDNVault() public {
        uint256 amount = TEST_AMOUNT;

        mockUSDC.mint(users.institution, amount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);

        vm.prank(users.institution);
        minter.mint(tokens.usdc, users.institution, amount);

        assertEq(kUSD.balanceOf(users.institution), amount, "kTokens should be minted");
    }

    /* //////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Mint_MaxAmount() public {
        uint256 maxAmount = type(uint128).max;

        mockUSDC.mint(users.institution, maxAmount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), maxAmount);

        vm.prank(users.institution);
        minter.mint(tokens.usdc, users.institution, maxAmount);

        assertEq(kUSD.balanceOf(users.institution), maxAmount, "Should mint max amount");
        assertEq(minter.getTotalLockedAssets(tokens.usdc), maxAmount, "Should track max amount");
    }

    function test_RequestBurn_Concurrent() public {
        uint256 totalAmount = 3000 * _1_USDC;
        mockUSDC.mint(users.institution, totalAmount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), totalAmount);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, users.institution, totalAmount);

        vm.prank(users.institution);
        kUSD.approve(address(minter), totalAmount);

        uint256 requestAmount = 1000 * _1_USDC;

        for (uint256 i = 0; i < 3; i++) {
            vm.prank(users.institution);
            vm.expectRevert();
            minter.requestBurn(tokens.usdc, users.institution, requestAmount);
        }
    }

    /* //////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintWorkflow() public {
        uint256 amount = TEST_AMOUNT;
        address recipient = users.institution;

        mockUSDC.mint(users.institution, amount);
        vm.prank(users.institution);
        IERC20(tokens.usdc).approve(address(minter), amount);
        vm.prank(users.institution);
        minter.mint(tokens.usdc, recipient, amount);

        assertEq(kUSD.balanceOf(recipient), amount, "Should have minted kTokens");

        assertEq(minter.getRequestCounter(), 0, "Request counter should remain zero");

        bytes32[] memory userRequests = minter.getUserRequests(recipient);
        assertEq(userRequests.length, 0, "Should have no user requests");
    }
}
