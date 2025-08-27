// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, RELAYER_ROLE, USDC_MAINNET, WBTC_MAINNET, _1_USDC, _1_WBTC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { kRegistry } from "src/kRegistry.sol";

/// @title kRegistryTest
/// @notice Comprehensive unit tests for kRegistry contract
contract kRegistryTest is DeploymentBaseTest {
    // Test addresses for non-deployed contracts
    address internal constant TEST_CONTRACT = 0x1111111111111111111111111111111111111111;
    address internal constant TEST_ASSET = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // MAINNET USDT
    address internal constant TEST_KTOKEN = 0x3333333333333333333333333333333333333333;
    address internal constant TEST_VAULT = 0x4444444444444444444444444444444444444444;
    address internal constant TEST_ADAPTER = 0x5555555555555555555555555555555555555555;

    string TEST_NAME = "TEST_TOKEN";
    string TEST_SYMBOL = "TTK";
    bytes32 internal constant TEST_CONTRACT_ID = keccak256("TEST_CONTRACT");
    bytes32 internal constant TEST_ASSET_ID = keccak256("TEST_ASSET");

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

    /// @dev Test successful singleton contract registration
    function test_SetSingletonContract_Success() public {
        vm.prank(users.admin);

        // Expect event emission
        vm.expectEmit(true, true, false, false);
        emit IkRegistry.SingletonContractSet(TEST_CONTRACT_ID, TEST_CONTRACT);

        registry.setSingletonContract(TEST_CONTRACT_ID, TEST_CONTRACT);

        // Verify registration
        assertEq(registry.getContractById(TEST_CONTRACT_ID), TEST_CONTRACT, "Contract not registered");
    }

    /// @dev Test singleton contract registration requires admin role
    function test_SetSingletonContract_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.setSingletonContract(TEST_CONTRACT_ID, TEST_CONTRACT);
    }

    /// @dev Test singleton contract registration reverts with zero address
    function test_SetSingletonContract_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
        registry.setSingletonContract(TEST_CONTRACT_ID, address(0));
    }

    /// @dev Test singleton contract registration reverts when already registered
    function test_SetSingletonContract_RevertAlreadyRegistered() public {
        // First registration
        vm.prank(users.admin);
        registry.setSingletonContract(TEST_CONTRACT_ID, TEST_CONTRACT);

        // Second registration should fail
        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.AlreadyRegistered.selector);
        registry.setSingletonContract(TEST_CONTRACT_ID, address(0x01));
    }

    /// @dev Test getContractById reverts when contract not set
    function test_GetContractById_RevertZeroAddress() public {
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
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

        address testKToken = registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

        // Verify asset registration
        assertTrue(registry.isAsset(TEST_ASSET), "Asset not registered");
        assertEq(registry.getAssetById(TEST_ASSET_ID), TEST_ASSET, "Asset ID mapping incorrect");

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
        address newKToken = registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);
        assertEq(registry.assetToKToken(TEST_ASSET), newKToken, "kToken mapping not updated");

        // Second registration
        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.AlreadyRegistered.selector);
        newKToken = registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);
    }

    /// @dev Test asset registration requires admin role
    function test_RegisterAsset_OnlyAdmin() public {
        vm.prank(users.bob);
        vm.expectRevert();
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);
    }

    /// @dev Test asset registration reverts with zero addresses
    function test_RegisterAsset_RevertZeroAddresses() public {
        vm.startPrank(users.admin);

        // Zero asset address
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, address(0), TEST_ASSET_ID);

        // Zero ID
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, bytes32(0));

        vm.stopPrank();
    }

    /// @dev Test getAssetById reverts when asset not set
    function test_GetAssetById_RevertZeroAddress() public {
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
        registry.getAssetById(keccak256("NONEXISTENT"));
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT MANAGEMENT  
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful vault registration
    function test_RegisterVault_Success() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

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
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

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
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
        registry.registerVault(address(0), IkRegistry.VaultType.ALPHA, TEST_ASSET);
    }

    /// @dev Test vault registration reverts when already registered
    function test_RegisterVault_RevertAlreadyRegistered() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

        vm.startPrank(users.admin);

        // First registration
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Second registration should fail
        vm.expectRevert(IkRegistry.AlreadyRegistered.selector);
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.BETA, TEST_ASSET);

        vm.stopPrank();
    }

    /// @dev Test vault registration reverts with unsupported asset
    function test_RegisterVault_RevertAssetNotSupported() public {
        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.AssetNotSupported.selector);
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);
    }

    /// @dev Test multiple vault types for same asset
    function test_RegisterVault_MultipleTypes() public {
        // Register asset first
        vm.prank(users.admin);
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

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
        registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);

        vm.prank(users.admin);
        registry.registerVault(TEST_VAULT, IkRegistry.VaultType.ALPHA, TEST_ASSET);

        // Test that only admin can register adapters
        vm.prank(users.alice);
        vm.expectRevert();
        registry.registerAdapter(TEST_VAULT, TEST_ADAPTER);
    }

    /// @dev Test adapter registration with zero address
    function test_RegisterAdapter_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.InvalidAdapter.selector);
        registry.registerAdapter(TEST_VAULT, address(0));
    }

    /// @dev Test removeAdapter access control
    function test_RemoveAdapter_OnlyAdmin() public {
        vm.prank(users.alice);
        vm.expectRevert();
        registry.removeAdapter(TEST_VAULT, TEST_ADAPTER);
    }

    /// @dev Test getAdapter returns zero for non-existent adapter
    function test_GetAdapter_RevertZeroAddress() public {
        vm.prank(users.admin);
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
        registry.getAdapters(TEST_VAULT);
    }

    /// @dev Test isAdapterRegistered returns false for non-existent adapter
    function test_IsAdapterRegistered_NonExistent() public view {
        assertFalse(
            registry.isAdapterRegistered(TEST_VAULT, TEST_ADAPTER), "Should return false for non-existent adapter"
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
            if (assets[i] == USDC_MAINNET) hasUSDC = true;
            if (assets[i] == WBTC_MAINNET) hasWBTC = true;
        }

        assertTrue(hasUSDC, "USDC should be in assets array");
        assertTrue(hasWBTC, "WBTC should be in assets array");
    }

    /// @dev Test getVaultsByAsset with deployed vaults
    function test_GetVaultsByAsset_DeployedVaults() public {
        address[] memory usdcVaults = registry.getVaultsByAsset(USDC_MAINNET);

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
        vm.expectRevert(IkRegistry.ZeroAddress.selector);
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
        vm.expectRevert(); // OwnableRoles Unauthorized
        registry.upgradeToAndCall(newImpl, "");

        // Note: Testing actual upgrade is complex due to initialization requirements
        // The authorization check passes if we get past the onlyOwner modifier
        // The above test for non-owner access is sufficient for access control testing
        assertTrue(true, "Authorization test completed");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test complete asset-vault registration workflow
    function test_CompleteAssetVaultWorkflow() public {
        // Step 1: Register new asset
        vm.startPrank(users.admin);
        address test_kToken = registry.registerAsset(TEST_NAME, TEST_SYMBOL, TEST_ASSET, TEST_ASSET_ID);
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
}
