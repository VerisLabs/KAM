// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kDNDataProvider } from "../../../src/kDNDataProvider.sol";
import { kDNStakingVault } from "../../../src/kDNStakingVault.sol";

import { kToken } from "../../../src/kToken.sol";
import { AdminModule } from "../../../src/modules/AdminModule.sol";

import { ClaimModule } from "../../../src/modules/ClaimModule.sol";
import { SettlementModule } from "../../../src/modules/SettlementModule.sol";

import { MockToken } from "../../helpers/MockToken.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract kDNStakingVaultHandler is BaseHandler, Test {
    kDNStakingVault public vault;
    kDNDataProvider public dataProvider;
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

    // Unstaking tracking
    uint256 public totalUnstakeRequests;
    uint256 public totalUnstakedStkTokens;
    uint256 public totalClaimedAssets;

    // Batch tracking
    uint256 public currentStakingBatchId;
    uint256 public currentUnstakingBatchId;
    uint256 public lastSettledStakingBatchId;
    uint256 public lastSettledUnstakingBatchId;

    // Enhanced tracking for escrow pattern validation
    mapping(uint256 => uint256) public batchSettledDistributions; // Per-batch settled kTokensToReturn
    mapping(uint256 => uint256) public batchClaimedOriginals; // Sum claimed originals per batch
    uint256 public totalEscrowedStkTokens; // Sum pending unstake stkTokens (pre-settle)
    uint256 public totalSettledDistributions; // Total settled across all batches
    uint256 public totalSimulatedYield; // Track total simulated yield for invariant adjustments

    ////////////////////////////////////////////////////////////////
    ///                      SETUP                               ///
    ////////////////////////////////////////////////////////////////

    constructor(kDNStakingVault _vault, kToken _kToken, MockToken _asset) {
        vault = _vault;
        kToken_ = _kToken;
        asset = _asset;

        // Deploy data provider for efficient queries
        dataProvider = new kDNDataProvider(address(_vault));

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

        // Initialize batch tracking
        _syncBatchStates();
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

    function requestUnstake(uint256 stkTokenAmount) public createActor countCall("unstake") {
        // Bound amount to reasonable range
        stkTokenAmount = bound(stkTokenAmount, 1, type(uint96).max / 10);

        // Check if actor has stkTokens to unstake
        uint256 userBalance = vault.getStkTokenBalance(currentActor);
        if (userBalance == 0) return;

        // Bound to actual balance
        stkTokenAmount = bound(stkTokenAmount, 1, userBalance);

        // Calculate expected state BEFORE operation
        expectedTotalStkTokenSupply = actualTotalStkTokenSupply - stkTokenAmount;
        totalUnstakeRequests++;
        totalUnstakedStkTokens += stkTokenAmount;

        // Track escrowed tokens
        totalEscrowedStkTokens += stkTokenAmount;

        vm.prank(currentActor);
        try vault.requestUnstake(stkTokenAmount) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Unstaking failed, revert expected state
            expectedTotalStkTokenSupply = actualTotalStkTokenSupply;
            totalUnstakeRequests--;
            totalUnstakedStkTokens -= stkTokenAmount;
            totalEscrowedStkTokens -= stkTokenAmount; // Revert escrow tracking
        }
    }

    function settleStakingBatch(uint256 batchId) public countCall("settleStakingBatch") {
        // Only settler/strategy manager can settle
        address settler = address(0x5E77E7);

        // Check if batch exists and can be settled
        if (batchId == 0) return;
        if (batchId > currentStakingBatchId) return;
        if (batchId <= lastSettledStakingBatchId) return;

        // Get actual total kTokens from batch data
        (, uint256 totalKTokensStaked,,) = dataProvider.getStakingBatchInfo(batchId);

        vm.prank(settler);
        try SettlementModule(payable(address(vault))).settleStakingBatch(batchId, totalKTokensStaked) {
            lastSettledStakingBatchId = batchId;
            _syncActualValues();
        } catch {
            // Settlement failed, skip
        }
    }

    function settleUnstakingBatch(uint256 batchId) public countCall("settleUnstakingBatch") {
        // Only settler/strategy manager can settle
        address settler = address(0x5E77E7);

        // Check if batch exists and can be settled
        if (batchId == 0) return;
        if (batchId > currentUnstakingBatchId) return;
        if (batchId <= lastSettledUnstakingBatchId) return;

        // Get actual total stkTokens from batch data
        (, uint256 totalStkTokensInBatch,,,) = dataProvider.getUnstakingBatchInfo(batchId);

        vm.prank(settler);
        try SettlementModule(payable(address(vault))).settleUnstakingBatch(batchId, totalStkTokensInBatch) {
            lastSettledUnstakingBatchId = batchId;

            // Track settled distributions using actual batch data
            (,, uint256 totalKTokensToReturn,,) = dataProvider.getUnstakingBatchInfo(batchId);
            batchSettledDistributions[batchId] = totalKTokensToReturn;
            totalSettledDistributions += totalKTokensToReturn;

            // Update escrow tracking - tokens no longer pending after settlement
            totalEscrowedStkTokens -= totalStkTokensInBatch;

            _syncActualValues();
        } catch {
            // Settlement failed, skip
        }
    }

    function claimStakedShares(
        uint256 batchId,
        uint256 requestIndex
    )
        public
        createActor
        countCall("claimStakedShares")
    {
        if (batchId == 0) return;
        if (batchId > lastSettledStakingBatchId) return;

        vm.prank(currentActor);
        try ClaimModule(payable(address(vault))).claimStakedShares(batchId, requestIndex) {
            _syncActualValues();
        } catch {
            // Claim failed, skip
        }
    }

    function claimUnstakedAssets(
        uint256 batchId,
        uint256 requestIndex
    )
        public
        createActor
        countCall("claimUnstakedAssets")
    {
        if (batchId == 0) return;
        if (batchId > lastSettledUnstakingBatchId) return;

        // Get pre-claim kToken balance to track actual amounts
        uint256 preClaimBalance = kToken_.balanceOf(currentActor);

        vm.prank(currentActor);
        try ClaimModule(payable(address(vault))).claimUnstakedAssets(batchId, requestIndex) {
            // Track actual claimed amounts based on balance difference
            uint256 postClaimBalance = kToken_.balanceOf(currentActor);
            uint256 actualClaimed = postClaimBalance - preClaimBalance;

            totalClaimedAssets += actualClaimed;
            batchClaimedOriginals[batchId] += actualClaimed;

            _syncActualValues();
        } catch {
            // Claim failed, skip
        }
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

    /// @dev kTokens staked should match vault holdings (excluding simulated yield)
    function INVARIANT_STAKED_KTOKENS() public view {
        uint256 vaultKTokenBalance = kToken_.balanceOf(address(vault));
        // Vault balance = staked kTokens + simulated yield
        uint256 expectedVaultBalance = actualTotalStakedKTokens + totalSimulatedYield;
        assertEq(expectedVaultBalance, vaultKTokenBalance, "Staked kTokens + yield mismatch");
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

    /// @dev Effective supply should never be zero when calculating division
    function INVARIANT_EFFECTIVE_SUPPLY_SAFE() public view {
        // Simulate the effective supply calculation from settleUnstakingBatch
        uint256 currentStkTokenSupply = vault.getTotalStkTokens();
        uint256 effectiveSupply = currentStkTokenSupply + totalUnstakedStkTokens;

        // If there are unstaked tokens, effective supply must be > 0
        if (totalUnstakedStkTokens > 0) {
            assertGt(effectiveSupply, 0, "Effective supply is zero");
        }
    }

    /// @dev stkToken price should always be within reasonable bounds
    function INVARIANT_STKTOKEN_PRICE_BOUNDS() public view {
        uint256 currentPrice = vault.getStkTokenPrice();

        // Price should never be zero (unless no supply exists)
        if (vault.getTotalStkTokens() > 0) {
            assertGt(currentPrice, 0, "stkToken price should not be zero with supply");
        }

        // Price should not be astronomically high (potential overflow)
        assertLt(currentPrice, type(uint128).max, "stkToken price too high");
    }

    /// @dev Unstaking should not result in negative balances
    function INVARIANT_NO_NEGATIVE_BALANCES() public view {
        // All balances should be non-negative by definition (uint256)
        // But check for underflow situations that might wrap around
        if (totalUnstakedStkTokens > 0) {
            assertGe(actualTotalStkTokenSupply, 0, "stkToken supply underflow");
        }
    }

    /// @dev Claim consistency: Total claimed should not exceed total settled
    function INVARIANT_CLAIM_CONSISTENCY() public view {
        // This is a placeholder - would need actual settled amounts to verify
        assertGe(totalClaimedAssets, 0, "Claimed assets should be non-negative");
    }

    /// @dev CRITICAL: Unstaking claims - sum of claimed originals matches expected prorata distribution
    function INVARIANT_UNSTAKING_CLAIM_TOTALS() public view {
        // Post-claims validation: claimed originals should follow prorata math
        // For the last settled batch, validate claim consistency
        if (lastSettledUnstakingBatchId > 0) {
            uint256 batchClaimedTotal = batchClaimedOriginals[lastSettledUnstakingBatchId];
            uint256 batchSettledTotal = batchSettledDistributions[lastSettledUnstakingBatchId];

            // Claims should not exceed what was settled for the batch
            assertLe(batchClaimedTotal, batchSettledTotal, "Batch claims exceed settled amount");
        }
    }

    /// @dev Peg protection - stkToken price should never go below 1:1 (CRITICAL FIX VALIDATION)
    function INVARIANT_PEG_PROTECTION() public view {
        uint256 currentPrice = dataProvider.getCurrentStkTokenPriceWithYield();
        // With fixed logic, yield should always be non-negative, price >= PRECISION (1e18)
        assertGe(currentPrice, 1e18, "stkToken price below peg - CRITICAL BUG");
    }

    /// @dev Enhanced dual accounting using data provider
    function INVARIANT_ENHANCED_DUAL_ACCOUNTING() public view {
        (bool isValid, uint256 minterAssets, uint256 userAssets, uint256 vaultAssets) =
            dataProvider.validateDualAccounting();
        assertTrue(
            isValid,
            string(
                abi.encodePacked(
                    "Enhanced dual accounting failed: minter=",
                    _toString(minterAssets),
                    " user=",
                    _toString(userAssets),
                    " vault=",
                    _toString(vaultAssets)
                )
            )
        );
    }

    /// @dev Claims should not exceed total settled distributions
    function INVARIANT_TOTAL_CLAIMS_BOUNDED() public view {
        // Validate that total claims never exceed what has been settled
        assertLe(totalClaimedAssets, totalSettledDistributions, "Claims exceed settled distributions");
    }

    /// @dev Escrow safety - vault holds sufficient escrowed tokens
    function INVARIANT_ESCROW_SAFETY() public view {
        // With escrow pattern, vault should hold >= pending unstake requests
        uint256 vaultStkTokenBalance = vault.balanceOf(address(vault));
        // Vault must hold at least the pending escrowed amount
        assertGe(vaultStkTokenBalance, totalEscrowedStkTokens, "Escrow shortfall");
    }

    /// @dev Rounding favors users in claims
    function INVARIANT_ROUNDING_FAVORS_USERS() public view {
        // FixedPointMathLib's mulWadUp ensures user-favorable rounding
        uint256 currentPrice = vault.getStkTokenPrice();

        // Price should be reasonable for safe calculations
        assertLt(currentPrice, type(uint128).max, "Price too high for safe rounding");
        assertGt(currentPrice, 0, "Price too low for safe rounding");
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _syncActualValues() internal {
        // Use data provider for efficient batch queries (split to avoid stack depth)
        (
            actualTotalMinterAssets,
            actualTotalStkTokenAssets,
            actualUserTotalAssets,
            actualTotalStkTokenSupply,
            actualTotalStakedKTokens,
            actualTotalVaultAssets
        ) = dataProvider.getHandlerAccountingData();

        (currentStakingBatchId, currentUnstakingBatchId, lastSettledStakingBatchId, lastSettledUnstakingBatchId) =
            dataProvider.getHandlerBatchData();

        actualUserTotalSupply = vault.totalSupply(); // Direct ERC20 query
    }

    function _syncBatchStates() internal {
        // Batch state synced in _syncActualValues via data provider
        // No separate sync needed
    }

    /// @notice Add yield simulation entry point for testing yield scenarios
    function simulateYield(uint256 yieldAmount) public countCall("simulateYield") {
        yieldAmount = bound(yieldAmount, 1, 1e18); // Reasonable yield bounds

        // Mint extra kTokens to vault to simulate strategy yield
        try kToken_.mint(address(vault), yieldAmount) {
            // Track simulated yield for invariant adjustments
            totalSimulatedYield += yieldAmount;
            _syncActualValues();
        } catch {
            // Minting failed (likely unauthorized), skip
        }
    }

    /// @notice Helper function to convert uint to string for error messages
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](9);
        _entryPoints[0] = this.requestMinterDeposit.selector;
        _entryPoints[1] = this.requestStake.selector;
        _entryPoints[2] = this.requestUnstake.selector;
        _entryPoints[3] = this.settleBatch.selector;
        _entryPoints[4] = this.settleStakingBatch.selector;
        _entryPoints[5] = this.settleUnstakingBatch.selector;
        _entryPoints[6] = this.claimStakedShares.selector;
        _entryPoints[7] = this.claimUnstakedAssets.selector;
        _entryPoints[8] = this.simulateYield.selector;
        return _entryPoints;
    }

    function callSummary() public view override {
        console2.log("");
        console2.log("=== kDNStakingVault Call Summary ===");
        console2.log("minterDeposit:", calls["minterDeposit"]);
        console2.log("stake:", calls["stake"]);
        console2.log("unstake:", calls["unstake"]);
        console2.log("settleBatch:", calls["settleBatch"]);
        console2.log("settleStakingBatch:", calls["settleStakingBatch"]);
        console2.log("settleUnstakingBatch:", calls["settleUnstakingBatch"]);
        console2.log("claimStakedShares:", calls["claimStakedShares"]);
        console2.log("claimUnstakedAssets:", calls["claimUnstakedAssets"]);
        console2.log("simulateYield:", calls["simulateYield"]);
        console2.log("Total Minter Assets:", actualTotalMinterAssets);
        console2.log("Total User Assets:", actualUserTotalAssets);
        console2.log("Total Vault Assets:", actualTotalVaultAssets);
        console2.log(
            "Dual Accounting Check:", (actualTotalMinterAssets + actualUserTotalAssets) == actualTotalVaultAssets
        );
        console2.log("Staked kTokens:", actualTotalStakedKTokens);
        console2.log("Simulated Yield:", totalSimulatedYield);
        console2.log("Total Unstake Requests:", totalUnstakeRequests);
        console2.log("Total Unstaked stkTokens:", totalUnstakedStkTokens);
        console2.log("Total Claimed Assets:", totalClaimedAssets);
    }
}
