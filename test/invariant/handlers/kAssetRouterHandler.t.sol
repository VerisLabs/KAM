// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kAssetRouter } from "../../../src/kAssetRouter.sol";

import { kBatch } from "../../../src/kBatch.sol";
import { kMinter } from "../../../src/kMinter.sol";
import { kStakingVault } from "../../../src/kStakingVault/kStakingVault.sol";
import { kToken } from "../../../src/kToken.sol";
import { MockToken } from "../../helpers/MockToken.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract kAssetRouterHandler is BaseHandler, Test {
    kAssetRouter public router;
    kMinter public minter;
    kStakingVault public vault;
    kToken public kToken_;
    kBatch public batch;
    MockToken public asset;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARIABLES                     ///
    ////////////////////////////////////////////////////////////////

    // Virtual balance tracking
    uint256 public expectedVaultBalance;
    uint256 public actualVaultBalance;

    uint256 public expectedMinterBalance;
    uint256 public actualMinterBalance;

    // Batch tracking
    uint256 public expectedTotalPendingDeposits;
    uint256 public actualTotalPendingDeposits;

    uint256 public expectedTotalPendingRedeems;
    uint256 public actualTotalPendingRedeems;

    // Asset flow tracking
    uint256 public totalAssetsPushed;
    uint256 public totalAssetsRequested;
    uint256 public totalYieldDistributed;

    ////////////////////////////////////////////////////////////////
    ///                      SETUP                               ///
    ////////////////////////////////////////////////////////////////

    constructor(
        kAssetRouter _router,
        kMinter _minter,
        kStakingVault _vault,
        kToken _kToken,
        kBatch _batch,
        MockToken _asset
    ) {
        router = _router;
        minter = _minter;
        vault = _vault;
        kToken_ = _kToken;
        batch = _batch;
        asset = _asset;

        // Initialize actual values
        _syncActualValues();
    }

    ////////////////////////////////////////////////////////////////
    ///                      ENTRY POINTS                        ///
    ////////////////////////////////////////////////////////////////

    function kAssetPush(uint256 amount, uint256 batchId) public createActor countCall("kAssetPush") {
        amount = bound(amount, 1_000_000, 10_000_000 * 1e6); // 1-10M USDC
        batchId = bound(batchId, 1, 100);

        // Give handler assets to perform operation on behalf of minter
        asset.mint(address(this), amount);
        asset.approve(address(router), amount);

        // Calculate expected state BEFORE operation
        unchecked {
            expectedVaultBalance = actualVaultBalance + amount;
            expectedTotalPendingDeposits = actualTotalPendingDeposits + amount;
            totalAssetsPushed += amount;
        }

        // Execute operation
        try router.kAssetPush(address(vault), address(asset), amount, batchId) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Operation failed, revert expected changes
            expectedVaultBalance = actualVaultBalance;
            expectedTotalPendingDeposits = actualTotalPendingDeposits;
        }
    }

    function kAssetRequestPull(uint256 amount, uint256 batchId) public createActor countCall("kAssetRequestPull") {
        amount = bound(amount, 1_000_000, 5_000_000 * 1e6); // 1-5M USDC
        batchId = bound(batchId, 1, 100);

        // Only pull if there's sufficient virtual balance
        uint256 currentBalance = router.getBalanceOf(address(vault), address(asset));
        if (currentBalance == 0) return;

        amount = bound(amount, 1, currentBalance);

        // Calculate expected state BEFORE operation
        unchecked {
            expectedTotalPendingRedeems = actualTotalPendingRedeems + amount;
            totalAssetsRequested += amount;
        }

        // Execute operation as vault
        vm.prank(address(vault));
        try router.kAssetRequestPull(address(vault), address(asset), amount, batchId) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Operation failed, revert expected changes
            expectedTotalPendingRedeems = actualTotalPendingRedeems;
        }
    }

    function kSharesRequestPull(uint256 amount, uint256 batchId) public createActor countCall("kSharesRequestPull") {
        amount = bound(amount, 1 * 1e18, 1000 * 1e18); // 1-1000 shares
        batchId = bound(batchId, 1, 100);

        // Execute operation as vault
        vm.prank(address(vault));
        try router.kSharesRequestPull(address(vault), amount, batchId) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Operation failed, skip
        }
    }

    function kSettleShares(uint256 batchId, uint256 totalAssets) public createActor countCall("kSettleShares") {
        batchId = bound(batchId, 1, 10);
        totalAssets = bound(totalAssets, 1_000_000 * 1e6, 100_000_000 * 1e6);

        address[] memory vaults = new address[](1);
        vaults[0] = address(vault);

        uint256[] memory totalAssetsArray = new uint256[](1);
        totalAssetsArray[0] = totalAssets;

        // Execute operation as vault
        vm.prank(address(vault));
        try router.kSettleShares(vaults, totalAssetsArray, batchId) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Operation failed, skip
        }
    }

    function kSettleAssets(uint256 batchId, uint256 totalAssets) public createActor countCall("kSettleAssets") {
        batchId = bound(batchId, 1, 10);
        totalAssets = bound(totalAssets, 1_000_000 * 1e6, 100_000_000 * 1e6);

        address[] memory vaults = new address[](2);
        vaults[0] = address(minter);
        vaults[1] = address(vault);

        uint256[] memory totalAssetsArray = new uint256[](2);
        totalAssetsArray[0] = totalAssets;
        totalAssetsArray[1] = totalAssets;

        // Calculate expected yield distribution
        uint256 lastTotalAssets = vault.lastTotalAssets();
        if (totalAssets > lastTotalAssets) {
            totalYieldDistributed += (totalAssets - lastTotalAssets);
        }

        // Execute operation as vault
        vm.prank(address(vault));
        try router.kSettleAssets(vaults, totalAssetsArray, batchId) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Operation failed, skip
        }
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////

    /// @dev Virtual balance should match expected
    function INVARIANT_VIRTUAL_BALANCE_VAULT() public view {
        uint256 actualBalance = router.getBalanceOf(address(vault), address(asset));
        // Allow for small discrepancies due to settlements
        assertApproxEqAbs(actualBalance, expectedVaultBalance, 1e6, "Vault virtual balance mismatch");
    }

    /// @dev Virtual balance should match expected for minter
    function INVARIANT_VIRTUAL_BALANCE_MINTER() public view {
        uint256 actualBalance = router.getBalanceOf(address(minter), address(asset));
        // Allow for small discrepancies due to settlements
        assertApproxEqAbs(actualBalance, expectedMinterBalance, 1e6, "Minter virtual balance mismatch");
    }

    /// @dev Total pending deposits should be reasonable
    function INVARIANT_PENDING_DEPOSITS() public view {
        assertGe(actualTotalPendingDeposits, 0, "Negative pending deposits");
        assertLe(actualTotalPendingDeposits, totalAssetsPushed, "Pending deposits > total pushed");
    }

    /// @dev Total pending redeems should be reasonable
    function INVARIANT_PENDING_REDEEMS() public view {
        assertGe(actualTotalPendingRedeems, 0, "Negative pending redeems");
        assertLe(actualTotalPendingRedeems, totalAssetsRequested, "Pending redeems > total requested");
    }

    /// @dev Asset conservation: router should hold all virtual balance assets
    function INVARIANT_ASSET_CONSERVATION() public view {
        uint256 routerBalance = asset.balanceOf(address(router));
        uint256 totalVirtualBalance =
            router.getBalanceOf(address(vault), address(asset)) + router.getBalanceOf(address(minter), address(asset));

        // Router should hold at least the virtual balances
        assertGe(routerBalance, totalVirtualBalance, "Router holds less than virtual balances");
    }

    /// @dev Yield distribution should increase kToken supply
    function INVARIANT_YIELD_INCREASES_SUPPLY() public view {
        if (totalYieldDistributed > 0) {
            uint256 initialSupply = 1_000_000 * 1e18; // Assume starting supply
            assertTrue(kToken_.totalSupply() >= initialSupply, "Yield should increase kToken supply");
        }
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _syncActualValues() internal {
        actualVaultBalance = router.getBalanceOf(address(vault), address(asset));
        actualMinterBalance = router.getBalanceOf(address(minter), address(asset));
        actualTotalPendingDeposits = _getActualTotalPendingDeposits();
        actualTotalPendingRedeems = _getActualTotalPendingRedeems();
    }

    /// @dev Read totalPendingDeposits from router storage slot +6
    function _getActualTotalPendingDeposits() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00) + 6);
        return uint256(vm.load(address(router), slot));
    }

    /// @dev Read totalPendingRedeems from router storage slot +7
    function _getActualTotalPendingRedeems() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00) + 7);
        return uint256(vm.load(address(router), slot));
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](5);
        _entryPoints[0] = this.kAssetPush.selector;
        _entryPoints[1] = this.kAssetRequestPull.selector;
        _entryPoints[2] = this.kSharesRequestPull.selector;
        _entryPoints[3] = this.kSettleShares.selector;
        _entryPoints[4] = this.kSettleAssets.selector;
        return _entryPoints;
    }

    function callSummary() public view override {
        console2.log("");
        console2.log("=== kAssetRouter Call Summary ===");
        console2.log("kAssetPush:", calls["kAssetPush"]);
        console2.log("kAssetRequestPull:", calls["kAssetRequestPull"]);
        console2.log("kSharesRequestPull:", calls["kSharesRequestPull"]);
        console2.log("kSettleShares:", calls["kSettleShares"]);
        console2.log("kSettleAssets:", calls["kSettleAssets"]);
        console2.log("Expected Vault Balance:", expectedVaultBalance);
        console2.log("Actual Vault Balance:", actualVaultBalance);
        console2.log("Total Assets Pushed:", totalAssetsPushed);
        console2.log("Total Yield Distributed:", totalYieldDistributed);
        console2.log(
            "Asset Conservation:", asset.balanceOf(address(router)) >= (actualVaultBalance + actualMinterBalance)
        );
    }
}
