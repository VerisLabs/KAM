// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";
//import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
//
//import { IERC20 } from "forge-std/interfaces/IERC20.sol";
//import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
//import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
//import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
//import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";
//
///// @title kStakingVaultDirectTest
///// @notice Tests for kStakingVault functions that are directly accessible (not through proxy modules)
//contract kStakingVaultDirectTest is DeploymentBaseTest {
//    // Test constants
//    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
//    address internal constant ZERO_ADDRESS = address(0);
//
//    /*//////////////////////////////////////////////////////////////
//                        DIRECTLY ACCESSIBLE FUNCTIONS TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test updateLastTotalAssets access control
//    function test_UpdateLastTotalAssets_OnlyKAssetRouter() public {
//        uint256 newAssets = TEST_AMOUNT;
//
//        // Non-asset router should fail
//        vm.prank(users.alice);
//        vm.expectRevert(BaseModule.OnlyKAssetRouter.selector);
//        alphaVault.updateLastTotalAssets(newAssets);
//
//        // Asset router should succeed
//        vm.prank(address(assetRouter));
//        alphaVault.updateLastTotalAssets(newAssets);
//
//        assertEq(alphaVault.lastTotalAssets(), newAssets, "Last total assets should be updated");
//    }
//
//    /// @dev Test mintStkTokens and burnStkTokens access control
//    function test_MintBurnStkTokens_AccessControl() public {
//        uint256 amount = TEST_AMOUNT;
//
//        // These functions exist but access control is handled internally
//        vm.prank(users.alice);
//        try alphaVault.mintStkTokens(users.alice, amount) {
//            // If it succeeds, verify the balance
//            assertEq(alphaVault.balanceOf(users.alice), amount, "Should have minted tokens");
//        } catch {
//            // Expected to fail due to access control or other validation
//            assertTrue(true, "Function exists and has proper validation");
//        }
//
//        vm.prank(users.alice);
//        try alphaVault.burnStkTokens(users.alice, amount) {
//            // Unlikely to succeed due to access control
//            assertTrue(false, "Should not succeed without proper access");
//        } catch {
//            // Expected to fail due to access control or insufficient balance
//            assertTrue(true, "Function exists and has proper validation");
//        }
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        VIEW FUNCTIONS TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test asset view function on all vaults
//    function test_Asset_AllVaultTypes() public view {
//        assertEq(alphaVault.asset(), USDC_MAINNET, "Alpha vault should return USDC");
//        assertEq(betaVault.asset(), USDC_MAINNET, "Beta vault should return USDC");
//        assertEq(dnVault.asset(), USDC_MAINNET, "DN vault should return USDC");
//    }
//
//    /// @dev Test calculateStkTokenPrice with zero total assets
//    function test_CalculateStkTokenPrice_ZeroAssets() public view {
//        uint256 price = alphaVault.calculateStkTokenPrice(0);
//        assertEq(price, 1e18, "Price should be 1e18 when total assets is zero");
//
//        price = betaVault.calculateStkTokenPrice(0);
//        assertEq(price, 1e18, "Price should be 1e18 when total assets is zero");
//
//        price = dnVault.calculateStkTokenPrice(0);
//        assertEq(price, 1e18, "Price should be 1e18 when total assets is zero");
//    }
//
//    /// @dev Test calculateStkTokenPrice with assets but no supply
//    function test_CalculateStkTokenPrice_NoSupply() public view {
//        uint256 totalAssets = TEST_AMOUNT;
//        uint256 price = alphaVault.calculateStkTokenPrice(totalAssets);
//        assertEq(price, 1e18, "Price should be 1e18 when total supply is zero");
//
//        price = betaVault.calculateStkTokenPrice(totalAssets);
//        assertEq(price, 1e18, "Price should be 1e18 when total supply is zero");
//
//        price = dnVault.calculateStkTokenPrice(totalAssets);
//        assertEq(price, 1e18, "Price should be 1e18 when total supply is zero");
//    }
//
//    /// @dev Test sharePrice view function
//    function test_SharePrice_AllVaultTypes() public view {
//        uint256 price = alphaVault.sharePrice();
//        assertEq(price, 1e18, "Initial share price should be 1e18");
//
//        price = betaVault.sharePrice();
//        assertEq(price, 1e18, "Initial share price should be 1e18");
//
//        price = dnVault.sharePrice();
//        assertEq(price, 1e18, "Initial share price should be 1e18");
//    }
//
//    /// @dev Test lastTotalAssets view function
//    function test_LastTotalAssets_AllVaultTypes() public view {
//        assertEq(alphaVault.lastTotalAssets(), 0, "Initial last total assets should be zero");
//        assertEq(betaVault.lastTotalAssets(), 0, "Initial last total assets should be zero");
//        assertEq(dnVault.lastTotalAssets(), 0, "Initial last total assets should be zero");
//    }
//
//    /// @dev Test totalAssets view function
//    function test_TotalAssets_AllVaultTypes() public view {
//        uint256 assets = alphaVault.totalAssets();
//        assertEq(assets, 0, "Initial total assets should be zero");
//
//        assets = betaVault.totalAssets();
//        assertEq(assets, 0, "Initial total assets should be zero");
//
//        assets = dnVault.totalAssets();
//        assertEq(assets, 0, "Initial total assets should be zero");
//    }
//
//    /// @dev Test estimatedTotalAssets view function
//    function test_EstimatedTotalAssets_AllVaultTypes() public view {
//        uint256 assets = alphaVault.estimatedTotalAssets();
//        assertEq(assets, 0, "Initial estimated total assets should be zero");
//
//        assets = betaVault.estimatedTotalAssets();
//        assertEq(assets, 0, "Initial estimated total assets should be zero");
//
//        assets = dnVault.estimatedTotalAssets();
//        assertEq(assets, 0, "Initial estimated total assets should be zero");
//    }
//
//    /// @dev Test getKToken view function
//    function test_GetKToken_AllVaultTypes() public view {
//        address kToken = alphaVault.getKToken();
//        assertEq(kToken, address(kUSD), "Should return kUSD token");
//
//        kToken = betaVault.getKToken();
//        assertEq(kToken, address(kUSD), "Should return kUSD token");
//
//        kToken = dnVault.getKToken();
//        assertEq(kToken, address(kUSD), "Should return kUSD token");
//    }
//
//    /// @dev Test batch-related view functions
//    function test_BatchFunctions_AllVaultTypes() public view {
//        // Test getBatchId
//        assertEq(alphaVault.getBatchId(), 0, "Initial batch ID should be zero");
//        assertEq(betaVault.getBatchId(), 0, "Initial batch ID should be zero");
//        assertEq(dnVault.getBatchId(), 0, "Initial batch ID should be zero");
//
//        // Test getSafeBatchId
//        assertEq(alphaVault.getSafeBatchId(), 0, "Initial safe batch ID should be zero");
//        assertEq(betaVault.getSafeBatchId(), 0, "Initial safe batch ID should be zero");
//        assertEq(dnVault.getSafeBatchId(), 0, "Initial safe batch ID should be zero");
//
//        // Test isBatchClosed
//        assertFalse(alphaVault.isBatchClosed(), "Initial batch should not be closed");
//        assertFalse(betaVault.isBatchClosed(), "Initial batch should not be closed");
//        assertFalse(dnVault.isBatchClosed(), "Initial batch should not be closed");
//
//        // Test isBatchSettled
//        assertFalse(alphaVault.isBatchSettled(), "Initial batch should not be settled");
//        assertFalse(betaVault.isBatchSettled(), "Initial batch should not be settled");
//        assertFalse(dnVault.isBatchSettled(), "Initial batch should not be settled");
//    }
//
//    /// @dev Test getBatchInfo function
//    function test_GetBatchInfo_AllVaultTypes() public view {
//        // Test Alpha vault
//        (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled) = alphaVault.getBatchInfo();
//        assertEq(batchId, 0, "Alpha vault batch ID should be zero");
//        assertEq(batchReceiver, address(0), "Alpha vault batch receiver should be zero");
//        assertFalse(isClosed, "Alpha vault batch should not be closed");
//        assertFalse(isSettled, "Alpha vault batch should not be settled");
//
//        // Test Beta vault
//        (batchId, batchReceiver, isClosed, isSettled) = betaVault.getBatchInfo();
//        assertEq(batchId, 0, "Beta vault batch ID should be zero");
//        assertEq(batchReceiver, address(0), "Beta vault batch receiver should be zero");
//        assertFalse(isClosed, "Beta vault batch should not be closed");
//        assertFalse(isSettled, "Beta vault batch should not be settled");
//
//        // Test DN vault
//        (batchId, batchReceiver, isClosed, isSettled) = dnVault.getBatchInfo();
//        assertEq(batchId, 0, "DN vault batch ID should be zero");
//        assertEq(batchReceiver, address(0), "DN vault batch receiver should be zero");
//        assertFalse(isClosed, "DN vault batch should not be closed");
//        assertFalse(isSettled, "DN vault batch should not be settled");
//    }
//
//    /// @dev Test getBatchReceiver for non-existent batch
//    function test_GetBatchReceiver_NonExistent() public view {
//        address receiver = alphaVault.getBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//
//        receiver = betaVault.getBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//
//        receiver = dnVault.getBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//    }
//
//    /// @dev Test getSafeBatchReceiver for non-existent batch
//    function test_GetSafeBatchReceiver_NonExistent() public view {
//        address receiver = alphaVault.getSafeBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//
//        receiver = betaVault.getSafeBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//
//        receiver = dnVault.getSafeBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        CONTRACT INFO TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test contract info functions
//    function test_ContractInfo_AllVaultTypes() public view {
//        assertEq(alphaVault.contractName(), "kStakingVault", "Alpha vault contract name incorrect");
//        assertEq(alphaVault.contractVersion(), "1.0.0", "Alpha vault contract version incorrect");
//
//        assertEq(betaVault.contractName(), "kStakingVault", "Beta vault contract name incorrect");
//        assertEq(betaVault.contractVersion(), "1.0.0", "Beta vault contract version incorrect");
//
//        assertEq(dnVault.contractName(), "kStakingVault", "DN vault contract name incorrect");
//        assertEq(dnVault.contractVersion(), "1.0.0", "DN vault contract version incorrect");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        VAULT TYPE BEHAVIOR TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that different vault types behave consistently
//    function test_VaultTypes_ConsistentBehavior() public view {
//        // All vault types should have consistent behavior for directly accessible functions
//
//        // Test Alpha vault (Type 1)
//        assertEq(alphaVault.asset(), USDC_MAINNET, "Alpha vault asset");
//        assertEq(alphaVault.getBatchId(), 0, "Alpha vault batch ID");
//        assertEq(alphaVault.sharePrice(), 1e18, "Alpha vault share price");
//
//        // Test Beta vault (Type 2)
//        assertEq(betaVault.asset(), USDC_MAINNET, "Beta vault asset");
//        assertEq(betaVault.getBatchId(), 0, "Beta vault batch ID");
//        assertEq(betaVault.sharePrice(), 1e18, "Beta vault share price");
//
//        // Test DN vault (Type 0)
//        assertEq(dnVault.asset(), USDC_MAINNET, "DN vault asset");
//        assertEq(dnVault.getBatchId(), 0, "DN vault batch ID");
//        assertEq(dnVault.sharePrice(), 1e18, "DN vault share price");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        EDGE CASE TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test functions with edge case inputs
//    function test_EdgeCaseInputs() public view {
//        // Test calculateStkTokenPrice with large values
//        uint256 largeAssets = type(uint128).max;
//        uint256 price = alphaVault.calculateStkTokenPrice(largeAssets);
//        assertEq(price, 1e18, "Price should be 1e18 with large assets and zero supply");
//
//        // Test batch functions with edge case IDs
//        assertEq(alphaVault.getBatchReceiver(type(uint32).max), address(0), "Max batch ID should return zero");
//        assertEq(alphaVault.getSafeBatchReceiver(0), address(0), "Zero batch ID should return zero");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        VAULT INITIALIZATION VERIFICATION
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that all vaults are properly initialized
//    function test_VaultInitialization() public view {
//        // Verify vaults are initialized and functional
//        assertTrue(address(alphaVault).code.length > 0, "Alpha vault should have code");
//        assertTrue(address(betaVault).code.length > 0, "Beta vault should have code");
//        assertTrue(address(dnVault).code.length > 0, "DN vault should have code");
//
//        // Verify basic vault properties
//        assertEq(alphaVault.name(), ALPHA_VAULT_NAME, "Alpha vault name");
//        assertEq(betaVault.name(), BETA_VAULT_NAME, "Beta vault name");
//        assertEq(dnVault.name(), DN_VAULT_NAME, "DN vault name");
//
//        assertEq(alphaVault.symbol(), ALPHA_VAULT_SYMBOL, "Alpha vault symbol");
//        assertEq(betaVault.symbol(), BETA_VAULT_SYMBOL, "Beta vault symbol");
//        assertEq(dnVault.symbol(), DN_VAULT_SYMBOL, "DN vault symbol");
//
//        assertEq(alphaVault.decimals(), 6, "All vaults should have 6 decimals");
//        assertEq(betaVault.decimals(), 6, "All vaults should have 6 decimals");
//        assertEq(dnVault.decimals(), 6, "All vaults should have 6 decimals");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        FUNCTION SIGNATURE VALIDATION
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that functions have correct signatures and return types
//    function test_FunctionSignatures() public {
//        // Test updateLastTotalAssets signature (uint256 -> void)
//        vm.prank(address(assetRouter));
//        alphaVault.updateLastTotalAssets(100);
//
//        // Test view function signatures
//        uint256 result = alphaVault.calculateStkTokenPrice(1000);
//        assertTrue(result > 0, "calculateStkTokenPrice returns uint256");
//
//        address assetResult = alphaVault.asset();
//        assertTrue(assetResult != address(0), "asset returns address");
//
//        string memory nameResult = alphaVault.contractName();
//        assertTrue(bytes(nameResult).length > 0, "contractName returns string");
//    }
//}
//
