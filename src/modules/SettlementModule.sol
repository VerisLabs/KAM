// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title SettlementModule
/// @notice Handles all settlement operations for kDNStakingVault
/// @dev Contains batch settlement functions for minter, staking, and unstaking operations
contract SettlementModule is ModuleBase {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

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
    error StkTokenAssetsOverflow();
    error UserAssetsOverflow();
    error InsufficientMinterBacking();
    error StkTokenSupplyOverflow();
    error InsufficientVaultBalance();

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

        // Distribute assets to batch receivers for redemptions
        _distributeMinterAssets(batch, $);

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
                // Yield comes as extra kTokens from external sources (strategies), not minter funds
                uint256 newStkTokenAssetsYield = uint256($.totalStkTokenAssets) + yield;
                uint256 newUserTotalAssetsYield = uint256($.userTotalAssets) + yield;

                // Overflow protection before downcasting
                if (newStkTokenAssetsYield <= type(uint128).max && newUserTotalAssetsYield <= type(uint128).max) {
                    $.totalStkTokenAssets = uint128(newStkTokenAssetsYield);
                    $.userTotalAssets = uint128(newUserTotalAssetsYield);
                    emit VarianceRecorded(yield, true);
                }
                // If overflow would occur, skip yield distribution for safety
            }
        }

        // Calculate stkToken price AFTER rebase (includes yield) using FixedPointMathLib
        uint256 currentStkTokenPrice = $.totalStkTokenSupply == 0
            ? PRECISION // 1:1 initial
            : uint256($.totalStkTokenAssets).divWad(uint256($.totalStkTokenSupply)); // Automatic zero protection

        // Calculate total stkTokens for entire batch
        uint256 totalStkTokensToMint = totalKTokensStaked.divWad(currentStkTokenPrice);

        // Update global accounting to track assets in user pool
        uint256 newStkTokenAssets = uint256($.totalStkTokenAssets) + totalKTokensStaked;
        uint256 newUserTotalAssets = uint256($.userTotalAssets) + totalKTokensStaked;

        // Overflow protection before downcasting
        if (newStkTokenAssets > type(uint128).max) revert StkTokenAssetsOverflow();
        if (newUserTotalAssets > type(uint128).max) revert UserAssetsOverflow();

        $.totalStkTokenAssets = uint128(newStkTokenAssets);
        $.userTotalAssets = uint128(newUserTotalAssets);

        // Reduce minter pool by the same amount to shift backing to users
        // This ensures yield flows to users, not minters
        if ($.totalMinterAssets < totalKTokensStaked) revert InsufficientMinterBacking();
        $.totalMinterAssets = uint128(uint256($.totalMinterAssets) - totalKTokensStaked);

        // Update stkToken supply with overflow protection
        uint256 newStkTokenSupply = uint256($.totalStkTokenSupply) + totalStkTokensToMint;
        if (newStkTokenSupply > type(uint128).max) revert StkTokenSupplyOverflow();
        $.totalStkTokenSupply = uint128(newStkTokenSupply);

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
                // Yield comes as extra kTokens from external sources (strategies)
                $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) + yield);
                $.userTotalAssets = uint128(uint256($.userTotalAssets) + yield);
                emit VarianceRecorded(yield, true);
            }
        }

        // Calculate effective supply - escrow pattern means totalStkTokenSupply already includes unstaked tokens
        uint256 effectiveSupply = $.totalStkTokenSupply;

        // Calculate current stkToken price using effective supply
        uint256 currentStkTokenPrice =
            effectiveSupply == 0 ? PRECISION : uint256($.totalStkTokenAssets).divWad(effectiveSupply);

        // Calculate total assets to distribute for entire batch
        uint256 totalAssetsToDistribute = totalStkTokensUnstaked.mulWad(currentStkTokenPrice);

        // Update global accounting
        // Tokens remain escrowed until individual claims
        // Settlement calculates distributions without token operations

        // Update asset accounting to reflect redemption
        $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) - totalAssetsToDistribute);
        $.userTotalAssets = uint128(uint256($.userTotalAssets) - totalAssetsToDistribute);

        // Calculate total original kTokens being unstaked to return to minter pool
        uint256 totalOriginalKTokens = $.totalStakedKTokens;
        uint256 batchOriginalKTokens = effectiveSupply == 0
            ? 0
            : totalStkTokensUnstaked.mulWad(uint256(totalOriginalKTokens)).divWad(effectiveSupply);

        // Return original kTokens backing to minter pool (yield stays with users)
        $.totalMinterAssets = uint128(uint256($.totalMinterAssets) + batchOriginalKTokens);

        // O(1) BATCH STATE: Mark batch as settled with settlement parameters
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        // Note: Using totalKTokensToReturn for asset distribution
        batch.totalKTokensToReturn = totalAssetsToDistribute;

        // Store the ratio of original kTokens to stkTokens for efficient claims
        batch.originalKTokenRatio = effectiveSupply == 0 ? 0 : uint256(totalOriginalKTokens).divWad(effectiveSupply);

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

    /// @notice Internal function to distribute assets to batch receivers for net redemptions
    /// @param batch The batch being settled
    /// @param $ Storage reference
    function _distributeMinterAssets(DataTypes.Batch storage batch, kDNStakingVaultStorage storage $) internal {
        // Only process if there are net redeems
        if (batch.netRedeems == 0) return;

        // Validate vault has sufficient assets
        uint256 vaultBalance = $.underlyingAsset.balanceOf(address(this));
        if (vaultBalance < batch.netRedeems) revert InsufficientVaultBalance();

        // Distribute assets to each minter's batch receiver
        for (uint256 i = 0; i < batch.minters.length; i++) {
            address minter = batch.minters[i];
            uint256 redeemAmount = batch.redeemAmounts[minter];

            if (redeemAmount > 0) {
                address batchReceiver = batch.batchReceivers[minter];
                if (batchReceiver != address(0)) {
                    // Transfer assets to the batch receiver
                    $.underlyingAsset.safeTransfer(batchReceiver, redeemAmount);
                }
            }
        }
    }

    /// @notice Returns total vault assets (real balance)
    /// @param $ Storage reference
    /// @return Total assets in the vault
    function _getTotalVaultAssets(kDNStakingVaultStorage storage $) internal view returns (uint256) {
        // Return kToken balance only (underlyingAsset for vault is kToken, not USDC)
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
