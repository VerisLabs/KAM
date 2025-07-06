// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { LibTransient } from "solady/utils/LibTransient.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title SettlementModule
/// @notice Handles all settlement operations for kDNStakingVault
/// @dev Contains batch settlement functions for minter, staking, and unstaking operations
contract SettlementModule is ModuleBase {
    using LibTransient for *;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchSettled(
        uint256 indexed batchId, uint256 netDeposits, uint256 netRedeems, uint256 sharesCreated, uint256 sharesBurned
    );
    event StakingBatchSettled(uint256 indexed batchId, uint256 totalStkTokens, uint256 stkTokenPrice);
    event UnstakingBatchSettled(uint256 indexed batchId, uint256 totalAssets, uint256 assetPrice);
    event VarianceRecorded(uint256 amount, bool positive);

    // Constants inherited from ModuleBase

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error SettlementTooEarly();

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles a unified batch with netting
    /// @param batchId Batch ID to settle
    function settleBatch(uint256 batchId) external nonReentrant onlyRoles(SETTLER_ROLE) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch
        if (batchId == 0 || batchId > $.currentBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledBatchId) revert BatchAlreadySettled();

        // Enforce sequential settlement
        if (batchId != $.lastSettledBatchId + 1) revert BatchNotFound();

        // Check settlement interval
        if (block.timestamp < $.lastSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        DataTypes.Batch storage batch = $.batches[batchId];

        // Calculate net flows with overflow protection
        uint256 netDeposits = 0;
        uint256 netRedeems = 0;

        if (batch.totalDeposits > batch.totalRedeems) {
            netDeposits = batch.totalDeposits - batch.totalRedeems;
            // Sanity check for reasonable amounts
            if (netDeposits > type(uint128).max) revert("Net deposits too large");
        } else if (batch.totalRedeems > batch.totalDeposits) {
            netRedeems = batch.totalRedeems - batch.totalDeposits;
            // Sanity check for reasonable amounts
            if (netRedeems > type(uint128).max) revert("Net redeems too large");
        }

        // Process based on net flow (dual accounting)
        uint256 sharesCreated = 0;
        uint256 sharesBurned = 0;

        if (netDeposits > 0) {
            // Net deposits: increase total minter assets (1:1)
            // No user shares created here - only minter asset tracking
            sharesCreated = netDeposits; // 1:1 for tracking
        } else if (netRedeems > 0) {
            // Net redeems: decrease total minter assets (1:1)
            // No user shares burned here - only minter asset tracking
            sharesBurned = netRedeems; // 1:1 for tracking
        }

        // Process each minter's net position
        _processMinterPositions(batch, $);

        // Mark batch as settled
        batch.settled = true;
        batch.netDeposits = netDeposits;
        batch.netRedeems = netRedeems;
        batch.sharesCreated = sharesCreated;
        batch.sharesBurned = sharesBurned;

        $.lastSettledBatchId = uint64(batchId);
        $.lastSettlement = uint64(block.timestamp);

        // Create new batch
        unchecked {
            $.currentBatchId++;
        }

        emit BatchSettled(batchId, netDeposits, netRedeems, sharesCreated, sharesBurned);
    }

    /// @notice Processes staking batch settlement by updating global state and batch parameters
    /// @dev Validates batch sequence, applies automatic rebase, calculates stkToken price, and updates accounting
    /// @param batchId The identifier of the staking batch to settle
    /// @param totalKTokensStaked Aggregated amount of kTokens from all requests in the batch
    function settleStakingBatch(
        uint256 batchId,
        uint256 totalKTokensStaked
    )
        external
        nonReentrant
        onlyRoles(SETTLER_ROLE | STRATEGY_MANAGER_ROLE)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch
        if (batchId == 0 || batchId > $.currentStakingBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledStakingBatchId) revert BatchAlreadySettled();

        // Enforce sequential settlement
        if (batchId != $.lastSettledStakingBatchId + 1) revert BatchNotFound();

        // Check settlement interval
        if (block.timestamp < $.lastStakingSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];

        if (totalKTokensStaked == 0) {
            // Empty batch, just mark as settled
            $.lastSettledStakingBatchId = uint64(batchId);
            $.lastStakingSettlement = uint64(block.timestamp);
            emit StakingBatchSettled(batchId, 0, 0);
            return;
        }

        // AUTOMATIC REBASE: Update stkToken assets with real vault balance
        uint256 totalVaultAssets = _getTotalVaultAssets($); // Real assets
        uint256 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;

        // Auto-rebase stkTokens with unaccounted yield
        if (totalVaultAssets > accountedAssets) {
            uint256 yield = totalVaultAssets - accountedAssets;
            if (yield <= MAX_YIELD_PER_SYNC) {
                // Add yield directly to stkToken pool - DO NOT reduce minter assets
                // Yield comes from external sources (strategies), not minter funds
                $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) + yield);
                $.userTotalAssets = uint128(uint256($.userTotalAssets) + yield);
                emit VarianceRecorded(yield, true);
            }
        }

        // Calculate stkToken price AFTER rebase (includes yield)
        uint256 currentStkTokenPrice = $.totalStkTokenSupply == 0
            ? PRECISION // 1:1 initial
            : ($.totalStkTokenAssets * PRECISION) / $.totalStkTokenSupply;

        // O(1) OPTIMIZATION: Calculate total stkTokens for entire batch
        uint256 totalStkTokensToMint = (totalKTokensStaked * PRECISION) / currentStkTokenPrice;

        // O(1) STATE UPDATE: Update global accounting without loops
        // NOTE: kTokens were already transferred to vault in requestStake()
        // Just update accounting to track that these assets are now in user pool
        $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) + totalKTokensStaked);
        $.userTotalAssets = uint128(uint256($.userTotalAssets) + totalKTokensStaked);

        // Update stkToken supply
        $.totalStkTokenSupply = uint128(uint256($.totalStkTokenSupply) + totalStkTokensToMint);

        // O(1) BATCH STATE: Mark batch as settled with settlement parameters
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        batch.totalStkTokens = totalStkTokensToMint;
        batch.totalAssetsFromMinter = totalKTokensStaked;
        $.lastSettledStakingBatchId = uint64(batchId);
        $.lastStakingSettlement = uint64(block.timestamp);

        // Create new staking batch
        unchecked {
            $.currentStakingBatchId++;
        }

        emit StakingBatchSettled(batchId, totalStkTokensToMint, currentStkTokenPrice);
    }

    /// @notice Processes unstaking batch settlement by calculating asset distribution and updating global state
    /// @dev Validates batch sequence, calculates stkToken value with current price, and updates accounting
    /// @param batchId The identifier of the unstaking batch to settle
    /// @param totalStkTokensUnstaked Aggregated amount of stkTokens from all requests in the batch
    function settleUnstakingBatch(
        uint256 batchId,
        uint256 totalStkTokensUnstaked
    )
        external
        nonReentrant
        onlyRoles(SETTLER_ROLE | STRATEGY_MANAGER_ROLE)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch
        if (batchId == 0 || batchId > $.currentUnstakingBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledUnstakingBatchId) revert BatchAlreadySettled();

        // Enforce sequential settlement
        if (batchId != $.lastSettledUnstakingBatchId + 1) revert BatchNotFound();

        // Check settlement interval
        if (block.timestamp < $.lastUnstakingSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];

        if (totalStkTokensUnstaked == 0) {
            // Empty batch, just mark as settled
            $.lastSettledUnstakingBatchId = uint64(batchId);
            $.lastUnstakingSettlement = uint64(block.timestamp);
            emit UnstakingBatchSettled(batchId, 0, 0);
            return;
        }

        // AUTOMATIC REBASE: Update stkToken assets with real vault balance
        uint256 totalVaultAssets = _getTotalVaultAssets($); // Real assets
        uint256 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;

        // Auto-rebase stkTokens with unaccounted yield
        if (totalVaultAssets > accountedAssets) {
            uint256 yield = totalVaultAssets - accountedAssets;
            if (yield <= MAX_YIELD_PER_SYNC) {
                // Add yield directly to stkToken pool
                $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) + yield);
                $.userTotalAssets = uint128(uint256($.userTotalAssets) + yield);
                emit VarianceRecorded(yield, true);
            }
        }

        // Calculate current stkToken price AFTER rebase
        uint256 currentStkTokenPrice = $.totalStkTokenSupply == 0
            ? PRECISION // 1:1 initial
            : ($.totalStkTokenAssets * PRECISION) / $.totalStkTokenSupply;

        // O(1) OPTIMIZATION: Calculate total assets to distribute for entire batch
        uint256 totalAssetsToDistribute = (totalStkTokensUnstaked * currentStkTokenPrice) / PRECISION;

        // O(1) STATE UPDATE: Update global accounting
        // NOTE: stkTokens were already burned in requestUnstake()
        // Just update asset accounting to reflect redemption
        $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) - totalAssetsToDistribute);
        $.userTotalAssets = uint128(uint256($.userTotalAssets) - totalAssetsToDistribute);

        // O(1) BATCH STATE: Mark batch as settled with settlement parameters
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        // Note: Using totalKTokensToReturn for asset distribution
        batch.totalKTokensToReturn = totalAssetsToDistribute;
        $.lastSettledUnstakingBatchId = uint64(batchId);
        $.lastUnstakingSettlement = uint64(block.timestamp);

        // Create new unstaking batch
        unchecked {
            $.currentUnstakingBatchId++;
        }

        emit UnstakingBatchSettled(batchId, totalAssetsToDistribute, currentStkTokenPrice);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to process minter positions during settlement
    /// @param batch The batch being settled
    /// @param $ Storage reference
    function _processMinterPositions(DataTypes.Batch storage batch, kDNStakingVaultStorage storage $) internal {
        for (uint256 i = 0; i < batch.minters.length; i++) {
            address minter = batch.minters[i];
            int256 netAmount = $.minterPendingNetAmounts[minter];

            if (netAmount > 0) {
                // Net deposit: increase minter balance 1:1
                $.minterAssetBalances[minter] += uint256(netAmount);
                $.totalMinterAssets = uint128(uint256($.totalMinterAssets) + uint256(netAmount));
            } else if (netAmount < 0) {
                // Net redeem: decrease minter balance 1:1
                uint256 redeemAmount = uint256(-netAmount);
                if ($.minterAssetBalances[minter] >= redeemAmount) {
                    $.minterAssetBalances[minter] -= redeemAmount;
                    $.totalMinterAssets = uint128(uint256($.totalMinterAssets) - redeemAmount);
                }
            }

            // Clear pending amount
            delete $.minterPendingNetAmounts[minter];
        }
    }

    /// @notice Returns total vault assets (real balance)
    /// @param $ Storage reference
    /// @return Total assets in the vault
    function _getTotalVaultAssets(kDNStakingVaultStorage storage $) internal view returns (uint256) {
        return $.underlyingAsset.balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                      MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the function selectors for this module
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](3);
        s[0] = this.settleBatch.selector;
        s[1] = this.settleStakingBatch.selector;
        s[2] = this.settleUnstakingBatch.selector;
        return s;
    }
}
