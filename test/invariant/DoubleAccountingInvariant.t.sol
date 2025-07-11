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
    AdminModule public adminModule;
    SettlementModule public settlementModule;

    ////////////////////////////////////////////////////////////////
    ///                      HANDLERS                            ///
    ////////////////////////////////////////////////////////////////

    kDNStakingVaultHandler public vaultHandler;

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

        // Set up handlers first
        vaultHandler = new kDNStakingVaultHandler(vault, kToken(address(testKToken)), asset);

        // Grant roles using properly configured AdminModule interface
        vm.startPrank(admin);
        // admin already has ADMIN_ROLE from initialization (roles: 1)
        testKToken.grantMinterRole(address(vault)); // Grant minter role to vault
        testKToken.grantMinterRole(address(vaultHandler)); // Grant minter role to handler
        vm.stopPrank();

        // Target contracts for invariant testing
        targetContract(address(vaultHandler));

        // Target selectors
        bytes4[] memory vaultSelectors = vaultHandler.getEntryPoints();
        for (uint256 i = 0; i < vaultSelectors.length; i++) {
            targetSelector(
                FuzzSelector({ addr: address(vaultHandler), selectors: _toSingletonArray(vaultSelectors[i]) })
            );
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
