// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC20 } from "solady/tokens/ERC20.sol";

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";

import { BaseVault } from "src/kStakingVault/base/BaseVault.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

/// @title VaultClaims
/// @notice Handles claim operations for settled batches
/// @dev Contains claim functions for staking and unstaking operations
contract VaultClaims is BaseVault {
    using SafeCastLib for uint256;
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error BatchNotSettled();
    error InvalidBatchId();
    error RequestNotPending();
    error NotBeneficiary();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user claims staking shares
    event StakingSharesClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 shares);

    /// @notice Emitted when a user claims unstaking assets
    event UnstakingAssetsClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 assets);

    /// @notice Emitted when stkTokens are issued
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);

    /// @notice Emitted when kTokens are unstaked
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);

    /*//////////////////////////////////////////////////////////////
                          CLAIM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable {
        // Open `nonRentrant`
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (_getPaused($)) revert IsPaused();
        if (!$.batches[batchId].isSettled) revert BatchNotSettled();

        BaseVaultTypes.StakeRequest storage request = $.stakeRequests[requestId];
        if (request.batchId != batchId) revert InvalidBatchId();
        if (request.status != BaseVaultTypes.RequestStatus.PENDING) revert RequestNotPending();
        if (msg.sender != request.user) revert NotBeneficiary();

        request.status = BaseVaultTypes.RequestStatus.CLAIMED;

        // Calculate stkToken amount based on settlement-time share price
        uint256 netSharePrice = $.batches[batchId].netSharePrice;
        if (netSharePrice == 0) revert();

        // Divide the deposited assets by the share price of the batch to obtain stkTokens to mint
        uint256 stkTokensToMint = (uint256(request.kTokenAmount)).fullMulDiv(10 ** _getDecimals($), netSharePrice);

        emit StakingSharesClaimed(batchId, requestId, request.user, stkTokensToMint);

        // Reduce total pending stake and remove user stake request
        $.userRequests[msg.sender].remove(requestId);
        $.totalPendingStake -= request.kTokenAmount;

        // Mint stkTokens to user
        _mint(request.user, stkTokensToMint);
        emit StkTokensIssued(request.user, stkTokensToMint);

        // Close `nonRentrant`
        _unlockReentrant();
    }

    /// @notice Claims kTokens from a settled unstaking batch (simplified implementation)
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable {
        // Open `nonRentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (_getPaused($)) revert IsPaused();
        if (!$.batches[batchId].isSettled) revert BatchNotSettled();

        BaseVaultTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];
        if (request.batchId != batchId) revert InvalidBatchId();
        if (request.status != BaseVaultTypes.RequestStatus.PENDING) revert RequestNotPending();
        if (msg.sender != request.user) revert NotBeneficiary();

        request.status = BaseVaultTypes.RequestStatus.CLAIMED;

        uint256 sharePrice = $.batches[batchId].sharePrice;
        uint256 netSharePrice = $.batches[batchId].netSharePrice;
        if (sharePrice == 0) revert();

        // Calculate total kTokens to return based on settlement-time share price
        // Multply redeemed shares for net and gross share price to obtain gross and net amount of assets
        uint256 totalKTokensGross = (uint256(request.stkTokenAmount)).fullMulDiv(sharePrice, 10 ** _getDecimals($));
        uint256 totalKTokensNet = (uint256(request.stkTokenAmount)).fullMulDiv(netSharePrice, 10 ** _getDecimals($));

        // Calculate fees as the deifference between gross and net amount
        uint256 fees = totalKTokensGross - totalKTokensNet;

        // Burn stkTokens from vault (already transferred to vault during request)
        _burn(address(this), request.stkTokenAmount);
        emit UnstakingAssetsClaimed(batchId, requestId, request.user, totalKTokensNet);

        // Transfer fees to treasury
        $.kToken.safeTransfer(_registry().getTreasury(), fees);

        // Transfer kTokens to user
        $.kToken.safeTransfer(request.user, totalKTokensNet);
        emit KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensNet);

        // Close `nonRentrant`
        _unlockReentrant();
    }
}
