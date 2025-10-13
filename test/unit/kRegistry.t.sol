pragma solidity 0.8.30;

import { MockERC20 } from "../mocks/MockERC20.sol";
import { ADMIN_ROLE, RELAYER_ROLE } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import {
    KREGISTRY_ALREADY_REGISTERED,
    KREGISTRY_ASSET_NOT_SUPPORTED,
    KREGISTRY_FEE_EXCEEDS_MAXIMUM,
    KREGISTRY_INVALID_ADAPTER,
    KREGISTRY_ZERO_ADDRESS,
    KROLESBASE_ZERO_ADDRESS
} from "kam/src/errors/Errors.sol";
import { IRegistry } from "kam/src/interfaces/IRegistry.sol";
import { kRegistry } from "kam/src/kRegistry/kRegistry.sol";

contract kRegistryTest is DeploymentBaseTest {
    address internal testContract = makeAddr("TestContract");
    address internal testAsset;
    address internal testVault = makeAddr("TestVault");
    address internal TEST_ADAPTER = makeAddr("TestAdapter");

    string internal constant TEST_NAME = "TEST_TOKEN";
    string internal constant TEST_SYMBOL = "TTK";
    bytes32 internal constant testContract_ID = keccak256("testContract");
    bytes32 internal constant testAsset_ID = keccak256("testAsset");

    uint256 constant MAX_BPS = 10_000;
    uint16 constant TEST_HURDLE_RATE = 500; //5%

    function setUp() public override {
        super.setUp();

        MockERC20 testToken = new MockERC20("Test USDT", "USDT", 6);
        testAsset = address(testToken);
    }

    /* //////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_InitialState() public view {
        assertEq(registry.owner(), users.owner, "Owner not set correctly");
        assertTrue(registry.hasAnyRole(users.admin, ADMIN_ROLE), "Admin role not granted");
        assertTrue(registry.hasAnyRole(users.relayer, RELAYER_ROLE), "Relayer role not granted");
    }

    function test_ContractInfo() public view {
        assertEq(registry.contractName(), "kRegistry", "Contract name incorrect");
        assertEq(registry.contractVersion(), "1.0.0", "Contract version incorrect");
    }

    /* //////////////////////////////////////////////////////////////
                    SINGLETON CONTRACT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_SetSingletonContract_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.setSingletonContract(testContract_ID, testContract);
    }

    function test_SetSingletonContract_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.setSingletonContract(testContract_ID, address(0));
    }

    function test_SetSingletonContract_RevertAlreadyRegistered() public {
        vm.prank(users.admin);
        registry.setSingletonContract(testContract_ID, testContract);

        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_ALREADY_REGISTERED));
        registry.setSingletonContract(testContract_ID, address(0x01));
    }

    function test_GetContractById_RevertZeroAddress() public {
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.getContractById(keccak256("NONEXISTENT"));
    }

    /* //////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_RegisterAsset_NewAsset_Success() public {
        vm.prank(users.admin);

        vm.expectEmit(true, false, false, false);
        emit IRegistry.AssetSupported(testAsset);

        address testKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max
        );

        assertTrue(registry.isAsset(testAsset), "Asset not registered");
        assertEq(registry.assetToKToken(testAsset), testKToken, "Asset->kToken mapping incorrect");

        address[] memory allAssets = registry.getAllAssets();
        bool found = false;
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == testAsset) {
                found = true;
                break;
            }
        }
        assertTrue(found, "Asset not in getAllAssets");
    }

    function test_RegisterAsset_ExistingAsset_Revert() public {
        vm.prank(users.admin);
        address newKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max
        );
        assertEq(registry.assetToKToken(testAsset), newKToken, "kToken mapping not updated");

        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_ALREADY_REGISTERED));
        newKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max
        );
    }

    function test_RegisterAsset_OnlyAdmin() public {
        vm.prank(users.bob);
        vm.expectRevert();
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);
    }

    function test_RegisterAsset_RevertZeroAddresses() public {
        vm.startPrank(users.admin);

        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, address(0), testAsset_ID, type(uint256).max, type(uint256).max);

        vm.expectRevert(bytes(KREGISTRY_ZERO_ADDRESS));
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, bytes32(0), type(uint256).max, type(uint256).max);

        vm.stopPrank();
    }

    /* //////////////////////////////////////////////////////////////
                        VAULT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_RegisterVault_Success() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.admin);

        vm.expectEmit(true, true, true, false);
        emit IRegistry.VaultRegistered(testVault, testAsset, IRegistry.VaultType.ALPHA);

        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);

        assertTrue(registry.isVault(testVault), "Vault not registered");
        assertEq(registry.getVaultType(testVault), uint8(IRegistry.VaultType.ALPHA), "Vault type incorrect");
        assertEq(registry.getVaultAssets(testVault)[0], testAsset, "Vault asset incorrect");
        assertEq(
            registry.getVaultByAssetAndType(testAsset, uint8(IRegistry.VaultType.ALPHA)),
            testVault,
            "Asset->Vault mapping incorrect"
        );

        address[] memory vaultsByAsset = registry.getVaultsByAsset(testAsset);
        assertEq(vaultsByAsset.length, 1, "VaultsByAsset length incorrect");
        assertEq(vaultsByAsset[0], testVault, "VaultsByAsset content incorrect");
    }

    function test_RegisterVault_OnlyFactory() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.alice);
        vm.expectRevert();
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);

        vm.prank(users.emergencyAdmin);
        vm.expectRevert();
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);
    }

    function test_RegisterVault_RevertZeroAddress() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.admin);
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.registerVault(address(0), IRegistry.VaultType.ALPHA, testAsset);
    }

    function test_RegisterVault_RevertAlreadyRegistered() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.startPrank(users.admin);

        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);

        vm.expectRevert(bytes(KREGISTRY_ALREADY_REGISTERED));
        registry.registerVault(testVault, IRegistry.VaultType.BETA, testAsset);

        vm.stopPrank();
    }

    function test_RegisterVault_RevertAssetNotSupported() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_ASSET_NOT_SUPPORTED));
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);
    }

    function test_RegisterVault_MultipleTypes() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        address kMinter = address(0x6666666666666666666666666666666666666666);
        address dnVault = address(0x7777777777777777777777777777777777777777);
        address alphaVault = address(0x8888888888888888888888888888888888888888);
        address betaVault = address(0x9999999999999999999999999999999999999999);

        vm.startPrank(users.admin);

        registry.registerVault(kMinter, IRegistry.VaultType.MINTER, testAsset);
        registry.registerVault(dnVault, IRegistry.VaultType.DN, testAsset);
        registry.registerVault(alphaVault, IRegistry.VaultType.ALPHA, testAsset);
        registry.registerVault(betaVault, IRegistry.VaultType.BETA, testAsset);

        vm.stopPrank();

        assertEq(registry.getVaultByAssetAndType(testAsset, uint8(IRegistry.VaultType.MINTER)), kMinter);
        assertEq(registry.getVaultByAssetAndType(testAsset, uint8(IRegistry.VaultType.DN)), dnVault);
        assertEq(registry.getVaultByAssetAndType(testAsset, uint8(IRegistry.VaultType.ALPHA)), alphaVault);
        assertEq(registry.getVaultByAssetAndType(testAsset, uint8(IRegistry.VaultType.BETA)), betaVault);

        address[] memory vaultsByAsset = registry.getVaultsByAsset(testAsset);
        assertEq(vaultsByAsset.length, 4, "Should have 4 vaults for asset");
    }

    /* //////////////////////////////////////////////////////////////
                        ADAPTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_RegisterAdapter_OnlyAdmin() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.admin);
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);

        vm.prank(users.alice);
        vm.expectRevert();
        registry.registerAdapter(testVault, testAsset, TEST_ADAPTER);
    }

    function test_RegisterAdapter_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KREGISTRY_INVALID_ADAPTER));
        registry.registerAdapter(testVault, testAsset, address(0));
    }

    function test_RemoveAdapter_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.removeAdapter(testVault, testAsset, TEST_ADAPTER);
    }

    function test_GetAdapter_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(bytes(KROLESBASE_ZERO_ADDRESS));
        registry.getAdapter(testVault, testAsset);
    }

    function test_IsAdapterRegistered_NonExistent() public view {
        assertFalse(
            registry.isAdapterRegistered(testVault, testAsset, TEST_ADAPTER),
            "Should return false for non-existent adapter"
        );
    }

    /* //////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function test_GetCoreContracts() public view {
        (address kMinter, address kAssetRouter) = registry.getCoreContracts();

        assertEq(kMinter, address(minter), "kMinter address incorrect");
        assertEq(kAssetRouter, address(assetRouter), "kAssetRouter address incorrect");
    }

    function test_IsRelayer() public view {
        assertTrue(registry.isRelayer(users.relayer), "relayer should be relayer");
        assertFalse(registry.isRelayer(users.alice), "Alice should not be relayer");
    }

    function test_GetAllAssets_ExistingAssets() public view {
        address[] memory assets = registry.getAllAssets();

        assertEq(assets.length, 2, "Should have 2 assets from deployment");

        bool hasUSDC = false;
        bool hasWBTC = false;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == tokens.usdc) hasUSDC = true;
            if (assets[i] == tokens.wbtc) hasWBTC = true;
        }

        assertTrue(hasUSDC, "USDC should be in assets array");
        assertTrue(hasWBTC, "WBTC should be in assets array");
    }

    function test_GetVaultsByAsset_DeployedVaults() public view {
        address[] memory usdcVaults = registry.getVaultsByAsset(tokens.usdc);

        assertEq(usdcVaults.length, 4, "Should have 4 USDC vaults from deployment");

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

    function test_GetVaultsByAsset_ZeroAddress() public {
        vm.expectRevert(bytes(KREGISTRY_ZERO_ADDRESS));
        registry.getVaultsByAsset(testAsset);
    }

    /* //////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_ReceiveETH() public {
        uint256 amount = 1 ether;

        vm.deal(users.alice, amount);
        vm.prank(users.alice);
        (bool success,) = address(registry).call{ value: amount }("");

        assertTrue(success, "ETH transfer should succeed");
        assertEq(address(registry).balance, amount, "Registry should receive ETH");
    }

    function test_AuthorizeUpgrade_OnlyOwner() public {
        address newImpl = address(new kRegistry());

        vm.prank(users.admin);
        vm.expectRevert();
        registry.upgradeToAndCall(newImpl, "");

        assertTrue(true, "Authorization test completed");
    }

    /* //////////////////////////////////////////////////////////////
                        ENHANCED ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RoleManagement_GrantAllRoles() public {
        address testUser = address(0xABCD);

        vm.startPrank(users.admin);

        registry.grantInstitutionRole(testUser);
        assertTrue(registry.isInstitution(testUser), "Institution role not granted");

        address testVendor = address(0xDEAD);
        registry.grantVendorRole(testVendor);
        assertTrue(registry.isVendor(testVendor), "Vendor role not granted");

        address testRelayer = address(0xBEEF);
        registry.grantRelayerRole(testRelayer);
        assertTrue(registry.isRelayer(testRelayer), "Relayer role not granted");

        vm.stopPrank();
    }

    function test_RoleManagement_OnlyAdminCanGrant() public {
        address testUser = address(0xABCD);

        vm.prank(users.alice);
        vm.expectRevert();
        registry.grantInstitutionRole(testUser);

        vm.prank(users.bob);
        vm.expectRevert();
        registry.grantVendorRole(testUser);

        vm.prank(users.charlie);
        vm.expectRevert();
        registry.grantRelayerRole(testUser);

        assertFalse(registry.isInstitution(testUser), "Institution role should not be granted");
        assertFalse(registry.isVendor(testUser), "Vendor role should not be granted");
        assertFalse(registry.isRelayer(testUser), "Relayer role should not be granted");
    }

    function test_RoleManagement_RoleHierarchy() public view {
        assertTrue(registry.hasAnyRole(users.admin, 1), "Admin should have ADMIN_ROLE");

        assertTrue(registry.hasAnyRole(users.emergencyAdmin, 2), "EmergencyAdmin should have EMERGENCY_ADMIN_ROLE");

        assertTrue(registry.hasAnyRole(users.guardian, 4), "Guardian should have GUARDIAN_ROLE");

        assertFalse(registry.hasAnyRole(users.alice, 1), "Alice should not have admin role");
        assertFalse(registry.hasAnyRole(users.bob, 2), "Bob should not have emergency admin role");
    }

    function test_RoleManagement_OperationPermissions() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.prank(users.bob);
        vm.expectRevert();
        registry.registerAdapter(testVault, testAsset, TEST_ADAPTER);

        vm.startPrank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);
        registry.registerAdapter(testVault, testAsset, TEST_ADAPTER);
        vm.stopPrank();

        assertTrue(registry.isAsset(testAsset), "Asset should be registered");
        assertTrue(registry.isVault(testVault), "Vault should be registered");
    }

    function test_RoleManagement_MultipleRoles() public {
        address testUser = address(0xFEED);

        vm.startPrank(users.admin);

        registry.grantInstitutionRole(testUser);
        registry.grantVendorRole(testUser);
        registry.grantRelayerRole(testUser);

        vm.stopPrank();

        assertTrue(registry.isInstitution(testUser), "Should have institution role");
        assertTrue(registry.isVendor(testUser), "Should have vendor role");
        assertTrue(registry.isRelayer(testUser), "Should have relayer role");

        assertTrue(registry.hasAnyRole(testUser, 16 | 32 | 8), "Should have multiple roles combined");
    }

    function test_RoleManagement_EdgeCases() public {
        address testUser = address(0xCAFE);
        vm.startPrank(users.admin);

        registry.grantInstitutionRole(testUser);
        registry.grantInstitutionRole(testUser);

        vm.stopPrank();

        assertTrue(registry.isInstitution(testUser), "Role should still be present");
    }

    /* //////////////////////////////////////////////////////////////
                    ADVANCED ASSET MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AssetManagement_IdCollisions() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        address differentAsset = address(0xDEADBEEF);
        vm.prank(users.admin);
        vm.expectRevert();
        registry.registerAsset("DIFFERENT", "DIFF", differentAsset, testAsset_ID, type(uint256).max, type(uint256).max);
    }

    function test_AssetManagement_KTokenRelationship() public {
        vm.prank(users.admin);
        address deployedKToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max
        );

        assertEq(registry.assetToKToken(testAsset), deployedKToken, "Asset->kToken mapping incorrect");

        assertTrue(deployedKToken != address(0), "kToken should be deployed");

        assertEq(registry.isAsset(testAsset), true, "Asset ID lookup incorrect");
    }

    function test_AssetManagement_Boundaries() public {
        vm.startPrank(users.admin);

        string memory longName = "VERY_LONG_ASSET_NAME_THAT_EXCEEDS_NORMAL_LIMITS_FOR_TESTING_PURPOSES_ONLY";
        string memory longSymbol = "VERYLONGSYMBOL";

        address longKToken =
            registry.registerAsset(longName, longSymbol, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);
        assertTrue(longKToken != address(0), "Should handle long names/symbols");

        vm.stopPrank();
    }

    function test_AssetManagement_StateConsistency() public view {
        address[] memory allAssets = registry.getAllAssets();
        assertTrue(allAssets.length >= 2, "Should have existing assets");

        assertTrue(registry.isAsset(tokens.usdc), "tokens.usdc should be registered");

        bool foundUSDC = false;
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (allAssets[i] == tokens.usdc) {
                foundUSDC = true;
                break;
            }
        }
        assertTrue(foundUSDC, "USDC should be in getAllAssets");
    }

    /* //////////////////////////////////////////////////////////////
                    ENHANCED VAULT MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_VaultManagement_VaultTypeValidation() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.startPrank(users.admin);

        address[] memory testVaults = new address[](5);
        testVaults[0] = address(0x1001);
        testVaults[1] = address(0x1002);
        testVaults[2] = address(0x1003);
        testVaults[3] = address(0x1004);
        testVaults[4] = address(0x1005);

        registry.registerVault(testVaults[0], IRegistry.VaultType.MINTER, testAsset);
        registry.registerVault(testVaults[1], IRegistry.VaultType.DN, testAsset);
        registry.registerVault(testVaults[2], IRegistry.VaultType.ALPHA, testAsset);
        registry.registerVault(testVaults[3], IRegistry.VaultType.BETA, testAsset);
        registry.registerVault(testVaults[4], IRegistry.VaultType.GAMMA, testAsset);

        vm.stopPrank();

        assertEq(registry.getVaultType(testVaults[0]), uint8(IRegistry.VaultType.MINTER), "MINTER type incorrect");
        assertEq(registry.getVaultType(testVaults[1]), uint8(IRegistry.VaultType.DN), "DN type incorrect");
        assertEq(registry.getVaultType(testVaults[2]), uint8(IRegistry.VaultType.ALPHA), "ALPHA type incorrect");
        assertEq(registry.getVaultType(testVaults[3]), uint8(IRegistry.VaultType.BETA), "BETA type incorrect");
        assertEq(registry.getVaultType(testVaults[4]), uint8(IRegistry.VaultType.GAMMA), "GAMMA type incorrect");
    }

    function test_VaultManagement_MultipleAssetScenarios() public {
        vm.startPrank(users.admin);

        address vault1 = address(0x3001);
        registry.registerVault(vault1, IRegistry.VaultType.ALPHA, tokens.usdc);

        vm.stopPrank();

        assertTrue(registry.isVault(vault1), "Vault should be registered");
        assertEq(registry.getVaultType(vault1), uint8(IRegistry.VaultType.ALPHA), "Vault type should be ALPHA");

        address[] memory usdcVaults = registry.getVaultsByAsset(tokens.usdc);

        bool foundVault = false;
        for (uint256 i = 0; i < usdcVaults.length; i++) {
            if (usdcVaults[i] == vault1) {
                foundVault = true;
                break;
            }
        }
        assertTrue(foundVault, "Vault should be found in USDC vaults");
    }

    function test_VaultManagement_BoundaryConditions() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        vm.startPrank(users.admin);

        address highTypeVault = address(0x4001);

        registry.registerVault(highTypeVault, IRegistry.VaultType.TAU, testAsset);
        assertEq(registry.getVaultType(highTypeVault), uint8(IRegistry.VaultType.TAU), "High vault type incorrect");

        vm.stopPrank();
    }

    function test_VaultManagement_StateConsistency() public {
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);

        address[] memory testVaults = new address[](3);
        testVaults[0] = address(0x5001);
        testVaults[1] = address(0x5002);
        testVaults[2] = address(0x5003);

        vm.startPrank(users.admin);
        registry.registerVault(testVaults[0], IRegistry.VaultType.ALPHA, testAsset);
        registry.registerVault(testVaults[1], IRegistry.VaultType.BETA, testAsset);
        registry.registerVault(testVaults[2], IRegistry.VaultType.GAMMA, testAsset);
        vm.stopPrank();

        address[] memory assetVaults = registry.getVaultsByAsset(testAsset);
        assertEq(assetVaults.length, 3, "Should have 3 vaults for asset");

        for (uint256 i = 0; i < testVaults.length; i++) {
            assertTrue(registry.isVault(testVaults[i]), "Vault should be registered");
            address[] memory vaultAssets = registry.getVaultAssets(testVaults[i]);
            assertEq(vaultAssets.length, 1, "Vault should have 1 asset");
            assertEq(vaultAssets[0], testAsset, "Vault asset should match");
        }
    }

    /* //////////////////////////////////////////////////////////////
                COMPREHENSIVE ADAPTER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AdapterManagement_CompleteWorkflow() public {
        vm.startPrank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);

        vm.expectEmit(true, true, true, false);
        emit IRegistry.AdapterRegistered(testVault, testAsset, TEST_ADAPTER);
        registry.registerAdapter(testVault, testAsset, TEST_ADAPTER);

        vm.stopPrank();

        assertTrue(registry.isAdapterRegistered(testVault, testAsset, TEST_ADAPTER), "Adapter should be registered");

        address adapter = registry.getAdapter(testVault, testAsset);
        assertEq(adapter, TEST_ADAPTER, "Adapter address incorrect");
    }

    function test_AdapterManagement_RemovalWorkflow() public {
        vm.startPrank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max);
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);
        registry.registerAdapter(testVault, testAsset, TEST_ADAPTER);

        assertTrue(
            registry.isAdapterRegistered(testVault, testAsset, TEST_ADAPTER), "Adapter should be registered initially"
        );

        registry.removeAdapter(testVault, testAsset, TEST_ADAPTER);

        vm.stopPrank();

        assertFalse(registry.isAdapterRegistered(testVault, testAsset, TEST_ADAPTER), "Adapter should be removed");
    }

    /* //////////////////////////////////////////////////////////////
                    ADVANCED VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ViewFunctions_LargeDatasets() public view {
        address[] memory allAssets = registry.getAllAssets();
        assertTrue(allAssets.length >= 2, "Should have at least USDC and WBTC");

        address[] memory usdcVaults = registry.getVaultsByAsset(tokens.usdc);
        assertTrue(usdcVaults.length > 0, "USDC should have vaults");

        for (uint256 i = 0; i < usdcVaults.length; i++) {
            assertTrue(registry.isVault(usdcVaults[i]), "Each vault should be registered");
        }
    }

    function test_ViewFunctions_EdgeCases() public view {
        address nonExistentAsset = address(0x9001);
        address nonExistentVault = address(0x9002);

        assertFalse(registry.isAsset(nonExistentAsset), "Non-existent asset should return false");
        assertFalse(registry.isVault(nonExistentVault), "Non-existent vault should return false");
    }

    /* //////////////////////////////////////////////////////////////
                    SECURITY AND EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Security_EmergencyFunctions() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.rescueAssets(tokens.usdc, users.admin, 1000);

        vm.prank(users.admin);
        try registry.rescueAssets(tokens.usdc, users.admin, 0) { } catch { }

        assertTrue(true, "Access control test completed");
    }

    /* //////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CompleteAssetVaultWorkflow() public {
        vm.startPrank(users.admin);
        address test_kToken = registry.registerAsset(
            TEST_NAME, TEST_SYMBOL, testAsset, testAsset_ID, type(uint256).max, type(uint256).max
        );
        registry.registerVault(testVault, IRegistry.VaultType.ALPHA, testAsset);
        vm.stopPrank();

        assertTrue(registry.isAsset(testAsset), "Asset should be registered");
        assertTrue(registry.isVault(testVault), "Vault should be registered");

        assertEq(registry.assetToKToken(testAsset), test_kToken, "Asset->kToken mapping");
        assertEq(registry.getVaultAssets(testVault)[0], testAsset, "Vault->Asset mapping");
        assertEq(registry.getVaultType(testVault), uint8(IRegistry.VaultType.ALPHA), "Vault type");

        address[] memory assets = registry.getAllAssets();
        address[] memory vaults = registry.getVaultsByAsset(testAsset);

        assertTrue(assets.length >= 1, "Asset should be in getAllAssets");
        assertEq(vaults.length, 1, "Should have 1 vault for test asset");
        assertEq(vaults[0], testVault, "Vault should match");
    }

    /* //////////////////////////////////////////////////////////////
                        HURDLE RATE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetHurdleRate_Success() public {
        vm.prank(users.relayer);

        vm.expectEmit(true, false, false, true);
        emit IRegistry.HurdleRateSet(tokens.usdc, TEST_HURDLE_RATE);

        registry.setHurdleRate(tokens.usdc, TEST_HURDLE_RATE);

        assertEq(registry.getHurdleRate(tokens.usdc), TEST_HURDLE_RATE, "Hurdle rate not set correctly");
    }

    function test_SetHurdleRate_OnlyRelayer() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.setHurdleRate(tokens.usdc, TEST_HURDLE_RATE);
    }

    function test_SetHurdleRate_ExceedsMaximum() public {
        vm.expectRevert(bytes(KREGISTRY_FEE_EXCEEDS_MAXIMUM));
        vm.prank(users.relayer);
        registry.setHurdleRate(tokens.usdc, uint16(MAX_BPS + 1));
    }

    function test_SetHurdleRate_AssetNotSupported() public {
        vm.expectRevert(bytes(KREGISTRY_ASSET_NOT_SUPPORTED));
        vm.prank(users.relayer);
        registry.setHurdleRate(testAsset, TEST_HURDLE_RATE);
    }

    function test_SetHurdleRate_MultipleAssets() public {
        vm.startPrank(users.relayer);

        registry.setHurdleRate(tokens.usdc, TEST_HURDLE_RATE);
        registry.setHurdleRate(tokens.wbtc, 750);

        assertEq(registry.getHurdleRate(tokens.usdc), TEST_HURDLE_RATE, "USDC hurdle rate incorrect");
        assertEq(registry.getHurdleRate(tokens.wbtc), 750, "WBTC hurdle rate incorrect");

        vm.stopPrank();
    }
}
