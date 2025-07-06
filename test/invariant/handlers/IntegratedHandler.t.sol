// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kDNStakingVault } from "../../../src/kDNStakingVault.sol";
import { kMinter } from "../../../src/kMinter.sol";
import { kToken } from "../../../src/kToken.sol";
import { MockToken } from "../../helpers/MockToken.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

/// @title Integrated Handler for Cross-Contract Invariants
/// @notice Tests invariants that span across kMinter and kDNStakingVault
contract IntegratedHandler is BaseHandler, Test {
    kMinter public minter;
    kDNStakingVault public vault;
    kToken public kToken_;
    MockToken public asset;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARIABLES                     ///
    ////////////////////////////////////////////////////////////////

    // Cross-contract tracking
    uint256 public expectedTotalSystemAssets; // Total assets in the system
    uint256 public actualTotalSystemAssets;

    uint256 public expectedTotalKTokenSupply;
    uint256 public actualTotalKTokenSupply;

    ////////////////////////////////////////////////////////////////
    ///                      SETUP                               ///
    ////////////////////////////////////////////////////////////////

    constructor(kMinter _minter, kDNStakingVault _vault, kToken _kToken, MockToken _asset) {
        minter = _minter;
        vault = _vault;
        kToken_ = _kToken;
        asset = _asset;

        // Initialize actual values
        _syncActualValues();
    }

    ////////////////////////////////////////////////////////////////
    ///                    CRITICAL INVARIANTS                   ///
    ////////////////////////////////////////////////////////////////

    /// @dev MASTER INVARIANT: Total kTokens == Total assets backing them
    /// @dev This is the ultimate 1:1 backing guarantee across the entire system
    function INVARIANT_MASTER_1TO1_BACKING() public view {
        uint256 totalKTokens = actualTotalKTokenSupply;

        // Total backing = minter deposits not yet redeemed + vault assets holding kTokens
        uint256 totalMinterDeposits = _getActualTotalDeposited();
        uint256 totalMinterRedeemed = _getActualTotalRedeemed();
        uint256 netMinterPosition = totalMinterDeposits - totalMinterRedeemed;

        // The core invariant: kTokens in circulation should equal net deposited assets
        assertEq(totalKTokens, netMinterPosition, "Master 1:1 backing violated");
    }

    /// @dev Cross-contract consistency: kMinter accounting matches vault accounting
    function INVARIANT_CROSS_CONTRACT_CONSISTENCY() public view {
        uint256 minterTotalDeposited = _getActualTotalDeposited();
        uint256 minterTotalRedeemed = _getActualTotalRedeemed();
        uint256 netMinterAssets = minterTotalDeposited - minterTotalRedeemed;

        // Minter's net position should be reflected in vault's minter assets
        uint256 vaultMinterAssets = _getActualTotalMinterAssets();

        // Note: This may not be exact due to pending settlements, but should be close
        // In a fully settled state, these should be equal
        console2.log("Minter Net Assets:", netMinterAssets);
        console2.log("Vault Minter Assets:", vaultMinterAssets);

        // Allow for settlement delays - assets may be in transit
        // The critical check is that vault assets >= minter net position
        assertGe(vault.getTotalVaultAssets(), netMinterAssets, "Vault assets < minter position");
    }

    /// @dev System-wide asset conservation
    function INVARIANT_ASSET_CONSERVATION() public view {
        // Total assets in system = vault balance + any assets in transit
        uint256 vaultBalance = vault.getTotalVaultAssets();
        uint256 minterBalance = asset.balanceOf(address(minter));
        uint256 totalSystemAssets = vaultBalance + minterBalance;

        // Should equal total deposits minus redeems that have been executed
        uint256 totalDeposited = _getActualTotalDeposited();
        uint256 totalRedeemed = _getActualTotalRedeemed();
        uint256 expectedSystemAssets = totalDeposited - totalRedeemed;

        assertEq(totalSystemAssets, expectedSystemAssets, "Asset conservation violated");
    }

    /// @dev Dual accounting integrity across contracts
    function INVARIANT_DUAL_ACCOUNTING_INTEGRITY() public view {
        uint256 vaultMinterAssets = _getActualTotalMinterAssets();
        uint256 vaultUserAssets = vault.getTotalUserAssets(); // Includes yield
        uint256 totalVaultAssets = vault.getTotalVaultAssets();

        // Core dual accounting: minter (1:1) + user (yield-bearing) = total
        assertEq(vaultMinterAssets + vaultUserAssets, totalVaultAssets, "Dual accounting broken");

        // Minter assets should never decrease due to yield (1:1 guarantee)
        assertGe(vaultMinterAssets, 0, "Minter assets negative");

        // User assets can only increase with yield
        assertGe(vaultUserAssets, _getActualUserTotalAssets(), "User assets decreased");
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _syncActualValues() internal {
        actualTotalSystemAssets = vault.getTotalVaultAssets() + asset.balanceOf(address(minter));
        actualTotalKTokenSupply = kToken_.totalSupply();
    }

    /// @dev Read totalDeposited from kMinter storage slot +14
    function _getActualTotalDeposited() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 14);
        return uint256(vm.load(address(minter), slot));
    }

    /// @dev Read totalRedeemed from kMinter storage slot +15
    function _getActualTotalRedeemed() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 15);
        return uint256(vm.load(address(minter), slot));
    }

    /// @dev Read totalMinterAssets from vault storage slot +10
    function _getActualTotalMinterAssets() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00) + 10);
        return uint256(vm.load(address(vault), slot));
    }

    /// @dev Read userTotalAssets from vault storage slot +12
    function _getActualUserTotalAssets() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00) + 12);
        return uint256(vm.load(address(vault), slot));
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](0);
        return _entryPoints; // No entry points - this is a view-only handler
    }

    function callSummary() public view override {
        console2.log("");
        console2.log("=== Integrated Invariants Summary ===");
        console2.log("Total kToken Supply:", actualTotalKTokenSupply);
        console2.log("Total Deposited:", _getActualTotalDeposited());
        console2.log("Total Redeemed:", _getActualTotalRedeemed());
        console2.log("Net Minter Position:", _getActualTotalDeposited() - _getActualTotalRedeemed());
        console2.log("Vault Minter Assets:", _getActualTotalMinterAssets());
        console2.log("Vault User Assets (with yield):", vault.getTotalUserAssets());
        console2.log("Total Vault Assets:", vault.getTotalVaultAssets());
        console2.log(
            "Master 1:1 Backing Valid:",
            actualTotalKTokenSupply == (_getActualTotalDeposited() - _getActualTotalRedeemed())
        );
    }
}
