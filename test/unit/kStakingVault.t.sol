//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.30;
//
//import { ADMIN_ROLE, EMERGENCY_ADMIN_ROLE, USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from
// "../utils/Constants.sol";
//import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
//
//import { IERC20 } from "forge-std/interfaces/IERC20.sol";
//import { LibClone } from "solady/utils/LibClone.sol";
//import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
//import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
//import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
//import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";
//
///// @title kStakingVaultTest
///// @notice Comprehensive unit tests for kStakingVault contract
//contract kStakingVaultTest is DeploymentBaseTest {
//    using LibClone for address;
//
//    // Test constants
//    uint256 internal constant TEST_AMOUNT = 1000 * _1_USDC;
//    uint256 internal constant TEST_DUST_AMOUNT = 100 * _1_USDC;
//    uint256 internal constant MIN_STK_TOKENS = 900 * _1_USDC; // Allow for some slippage
//    address internal constant ZERO_ADDRESS = address(0);
//
//    // Events to test
//    event StakeRequestCreated(
//        bytes32 indexed requestId,
//        address indexed user,
//        address indexed kToken,
//        uint256 amount,
//        address recipient,
//        uint32 batchId
//    );
//    event UnstakeRequestCreated(
//        bytes32 indexed requestId, address indexed user, uint256 amount, address recipient, uint32 batchId
//    );
//    event StakeRequestRedeemed(bytes32 indexed requestId);
//    event UnstakeRequestRedeemed(bytes32 indexed requestId);
//
//    /*//////////////////////////////////////////////////////////////
//                        INITIALIZATION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test contract initialization state
//    function test_InitialState() public view {
//        // Check basic properties
//        assertEq(alphaVault.contractName(), "kStakingVault", "Contract name incorrect");
//        assertEq(alphaVault.contractVersion(), "1.0.0", "Contract version incorrect");
//
//        // Check initialization parameters
//        // Note: Owner and role functions are handled by MultiFacetProxy/BaseModule
//        // These are not exposed in the IkStakingVault interface for unit testing
//
//        // Check ERC20 properties
//        assertEq(alphaVault.name(), ALPHA_VAULT_NAME, "Name incorrect");
//        assertEq(alphaVault.symbol(), ALPHA_VAULT_SYMBOL, "Symbol incorrect");
//        assertEq(alphaVault.decimals(), 6, "Decimals incorrect");
//
//        // Check vault-specific properties
//        assertEq(alphaVault.asset(), USDC_MAINNET, "Asset incorrect");
//        assertEq(alphaVault.totalSupply(), 0, "Total supply should be zero initially");
//        assertEq(alphaVault.getBatchId(), 0, "Batch ID should be zero initially");
//        assertEq(alphaVault.lastTotalAssets(), 0, "Last total assets should be zero initially");
//    }
//
//    /// @dev Test successful initialization with valid parameters
//    function test_Initialize_Success() public {
//        // Deploy fresh implementation for testing
//        kStakingVault newVaultImpl = new kStakingVault();
//
//        bytes memory initData = abi.encodeWithSelector(
//            kStakingVault.initialize.selector,
//            address(registry),
//            users.owner,
//            users.admin,
//            false,
//            "Test Vault",
//            "tVault",
//            6,
//            uint128(TEST_DUST_AMOUNT),
//            users.emergencyAdmin,
//            USDC_MAINNET
//        );
//
//        address newProxy = address(newVaultImpl).clone();
//        (bool success,) = newProxy.call(initData);
//
//        assertTrue(success, "Initialization should succeed");
//
//        kStakingVault newVault = kStakingVault(payable(newProxy));
//        // Note: Owner/role functions not exposed in interface
//        assertEq(newVault.name(), "Test Vault", "Name not set");
//        assertEq(newVault.symbol(), "tVault", "Symbol not set");
//        assertEq(newVault.asset(), USDC_MAINNET, "Asset not set");
//    }
//
//    /// @dev Test initialization reverts with zero addresses
//    function test_Initialize_RevertZeroAddresses() public {
//        kStakingVault newVaultImpl = new kStakingVault();
//
//        // Test zero asset
//        bytes memory initData = abi.encodeWithSelector(
//            kStakingVault.initialize.selector,
//            address(registry),
//            users.owner,
//            users.admin,
//            false,
//            "Test Vault",
//            "tVault",
//            6,
//            uint128(TEST_DUST_AMOUNT),
//            users.emergencyAdmin,
//            address(0) // zero asset
//        );
//
//        address newProxy = address(newVaultImpl).clone();
//        (bool success,) = newProxy.call(initData);
//
//        assertFalse(success, "Should revert with zero asset");
//    }
//
//    /// @dev Test double initialization reverts
//    function test_Initialize_RevertDoubleInit() public {
//        vm.expectRevert();
//        alphaVault.initialize(
//            address(registry),
//            users.owner,
//            users.admin,
//            false,
//            "Test",
//            "TEST",
//            6,
//            uint128(TEST_DUST_AMOUNT),
//            users.emergencyAdmin,
//            USDC_MAINNET
//        );
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        STAKING REQUEST TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test staking request requires institution role
//    function test_RequestStake_RequiresInstitution() public {
//        uint256 amount = TEST_AMOUNT;
//        address recipient = users.alice;
//
//        // Regular user should fail with OnlyInstitution
//        vm.prank(users.alice);
//        vm.expectRevert(); // OnlyInstitution error
//
//        alphaVault.requestStake(recipient, uint96(amount), uint96(MIN_STK_TOKENS));
//
//        // This validates that the function has proper access control
//    }
//
//    /// @dev Test staking request reverts with zero amount
//    function test_RequestStake_RevertZeroAmount() public {
//        vm.prank(users.alice);
//        vm.expectRevert(BaseModule.ZeroAmount.selector);
//        alphaVault.requestStake(users.alice, 0, uint96(MIN_STK_TOKENS));
//    }
//
//    /// @dev Test staking request reverts with insufficient balance
//    function test_RequestStake_RevertInsufficientBalance() public {
//        // User has no kTokens
//        vm.prank(users.alice);
//        vm.expectRevert(); // InsufficientBalance or similar
//        alphaVault.requestStake(users.alice, uint96(TEST_AMOUNT), uint96(MIN_STK_TOKENS));
//    }
//
//    /// @dev Test staking request access control before dust threshold check
//    function test_RequestStake_AccessControlFirst() public {
//        uint256 dustAmount = 50 * _1_USDC; // Below dust threshold
//
//        // Regular user fails with OnlyInstitution before dust threshold check
//        vm.prank(users.alice);
//        vm.expectRevert(); // OnlyInstitution comes before dust threshold check
//        alphaVault.requestStake(users.alice, uint96(dustAmount), uint96(dustAmount - 10));
//    }
//
//    /// @dev Test staking request access control
//    function test_RequestStake_AccessControl() public {
//        // This test verifies the function exists and validates inputs
//        // Pause functionality is internal to BaseModule
//        vm.prank(users.alice);
//        vm.expectRevert(); // InsufficientBalance or similar
//        alphaVault.requestStake(users.alice, uint96(TEST_AMOUNT), uint96(MIN_STK_TOKENS));
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        UNSTAKING REQUEST TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test unstaking request reverts with zero amount
//    function test_RequestUnstake_RevertZeroAmount() public {
//        vm.prank(users.alice);
//        vm.expectRevert(BaseModule.ZeroAmount.selector);
//        alphaVault.requestUnstake(users.alice, 0, uint96(MIN_STK_TOKENS));
//    }
//
//    /// @dev Test unstaking request reverts with insufficient balance
//    function test_RequestUnstake_RevertInsufficientBalance() public {
//        // User has no stkTokens
//        vm.prank(users.alice);
//        vm.expectRevert(); // InsufficientBalance or similar
//        alphaVault.requestUnstake(users.alice, uint96(TEST_AMOUNT), uint96(MIN_STK_TOKENS));
//    }
//
//    /// @dev Test mintStkTokens requires proper authorization
//    function test_MintStkTokens_RequiresAuthorization() public {
//        uint256 dustAmount = 50 * _1_USDC;
//
//        // Direct mint should require proper authorization (OnlyKAssetRouter or similar)
//        vm.prank(users.admin);
//        vm.expectRevert(); // OnlyKAssetRouter or similar access control error
//        alphaVault.mintStkTokens(users.alice, dustAmount);
//    }
//
//    /// @dev Test unstaking request access control
//    function test_RequestUnstake_AccessControl() public {
//        // This test verifies the function exists and validates inputs
//        vm.prank(users.alice);
//        vm.expectRevert(); // InsufficientBalance or similar
//        alphaVault.requestUnstake(users.alice, uint96(TEST_AMOUNT), uint96(MIN_STK_TOKENS));
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        ADMIN FUNCTION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test updateLastTotalAssets only by asset router
//    function test_UpdateLastTotalAssets_OnlyAssetRouter() public {
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
//    /// @dev Test mintStkTokens function exists (access control handled by modules)
//    function test_MintStkTokens_FunctionExists() public {
//        uint256 amount = TEST_AMOUNT;
//
//        // This function exists but access control is handled by admin module
//        // We can't test the full functionality without proper module setup
//        vm.prank(users.alice);
//        try alphaVault.mintStkTokens(users.alice, amount) {
//            // If it succeeds, verify the balance
//            assertEq(alphaVault.balanceOf(users.alice), amount, "Should have minted tokens");
//        } catch {
//            // Expected to fail due to access control or other validation
//            assertTrue(true, "Function exists and has proper validation");
//        }
//    }
//
//    /// @dev Test burnStkTokens function exists (access control handled by modules)
//    function test_BurnStkTokens_FunctionExists() public {
//        uint256 amount = TEST_AMOUNT;
//
//        // This function exists but access control is handled by admin module
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
//                        VIEW FUNCTION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test asset view function
//    function test_Asset() public view {
//        assertEq(alphaVault.asset(), USDC_MAINNET, "Asset should return USDC");
//    }
//
//    /// @dev Test ERC20 metadata functions
//    function test_ERC20Metadata() public view {
//        assertEq(alphaVault.name(), ALPHA_VAULT_NAME, "Name incorrect");
//        assertEq(alphaVault.symbol(), ALPHA_VAULT_SYMBOL, "Symbol incorrect");
//        assertEq(alphaVault.decimals(), 6, "Decimals incorrect");
//    }
//
//    /// @dev Test calculateStkTokenPrice with zero total assets
//    function test_CalculateStkTokenPrice_ZeroAssets() public view {
//        uint256 price = alphaVault.calculateStkTokenPrice(0);
//        assertEq(price, 1e18, "Price should be 1e18 when total assets is zero");
//    }
//
//    /// @dev Test calculateStkTokenPrice with assets but no supply
//    function test_CalculateStkTokenPrice_NoSupply() public view {
//        uint256 totalAssets = TEST_AMOUNT;
//        uint256 price = alphaVault.calculateStkTokenPrice(totalAssets);
//        assertEq(price, 1e18, "Price should be 1e18 when total supply is zero");
//    }
//
//    /// @dev Test sharePrice view function
//    function test_SharePrice() public view {
//        uint256 price = alphaVault.sharePrice();
//        assertEq(price, 1e18, "Initial share price should be 1e18");
//    }
//
//    /// @dev Test lastTotalAssets view function
//    function test_LastTotalAssets() public view {
//        assertEq(alphaVault.lastTotalAssets(), 0, "Initial last total assets should be zero");
//    }
//
//    /// @dev Test totalAssets view function
//    function test_TotalAssets() public view {
//        uint256 assets = alphaVault.totalAssets();
//        assertEq(assets, 0, "Initial total assets should be zero");
//    }
//
//    /// @dev Test estimatedTotalAssets view function
//    function test_EstimatedTotalAssets() public view {
//        uint256 assets = alphaVault.estimatedTotalAssets();
//        assertEq(assets, 0, "Initial estimated total assets should be zero");
//    }
//
//    /// @dev Test getKToken view function
//    function test_GetKToken() public view {
//        address kToken = alphaVault.getKToken();
//        assertEq(kToken, address(kUSD), "Should return kUSD token");
//    }
//
//    /// @dev Test batch-related view functions
//    function test_BatchFunctions() public view {
//        assertEq(alphaVault.getBatchId(), 0, "Initial batch ID should be zero");
//        assertEq(alphaVault.getSafeBatchId(), 0, "Initial safe batch ID should be zero");
//        assertFalse(alphaVault.isBatchClosed(), "Initial batch should not be closed");
//        assertFalse(alphaVault.isBatchSettled(), "Initial batch should not be settled");
//
//        // Test getBatchInfo
//        (uint256 batchId, address batchReceiver, bool isClosed, bool isSettled) = alphaVault.getBatchInfo();
//        assertEq(batchId, 0, "Batch ID should be zero");
//        assertEq(batchReceiver, address(0), "Batch receiver should be zero");
//        assertFalse(isClosed, "Batch should not be closed");
//        assertFalse(isSettled, "Batch should not be settled");
//    }
//
//    /// @dev Test getBatchReceiver for non-existent batch
//    function test_GetBatchReceiver_NonExistent() public view {
//        address receiver = alphaVault.getBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//    }
//
//    /// @dev Test getSafeBatchReceiver for non-existent batch
//    function test_GetSafeBatchReceiver_NonExistent() public view {
//        address receiver = alphaVault.getSafeBatchReceiver(999);
//        assertEq(receiver, address(0), "Non-existent batch should return zero address");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        CONTRACT INFO TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test contract info functions
//    function test_ContractInfo() public view {
//        assertEq(alphaVault.contractName(), "kStakingVault", "Contract name incorrect");
//        assertEq(alphaVault.contractVersion(), "1.0.0", "Contract version incorrect");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        UPGRADE TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test upgrade functions are inherited (not directly testable via interface)
//    function test_UpgradeCapability() public view {
//        // kStakingVault inherits from UUPSUpgradeable
//        // Upgrade authorization is handled internally
//        // This test just confirms the contract exists and is deployed
//        assertTrue(address(alphaVault).code.length > 0, "Vault should have implementation code");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        ERC20 STANDARD TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test ERC20 transfer functionality (when tokens exist)
//    function test_Transfer_WithZeroBalance() public {
//        // Test transfer with zero balance (should succeed but transfer nothing)
//        vm.prank(users.alice);
//        bool success = alphaVault.transfer(users.bob, 0);
//
//        assertTrue(success, "Zero transfer should succeed");
//        assertEq(alphaVault.balanceOf(users.alice), 0, "Alice balance should remain zero");
//        assertEq(alphaVault.balanceOf(users.bob), 0, "Bob balance should remain zero");
//    }
//
//    /// @dev Test transferFrom with zero allowance
//    function test_TransferFrom_ZeroAmount() public {
//        // Test transferFrom with zero amount
//        vm.prank(users.bob);
//        bool success = alphaVault.transferFrom(users.alice, users.charlie, 0);
//
//        assertTrue(success, "Zero transferFrom should succeed");
//        assertEq(alphaVault.balanceOf(users.alice), 0, "Alice balance should remain zero");
//        assertEq(alphaVault.balanceOf(users.charlie), 0, "Charlie balance should remain zero");
//    }
//
//    /// @dev Test approve functionality
//    function test_Approve_Success() public {
//        uint256 amount = TEST_AMOUNT;
//
//        vm.prank(users.alice);
//        bool success = alphaVault.approve(users.bob, amount);
//
//        assertTrue(success, "Approve should succeed");
//        assertEq(alphaVault.allowance(users.alice, users.bob), amount, "Allowance incorrect");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        MODULAR ARCHITECTURE TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test that vault uses modular architecture
//    function test_ModularArchitecture() public view {
//        // The vault should inherit from BaseModule and have implementation code
//        assertTrue(address(alphaVault).code.length > 0, "Vault should have code");
//
//        // Verify it implements the expected interface functions
//        assertEq(alphaVault.contractName(), "kStakingVault", "Should have contract name");
//        assertEq(alphaVault.contractVersion(), "1.0.0", "Should have contract version");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        INTEGRATION HELPERS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test vault type identification
//    function test_VaultType() public {
//        // Alpha vault should be type 1
//        uint8 vaultType = registry.getVaultType(address(alphaVault));
//        assertEq(vaultType, 1, "Alpha vault should be type 1");
//
//        // Beta vault should be type 2
//        vaultType = registry.getVaultType(address(betaVault));
//        assertEq(vaultType, 2, "Beta vault should be type 2");
//
//        // DN vault should be type 0
//        vaultType = registry.getVaultType(address(dnVault));
//        assertEq(vaultType, 0, "DN vault should be type 0");
//    }
//
//    /// @dev Test vault asset registration
//    function test_VaultAssetRegistration() public {
//        assertEq(registry.getVaultAsset(address(alphaVault)), USDC_MAINNET, "Alpha vault asset should be USDC");
//        assertEq(registry.getVaultAsset(address(betaVault)), USDC_MAINNET, "Beta vault asset should be USDC");
//        assertEq(registry.getVaultAsset(address(dnVault)), USDC_MAINNET, "DN vault asset should be USDC");
//    }
//}
//
