// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { kDNStakingVault } from "src/kDNStakingVault.sol";

import { kMinter } from "src/kMinter.sol";
import { kToken } from "src/kToken.sol";
import { AdminModule } from "src/modules/AdminModule.sol";

import { ClaimModule } from "src/modules/ClaimModule.sol";
import { SettlementModule } from "src/modules/SettlementModule.sol";
import { MockToken } from "test/helpers/MockToken.sol";
import { MockkDNStaking } from "test/helpers/MockkDNStaking.sol";
import { TestToken } from "test/helpers/TestToken.sol";
import { kDNStakingVaultProxy } from "test/helpers/kDNStakingVaultProxy.sol";
import { kMinterProxy } from "test/helpers/kMinterProxy.sol";

import { kDNStakingVaultHandler } from "test/invariant/handlers/kDNStakingVaultHandler.t.sol";
import { kMinterHandler } from "test/invariant/handlers/kMinterHandler.t.sol";

import { DataTypes } from "src/types/DataTypes.sol";
import {
    ADMIN_ROLE,
    EMERGENCY_ADMIN_ROLE,
    INSTITUTION_ROLE,
    MINTER_ROLE,
    SETTLEMENT_INTERVAL,
    SETTLER_ROLE
} from "test/utils/Constants.sol";

/// @title Double Accounting Invariant Tests
/// @notice Tests the critical invariants of the dual accounting system
contract DoubleAccountingInvariant is StdInvariant, Test {
    ////////////////////////////////////////////////////////////////
    ///                      CONTRACTS                           ///
    ////////////////////////////////////////////////////////////////

    MockToken public asset;
    TestToken public testKToken; // Use TestToken to avoid proxy issues
    MockkDNStaking public mockStaking;
    kDNStakingVault public vault;
    kDNStakingVault public vaultImpl;
    kDNStakingVaultProxy public proxyDeployer;
    kMinter public minter;
    AdminModule public adminModule;
    SettlementModule public settlementModule;

    ////////////////////////////////////////////////////////////////
    ///                      HANDLERS                            ///
    ////////////////////////////////////////////////////////////////

    kDNStakingVaultHandler public vaultHandler;
    kMinterHandler public minterHandler;

    ////////////////////////////////////////////////////////////////
    ///                      ACTORS                              ///
    ////////////////////////////////////////////////////////////////

    address public admin = address(0x1);
    address public emergencyAdmin = address(0x2);
    address public institution = address(0x3);
    address public settler = address(0x4);
    address public alice = address(0x5);

    function setUp() public {
        // Deploy asset token
        asset = new MockToken("USDC", "USDC", 6);

        // Deploy test kToken (simple ERC20 for testing)
        testKToken = new TestToken();

        // Initialize kToken
        testKToken.initialize(
            "KAM USDC",
            "kUSD",
            6,
            alice, // owner
            admin, // admin
            emergencyAdmin, // emergency admin
            address(this) // initial minter
        );

        // Deploy mock staking vault
        mockStaking = new MockkDNStaking();
        mockStaking.setAsset(address(asset));

        // Deploy kDNStakingVault implementation
        vaultImpl = new kDNStakingVault();

        // Deploy proxy deployer
        proxyDeployer = new kDNStakingVaultProxy();

        // Prepare initialization data for new signature
        bytes memory initData = abi.encodeWithSelector(
            kDNStakingVault.initialize.selector,
            address(asset), // asset_
            address(testKToken), // kToken_
            alice, // owner_
            admin, // admin_
            emergencyAdmin, // emergencyAdmin_
            settler, // settler_
            alice, // strategyManager_
            6 // decimals_
        );

        // Deploy and initialize proxy
        address proxyAddress = proxyDeployer.deployAndInitialize(address(vaultImpl), initData);
        vault = kDNStakingVault(payable(proxyAddress));

        // Deploy modules
        adminModule = new AdminModule();
        settlementModule = new SettlementModule();

        // Configure modules in MultiFacetProxy using the fixed authorization
        // admin (not alice) has ADMIN_ROLE from initialization
        vm.startPrank(admin);

        // Add AdminModule functions
        bytes4[] memory adminSelectors = adminModule.selectors();
        vault.addFunctions(adminSelectors, address(adminModule), false);

        // Add SettlementModule functions
        bytes4[] memory settlementSelectors = settlementModule.selectors();
        vault.addFunctions(settlementSelectors, address(settlementModule), false);

        // Add ClaimModule functions
        ClaimModule claimModule = new ClaimModule();
        bytes4[] memory claimSelectors = claimModule.selectors();
        vault.addFunctions(claimSelectors, address(claimModule), false);

        vm.stopPrank();

        console2.log("Module configuration completed successfully!");

        // Deploy kMinter
        kMinter minterImpl = new kMinter();
        kMinterProxy minterProxyDeployer = new kMinterProxy();

        DataTypes.InitParams memory initParams = DataTypes.InitParams({
            kToken: address(testKToken),
            underlyingAsset: address(asset),
            owner: alice,
            admin: admin,
            emergencyAdmin: emergencyAdmin,
            institution: institution,
            settler: settler,
            manager: address(vault), // kDNStaking vault as manager
            settlementInterval: 3600 // 1 hour
         });

        bytes memory minterInitData = abi.encodeWithSelector(kMinter.initialize.selector, initParams);

        address minterProxyAddress = minterProxyDeployer.deployAndInitialize(address(minterImpl), minterInitData);
        minter = kMinter(payable(minterProxyAddress));

        // Set up handlers with cross-references for synchronization
        vaultHandler = new kDNStakingVaultHandler(vault, kToken(address(testKToken)), asset);
        minterHandler = new kMinterHandler(minter, kToken(address(testKToken)), asset, mockStaking);

        // CRITICAL: Set up cross-handler synchronization
        vaultHandler.setMinterHandler(address(minterHandler));
        minterHandler.setVaultHandler(address(vaultHandler));

        // Grant roles using properly configured AdminModule interface
        vm.startPrank(admin);

        // CRITICAL: kDNStakingVault MUST have MINTER_ROLE on kToken for yield distribution
        testKToken.grantMinterRole(address(vault));

        // CRITICAL: kMinter MUST have MINTER_ROLE on kToken to mint for institutions
        testKToken.grantMinterRole(address(minter));

        // Grant handler roles for fuzzing
        testKToken.grantMinterRole(address(vaultHandler)); // For direct vault operations

        // CRITICAL: Institutions need INSTITUTION_ROLE on kMinter to deposit USDC/WBTC
        minter.grantInstitutionRole(address(minterHandler)); // Handler acts as institution

        // CRITICAL: kMinter needs MINTER_ROLE on kDNStakingVault to deposit/redeem
        AdminModule(payable(address(vault))).grantMinterRole(address(minter));

        // CRITICAL: kMinter needs to know about the kDNStakingVault
        minter.setKDNStaking(address(vault));

        vm.stopPrank();

        // Target contracts for invariant testing
        targetContract(address(vaultHandler));
        targetContract(address(minterHandler));

        // Target vault selectors
        bytes4[] memory vaultSelectors = vaultHandler.getEntryPoints();
        uint256 length = vaultSelectors.length;
        for (uint256 i; i < length;) {
            targetSelector(
                FuzzSelector({ addr: address(vaultHandler), selectors: _toSingletonArray(vaultSelectors[i]) })
            );

            unchecked {
                i++;
            }
        }

        // Target minter selectors
        bytes4[] memory minterSelectors = minterHandler.getEntryPoints();
        length = minterSelectors.length;
        for (uint256 i; i < length;) {
            targetSelector(
                FuzzSelector({ addr: address(minterHandler), selectors: _toSingletonArray(minterSelectors[i]) })
            );

            unchecked {
                i++;
            }
        }

        console2.log("=== Double Accounting Invariant Test Setup Complete ===");
        console2.log("Asset:", address(asset));
        console2.log("kToken:", address(testKToken));
        console2.log("Vault:", address(vault));
        console2.log("VaultHandler:", address(vaultHandler));
        console2.log("AdminModule:", address(adminModule));
        console2.log("SettlementModule:", address(settlementModule));
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////

    /// @dev Critical: Dual accounting must always balance
    function invariant_DualAccounting() public view {
        vaultHandler.INVARIANT_DUAL_ACCOUNTING();
    }

    /// @dev Minter assets maintain 1:1 guarantee
    function invariant_MinterAssets() public view {
        vaultHandler.INVARIANT_MINTER_ASSETS();
    }

    /// @dev User assets accounting
    function invariant_UserAssets() public view {
        vaultHandler.INVARIANT_USER_ASSETS();
    }

    /// @dev Total vault assets consistency
    function invariant_VaultAssets() public view {
        vaultHandler.INVARIANT_VAULT_ASSETS();
    }

    /// @dev Staked kTokens balance
    function invariant_StakedKTokens() public view {
        vaultHandler.INVARIANT_STAKED_KTOKENS();
    }

    /// @dev Yield distribution rules
    function invariant_YieldDistribution() public view {
        vaultHandler.INVARIANT_YIELD_DISTRIBUTION();
    }

    /// @dev stkToken bounds
    function invariant_StkTokenBounds() public view {
        vaultHandler.INVARIANT_STKTOKEN_BOUNDS();
    }

    /// @dev CRITICAL: Peg protection - validates the unstaking settlement fix
    function invariant_PegProtection() public view {
        vaultHandler.INVARIANT_PEG_PROTECTION();
    }

    /// @dev Enhanced dual accounting using data provider
    function invariant_EnhancedDualAccounting() public view {
        vaultHandler.INVARIANT_ENHANCED_DUAL_ACCOUNTING();
    }

    /// @dev Unstaking claim validation
    function invariant_UnstakingClaimTotals() public view {
        vaultHandler.INVARIANT_UNSTAKING_CLAIM_TOTALS();
    }

    /// @dev Escrow safety validation
    function invariant_EscrowSafety() public view {
        vaultHandler.INVARIANT_ESCROW_SAFETY();
    }

    /// @dev CRITICAL: USDC Lock Invariant following expected/actual pattern
    function invariant_USDCLock() public view {
        // Use the existing expected/actual pattern from vault handler
        uint256 actualVaultAssets = vaultHandler.actualTotalVaultAssets();
        uint256 expectedVaultAssets = vaultHandler.expectedTotalVaultAssets();

        // CRITICAL: Vault USDC should only change through tracked operations
        // Yield minting (kTokens) should NOT affect underlying USDC balance
        // The vault tracks kTokens as assets, but USDC backing should remain constant
        uint256 vaultUSDCBalance = asset.balanceOf(address(vault));

        // CORRECTED: USDC balance should match expected vault assets from tracked operations
        // This tests that yield minting doesn't affect USDC - USDC only changes from deposits/redeems
        assertEq(vaultUSDCBalance, expectedVaultAssets, "USDC Lock Violation: Vault USDC != expected vault assets");
    }

    /// @dev CRITICAL: kToken backing using expected/actual pattern
    function invariant_kTokenBacking() public view {
        // Follow the established pattern - compare expected vs actual
        uint256 actualMinterAssets = vaultHandler.actualTotalMinterAssets();
        uint256 expectedMinterAssets = vaultHandler.expectedTotalMinterAssets();

        // Minter assets should maintain 1:1 backing (this is tested elsewhere too)
        assertEq(actualMinterAssets, expectedMinterAssets, "kToken Backing: Minter assets expected/actual mismatch");

        // Additional check: Total kToken supply should have USDC backing
        uint256 vaultUSDCBalance = asset.balanceOf(address(vault));
        assertGe(vaultUSDCBalance, actualMinterAssets, "kToken Backing: Insufficient USDC for minter assets");
    }

    ////////////////////////////////////////////////////////////////
    ///                      CALL SUMMARY                        ///
    ////////////////////////////////////////////////////////////////

    function invariant_CallSummary() public view {
        vaultHandler.callSummary();
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _toSingletonArray(bytes4 selector) internal pure returns (bytes4[] memory) {
        bytes4[] memory array = new bytes4[](1);
        array[0] = selector;
        return array;
    }
}
