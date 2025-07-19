// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkToken } from "src/interfaces/IkToken.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title SettlementModule
/// @notice Handles all settlement operations for kDNStakingVault
/// @dev Contains batch settlement functions for minter, staking, and unstaking operations
contract SettlementModule is ModuleBase {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchSettled(
        uint256 indexed batchId, uint256 netDeposits, uint256 netRedeems, uint256 sharesCreated, uint256 sharesBurned
    );
    event StakingBatchSettled(uint256 indexed batchId, uint256 totalStkTokens, uint256 stkTokenPrice);
    event UnstakingBatchSettled(uint256 indexed batchId, uint256 totalAssets, uint256 assetPrice);
    event VarianceRecorded(uint256 amount, bool positive);
    event AllocationRequested(uint256 indexed batchId, address[] destinations, uint256[] amounts);

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
    error NetDepositsTooLarge();
    error NetRedeemsTooLarge();
    error ProtocolInvariantsViolatedAfterStakingSettlement();
    error ProtocolInvariantsViolatedAfterUnstakingSettlement();

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles a unified batch with netting
    /// @param batchId Batch ID to settle
    function settleBatch(uint256 batchId) external nonReentrant onlyRoles(SETTLER_ROLE) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();

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
            if (netDeposits > type(uint128).max) revert NetDepositsTooLarge();
        } else if (batch.totalRedeems > batch.totalDeposits) {
            netRedeems = batch.totalRedeems - batch.totalDeposits;
            // Sanity check for reasonable amounts
            if (netRedeems > type(uint128).max) revert NetRedeemsTooLarge();
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
    /// @param destinations Optional array of destination addresses for asset allocation (empty array if no routing)
    /// @param amounts Optional array of amounts for each destination (empty array if no routing)
    function settleStakingBatch(
        uint256 batchId,
        uint256 totalKTokensStaked,
        address[] calldata destinations,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        onlyRoles(SETTLER_ROLE | STRATEGY_MANAGER_ROLE)
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();

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
        {
            uint256 totalVaultAssets = _getTotalVaultAssets($); // Real assets
            uint256 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;
            if (totalVaultAssets > accountedAssets) {
                // Positive rebase - yield generation
                uint256 yield = totalVaultAssets - accountedAssets;
                if (yield <= MAX_YIELD_PER_SYNC) {
                    uint256 newStkTokenAssetsYield = uint256($.totalStkTokenAssets) + yield;
                    uint256 newUserTotalAssetsYield = uint256($.userTotalAssets) + yield;
                    if (newStkTokenAssetsYield <= type(uint128).max && newUserTotalAssetsYield <= type(uint128).max) {
                        $.totalStkTokenAssets = uint128(newStkTokenAssetsYield);
                        $.userTotalAssets = uint128(newUserTotalAssetsYield);
                        emit VarianceRecorded(yield, true);
                    }
                    IkToken($.kToken).mint(address(this), yield);
                }
            } else if (totalVaultAssets < accountedAssets) {
                // Negative rebase - loss realization for user pool only
                // NOTE: Minter assets maintain 1:1 guarantee, losses only affect user pool
                uint256 loss = accountedAssets - totalVaultAssets;
                if (loss <= MAX_YIELD_PER_SYNC) {
                    // Realize losses by reducing stkToken assets and user assets
                    $.totalStkTokenAssets =
                        (uint256($.totalStkTokenAssets) > loss ? uint256($.totalStkTokenAssets) - loss : 0).toUint128();
                    $.userTotalAssets =
                        (uint256($.userTotalAssets) > loss ? uint256($.userTotalAssets) - loss : 0).toUint128();

                    // Burn kTokens to maintain 1:1 backing
                    if (loss > 0) {
                        IkToken($.kToken).burn(address(this), loss);
                    }

                    emit VarianceRecorded(loss, false);
                }
            }
        }
        // Calculate stkToken price AFTER rebase (includes yield) using FixedPointMathLib
        uint256 currentStkTokenPrice;
        uint256 totalStkTokensToMint;
        {
            currentStkTokenPrice = $.totalStkTokenSupply == 0
                ? PRECISION // 1:1 initial
                : uint256($.totalStkTokenAssets).divWad(uint256($.totalStkTokenSupply));
            totalStkTokensToMint = totalKTokensStaked.divWad(currentStkTokenPrice);
        }
        // Update global accounting to track assets in user pool
        {
            uint256 newStkTokenAssets = uint256($.totalStkTokenAssets) + totalKTokensStaked;
            uint256 newUserTotalAssets = uint256($.userTotalAssets) + totalKTokensStaked;
            if (newStkTokenAssets > type(uint128).max) revert StkTokenAssetsOverflow();
            if (newUserTotalAssets > type(uint128).max) revert UserAssetsOverflow();
            $.totalStkTokenAssets = uint128(newStkTokenAssets);
            $.userTotalAssets = uint128(newUserTotalAssets);
        }
        // Reduce minter pool by the same amount to shift backing to users
        if ($.totalMinterAssets < totalKTokensStaked) revert InsufficientMinterBacking();
        $.totalMinterAssets = (uint256($.totalMinterAssets) - totalKTokensStaked).toUint128();
        // Update stkToken supply with overflow protection
        {
            uint256 newStkTokenSupply = uint256($.totalStkTokenSupply) + totalStkTokensToMint;
            if (newStkTokenSupply > type(uint128).max) revert StkTokenSupplyOverflow();
            $.totalStkTokenSupply = uint128(newStkTokenSupply);
        }
        // OPTIONAL ASSET ALLOCATION: Route assets to destinations if specified
        if (destinations.length > 0 && amounts.length > 0) {
            _handleAssetAllocation(batchId, destinations, amounts);
        }

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

        // Validate protocol invariants after settlement
        if (!(_validateProtocolInvariants($))) revert ProtocolInvariantsViolatedAfterStakingSettlement();

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
        BaseVaultStorage storage $ = _getBaseVaultStorage();

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
        {
            uint256 totalVaultAssets = _getTotalVaultAssets($); // Real assets
            uint128 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;
            if (totalVaultAssets > accountedAssets) {
                // Positive rebase - yield generation
                uint128 yield = totalVaultAssets.toUint128() - accountedAssets;
                if (yield <= MAX_YIELD_PER_SYNC) {
                    $.totalStkTokenAssets = $.totalStkTokenAssets + yield;
                    $.userTotalAssets = $.userTotalAssets + yield;
                    IkToken($.kToken).mint(address(this), yield);
                    emit VarianceRecorded(yield, true);
                }
            } else if (totalVaultAssets < accountedAssets) {
                // Negative rebase - loss realization for user pool only
                uint128 loss = accountedAssets - totalVaultAssets.toUint128();
                if (loss <= MAX_YIELD_PER_SYNC) {
                    // Realize losses by reducing stkToken assets and user assets
                    $.totalStkTokenAssets = $.totalStkTokenAssets > loss ? $.totalStkTokenAssets - loss : 0;
                    $.userTotalAssets = $.userTotalAssets > loss ? $.userTotalAssets - loss : 0;

                    // Burn kTokens to maintain 1:1 backing
                    if (loss > 0) {
                        IkToken($.kToken).burn(address(this), loss);
                    }

                    emit VarianceRecorded(loss, false);
                }
            }
        }
        // Calculate effective supply - escrow pattern means totalStkTokenSupply already includes unstaked tokens
        uint256 effectiveSupply;
        {
            effectiveSupply = $.totalStkTokenSupply;
        }
        // Calculate current stkToken price using effective supply
        uint256 currentStkTokenPrice;
        {
            currentStkTokenPrice =
                effectiveSupply == 0 ? PRECISION : uint256($.totalStkTokenAssets).divWad(effectiveSupply);
        }
        // Calculate total assets to distribute for entire batch
        uint256 totalAssetsToDistribute;
        {
            totalAssetsToDistribute = totalStkTokensUnstaked.mulWad(currentStkTokenPrice);
        }
        // Update global accounting
        {
            $.totalStkTokenAssets = (uint256($.totalStkTokenAssets) - totalAssetsToDistribute).toUint128();
            $.userTotalAssets = (uint256($.userTotalAssets) - totalAssetsToDistribute).toUint128();
        }
        // Calculate total original kTokens being unstaked to return to minter pool
        uint256 totalOriginalKTokens;
        {
            totalOriginalKTokens = $.totalStakedKTokens;
        }
        uint256 batchOriginalKTokens;
        {
            batchOriginalKTokens = effectiveSupply == 0
                ? 0
                : totalStkTokensUnstaked.mulWad(uint256(totalOriginalKTokens)).divWad(effectiveSupply);
        }
        // Return original kTokens backing to minter pool (yield stays with users)
        {
            $.totalMinterAssets = $.totalMinterAssets + batchOriginalKTokens.toUint128();
        }

        // O(1) BATCH STATE: Mark batch as settled with settlement parameters
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        // Note: Using totalKTokensToReturn for asset distribution
        batch.totalKTokensToReturn = totalAssetsToDistribute;

        // Store the ratio of original kTokens to stkTokens for efficient claims
        batch.originalKTokenRatio = effectiveSupply == 0 ? 0 : uint256(totalOriginalKTokens).divWad(effectiveSupply);

        $.lastSettledUnstakingBatchId = batchId.toUint64();
        $.lastUnstakingSettlement = block.timestamp.toUint64();

        // Create new unstaking batch
        unchecked {
            $.currentUnstakingBatchId++;
        }

        // Validate protocol invariants after settlement
        if (!(_validateProtocolInvariants($))) revert ProtocolInvariantsViolatedAfterUnstakingSettlement();

        emit UnstakingBatchSettled(batchId, totalAssetsToDistribute, currentStkTokenPrice);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function to process minter positions during settlement
    /// @param batch The batch being settled
    /// @param $ Storage reference
    function _processMinterPositions(DataTypes.Batch storage batch, BaseVaultStorage storage $) internal {
        address minter = batch.activeMinter;

        // Skip processing if no active minter
        if (minter == address(0)) return;

        uint128 totalMinterAssets = $.totalMinterAssets;
        int256 netAmount = $.minterPendingNetAmounts[minter];
        uint256 minterAssetBalance = $.minterAssetBalances[minter];

        if (netAmount > 0) {
            // Net deposit: increase minter balance 1:1
            minterAssetBalance += uint256(netAmount);
            totalMinterAssets = (uint256(totalMinterAssets) + uint256(netAmount)).toUint128();
        } else if (netAmount < 0) {
            // Net redeem: decrease minter balance 1:1
            uint256 redeemAmount = uint256(-netAmount);
            if (minterAssetBalance >= redeemAmount) {
                minterAssetBalance = (uint256(minterAssetBalance) - redeemAmount).toUint128();
                totalMinterAssets = (uint256(totalMinterAssets) - redeemAmount).toUint128();
            }
        }

        $.minterAssetBalances[minter] = minterAssetBalance;
        // Clear pending amount
        delete $.minterPendingNetAmounts[minter];

        $.totalMinterAssets = totalMinterAssets;
    }

    /// @notice Internal function to distribute assets to batch receivers for net redemptions
    /// @param batch The batch being settled
    /// @param $ Storage reference
    function _distributeMinterAssets(DataTypes.Batch storage batch, BaseVaultStorage storage $) internal {
        // Only process if there are net redeems
        if (batch.netRedeems == 0) return;

        // Validate vault has sufficient assets
        uint256 vaultBalance = $.underlyingAsset.balanceOf(address(this));
        if (vaultBalance < batch.netRedeems) revert InsufficientVaultBalance();

        address minter = batch.activeMinter;

        // Skip if no active minter
        if (minter == address(0)) return;

        uint256 redeemAmount = batch.redeemAmounts[minter];
        address underlyingAsset = $.underlyingAsset;

        // Distribute assets to the minter's batch receiver
        if (redeemAmount > 0) {
            address batchReceiver = batch.batchReceivers[minter];
            if (batchReceiver != address(0)) {
                // Transfer assets to the batch receiver
                underlyingAsset.safeTransfer(batchReceiver, redeemAmount);
            }
        }
    }

    /// @notice Returns total vault assets (real balance)
    /// @param $ Storage reference
    /// @return Total assets in the vault
    function _getTotalVaultAssets(BaseVaultStorage storage $) internal view returns (uint256) {
        // Return kToken balance only (underlyingAsset for vault is kToken, not USDC)
        return $.underlyingAsset.balanceOf(address(this));
    }

    /// @notice Internal function to handle asset allocation
    /// @param batchId The identifier of the batch
    /// @param destinations Array of destination addresses
    /// @param amounts Array of amounts for each destination
    function _handleAssetAllocation(
        uint256 batchId,
        address[] calldata destinations,
        uint256[] calldata amounts
    )
        internal
    {
        // Validate array lengths match
        if (destinations.length != amounts.length) revert InvalidRequestIndex();
        uint256 totalAllocation;
        uint256 length = amounts.length;

        for (uint256 i; i < length;) {
            totalAllocation += amounts[i];
            unchecked {
                ++i;
            }
        }
        emit AllocationRequested(batchId, destinations, amounts);
    }

    /*//////////////////////////////////////////////////////////////
                      MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the function selectors for this module
    /// @return Array of function selectors that this module implements
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](3);
        s[0] = this.settleBatch.selector;
        s[1] = this.settleStakingBatch.selector;
        s[2] = this.settleUnstakingBatch.selector;
        return s;
    }
}
