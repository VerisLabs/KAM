// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";
//import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
//
//import { IERC20 } from "forge-std/interfaces/IERC20.sol";
//import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
//import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
//import { BaseVaultModule } from "src/kStakingVault/modules/BaseVaultModule.sol";
//import { BatchModule } from "src/kStakingVault/modules/BatchModule.sol";
//import { ClaimModule } from "src/kStakingVault/modules/ClaimModule.sol";
//
///// @title kStakingVaultModulesTest
///// @notice Tests kStakingVault module integration through interface
//contract kStakingVaultModulesTest is DeploymentBaseTest {
//    // Test constants
//    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
//    uint32 internal constant TEST_BATCH_ID = 1;
//    uint256 internal constant TEST_REQUEST_ID = 1;
//
//    IkStakingVault internal vaultInterface;
//
//    function setUp() public override {
//        super.setUp();
//
//        // Cast alphaVault to interface for testing
//        vaultInterface = IkStakingVault(address(alphaVault));
//
//        // Add module functions to alphaVault
//        _integrateModules();
//    }
//
//    /// @dev Integrate modules into alphaVault by registering their functions
//    function _integrateModules() internal {
//        // Get module selectors
//        bytes4[] memory claimSelectors = claimModule.selectors();
//        bytes4[] memory batchSelectors = batchModule.selectors();
//
//        // Add ClaimModule functions (use owner as admin might not have proxy admin role)
//        vm.prank(users.owner);
//        alphaVault.addFunctions(claimSelectors, address(claimModule), false);
//
//        // Add BatchModule functions
//        vm.prank(users.owner);
//        alphaVault.addFunctions(batchSelectors, address(batchModule), false);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        CLAIM MODULE TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test claimStakedShares through interface
//    function test_ClaimStakedShares_Interface() public {
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(TEST_BATCH_ID, TEST_REQUEST_ID);
//    }
//
//    /// @dev Test claimUnstakedAssets through interface
//    function test_ClaimUnstakedAssets_Interface() public {
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimUnstakedAssets(TEST_BATCH_ID, TEST_REQUEST_ID);
//    }
//
//    /// @dev Test claim functions with different users
//    function test_ClaimFunctions_DifferentUsers() public {
//        address[] memory testUsers = new address[](3);
//        testUsers[0] = users.alice;
//        testUsers[1] = users.bob;
//        testUsers[2] = users.institution;
//
//        for (uint256 i = 0; i < testUsers.length; i++) {
//            vm.prank(testUsers[i]);
//            vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//            vaultInterface.claimStakedShares(1, 1);
//
//            vm.prank(testUsers[i]);
//            vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//            vaultInterface.claimUnstakedAssets(1, 1);
//        }
//    }
//
//    /// @dev Test claim functions are payable
//    function test_ClaimFunctions_Payable() public {
//        vm.deal(users.alice, 1 ether);
//
//        vm.prank(users.alice);
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares{ value: 0.1 ether }(1, 1);
//
//        vm.prank(users.alice);
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimUnstakedAssets{ value: 0.1 ether }(1, 1);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        BATCH MODULE TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test createBatchReceiver through interface
//    function test_createBatchReceiver_Interface() public {
//        // Non-asset router should fail with access control
//        vm.prank(users.alice);
//        vm.expectRevert(BaseVaultModule.OnlyKAssetRouter.selector);
//        vaultInterface.createBatchReceiver(TEST_BATCH_ID);
//    }
//
//    /// @dev Test createBatchReceiver with asset router
//    function test_createBatchReceiver_AssetRouter() public {
//        vm.prank(address(assetRouter));
//        address receiver = vaultInterface.createBatchReceiver(TEST_BATCH_ID);
//
//        assertTrue(receiver != address(0), "Should deploy batch receiver");
//
//        // Should be idempotent
//        vm.prank(address(assetRouter));
//        address receiver2 = vaultInterface.createBatchReceiver(TEST_BATCH_ID);
//        assertEq(receiver, receiver2, "Should return same receiver");
//    }
//
//    /// @dev Test createBatchReceiver access control
//    function test_createBatchReceiver_AccessControl() public {
//        address[] memory nonRouters = new address[](4);
//        nonRouters[0] = users.alice;
//        nonRouters[1] = users.admin;
//        nonRouters[2] = users.owner;
//        nonRouters[3] = users.institution;
//
//        for (uint256 i = 0; i < nonRouters.length; i++) {
//            vm.prank(nonRouters[i]);
//            vm.expectRevert(BaseVaultModule.OnlyKAssetRouter.selector);
//            vaultInterface.createBatchReceiver(1);
//        }
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        INTEGRATION VALIDATION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that modules work together with existing functionality
//    function test_ModulesWithExistingFunctions() public {
//        // Test existing functions still work
//        assertEq(vaultInterface.getBatchId(), 0, "Existing functions should work");
//        assertEq(vaultInterface.asset(), USDC_MAINNET, "Asset function should work");
//
//        // Test module functions work
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(1, 1);
//
//        vm.prank(address(assetRouter));
//        address receiver = vaultInterface.createBatchReceiver(1);
//        assertTrue(receiver != address(0), "Module functions should work");
//    }
//
//    /// @dev Test that interface functions have correct signatures
//    function test_InterfaceFunctionSignatures() public {
//        // Test claim functions (payable, takes 2 uint256s)
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(1, 1);
//
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimUnstakedAssets(1, 1);
//
//        // Test createBatchReceiver (takes uint256, returns address)
//        vm.prank(address(assetRouter));
//        address result = vaultInterface.createBatchReceiver(1);
//        assertTrue(result != address(0), "Should return address");
//    }
//
//    /// @dev Test error handling through interface
//    function test_InterfaceErrorHandling() public {
//        // Should get proper module errors, not interface errors
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(999, 999);
//
//        vm.expectRevert(BaseVaultModule.OnlyKAssetRouter.selector);
//        vaultInterface.createBatchReceiver(999);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        EDGE CASE TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test functions with edge case inputs
//    function test_EdgeCaseInputs() public {
//        // Test with large but safe values (uint32 max)
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(type(uint32).max, type(uint256).max);
//
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimUnstakedAssets(type(uint32).max, type(uint256).max);
//
//        // Test createBatchReceiver with uint32 max (safe casting)
//        vm.prank(address(assetRouter));
//        address receiver = vaultInterface.createBatchReceiver(type(uint32).max);
//        assertTrue(receiver != address(0), "Should handle large batch IDs");
//    }
//
//    /// @dev Test functions with zero values
//    function test_ZeroValueInputs() public {
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(0, 0);
//
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimUnstakedAssets(0, 0);
//
//        vm.prank(address(assetRouter));
//        address receiver = vaultInterface.createBatchReceiver(0);
//        assertTrue(receiver != address(0), "Should handle zero batch ID");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        PROXY FUNCTIONALITY TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that only integrated vault has module functions
//    function test_OnlyIntegratedVaultHasModules() public {
//        // alphaVault should have integrated functions
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(1, 1);
//
//        // betaVault should not have these functions
//        IkStakingVault betaInterface = IkStakingVault(address(betaVault));
//        vm.expectRevert(); // Should revert with "Function not found" or similar
//        betaInterface.claimStakedShares(1, 1);
//
//        // dnVault should not have these functions
//        IkStakingVault dnInterface = IkStakingVault(address(dnVault));
//        vm.expectRevert(); // Should revert with "Function not found" or similar
//        dnInterface.claimStakedShares(1, 1);
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        GAS EFFICIENCY TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that integrated functions have reasonable gas usage
//    function test_GasEfficiency() public {
//        // Test claim function gas usage
//        uint256 gasStart = gasleft();
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(1, 1);
//        uint256 gasUsed = gasStart - gasleft();
//
//        assertTrue(gasUsed < 100_000, "Claim should be gas efficient");
//
//        // Test batch receiver deployment gas usage
//        gasStart = gasleft();
//        vm.prank(address(assetRouter));
//        vaultInterface.createBatchReceiver(999);
//        gasUsed = gasStart - gasleft();
//
//        assertTrue(gasUsed < 500_000, "Batch deployment should be reasonably efficient");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        MODULE SELECTOR VALIDATION
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that correct selectors are registered
//    function test_ModuleSelectors() public view {
//        // Test ClaimModule selectors
//        bytes4[] memory claimSelectors = claimModule.selectors();
//        assertEq(claimSelectors.length, 2, "ClaimModule should have 2 selectors");
//        assertEq(claimSelectors[0], IkStakingVault.claimStakedShares.selector, "claimStakedShares selector");
//        assertEq(claimSelectors[1], IkStakingVault.claimUnstakedAssets.selector, "claimUnstakedAssets selector");
//
//        // Test BatchModule selectors
//        bytes4[] memory batchSelectors = batchModule.selectors();
//        assertEq(batchSelectors.length, 4, "BatchModule should have 4 selectors");
//        // Note: BatchModule has functions not in IkStakingVault interface
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        COMPREHENSIVE FUNCTIONALITY TEST
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test complete module integration functionality
//    function test_CompleteModuleIntegration() public {
//        // 1. Test that existing vault functions work
//        assertEq(vaultInterface.name(), ALPHA_VAULT_NAME, "Vault name should work");
//        assertEq(vaultInterface.symbol(), ALPHA_VAULT_SYMBOL, "Vault symbol should work");
//        assertEq(vaultInterface.decimals(), 6, "Vault decimals should work");
//        assertEq(vaultInterface.asset(), USDC_MAINNET, "Vault asset should work");
//
//        // 2. Test that module functions are accessible
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimStakedShares(1, 1);
//
//        vm.expectRevert(ClaimModule.BatchNotSettled.selector);
//        vaultInterface.claimUnstakedAssets(1, 1);
//
//        // 3. Test that access-controlled module functions work for authorized users
//        vm.prank(address(assetRouter));
//        address receiver = vaultInterface.createBatchReceiver(1);
//        assertTrue(receiver != address(0), "Asset router should be able to deploy receivers");
//
//        // 4. Test that access-controlled functions fail for unauthorized users
//        vm.prank(users.alice);
//        vm.expectRevert(BaseVaultModule.OnlyKAssetRouter.selector);
//        vaultInterface.createBatchReceiver(2);
//
//        // 5. Test that the integration doesn't break existing functionality
//        assertEq(vaultInterface.getBatchId(), 0, "Batch ID should still work");
//        assertEq(vaultInterface.lastTotalAssets(), 0, "Last total assets should still work");
//        assertTrue(vaultInterface.sharePrice() > 0, "Share price should still work");
//    }
//}
//
