// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC20 } from "solady/tokens/ERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

/// @title ClaimModule
/// @notice Handles claim operations for settled batches
/// @dev Contains claim functions for staking and unstaking operations
contract ClaimModule is BaseModule {
    using SafeCastLib for uint256;
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error BatchNotSettled();
    error InvalidBatchId();
    error RequestNotPending();
    error NotBeneficiary();
    error MinimumOutputNotMet();

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice ERC20 Transfer event for stkToken operations
    event Transfer(address indexed from, address indexed to, uint256 value);
    event StakingSharesClaimed(uint32 indexed batchId, uint256 requestIndex, address indexed user, uint256 shares);
    event UnstakingAssetsClaimed(uint32 indexed batchId, uint256 requestIndex, address indexed user, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);

    /*//////////////////////////////////////////////////////////////
                          CLAIM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimStakedShares(uint256 batchId, uint256 requestId) external payable nonReentrant whenNotPaused {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        if (!$.batches[batchId.toUint32()].isSettled) revert BatchNotSettled();
        BaseModuleTypes.StakeRequest storage request = $.stakeRequests[requestId];
        if (request.batchId != batchId.toUint32()) revert InvalidBatchId();
        if (request.status != uint8(BaseModuleTypes.RequestStatus.PENDING)) revert RequestNotPending();
        if (msg.sender != request.user) revert NotBeneficiary();

        request.status = uint8(BaseModuleTypes.RequestStatus.CLAIMED);

        // Calculate stkToken amount based on settlement-time share price
        uint256 sharePrice = _calculateStkTokenPrice($.lastTotalAssets, ERC20(address(this)).totalSupply());
        uint256 stkTokensToMint = _calculateStkTokensToMint(uint256(request.kTokenAmount), sharePrice);

        // Double-check slippage protection at claim time
        if (stkTokensToMint < request.minStkTokens) {
            revert MinimumOutputNotMet();
        }

        // Mint stkTokens to user
        IkStakingVault(address(this)).mintStkTokens(request.user, stkTokensToMint);

        emit StakingSharesClaimed(batchId.toUint32(), 0, request.user, stkTokensToMint);
        emit StkTokensIssued(request.user, stkTokensToMint);
    }

    /// @notice Claims kTokens from a settled unstaking batch (simplified implementation)
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimUnstakedAssets(uint256 batchId, uint256 requestId) external payable nonReentrant whenNotPaused {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        if (!$.batches[batchId.toUint32()].isSettled) revert BatchNotSettled();
        BaseModuleTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];
        if (request.batchId != batchId.toUint32()) revert InvalidBatchId();
        if (request.status != uint8(BaseModuleTypes.RequestStatus.PENDING)) revert RequestNotPending();
        if (msg.sender != request.user) revert NotBeneficiary();

        request.status = uint8(BaseModuleTypes.RequestStatus.CLAIMED);

        // Calculate total kTokens to return based on settlement-time share price
        uint256 sharePrice = _calculateStkTokenPrice(
            IAdapter(_registry().getAdapter(address(this))).totalAssets(address(this)),
            ERC20(address(this)).totalSupply()
        );
        uint256 totalKTokensToReturn = _calculateAssetValue(uint256(request.stkTokenAmount), sharePrice);

        // SECURITY: Validate slippage protection at claim time
        if (totalKTokensToReturn < request.minKTokens) {
            revert MinimumOutputNotMet();
        }

        // Burn stkTokens from vault (already transferred to vault during request)
        IkStakingVault(address(this)).burnStkTokens(address(this), request.stkTokenAmount);

        emit UnstakingAssetsClaimed(batchId.toUint32(), 0, request.user, totalKTokensToReturn);
        emit KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensToReturn);

        // Transfer kTokens to user
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
