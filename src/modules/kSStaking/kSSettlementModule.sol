// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkDNStaking } from "src/interfaces/IkDNStaking.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title kSSettlementModule
/// @notice Handles strategy-based settlement operations for kSStakingVault
/// @dev Contains batch settlement functions with inter-vault asset management
contract kSSettlementModule is ModuleBase {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event StakingBatchSettled(uint256 indexed batchId, uint256 totalStkTokens, uint256 stkTokenPrice);
    event UnstakingBatchSettled(uint256 indexed batchId, uint256 totalAssets, uint256 assetPrice);
    event VarianceRecorded(uint256 amount, bool positive);
    event AssetsRequestedFromDN(uint256 amount, uint256 indexed batchId);
    event AssetsReturnedToDN(uint256 amount, uint256 indexed batchId);
    event AssetsReceivedFromDN(uint256 requested, uint256 received, uint256 verified);
    event AssetsAllocatedToStrategies(uint256 totalAmount, uint256 destinationCount);
    event AssetRecoveredFromStrategies(uint256 totalRecovered, uint256 totalRequired);
    event AccountingDiscrepancyDetected(string discrepancyType, uint256 expected, uint256 actual);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error SettlementTooEarly();
    error StkTokenSupplyOverflow();
    error DNVaultNotSet();
    error AssetAllocationFailed();
    error InsufficientAssetsReceivedFromKDN();
    error ProtocolInvariantsViolatedAfterStakingSettlement();
    error InsufficientAssetsToReturnToKDN();
    error ProtocolInvariantsViolatedAfterUnstakingSettlement();

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes staking batch settlement with asset sourcing from kDNStakingVault
    /// @dev Validates batch sequence, requests assets from DN vault, calculates stkToken price, and updates accounting
    /// @param batchId The identifier of the staking batch to settle
    /// @param totalKTokensStaked Aggregated amount of kTokens from all requests in the batch
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
        if (batchId == 0 || batchId > $.currentStakingBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledStakingBatchId) revert BatchAlreadySettled();
        if (batchId != $.lastSettledStakingBatchId + 1) revert BatchNotFound();
        if (block.timestamp < $.lastStakingSettlement + $.settlementInterval) revert SettlementTooEarly();
        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];
        if (totalKTokensStaked == 0) {
            $.lastSettledStakingBatchId = uint64(batchId);
            $.lastStakingSettlement = uint64(block.timestamp);
            emit StakingBatchSettled(batchId, 0, 0);
            return;
        }
        address kDNVault = $.kSStakingVault;
        if (kDNVault == address(0)) revert DNVaultNotSet();
        uint256 totalAssetsRequired = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAssetsRequired += amounts[i];
        }
        _handleAssetRequestAndAllocation($, kDNVault, totalAssetsRequired, destinations);
        _rebaseIfNeeded($);
        (uint256 currentStkTokenPrice, uint256 totalStkTokensToMint) =
            _updateAccountingForStaking($, totalKTokensStaked);
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        batch.totalStkTokens = totalStkTokensToMint;
        batch.totalAssetsFromMinter = totalKTokensStaked;
        $.lastSettledStakingBatchId = uint64(batchId);
        $.lastStakingSettlement = uint64(block.timestamp);
        unchecked {
            $.currentStakingBatchId++;
        }
        if (!(_validateProtocolInvariants($))) revert ProtocolInvariantsViolatedAfterStakingSettlement();
        emit StakingBatchSettled(batchId, totalStkTokensToMint, currentStkTokenPrice);
    }

    /// @notice Processes unstaking batch settlement with asset return to kDNStakingVault
    /// @dev Validates batch sequence, calculates stkToken value with current price, returns assets to DN vault
    /// @param batchId The identifier of the unstaking batch to settle
    /// @param totalStkTokensUnstaked Aggregated amount of stkTokens from all requests in the batch
    function settleUnstakingBatch(
        uint256 batchId,
        uint256 totalStkTokensUnstaked,
        address[] calldata sources,
        uint256[] calldata amounts
    )
        external
        nonReentrant
        onlyRoles(SETTLER_ROLE | STRATEGY_MANAGER_ROLE)
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (batchId == 0 || batchId > $.currentUnstakingBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledUnstakingBatchId) revert BatchAlreadySettled();
        if (batchId != $.lastSettledUnstakingBatchId + 1) revert BatchNotFound();
        if (block.timestamp < $.lastUnstakingSettlement + $.settlementInterval) revert SettlementTooEarly();
        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];
        if (totalStkTokensUnstaked == 0) {
            $.lastSettledUnstakingBatchId = uint64(batchId);
            $.lastUnstakingSettlement = uint64(block.timestamp);
            emit UnstakingBatchSettled(batchId, 0, 0);
            return;
        }
        _rebaseIfNeeded($);
        _handleUnstakingAssetReturn($, batch, batchId, totalStkTokensUnstaked, sources, amounts);
        $.lastSettledUnstakingBatchId = uint64(batchId);
        $.lastUnstakingSettlement = uint64(block.timestamp);
        unchecked {
            $.currentUnstakingBatchId++;
        }
        if (!(_validateProtocolInvariants($))) revert ProtocolInvariantsViolatedAfterUnstakingSettlement();
        emit UnstakingBatchSettled(batchId, batch.totalKTokensToReturn, batch.stkTokenPrice);
    }

    /// @dev Handles the asset return logic for unstaking batch settlement, including accounting and asset transfer
    function _handleUnstakingAssetReturn(
        BaseVaultStorage storage $,
        DataTypes.UnstakingBatch storage batch,
        uint256 batchId,
        uint256 totalStkTokensUnstaked,
        address[] calldata sources,
        uint256[] calldata amounts
    )
        internal
    {
        (
            uint256 effectiveSupply,
            uint256 currentStkTokenPrice,
            uint256 totalAssetsToDistribute,
            uint256 totalOriginalKTokens
        ) = _updateAccountingForUnstaking($, totalStkTokensUnstaked);
        uint256 batchOriginalKTokens =
            _calculateBatchOriginalKTokens(totalStkTokensUnstaked, totalOriginalKTokens, effectiveSupply);
        address kDNVault = $.kSStakingVault;
        if (kDNVault == address(0)) revert DNVaultNotSet();
        if (batchOriginalKTokens > 0) {
            _processAssetReturn($, kDNVault, batchOriginalKTokens, batchId, sources, amounts);
        }
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        batch.totalKTokensToReturn = totalAssetsToDistribute;
        batch.originalKTokenRatio = effectiveSupply == 0 ? 0 : uint256(totalOriginalKTokens).divWad(effectiveSupply);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns total vault assets (real underlying asset balance)
    /// @param $ Storage reference
    /// @return Total underlying assets in the vault
    function _getTotalVaultAssets(BaseVaultStorage storage $) internal view returns (uint256) {
        // Return underlying asset balance (USDC/WBTC for strategy operations)
        return $.underlyingAsset.balanceOf(address(this));
    }

    function _handleAssetRequestAndAllocation(
        BaseVaultStorage storage $,
        address kDNVault,
        uint256 totalAssetsRequired,
        address[] calldata destinations
    )
        internal
    {
        // Get balance before allocation
        uint256 balanceBefore = $.underlyingAsset.balanceOf(address(this));

        // Approve kTokens to kDNStakingVault
        $.kToken.safeApprove(kDNVault, totalAssetsRequired);
        address[] memory targetVault = new address[](1);
        targetVault[0] = address(this);
        uint256[] memory assetAmount = new uint256[](1);
        assetAmount[0] = totalAssetsRequired;
        bool received = IkDNStaking(kDNVault).allocateAssetsToDestinations(targetVault, assetAmount);
        if (!received) revert AssetAllocationFailed();

        // Get balance after allocation
        uint256 balanceAfter = $.underlyingAsset.balanceOf(address(this));
        uint256 actualReceived = balanceAfter - balanceBefore;
        if (!(actualReceived >= totalAssetsRequired)) revert InsufficientAssetsReceivedFromKDN();
        if (actualReceived > totalAssetsRequired) {
            uint256 excess = actualReceived - totalAssetsRequired;
            $.underlyingAsset.safeTransfer(kDNVault, excess);
        }
        emit AssetsAllocatedToStrategies(totalAssetsRequired, destinations.length);
        emit AssetsReceivedFromDN(totalAssetsRequired, actualReceived, totalAssetsRequired);
    }

    function _calculateBatchOriginalKTokens(
        uint256 totalStkTokensUnstaked,
        uint256 totalOriginalKTokens,
        uint256 effectiveSupply
    )
        internal
        pure
        returns (uint256)
    {
        if (effectiveSupply == 0) return 0;
        return totalStkTokensUnstaked.mulWad(uint256(totalOriginalKTokens)).divWad(effectiveSupply);
    }

    function _rebaseIfNeeded(BaseVaultStorage storage $) internal {
        uint256 totalVaultAssets = _getTotalVaultAssets($);
        uint256 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;
        if (totalVaultAssets > accountedAssets) {
            uint256 yield = totalVaultAssets - accountedAssets;
            if (yield <= MAX_YIELD_PER_SYNC) {
                $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) + yield);
                $.userTotalAssets = uint128(uint256($.userTotalAssets) + yield);
                emit VarianceRecorded(yield, true);
            }
        }
    }

    function _updateAccountingForStaking(
        BaseVaultStorage storage $,
        uint256 totalKTokensStaked
    )
        internal
        returns (uint256 currentStkTokenPrice, uint256 totalStkTokensToMint)
    {
        currentStkTokenPrice = $.totalStkTokenSupply == 0
            ? PRECISION
            : uint256($.totalStkTokenAssets).divWad(uint256($.totalStkTokenSupply));
        totalStkTokensToMint = totalKTokensStaked.divWad(currentStkTokenPrice);
        uint256 newStkTokenSupply = uint256($.totalStkTokenSupply) + totalStkTokensToMint;
        if (newStkTokenSupply > type(uint128).max) revert StkTokenSupplyOverflow();
        $.totalStkTokenSupply = uint128(newStkTokenSupply);
    }

    function _updateAccountingForUnstaking(
        BaseVaultStorage storage $,
        uint256 totalStkTokensUnstaked
    )
        internal
        returns (
            uint256 effectiveSupply,
            uint256 currentStkTokenPrice,
            uint256 totalAssetsToDistribute,
            uint256 totalOriginalKTokens
        )
    {
        effectiveSupply = $.totalStkTokenSupply;
        currentStkTokenPrice = effectiveSupply == 0 ? PRECISION : uint256($.totalStkTokenAssets).divWad(effectiveSupply);
        totalAssetsToDistribute = totalStkTokensUnstaked.mulWad(currentStkTokenPrice);
        totalOriginalKTokens = $.totalStakedKTokens;
        $.totalStkTokenAssets = uint128(uint256($.totalStkTokenAssets) - totalAssetsToDistribute);
        $.userTotalAssets = uint128(uint256($.userTotalAssets) - totalAssetsToDistribute);
    }

    function _processAssetReturn(
        BaseVaultStorage storage $,
        address kDNVault,
        uint256 batchOriginalKTokens,
        uint256 batchId,
        address[] calldata sources,
        uint256[] calldata amounts
    )
        internal
    {
        uint256 totalAssetsToReturn = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAssetsToReturn += amounts[i];
        }
        (bool returned,) = address(this).call(
            abi.encodeWithSignature("returnAssetsFromDestinations(address[],uint256[])", sources, amounts)
        );
        if (!returned) revert AssetAllocationFailed();
        uint256 currentBalance = $.underlyingAsset.balanceOf(address(this));
        if (!(currentBalance >= batchOriginalKTokens)) revert InsufficientAssetsToReturnToKDN();
        require(totalAssetsToReturn >= batchOriginalKTokens, "Strategy return amount insufficient for kDN requirement");
        if (currentBalance < totalAssetsToReturn) {
            uint256 shortfall = totalAssetsToReturn - currentBalance;
            emit VarianceRecorded(shortfall, false);
        }
        $.underlyingAsset.safeTransfer(kDNVault, batchOriginalKTokens);
        emit AssetRecoveredFromStrategies(currentBalance, totalAssetsToReturn);
        emit AssetsReturnedToDN(batchOriginalKTokens, batchId);
    }

    /*//////////////////////////////////////////////////////////////
                      MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the function selectors for this module
    /// @return Array of function selectors that this module implements
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](2);
        s[0] = this.settleStakingBatch.selector;
        s[1] = this.settleUnstakingBatch.selector;
        return s;
    }
}
