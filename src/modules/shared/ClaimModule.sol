// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title ClaimModule
/// @notice Handles claim operations for settled batches
/// @dev Contains claim functions for staking and unstaking operations
contract ClaimModule is ModuleBase {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    // Constants inherited from ModuleBase

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice ERC20 Transfer event for stkToken operations
    event Transfer(address indexed from, address indexed to, uint256 value);

    event StakingSharesClaimed(uint256 indexed batchId, uint256 requestIndex, address indexed user, uint256 shares);
    event UnstakingAssetsClaimed(uint256 indexed batchId, uint256 requestIndex, address indexed user, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);

    /*//////////////////////////////////////////////////////////////
                          CLAIM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestIndex Index of the request in the batch
    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable nonReentrant whenNotPaused {
        BaseVaultStorage storage $ = _getBaseVaultStorage();

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
        uint256 stkTokensToMint = uint256(request.kTokenAmount).divWad(batch.stkTokenPrice);

        // Mint stkTokens to user with proper ERC20 accounting and events
        $.userTotalSupply += _safeToUint128(stkTokensToMint);
        $.userShareBalances[request.user] += stkTokensToMint;

        // Emit proper ERC20 Transfer event for minting
        emit Transfer(address(0), request.user, stkTokensToMint);

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
        BaseVaultStorage storage $ = _getBaseVaultStorage();

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

        // Burn the user's escrowed stkTokens from vault balance with proper ERC20 accounting and events
        $.userTotalSupply -= _safeToUint128(uint256(request.stkTokenAmount));
        $.userShareBalances[address(this)] -= uint256(request.stkTokenAmount);

        // Emit proper ERC20 Transfer event for burning
        emit Transfer(address(this), address(0), uint256(request.stkTokenAmount));

        // Calculate user's share using batch-level ratio
        uint256 originalKTokens = uint256(request.stkTokenAmount).mulWad(batch.originalKTokenRatio);

        // Calculate total kTokens to return including yield with user-favorable rounding
        uint256 totalKTokensToReturn = uint256(request.stkTokenAmount).mulWadUp(batch.stkTokenPrice);

        // Update accounting
        $.totalStakedKTokens = uint128(uint256($.totalStakedKTokens) - originalKTokens);
        batch.totalKTokensClaimed += totalKTokensToReturn;

        // Decrement user's original kTokens tracking
        $.userOriginalKTokens[request.user] -= originalKTokens;

        emit UnstakingAssetsClaimed(batchId, requestIndex, request.user, totalKTokensToReturn);
        emit KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensToReturn);

        // Transfer total kTokens (original + yield) to user
        $.kToken.safeTransfer(request.user, totalKTokensToReturn);
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
