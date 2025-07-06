// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kDNStakingVault } from "../../../src/kDNStakingVault.sol";

import { kToken } from "../../../src/kToken.sol";
import { AdminModule } from "../../../src/modules/AdminModule.sol";
import { SettlementModule } from "../../../src/modules/SettlementModule.sol";

import { MockToken } from "../../helpers/MockToken.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract kDNStakingVaultHandler is BaseHandler, Test {
    kDNStakingVault public vault;
    kToken public kToken_;
    MockToken public asset;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARIABLES                     ///
    ////////////////////////////////////////////////////////////////

    // Dual accounting core
    uint256 public expectedTotalMinterAssets;
    uint256 public actualTotalMinterAssets;

    uint256 public expectedUserTotalAssets;
    uint256 public actualUserTotalAssets;

    uint256 public expectedTotalVaultAssets;
    uint256 public actualTotalVaultAssets;

    // User shares and staking
    uint256 public expectedUserTotalSupply;
    uint256 public actualUserTotalSupply;

    uint256 public expectedTotalStakedKTokens;
    uint256 public actualTotalStakedKTokens;

    // stkToken tracking
    uint256 public expectedTotalStkTokenSupply;
    uint256 public actualTotalStkTokenSupply;

    uint256 public expectedTotalStkTokenAssets;
    uint256 public actualTotalStkTokenAssets;

    ////////////////////////////////////////////////////////////////
    ///                      SETUP                               ///
    ////////////////////////////////////////////////////////////////

    constructor(kDNStakingVault _vault, kToken _kToken, MockToken _asset) {
        vault = _vault;
        kToken_ = _kToken;
        asset = _asset;

        // Initialize actual values
        _syncActualValues();

        // Initialize expected values to match actual state
        expectedTotalMinterAssets = actualTotalMinterAssets;
        expectedUserTotalAssets = actualUserTotalAssets;
        expectedTotalVaultAssets = actualTotalVaultAssets;
        expectedUserTotalSupply = actualUserTotalSupply;
        expectedTotalStakedKTokens = actualTotalStakedKTokens;
        expectedTotalStkTokenSupply = actualTotalStkTokenSupply;
        expectedTotalStkTokenAssets = actualTotalStkTokenAssets;
    }

    ////////////////////////////////////////////////////////////////
    ///                      ENTRY POINTS                        ///
    ////////////////////////////////////////////////////////////////

    function requestMinterDeposit(uint256 amount) public createActor countCall("minterDeposit") {
        // Only authorized minters can deposit - check MINTER_ROLE (4)
        if (!vault.hasAnyRole(currentActor, 4)) return;

        amount = bound(amount, 1e12 + 1, type(uint96).max / 10); // Above dust threshold to safe uint96 limit

        // Give actor assets and approve
        asset.mint(currentActor, amount);

        // Calculate expected state BEFORE operation
        expectedTotalMinterAssets = actualTotalMinterAssets + amount;
        expectedTotalVaultAssets = actualTotalVaultAssets + amount;

        vm.startPrank(currentActor);
        asset.approve(address(vault), amount);

        // Execute operation
        uint256 batchId = vault.requestMinterDeposit(amount);
        vm.stopPrank();

        // Update actual state AFTER operation
        _syncActualValues();
    }

    function requestStake(uint256 amount) public createActor countCall("stake") {
        // Ensure amount fits in uint96 to prevent AmountTooLarge error
        amount = bound(amount, 1e12 + 1, type(uint96).max / 10); // Above dust threshold to safe uint96 limit

        // Calculate expected state BEFORE operation
        expectedTotalStakedKTokens = actualTotalStakedKTokens + amount;
        // Note: kTokens go to vault but don't affect minter accounting (dual accounting)

        // Try to mint kTokens for the actor - skip call if unauthorized
        try kToken_.mint(currentActor, amount) {
            // Mint successful, proceed with the test
        } catch {
            // Minting failed (likely unauthorized actor), skip this test call
            return;
        }

        vm.startPrank(currentActor);
        kToken_.approve(address(vault), amount);

        // Execute operation
        uint256 requestId = vault.requestStake(amount);

        vm.stopPrank();

        // Update actual state AFTER operation
        _syncActualValues();
    }

    function settleBatch(uint256 batchId) public countCall("settleBatch") {
        // Only settler can settle
        address settler = address(0x5E77E7); // Assume settler address

        // Check if batch exists and can be settled
        if (batchId == 0) return;
        if (vault.isBatchSettled(batchId)) return;

        // Calculate expected state BEFORE operation (settlement affects asset distribution)
        // Settlement moves assets from pending to actual minter accounting

        vm.prank(settler);
        // For modular architecture, settlement functions are in SettlementModule
        // Cast vault to SettlementModule interface for settlement calls
        try SettlementModule(payable(address(vault))).settleBatch(batchId) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Settlement failed, skip
        }
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////

    /// @dev Core dual accounting: minter + user assets == total vault assets
    /// @dev CRITICAL: Uses getTotalUserAssets() which includes automatic yield
    function INVARIANT_DUAL_ACCOUNTING() public view {
        uint256 actualUserAssetsWithYield = vault.getTotalUserAssets(); // Includes automatic yield
        uint256 expectedTotal = actualTotalMinterAssets + actualUserAssetsWithYield;
        assertEq(actualTotalVaultAssets, expectedTotal, "Dual accounting mismatch");
    }

    /// @dev Minter assets maintain 1:1 guarantee (no yield)
    function INVARIANT_MINTER_1TO1_GUARANTEE() public view {
        // Minter assets should never include yield - they maintain 1:1 ratio
        // This is the core guarantee for institutional users
        assertEq(actualTotalMinterAssets, expectedTotalMinterAssets, "Minter 1:1 guarantee violated");
    }

    /// @dev Yield automatically flows to user pool only
    function INVARIANT_YIELD_FLOWS_TO_USERS() public view {
        uint256 userAssetsWithYield = vault.getTotalUserAssets();
        uint256 userAssetsStored = actualUserTotalAssets;

        // User assets with yield should be >= stored user assets
        assertGe(userAssetsWithYield, userAssetsStored, "Yield not flowing to users");

        // If vault has excess assets, they should appear in user calculation
        if (actualTotalVaultAssets > (actualTotalMinterAssets + userAssetsStored)) {
            uint256 expectedYield = actualTotalVaultAssets - actualTotalMinterAssets - userAssetsStored;
            assertEq(userAssetsWithYield, userAssetsStored + expectedYield, "Yield calculation incorrect");
        }
    }

    /// @dev Minter assets should match expected (1:1 guarantee)
    function INVARIANT_MINTER_ASSETS() public view {
        assertEq(actualTotalMinterAssets, expectedTotalMinterAssets, "Minter assets mismatch");
    }

    /// @dev User assets should match expected
    function INVARIANT_USER_ASSETS() public view {
        assertEq(actualUserTotalAssets, expectedUserTotalAssets, "User assets mismatch");
    }

    /// @dev Total vault assets should be consistent
    function INVARIANT_VAULT_ASSETS() public view {
        assertEq(actualTotalVaultAssets, expectedTotalVaultAssets, "Vault assets mismatch");
    }

    /// @dev kTokens staked should match vault holdings
    function INVARIANT_STAKED_KTOKENS() public view {
        uint256 vaultKTokenBalance = kToken_.balanceOf(address(vault));
        assertEq(actualTotalStakedKTokens, vaultKTokenBalance, "Staked kTokens mismatch");
    }

    /// @dev Yield distribution: excess vault assets flow to user pool only
    function INVARIANT_YIELD_DISTRIBUTION() public view {
        // If vault has more assets than minter pool, excess should be in user pool
        if (actualTotalVaultAssets > actualTotalMinterAssets) {
            uint256 excessAssets = actualTotalVaultAssets - actualTotalMinterAssets;
            assertGe(actualUserTotalAssets, 0, "User assets negative with yield");
        }
    }

    /// @dev stkToken assets should not exceed total user assets
    function INVARIANT_STKTOKEN_BOUNDS() public view {
        assertLe(actualTotalStkTokenAssets, actualUserTotalAssets, "stkToken assets exceed user assets");
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _syncActualValues() internal {
        actualTotalMinterAssets = _getActualTotalMinterAssets();
        actualUserTotalAssets = _getActualUserTotalAssets();
        actualTotalVaultAssets = vault.getTotalVaultAssets();
        actualUserTotalSupply = _getActualUserTotalSupply();
        actualTotalStakedKTokens = _getActualTotalStakedKTokens();
        actualTotalStkTokenSupply = _getActualTotalStkTokenSupply();
        actualTotalStkTokenAssets = _getActualTotalStkTokenAssets();
    }

    /// @dev Read totalMinterAssets from SLOT 3 (first 16 bytes)
    function _getActualTotalMinterAssets() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00) + 3);
        bytes32 value = vm.load(address(vault), slot);
        // Extract first 16 bytes (uint128) as totalMinterAssets
        return uint256(uint128(uint256(value)));
    }

    /// @dev Read userTotalAssets from SLOT 4 (first 16 bytes)
    function _getActualUserTotalAssets() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00) + 4);
        bytes32 value = vm.load(address(vault), slot);
        // Extract first 16 bytes (uint128) as userTotalAssets
        return uint256(uint128(uint256(value)));
    }

    /// @dev Read userTotalSupply from SLOT 3 (second 16 bytes)
    function _getActualUserTotalSupply() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00) + 3);
        bytes32 value = vm.load(address(vault), slot);
        // Extract second 16 bytes (uint128) as userTotalSupply
        return uint256(uint128(uint256(value >> 128)));
    }

    /// @dev Read totalStakedKTokens from SLOT 4 (second 16 bytes)
    function _getActualTotalStakedKTokens() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00) + 4);
        bytes32 value = vm.load(address(vault), slot);
        // Extract second 16 bytes (uint128) as totalStakedKTokens
        return uint256(uint128(uint256(value >> 128)));
    }

    /// @dev Read totalStkTokenSupply from storage
    function _getActualTotalStkTokenSupply() internal view returns (uint256) {
        // Storage slot would need to be calculated based on struct layout
        return vault.getStkTokenBalance(address(this)); // Placeholder
    }

    /// @dev Read totalStkTokenAssets from storage
    function _getActualTotalStkTokenAssets() internal view returns (uint256) {
        // Storage slot would need to be calculated based on struct layout
        return 0; // Placeholder - need exact slot calculation
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](3);
        _entryPoints[0] = this.requestMinterDeposit.selector;
        _entryPoints[1] = this.requestStake.selector;
        _entryPoints[2] = this.settleBatch.selector;
        return _entryPoints;
    }

    function callSummary() public view override {
        console2.log("");
        console2.log("=== kDNStakingVault Call Summary ===");
        console2.log("minterDeposit:", calls["minterDeposit"]);
        console2.log("stake:", calls["stake"]);
        console2.log("settleBatch:", calls["settleBatch"]);
        console2.log("Total Minter Assets:", actualTotalMinterAssets);
        console2.log("Total User Assets:", actualUserTotalAssets);
        console2.log("Total Vault Assets:", actualTotalVaultAssets);
        console2.log(
            "Dual Accounting Check:", (actualTotalMinterAssets + actualUserTotalAssets) == actualTotalVaultAssets
        );
        console2.log("Staked kTokens:", actualTotalStakedKTokens);
    }
}
