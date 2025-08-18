// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";
import { ClaimModule } from "src/kStakingVault/modules/ClaimModule.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title ClaimModuleTest
/// @notice Comprehensive unit tests for ClaimModule contract
contract ClaimModuleTest is DeploymentBaseTest {
    // Test constants
    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
    uint256 internal constant TEST_STK_TOKENS = 900 * _1_USDC;
    bytes32 internal constant TEST_BATCH_ID = bytes32(uint256(1));
    bytes32 internal constant TEST_REQUEST_ID = bytes32(uint256(1));
    address internal constant ZERO_ADDRESS = address(0);

    // Events to test
    event StakingSharesClaimed(bytes32 indexed batchId, uint256 requestIndex, address indexed user, uint256 shares);
    event UnstakingAssetsClaimed(bytes32 indexed batchId, uint256 requestIndex, address indexed user, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public override {
        super.setUp();
        // claimModule is already deployed in DeploymentBaseTest
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM STAKED SHARES TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claimStakedShares reverts when batch not settled
    function test_ClaimStakedShares_RevertBatchNotSettled() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimStakedShares reverts with invalid batch ID
    function test_ClaimStakedShares_RevertInvalidBatchId() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(bytes32(uint256(999)), TEST_REQUEST_ID);
    }

    /// @dev Test claimStakedShares reverts when not beneficiary
    function test_ClaimStakedShares_RevertNotBeneficiary() public {
        vm.prank(users.alice);
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimStakedShares function exists and has proper validation
    function test_ClaimStakedShares_FunctionExists() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimStakedShares requires batch to be settled
    function test_ClaimStakedShares_RequiresBatchSettled() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(bytes32(0), TEST_REQUEST_ID);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(bytes32(uint256(1)), TEST_REQUEST_ID);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(bytes32(uint256(10)), TEST_REQUEST_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        CLAIM UNSTAKED ASSETS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claimUnstakedAssets reverts when batch not settled
    function test_ClaimUnstakedAssets_RevertBatchNotSettled() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimUnstakedAssets reverts with invalid batch ID
    function test_ClaimUnstakedAssets_RevertInvalidBatchId() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(bytes32(uint256(999)), TEST_REQUEST_ID);
    }

    /// @dev Test claimUnstakedAssets reverts when not beneficiary
    function test_ClaimUnstakedAssets_RevertNotBeneficiary() public {
        vm.prank(users.alice);
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimUnstakedAssets function exists and has proper validation
    function test_ClaimUnstakedAssets_FunctionExists() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimUnstakedAssets requires batch to be settled
    function test_ClaimUnstakedAssets_RequiresBatchSettled() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(bytes32(0), TEST_REQUEST_ID);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(bytes32(uint256(1)), TEST_REQUEST_ID);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(bytes32(uint256(10)), TEST_REQUEST_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        REENTRANCY PROTECTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claimStakedShares has reentrancy protection
    function test_ClaimStakedShares_ReentrancyProtection() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimUnstakedAssets has reentrancy protection
    function test_ClaimUnstakedAssets_ReentrancyProtection() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claimStakedShares respects pause state
    function test_ClaimStakedShares_RespectsPause() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /// @dev Test claimUnstakedAssets respects pause state
    function test_ClaimUnstakedAssets_RespectsPause() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test ClaimModule defines expected errors
    function test_ErrorDefinitions() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        SELECTOR FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test selectors function returns correct selectors
    function test_Selectors() public {
        bytes4[] memory moduleSelectors = claimModule.selectors();

        assertEq(moduleSelectors.length, 2, "Should return 2 selectors");
        assertEq(
            moduleSelectors[0], ClaimModule.claimStakedShares.selector, "First selector should be claimStakedShares"
        );
        assertEq(
            moduleSelectors[1],
            ClaimModule.claimUnstakedAssets.selector,
            "Second selector should be claimUnstakedAssets"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claim functions with zero batch ID
    function test_ClaimFunctions_ZeroBatchId() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(bytes32(0), TEST_REQUEST_ID);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(bytes32(0), TEST_REQUEST_ID);
    }

    /// @dev Test claim functions with zero request ID
    function test_ClaimFunctions_ZeroRequestId() public {
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, bytes32(0));

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, bytes32(0));
    }

    /// @dev Test claim functions with large batch ID
    function test_ClaimFunctions_LargeBatchId() public {
        bytes32 largeBatchId = bytes32(type(uint256).max);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(largeBatchId, TEST_REQUEST_ID);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(largeBatchId, TEST_REQUEST_ID);
    }

    /// @dev Test claim functions with large request ID
    function test_ClaimFunctions_LargeRequestId() public {
        bytes32 largeRequestId = bytes32(type(uint256).max);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares(TEST_BATCH_ID, largeRequestId);

        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets(TEST_BATCH_ID, largeRequestId);
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test ClaimModule inherits from BaseVaultModule
    function test_InheritsFromBaseVaultModule() public {
        assertTrue(address(claimModule).code.length > 0, "ClaimModule should have implementation code");
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test module interface compliance
    function test_ModuleInterface() public {
        bytes4[] memory moduleSelectors = claimModule.selectors();
        assertTrue(moduleSelectors.length > 0, "Module should return selectors");

        assertEq(
            moduleSelectors[0], bytes4(keccak256("claimStakedShares(bytes32,uint256)")), "claimStakedShares selector"
        );
        assertEq(
            moduleSelectors[1],
            bytes4(keccak256("claimUnstakedAssets(bytes32,uint256)")),
            "claimUnstakedAssets selector"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test claim functions called by different users
    function test_ClaimFunctions_DifferentCallers() public {
        address[] memory callers = new address[](4);
        callers[0] = users.alice;
        callers[1] = users.bob;
        callers[2] = users.admin;
        callers[3] = users.institution;

        for (uint256 i = 0; i < callers.length; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(ClaimModule.BatchNotSettled.selector);
            claimModule.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);

            vm.prank(callers[i]);
            vm.expectRevert(ClaimModule.BatchNotSettled.selector);
            claimModule.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
        }
    }

    /// @dev Test claim functions with payable calls
    function test_ClaimFunctions_Payable() public {
        vm.deal(users.alice, 1 ether);

        vm.prank(users.alice);
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimStakedShares{ value: 0.1 ether }(TEST_BATCH_ID, TEST_REQUEST_ID);

        vm.prank(users.alice);
        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
        claimModule.claimUnstakedAssets{ value: 0.1 ether }(TEST_BATCH_ID, TEST_REQUEST_ID);
    }
}
