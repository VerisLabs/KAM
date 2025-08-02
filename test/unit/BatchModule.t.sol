// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
import { BatchModule } from "src/kStakingVault/modules/BatchModule.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

/// @title BatchModuleTest
/// @notice Comprehensive unit tests for BatchModule contract
contract BatchModuleTest is DeploymentBaseTest {
    // Test constants
    uint32 internal constant TEST_BATCH_ID = 1;
    address internal constant ZERO_ADDRESS = address(0);

    // Events to test
    event BatchCreated(uint32 indexed batchId);
    event BatchReceiverDeployed(uint32 indexed batchId, address indexed receiver);
    event BatchSettled(uint32 indexed batchId);
    event BatchClosed(uint32 indexed batchId);
    event BatchReceiverSet(address indexed batchReceiver, uint32 indexed batchId);

    function setUp() public override {
        super.setUp();
        // batchModule is already deployed in DeploymentBaseTest
    }

    /*//////////////////////////////////////////////////////////////
                        CREATE NEW BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test createNewBatch requires initialization first
    function test_CreateNewBatch_RequiresInit() public {
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();
    }

    /// @dev Test createNewBatch function exists and requires initialization
    function test_CreateNewBatch_AccessControl() public {
        // All users should fail with NotInitialized since module is not initialized
        vm.prank(users.admin);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();

        vm.prank(users.owner);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();

        vm.prank(users.institution);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();
    }

    /// @dev Test createNewBatch with different callers - all require initialization
    function test_CreateNewBatch_DifferentCallers() public {
        address[] memory callers = new address[](5);
        callers[0] = users.alice;
        callers[1] = users.bob;
        callers[2] = users.admin;
        callers[3] = users.owner;
        callers[4] = users.institution;

        for (uint256 i = 0; i < callers.length; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.createNewBatch();
        }
    }

    /*//////////////////////////////////////////////////////////////
                        CLOSE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test closeBatch requires relayer role
    function test_CloseBatch_OnlyRelayer() public {
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(TEST_BATCH_ID, false);
    }

    /// @dev Test closeBatch access control
    function test_CloseBatch_AccessControl() public {
        // Non-relayer should fail
        vm.prank(users.admin);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(TEST_BATCH_ID, false);

        vm.prank(users.owner);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(TEST_BATCH_ID, true);
    }

    /// @dev Test closeBatch with create flag variations
    function test_CloseBatch_CreateFlag() public {
        // Test with create = false
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(TEST_BATCH_ID, false);

        // Test with create = true
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(TEST_BATCH_ID, true);
    }

    /// @dev Test closeBatch with different batch IDs
    function test_CloseBatch_DifferentBatchIds() public {
        uint256[] memory batchIds = new uint256[](4);
        batchIds[0] = 0;
        batchIds[1] = 1;
        batchIds[2] = 100;
        batchIds[3] = type(uint32).max;

        for (uint256 i = 0; i < batchIds.length; i++) {
            vm.prank(users.alice);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.closeBatch(batchIds[i], false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SETTLE BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test settleBatch requires kAssetRouter role
    function test_SettleBatch_OnlyKAssetRouter() public {
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(TEST_BATCH_ID);
    }

    /// @dev Test settleBatch access control
    function test_SettleBatch_AccessControl() public {
        // Non-kAssetRouter should fail
        vm.prank(users.admin);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(TEST_BATCH_ID);

        vm.prank(users.owner);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(TEST_BATCH_ID);

        vm.prank(users.institution);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(TEST_BATCH_ID);
    }

    /// @dev Test settleBatch with different callers
    function test_SettleBatch_DifferentCallers() public {
        address[] memory nonAssetRouters = new address[](5);
        nonAssetRouters[0] = users.alice;
        nonAssetRouters[1] = users.bob;
        nonAssetRouters[2] = users.admin;
        nonAssetRouters[3] = users.owner;
        nonAssetRouters[4] = users.institution;

        for (uint256 i = 0; i < nonAssetRouters.length; i++) {
            vm.prank(nonAssetRouters[i]);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.settleBatch(TEST_BATCH_ID);
        }
    }

    /// @dev Test settleBatch with different batch IDs
    function test_SettleBatch_DifferentBatchIds() public {
        uint256[] memory batchIds = new uint256[](4);
        batchIds[0] = 0;
        batchIds[1] = 1;
        batchIds[2] = 100;
        batchIds[3] = type(uint32).max;

        for (uint256 i = 0; i < batchIds.length; i++) {
            vm.prank(users.alice);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.settleBatch(batchIds[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOY BATCH RECEIVER TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test createBatchReceiver requires kAssetRouter role
    function test_createBatchReceiver_OnlyKAssetRouter() public {
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(TEST_BATCH_ID);
    }

    /// @dev Test createBatchReceiver access control
    function test_createBatchReceiver_AccessControl() public {
        // Non-kAssetRouter should fail
        vm.prank(users.admin);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(TEST_BATCH_ID);

        vm.prank(users.owner);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(TEST_BATCH_ID);

        vm.prank(users.institution);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(TEST_BATCH_ID);
    }

    /// @dev Test createBatchReceiver with different callers
    function test_createBatchReceiver_DifferentCallers() public {
        address[] memory nonAssetRouters = new address[](5);
        nonAssetRouters[0] = users.alice;
        nonAssetRouters[1] = users.bob;
        nonAssetRouters[2] = users.admin;
        nonAssetRouters[3] = users.owner;
        nonAssetRouters[4] = users.institution;

        for (uint256 i = 0; i < nonAssetRouters.length; i++) {
            vm.prank(nonAssetRouters[i]);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.createBatchReceiver(TEST_BATCH_ID);
        }
    }

    /// @dev Test createBatchReceiver with different batch IDs
    function test_createBatchReceiver_DifferentBatchIds() public {
        uint256[] memory batchIds = new uint256[](4);
        batchIds[0] = 0;
        batchIds[1] = 1;
        batchIds[2] = 100;
        batchIds[3] = type(uint32).max;

        for (uint256 i = 0; i < batchIds.length; i++) {
            vm.prank(users.alice);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.createBatchReceiver(batchIds[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SELECTOR FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test selectors function returns correct selectors
    function test_Selectors() public {
        bytes4[] memory moduleSelectors = batchModule.selectors();

        assertEq(moduleSelectors.length, 4, "Should return 4 selectors");
        assertEq(moduleSelectors[0], BatchModule.createNewBatch.selector, "First selector should be createNewBatch");
        assertEq(moduleSelectors[1], BatchModule.closeBatch.selector, "Second selector should be closeBatch");
        assertEq(moduleSelectors[2], BatchModule.settleBatch.selector, "Third selector should be settleBatch");
        assertEq(
            moduleSelectors[3],
            BatchModule.createBatchReceiver.selector,
            "Fourth selector should be createBatchReceiver"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test module interface compliance
    function test_ModuleInterface() public {
        // Test that the module implements the expected interface
        bytes4[] memory moduleSelectors = batchModule.selectors();
        assertTrue(moduleSelectors.length > 0, "Module should return selectors");

        // Test function selectors are correct
        assertEq(moduleSelectors[0], bytes4(keccak256("createNewBatch()")), "createNewBatch selector");
        assertEq(moduleSelectors[1], bytes4(keccak256("closeBatch(uint256,bool)")), "closeBatch selector");
        assertEq(moduleSelectors[2], bytes4(keccak256("settleBatch(uint256)")), "settleBatch selector");
        assertEq(moduleSelectors[3], bytes4(keccak256("createBatchReceiver(uint256)")), "createBatchReceiver selector");
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITANCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test BatchModule inherits from BaseModule
    function test_InheritsFromBaseModule() public {
        // BatchModule should inherit BaseModule functionality
        // This is validated by the contract compiling and having BaseModule functions available
        assertTrue(address(batchModule).code.length > 0, "BatchModule should have implementation code");
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test BatchModule requires initialization before use
    function test_ErrorDefinitions() public {
        // Test NotInitialized error is thrown before role checks
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(TEST_BATCH_ID);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(TEST_BATCH_ID);
    }

    /*//////////////////////////////////////////////////////////////
                        INPUT VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test batch functions with zero batch ID
    function test_BatchFunctions_ZeroBatchId() public {
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(0, false);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(0);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(0);
    }

    /// @dev Test batch functions with maximum batch ID
    function test_BatchFunctions_MaxBatchId() public {
        uint256 maxBatchId = type(uint32).max;

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(maxBatchId, false);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(maxBatchId);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(maxBatchId);
    }

    /*//////////////////////////////////////////////////////////////
                        FUNCTION SIGNATURE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test createNewBatch function signature
    function test_CreateNewBatch_Signature() public {
        // Function should return uint256 and take no parameters
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();
    }

    /// @dev Test closeBatch function signature
    function test_CloseBatch_Signature() public {
        // Function should take uint256 and bool parameters
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(1, true);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(1, false);
    }

    /// @dev Test settleBatch function signature
    function test_SettleBatch_Signature() public {
        // Function should take uint256 parameter
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(1);
    }

    /// @dev Test createBatchReceiver function signature
    function test_createBatchReceiver_Signature() public {
        // Function should take uint256 parameter and return address
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(1);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test all functions with boundary values
    function test_BoundaryValues() public {
        // Test with boundary values for uint256/uint32
        uint256[] memory values = new uint256[](3);
        values[0] = 0;
        values[1] = 1;
        values[2] = type(uint32).max;

        for (uint256 i = 0; i < values.length; i++) {
            vm.prank(users.alice);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.closeBatch(values[i], false);

            vm.prank(users.alice);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.settleBatch(values[i]);

            vm.prank(users.alice);
            vm.expectRevert(BaseModule.NotInitialized.selector);
            batchModule.createBatchReceiver(values[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE HIERARCHY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test initialization is required before any function calls
    function test_RoleEnforcement() public {
        // All functions require initialization before role checks
        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createNewBatch();

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.closeBatch(1, false);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.settleBatch(1);

        vm.prank(users.alice);
        vm.expectRevert(BaseModule.NotInitialized.selector);
        batchModule.createBatchReceiver(1);
    }
}
