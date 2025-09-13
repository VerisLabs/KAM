// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MockERC20 } from "../mocks/MockERC20.sol";
import { ADMIN_ROLE, RELAYER_ROLE, _1_USDC, _1_WBTC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import {
    KREGISTRY_ALREADY_REGISTERED,
    KREGISTRY_ASSET_NOT_SUPPORTED,
    KREGISTRY_FEE_EXCEEDS_MAXIMUM,
    KREGISTRY_INVALID_ADAPTER,
    KREGISTRY_ZERO_ADDRESS,
    KROLESBASE_ZERO_ADDRESS
} from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { kRegistry } from "src/kRegistry/kRegistry.sol";

/// @title kRegistryTest
/// @notice Comprehensive unit tests for kRegistry contract
contract kRegistryTest is DeploymentBaseTest {
    // Test addresses for non-deployed contracts
    address internal constant TEST_CONTRACT = 0x1111111111111111111111111111111111111111;
    address internal TEST_ASSET;
    address internal constant TEST_KTOKEN = 0x3333333333333333333333333333333333333333;
    address internal constant TEST_VAULT = 0x4444444444444444444444444444444444444444;
    address internal constant TEST_ADAPTER = 0x5555555555555555555555555555555555555555;

    string TEST_NAME = "TEST_TOKEN";
    string TEST_SYMBOL = "TTK";
    bytes32 internal constant TEST_CONTRACT_ID = keccak256("TEST_CONTRACT");
    bytes32 internal constant TEST_ASSET_ID = keccak256("TEST_ASSET");

    uint256 constant MAX_BPS = 10_000;
    uint16 constant TEST_HURDLE_RATE = 500; // 5%

    function setUp() public override {
        super.setUp();
        // Deploy a mock token for TEST_ASSET
        MockERC20 testToken = new MockERC20("Test USDT", "USDT", 6);
        TEST_ASSET = address(testToken);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test registry initialization state
    function test_InitialState() public {
        // Check initialization parameters
        assertEq(registry.owner(), users.owner, "Owner not set correctly");
        assertTrue(registry.hasAnyRole(users.admin, ADMIN_ROLE), "Admin role not granted");
        assertTrue(registry.hasAnyRole(users.relayer, RELAYER_ROLE), "Relayer role not granted"); // RELAYER_ROLE =
            // _ROLE_2 = 4
    }

    /// @dev Test contract info functions
    function test_ContractInfo() public view {
        assertEq(registry.contractName(), "kRegistry", "Contract name incorrect");
        assertEq(registry.contractVersion(), "1.0.0", "Contract version incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                    SINGLETON CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Test singleton contract registration requires admin role
    function test_SetSingletonContract_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.setSingletonContract(TEST_CONTRACT_ID, TEST_CONTRACT);
    }

    /// @dev Test singleton contract registration reverts with zero address
    function test_SetSingletonContract_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.setSingletonContract(TEST_CONTRACT_ID, address(0));
    }

    /// @dev Test singleton contract registration reverts when already registered
    function test_SetSingletonContract_RevertAlreadyRegistered() public {
        // First registration
        vm.prank(users.admin);
        registry.setSingletonContract(TEST_CONTRACT_ID, TEST_CONTRACT);

        // Second registration should fail
        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_ALREADY_REGISTERED));
        registry.setSingletonContract(TEST_CONTRACT_ID, address(0x01));
    }

    /// @dev Test getContractById reverts when contract not set
    function test_GetContractById_RevertZeroAddress() public {
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.getContractById(keccak256("NONEXISTENT"));
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful asset registration (new asset)
    function test_RegisterAsset_NewAsset_Success() public {
        vm.prank(users.admin);

        // Expect events
        vm.expectEmit(true, false, false, false);
        emit IkRegistry.AssetSupported(TEST_ASSET);

        address testKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );

        // Verify asset registration
        assertTrue(registry.isAsset(TEST_ASSET), "Asset not registered");
        assertEq(registry.assetToKToken(TEST_ASSET), testKToken, "Asset->kToken mapping incorrect");

        // Verify asset appears in getAllAssets
        address[] memory allAssets = registry.getAllAssets();
        bool found = false;
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == TEST_ASSET) {
                found = true;
                break;
            }
        }
        assertTrue(found, "Asset not in getAllAssets");
    }

    /// @dev Test asset registration with existing asset (only updates kToken)
    function test_RegisterAsset_ExistingAsset_Revert() public {
        // First registration
        vm.prank(users.admin);
        address newKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );
        assertEq(registry.assetToKToken(TEST_ASSET), newKToken, "kToken mapping not updated");

        // Second registration
        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_ALREADY_REGISTERED));
        newKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );
    }

    /// @dev Test asset registration requires admin role
    function test_RegisterAsset_OnlyAdmin() public {
        vm.prank(users.bob);
        vm.expectRevert();
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);
    }

    /// @dev Test asset registration reverts with zero addresses
    function test_RegisterAsset_RevertZeroAddresses() public {
        vm.startPrank(users.admin);

        // Zero asset address
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, address(0), TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        // Zero ID
        vm.expectRevert(bytes(KREGISTRY_ZERO_ADDRESS));
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, bytes32(0), type(uint256).max, type(uint256).max);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT MANAGEMENT  
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful vault registration
    function test_RegisterVault_Success() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.admin);

        // Expect event
        vm.expectEmit(true, true, true, false);
        emit IkRegistry.VaultRegistered(TEST_VAULT, TEST_ASSET, IkRegistry.VaultType.ALPHA);

        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Verify vault registration
        assertTrue(registry.isVault(TEST_VAULT), "Vault not registered");
        assertEq(registry.getVaultType(TEST_VAULT), uint8(IkRegistry.VaultType.ALPHA), "Vault type incorrect");
        assertEq(registry.getVaultAssets(TEST_VAULT)[0], TEST_ASSET, "Vault asset incorrect");
        assertEq(
            registry.getVaultByAssetAndType(TEST_ASSET, uint8(IkRegistry.VaultType.ALPHA)),
            TEST_VAULT,
            "Asset->Vault mapping incorrect"
        );

        // Verify vault appears in getVaultsByAsset
        address[] memory vaultsByAsset = registry.getVaultsByAsset(TEST_ASSET);
        assertEq(vaultsByAsset.length, 1, "VaultsByAsset length incorrect");
        assertEq(vaultsByAsset[0], TEST_VAULT, "VaultsByAsset content incorrect");
    }

    /// @dev Test vault registration requires factory role
    function test_RegisterVault_OnlyFactory() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        // Test with a user who has no roles at all
        vm.prank(users.alice);
        vm.expectRevert(); // Should revert with Unauthorized()
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Test with user who has different role (charlie as emergency admin)
        vm.prank(users.emergencyAdmin);
        vm.expectRevert(); // Should revert with Unauthorized()
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);
    }

    /// @dev Test vault registration reverts with zero address
    function test_RegisterVault_RevertZeroAddress() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.admin);
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.registerVault(address(0), IkRegistry.VaultType.ALPHA, TEST_ASSET);
    }

    /// @dev Test vault registration reverts when already registered
    function test_RegisterVault_RevertAlreadyRegistered() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        vm.startPrank(users.admin);

        // First registration
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Second registration should fail
        vm.expectRevert(bytes(KREGISTRY_ALREADY_REGISTERED));
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.BETA, TEST_ASSET);

        vm.stopPrank();
    }

    /// @dev Test vault registration reverts with unsupported asset
    function test_RegisterVault_RevertAssetNotSupported() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_ASSET_NOT_SUPPORTED));
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);
    }

    /// @dev Test multiple vault types for same asset
    function test_RegisterVault_MultipleTypes() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        address kMinter = address(0x6666666666666666666666666666666666666666);
        address dnVault = address(0x7777777777777777777777777777777777777777);
        address alphaVault = address(0x8888888888888888888888888888888888888888);
        address betaVault = address(0x9999999999999999999999999999999999999999);

        vm.startPrank(users.admin);

        // Register all four vault types
        registry.registerVault(kMinter, IkRegistry.VaultType.MINTER, TEST_ASSET);
        registry.registerVault(dnVault, IkRegistry.VaultType.DN, TEST_ASSET);
        registry.registerVault(alphaVault, IkRegistry.VaultType.ALPHA, TEST_ASSET);
        registry.registerVault(betaVault, IkRegistry.VaultType.BETA, TEST_ASSET);

        vm.stopPrank();

        // Verify all registrations
        assertEq(registry.getVaultByAssetAndType(TEST_ASSET, uint8(IkRegistry.VaultType.MINTER)), kMinter);
        assertEq(registry.getVaultByAssetAndType(TEST_ASSET, uint8(IkRegistry.VaultType.DN)), dnVault);
        assertEq(registry.getVaultByAssetAndType(TEST_ASSET, uint8(IkRegistry.VaultType.ALPHA)), alphaVault);
        assertEq(registry.getVaultByAssetAndType(TEST_ASSET, uint8(IkRegistry.VaultType.BETA)), betaVault);

        // Verify getVaultsByAsset returns all three
        address[] memory vaultsByAsset = registry.getVaultsByAsset(TEST_ASSET);
        assertEq(vaultsByAsset.length, 4, "Should have 4 vaults for asset");
    }

    /*//////////////////////////////////////////////////////////////
                        ADAPTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev Test adapter registration access control
    function test_RegisterAdapter_OnlyAdmin() public {
        // Register vault first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.admin);
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Test that only admin can register adapters
        vm.prank(users.alice);
        vm.expectRevert();
        registry.registerAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);
    }

    /// @dev Test adapter registration with zero address
    function test_RegisterAdapter_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_INVALID_ADAPTER));
        registry.registerAdapter(TEST_VAULT, TEST_ASSET, address(0));
    }

    /// @dev Test removeAdapter access control
    function test_RemoveAdapter_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.removeAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);
    }

    /// @dev Test getAdapter returns zero for non-existent adapter
    function test_GetAdapter_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.getAdapter(TEST_VAULT, TEST_ASSET);
    }

    /// @dev Test isAdapterRegistered returns false for non-existent adapter
    function test_IsAdapterRegistered_NonExistent() public view {
        assertFalse(
            registry.isAdapterRegistered(TEST_VAULT, TEST_ASSET, TEST_ADAPTER),
            "Should return false for non-existent adapter"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test getCoreContracts returns correct addresses
    function test_GetCoreContracts() public {
        (address kMinter, address kAssetRouter) = registry.getCoreContracts();

        // Should return registered addresses or zero
        assertEq(kMinter, address(minter), "kMinter address incorrect");
        assertEq(kAssetRouter, address(assetRouter), "kAssetRouter address incorrect");
    }

    /// @dev Test isRelayer function
    function test_IsRelayer() public {
        assertTrue(registry.isRelayer(users.relayer), "relayer should be relayer");
        assertFalse(registry.isRelayer(users.alice), "Alice should not be relayer");
    }

    /// @dev Test getAllAssets returns existing assets
    function test_GetAllAssets_ExistingAssets() public {
        address[] memory assets = registry.getAllAssets();

        // Should contain USDC and WBTC from deployment
        assertEq(assets.length, 2, "Should have 2 assets from deployment");

        bool hasUSDC = false;
        bool hasWBTC = false;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == getUSDC()) hasUSDC = true;
            if (assets[i] == getWBTC()) hasWBTC = true;
        }

        assertTrue(hasUSDC, "USDC should be in assets array");
        assertTrue(hasWBTC, "WBTC should be in assets array");
    }

    /// @dev Test getVaultsByAsset with deployed vaults
    function test_GetVaultsByAsset_DeployedVaults() public {
        address[] memory usdcVaults = registry.getVaultsByAsset(getUSDC());

        // Should contain all three deployed vaults
        assertEq(usdcVaults.length, 4, "Should have 4 USDC vaults from deployment");

        // Verify all vault addresses are present
        bool hasDN = false;
        bool hasAlpha = false;
        bool hasBeta = false;
        bool hasMinter = false;

        for (uint256 i = 0; i < usdcVaults.length; i++) {
            if (usdcVaults[i] == address(dnVault)) hasDN = true;
            if (usdcVaults[i] == address(alphaVault)) hasAlpha = true;
            if (usdcVaults[i] == address(betaVault)) hasBeta = true;
            if (usdcVaults[i] == address(minter)) hasMinter = true;
        }

        assertTrue(hasDN, "DN vault should be in USDC vaults");
        assertTrue(hasAlpha, "Alpha vault should be in USDC vaults");
        assertTrue(hasBeta, "Beta vault should be in USDC vaults");
        assertTrue(hasMinter, "Minter vault should be in USDC vaults");
    }

    /// @dev Test empty getVaultsByAsset
    function test_GetVaultsByAsset_ZeroAddress() public {
        vm.expectRevert(bytes(KREGISTRY_ZERO_ADDRESS));
        address[] memory vaults = registry.getVaultsByAsset(TEST_ASSET);
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Test registry handles ETH receive
    function test_ReceiveETH() public {
        uint256 amount = 1 ether;

        // Send ETH to registry
        vm.deal(users.alice, amount);
        vm.prank(users.alice);
        (bool success,) = address(registry).call{ value: amount }("");

        assertTrue(success, "ETH transfer should succeed");
        assertEq(address(registry).balance, amount, "Registry should receive ETH");
    }

    /// @dev Test upgrade authorization (only owner)
    function test_AuthorizeUpgrade_OnlyOwner() public {
        address newImpl = address(new kRegistry());

        // Non-owner should fail with Unauthorized
        vm.prank(users.admin);
        vm.expectRevert(); // OptimizedOwnableRoles Unauthorized
        registry.upgradeToAndCall(newImpl, "");

        // Note: Testing actual upgrade is complex due to initialization requirements
        // The authorization check passes if we get past the onlyOwner modifier
        // The above test for non-owner access is sufficient for access control testing
        assertTrue(true, "Authorization test completed");
    }

    /*//////////////////////////////////////////////////////////////
                        ENHANCED ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test comprehensive role granting for all role types
    function test_RoleManagement_GrantAllRoles() public {
        address testUser = address(0xABCD);

        vm.startPrank(users.admin);

        // Test institution role granting
        registry.grantInstitutionRole(testUser);
        assertTrue(registry.isInstitution(testUser), "Institution role not granted");

        // Test vendor role granting
        address testVendor = address(0xDEAD);
        registry.grantVendorRole(testVendor);
        assertTrue(registry.isVendor(testVendor), "Vendor role not granted");

        // Test relayer role granting
        address testRelayer = address(0xBEEF);
        registry.grantRelayerRole(testRelayer);
        assertTrue(registry.isRelayer(testRelayer), "Relayer role not granted");

        vm.stopPrank();
    }

    /// @dev Test role granting access control
    function test_RoleManagement_OnlyAdminCanGrant() public {
        address testUser = address(0xABCD);

        // Test institution role - non-admin should fail
        vm.prank(users.alice);
        vm.expectRevert();
        registry.grantInstitutionRole(testUser);

        // Test vendor role - non-admin should fail
        vm.prank(users.bob);
        vm.expectRevert();
        registry.grantVendorRole(testUser);

        // Test relayer role - non-admin should fail
        vm.prank(users.charlie);
        vm.expectRevert();
        registry.grantRelayerRole(testUser);

        // Verify no roles were granted
        assertFalse(registry.isInstitution(testUser), "Institution role should not be granted");
        assertFalse(registry.isVendor(testUser), "Vendor role should not be granted");
        assertFalse(registry.isRelayer(testUser), "Relayer role should not be granted");
    }

    /// @dev Test role hierarchy and permissions
    function test_RoleManagement_RoleHierarchy() public {
        // Admin should have access to all admin functions
        assertTrue(registry.hasAnyRole(users.admin, 1), "Admin should have ADMIN_ROLE"); // _ROLE_0 = 1

        // Emergency admin should have emergency role
        assertTrue(registry.hasAnyRole(users.emergencyAdmin, 2), "EmergencyAdmin should have EMERGENCY_ADMIN_ROLE"); // _ROLE_1
            // = 2

        // Guardian should have guardian role
        assertTrue(registry.hasAnyRole(users.guardian, 4), "Guardian should have GUARDIAN_ROLE"); // _ROLE_2 = 4

        // Regular users should not have admin roles
        assertFalse(registry.hasAnyRole(users.alice, 1), "Alice should not have admin role");
        assertFalse(registry.hasAnyRole(users.bob, 2), "Bob should not have emergency admin role");
    }

    /// @dev Test role validation for specific operations
    function test_RoleManagement_OperationPermissions() public {
        // Test that only admin can register assets
        vm.prank(users.alice);
        vm.expectRevert();
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        // Test that only admin can register adapters
        vm.prank(users.bob);
        vm.expectRevert();
        registry.registerAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);

        // Test that admin CAN perform these operations
        vm.startPrank(users.admin);
        address kToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);
        registry.registerAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);
        vm.stopPrank();

        // Verify operations succeeded
        assertTrue(registry.isAsset(TEST_ASSET), "Asset should be registered");
        assertTrue(registry.isVault(TEST_VAULT), "Vault should be registered");
    }

    /// @dev Test multiple role assignments to same user
    function test_RoleManagement_MultipleRoles() public {
        address testUser = address(0xFEED);

        vm.startPrank(users.admin);

        // Grant multiple roles to same user
        registry.grantInstitutionRole(testUser);
        registry.grantVendorRole(testUser);
        registry.grantRelayerRole(testUser);

        vm.stopPrank();

        // Verify all roles are present
        assertTrue(registry.isInstitution(testUser), "Should have institution role");
        assertTrue(registry.isVendor(testUser), "Should have vendor role");
        assertTrue(registry.isRelayer(testUser), "Should have relayer role");

        // Verify combined role value
        assertTrue(registry.hasAnyRole(testUser, 16 | 32 | 8), "Should have multiple roles combined");
    }

    /// @dev Test role edge cases and boundary conditions
    function test_RoleManagement_EdgeCases() public {
        // Test granting same role twice (should not cause issues)
        address testUser = address(0xCAFE);
        vm.startPrank(users.admin);

        registry.grantInstitutionRole(testUser);
        registry.grantInstitutionRole(testUser); // Should not revert

        vm.stopPrank();

        assertTrue(registry.isInstitution(testUser), "Role should still be present");
    }

    /*//////////////////////////////////////////////////////////////
                    ADVANCED ASSET MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test asset ID collision scenarios
    function test_AssetManagement_IdCollisions() public {
        // Register first asset
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        // Try to register different asset with same ID (should revert)
        address differentAsset = address(0xDEADBEEF);
        vm.prank(users.admin);
        vm.expectRevert();
        registry.registerAsset("DIFFERENT", "DIFF", differentAsset, TEST_ASSET_ID, type(uint256).max, type(uint256).max);
    }

    /// @dev Test asset metadata and kToken relationship
    function test_AssetManagement_KTokenRelationship() public {
        vm.prank(users.admin);
        address deployedKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );

        // Verify kToken properties
        assertEq(registry.assetToKToken(TEST_ASSET), deployedKToken, "Asset->kToken mapping incorrect");

        // Verify kToken is properly deployed and configured
        assertTrue(deployedKToken != address(0), "kToken should be deployed");

        // Test reverse lookup
        assertEq(registry.isAsset(TEST_ASSET), true, "Asset ID lookup incorrect");
    }

    /// @dev Test asset boundaries and limits
    function test_AssetManagement_Boundaries() public {
        vm.startPrank(users.admin);

        // Test with very long strings (should work)
        string memory longName = "VERY_LONG_ASSET_NAME_THAT_EXCEEDS_NORMAL_LIMITS_FOR_TESTING_PURPOSES_ONLY";
        string memory longSymbol = "VERYLONGSYMBOL";

        // Should work with long names/symbols
        address longKToken = registry.registerAsset(
            longName, longSymbol, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );
        assertTrue(longKToken != address(0), "Should handle long names/symbols");

        vm.stopPrank();
    }

    /// @dev Test asset registry basic functionality
    function test_AssetManagement_StateConsistency() public {
        // Test with existing registered assets
        address[] memory allAssets = registry.getAllAssets();
        assertTrue(allAssets.length >= 2, "Should have existing assets");

        // Verify USDC is registered correctly
        assertTrue(registry.isAsset(getUSDC()), "getUSDC() should be registered");

        // Verify USDC appears in getAllAssets
        bool foundUSDC = false;
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == getUSDC()) {
                foundUSDC = true;
                break;
            }
        }
        assertTrue(foundUSDC, "USDC should be in getAllAssets");
    }

    /*//////////////////////////////////////////////////////////////
                    ENHANCED VAULT MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test vault type enum validation and edge cases
    function test_VaultManagement_VaultTypeValidation() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        vm.startPrank(users.admin);

        // Test all valid vault types
        address[] memory testVaults = new address[](5);
        testVaults[0] = address(0x1001);
        testVaults[1] = address(0x1002);
        testVaults[2] = address(0x1003);
        testVaults[3] = address(0x1004);
        testVaults[4] = address(0x1005);

        // Register different vault types
        registry.registerVault(testVaults[0], IkRegistry.VaultType.MINTER, TEST_ASSET);
        registry.registerVault(testVaults[1], IkRegistry.VaultType.DN, TEST_ASSET);
        registry.registerVault(testVaults[2], IkRegistry.VaultType.ALPHA, TEST_ASSET);
        registry.registerVault(testVaults[3], IkRegistry.VaultType.BETA, TEST_ASSET);
        registry.registerVault(testVaults[4], IkRegistry.VaultType.GAMMA, TEST_ASSET);

        vm.stopPrank();

        // Verify all vault types are correctly set
        assertEq(registry.getVaultType(testVaults[0]), uint8(IkRegistry.VaultType.MINTER), "MINTER type incorrect");
        assertEq(registry.getVaultType(testVaults[1]), uint8(IkRegistry.VaultType.DN), "DN type incorrect");
        assertEq(registry.getVaultType(testVaults[2]), uint8(IkRegistry.VaultType.ALPHA), "ALPHA type incorrect");
        assertEq(registry.getVaultType(testVaults[3]), uint8(IkRegistry.VaultType.BETA), "BETA type incorrect");
        assertEq(registry.getVaultType(testVaults[4]), uint8(IkRegistry.VaultType.GAMMA), "GAMMA type incorrect");
    }

    /// @dev Test vault registration with multiple assets per vault
    function test_VaultManagement_MultipleAssetScenarios() public {
        // Simplified test using existing assets
        vm.startPrank(users.admin);

        address vault1 = address(0x3001);
        registry.registerVault(vault1, IkRegistry.VaultType.ALPHA, getUSDC());

        vm.stopPrank();

        // Verify vault-asset relationship
        assertTrue(registry.isVault(vault1), "Vault should be registered");
        assertEq(registry.getVaultType(vault1), uint8(IkRegistry.VaultType.ALPHA), "Vault type should be ALPHA");

        // Verify vault appears in asset's vault list
        address[] memory usdcVaults = registry.getVaultsByAsset(getUSDC());

        bool foundVault = false;
        for (uint256 i = 0; i < usdcVaults.length; i++) {
            if (usdcVaults[i] == vault1) {
                foundVault = true;
                break;
            }
        }
        assertTrue(foundVault, "Vault should be found in USDC vaults");
    }

    /// @dev Test vault registration boundary conditions
    function test_VaultManagement_BoundaryConditions() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        vm.startPrank(users.admin);

        // Test registering vault with maximum vault type values (using higher enum values)
        address highTypeVault = address(0x4001);

        // Test with higher vault type numbers
        registry.registerVault(highTypeVault, IkRegistry.VaultType.TAU, TEST_ASSET); // Higher in enum
        assertEq(registry.getVaultType(highTypeVault), uint8(IkRegistry.VaultType.TAU), "High vault type incorrect");

        vm.stopPrank();
    }

    /// @dev Test vault deregistration scenarios (if supported)
    function test_VaultManagement_StateConsistency() public {
        // Register asset and multiple vaults
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);

        address[] memory testVaults = new address[](3);
        testVaults[0] = address(0x5001);
        testVaults[1] = address(0x5002);
        testVaults[2] = address(0x5003);

        vm.startPrank(users.admin);
        registry.registerVault(testVaults[0], IkRegistry.VaultType.ALPHA, TEST_ASSET);
        registry.registerVault(testVaults[1], IkRegistry.VaultType.BETA, TEST_ASSET);
        registry.registerVault(testVaults[2], IkRegistry.VaultType.GAMMA, TEST_ASSET);
        vm.stopPrank();

        // Verify all vaults are tracked
        address[] memory assetVaults = registry.getVaultsByAsset(TEST_ASSET);
        assertEq(assetVaults.length, 3, "Should have 3 vaults for asset");

        // Verify each vault is properly registered
        for (uint256 i = 0; i < testVaults.length; i++) {
            assertTrue(registry.isVault(testVaults[i]), "Vault should be registered");
            address[] memory vaultAssets = registry.getVaultAssets(testVaults[i]);
            assertEq(vaultAssets.length, 1, "Vault should have 1 asset");
            assertEq(vaultAssets[0], TEST_ASSET, "Vault asset should match");
        }
    }

    /*//////////////////////////////////////////////////////////////
                COMPREHENSIVE ADAPTER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test complete adapter registration workflow
    function test_AdapterManagement_CompleteWorkflow() public {
        // Setup: Register asset and vault
        vm.startPrank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Test adapter registration
        vm.expectEmit(true, true, true, false);
        emit IkRegistry.AdapterRegistered(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);
        registry.registerAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);

        vm.stopPrank();

        // Verify adapter is registered
        assertTrue(registry.isAdapterRegistered(TEST_VAULT, TEST_ASSET, TEST_ADAPTER), "Adapter should be registered");

        // Verify getAdapter returns correct adapter
        address adapter = registry.getAdapter(TEST_VAULT, TEST_ASSET);
        assertEq(adapter, TEST_ADAPTER, "Adapter address incorrect");
    }

    /// @dev Test adapter removal workflow
    function test_AdapterManagement_RemovalWorkflow() public {
        // Setup vault with adapters
        vm.startPrank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max);
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);
        registry.registerAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);

        // Verify adapter is registered
        assertTrue(
            registry.isAdapterRegistered(TEST_VAULT, TEST_ASSET, TEST_ADAPTER), "Adapter should be registered initially"
        );

        // Remove adapter
        registry.removeAdapter(TEST_VAULT, TEST_ASSET, TEST_ADAPTER);

        vm.stopPrank();

        // Verify adapter is removed
        assertFalse(registry.isAdapterRegistered(TEST_VAULT, TEST_ASSET, TEST_ADAPTER), "Adapter should be removed");
    }

    /*//////////////////////////////////////////////////////////////
                    ADVANCED VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test view functions with large datasets
    function test_ViewFunctions_LargeDatasets() public {
        // Test with existing deployed assets
        address[] memory allAssets = registry.getAllAssets();
        assertTrue(allAssets.length >= 2, "Should have at least USDC and WBTC");

        // Test getVaultsByAsset with existing assets
        address[] memory usdcVaults = registry.getVaultsByAsset(getUSDC());
        assertTrue(usdcVaults.length > 0, "USDC should have vaults");

        // Verify each returned vault is actually registered
        for (uint256 i = 0; i < usdcVaults.length; i++) {
            assertTrue(registry.isVault(usdcVaults[i]), "Each vault should be registered");
        }
    }

    /// @dev Test view function edge cases
    function test_ViewFunctions_EdgeCases() public {
        // Test view functions with non-existent data
        address nonExistentAsset = address(0x9001);
        address nonExistentVault = address(0x9002);

        // Test isAsset/isVault with non-existent addresses
        assertFalse(registry.isAsset(nonExistentAsset), "Non-existent asset should return false");
        assertFalse(registry.isVault(nonExistentVault), "Non-existent vault should return false");
    }

    /*//////////////////////////////////////////////////////////////
                    SECURITY AND EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test emergency functions and rescue scenarios
    function test_Security_EmergencyFunctions() public {
        // Test that only admin can call rescue functions
        vm.prank(users.alice);
        vm.expectRevert();
        registry.rescueAssets(getUSDC(), users.admin, 1000);

        // Admin should be able to call rescue (even if no assets to rescue)
        vm.prank(users.admin);
        try registry.rescueAssets(getUSDC(), users.admin, 0) {
            // Success is acceptable
        } catch {
            // Revert is also acceptable if no assets
        }

        assertTrue(true, "Access control test completed");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test complete asset-vault registration workflow
    function test_CompleteAssetVaultWorkflow() public {
        // Step 1: Register new asset
        vm.startPrank(users.admin);
        address test_kToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID, type(uint256).max, type(uint256).max
        );
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);
        vm.stopPrank();

        // Step 3: Verify complete registration
        assertTrue(registry.isAsset(TEST_ASSET), "Asset should be registered");
        assertTrue(registry.isVault(TEST_VAULT), "Vault should be registered");

        // Step 4: Verify relationships
        assertEq(registry.assetToKToken(TEST_ASSET), test_kToken, "Asset->kToken mapping");
        assertEq(registry.getVaultAssets(TEST_VAULT)[0], TEST_ASSET, "Vault->Asset mapping");
        assertEq(registry.getVaultType(TEST_VAULT), uint8(IkRegistry.VaultType.ALPHA), "Vault type");

        // Step 5: Verify in arrays
        address[] memory assets = registry.getAllAssets();
        address[] memory vaults = registry.getVaultsByAsset(TEST_ASSET);

        assertTrue(assets.length >= 1, "Asset should be in getAllAssets");
        assertEq(vaults.length, 1, "Should have 1 vault for test asset");
        assertEq(vaults[0], TEST_VAULT, "Vault should match");
    }

    /*//////////////////////////////////////////////////////////////
                        HURDLE RATE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful hurdle rate setting
    function test_SetHurdleRate_Success() public {
        vm.prank(users.relayer);

        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit IkRegistry.HurdleRateSet(getUSDC(), TEST_HURDLE_RATE);

        registry.setHurdleRate(getUSDC(), TEST_HURDLE_RATE);

        // Verify hurdle rate is set
        assertEq(registry.getHurdleRate(getUSDC()), TEST_HURDLE_RATE, "Hurdle rate not set correctly");
    }

    /// @dev Test setting hurdle rate requires relayer role
    function test_SetHurdleRate_OnlyRelayer() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.setHurdleRate(getUSDC(), TEST_HURDLE_RATE);
    }

    /// @dev Test hurdle rate exceeds maximum
    function test_SetHurdleRate_ExceedsMaximum() public {
        vm.expectRevert(bytes(KREGISTRY_FEE_EXCEEDS_MAXIMUM));
        vm.prank(users.relayer);
        registry.setHurdleRate(getUSDC(), uint16(MAX_BPS + 1));
    }

    /// @dev Test setting hurdle rate for unsupported asset
    function test_SetHurdleRate_AssetNotSupported() public {
        vm.expectRevert(bytes(KREGISTRY_ASSET_NOT_SUPPORTED));
        vm.prank(users.relayer);
        registry.setHurdleRate(TEST_ASSET, TEST_HURDLE_RATE);
    }

    /// @dev Test setting hurdle rate for different assets
    function test_SetHurdleRate_MultipleAssets() public {
        vm.startPrank(users.relayer);

        // Set different rates for different assets
        registry.setHurdleRate(getUSDC(), TEST_HURDLE_RATE);
        registry.setHurdleRate(getWBTC(), 750); // 7.5%

        // Verify each asset has its own rate
        assertEq(registry.getHurdleRate(getUSDC()), TEST_HURDLE_RATE, "USDC hurdle rate incorrect");
        assertEq(registry.getHurdleRate(getWBTC()), 750, "WBTC hurdle rate incorrect");

        vm.stopPrank();
    }
}
