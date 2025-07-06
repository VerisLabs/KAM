// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title ClaimModule
/// @notice Handles claim operations for settled batches
/// @dev Contains claim functions for staking and unstaking operations
contract ClaimModule is ModuleBase {
    using SafeTransferLib for address;

    // Constants inherited from ModuleBase

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event StakingSharesClaimed(uint256 indexed batchId, uint256 requestIndex, address indexed user, uint256 shares);
    event UnstakingAssetsClaimed(uint256 indexed batchId, uint256 requestIndex, address indexed user, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);

    /*//////////////////////////////////////////////////////////////
                          CLAIM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestIndex Index of the request in the batch
    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable nonReentrant whenNotPaused {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch is settled
        if (batchId > $.lastSettledStakingBatchId) revert BatchNotFound();

        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];
        if (!batch.settled) revert BatchNotFound();

        // Validate request
        if (requestIndex >= batch.requests.length) revert InvalidRequestIndex();

        DataTypes.StakingRequest storage request = batch.requests[requestIndex];
        if (request.claimed) revert AlreadyClaimed();

        // Verify caller is the beneficiary
        if (msg.sender != request.user) revert NotBeneficiary();

        // Mark as claimed
        request.claimed = true;

        // Calculate stkTokens to mint based on batch settlement price
        uint256 stkTokensToMint = (request.kTokenAmount * PRECISION) / batch.stkTokenPrice;

        // O(1) CLAIM: Direct storage update for stkTokens transfer from vault to user
        // Update user share balances directly in the modular architecture
        $.userTotalSupply = uint128(uint256($.userTotalSupply) + stkTokensToMint);
        $.userShareBalances[request.user] += stkTokensToMint;

        // Track the specific kToken amount staked by this user
        $.userOriginalKTokens[request.user] += request.kTokenAmount;

        // Update batch tracking
        batch.totalStkTokensClaimed += stkTokensToMint;

        emit StakingSharesClaimed(batchId, requestIndex, request.user, stkTokensToMint);
        emit StkTokensIssued(request.user, stkTokensToMint);
    }

    /// @notice Claims kTokens from a settled unstaking batch (yield goes to minter)
    /// @param batchId Batch ID to claim from
    /// @param requestIndex Index of the request in the batch
    function claimUnstakedAssets(uint256 batchId, uint256 requestIndex) external payable nonReentrant whenNotPaused {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch is settled
        if (batchId > $.lastSettledUnstakingBatchId) revert BatchNotFound();

        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];
        if (!batch.settled) revert BatchNotFound();

        // Validate request
        if (requestIndex >= batch.requests.length) revert InvalidRequestIndex();

        DataTypes.UnstakingRequest storage request = batch.requests[requestIndex];
        if (request.claimed) revert AlreadyClaimed();

        // Verify caller is the beneficiary
        if (msg.sender != request.user) revert NotBeneficiary();

        // Mark as claimed
        request.claimed = true;

        uint256 kTokensToReturn = request.originalKTokenAmount;

        $.totalStakedKTokens = uint128(uint256($.totalStakedKTokens) - kTokensToReturn);
        batch.totalKTokensClaimed += kTokensToReturn;

        emit UnstakingAssetsClaimed(batchId, requestIndex, request.user, kTokensToReturn);

        $.kToken.safeTransfer(request.user, kTokensToReturn);

        // Note: yield assets already transferred to minter pool during settlement
    }

    /*//////////////////////////////////////////////////////////////
                          MODULE SELECTOR FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](2);
        moduleSelectors[0] = this.claimStakedShares.selector;
        moduleSelectors[1] = this.claimUnstakedAssets.selector;
        return moduleSelectors;
    }
}
