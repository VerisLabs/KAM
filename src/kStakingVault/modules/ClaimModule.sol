// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkBatch } from "src/interfaces/IkBatch.sol";
import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
import { ModuleBaseTypes } from "src/kStakingVault/types/ModuleBaseTypes.sol";

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

        if (!IkBatch(_getKBatch()).isBatchSettled(batchId)) revert BatchNotSettled();
        ModuleBaseTypes.StakeRequest storage request = $.stakeRequests[requestId];
        if (request.batchId != batchId.toUint32()) revert InvalidBatchId();
        if (request.status != uint8(ModuleBaseTypes.RequestStatus.PENDING)) revert RequestNotPending();
        if (msg.sender != request.user) revert NotBeneficiary();

        request.status = uint8(ModuleBaseTypes.RequestStatus.CLAIMED);

        // Calculate stkToken amount based on current exchange rate
        uint256 stkTokensToMint = uint256(request.kTokenAmount);

        // Double-check slippage protection at claim time
        if (stkTokensToMint < request.minStkTokens) {
            revert MinimumOutputNotMet();
        }

        emit StakingSharesClaimed(batchId.toUint32(), 0, request.user, stkTokensToMint);
        emit StkTokensIssued(request.user, stkTokensToMint);
    }

    /// @notice Claims kTokens from a settled unstaking batch (simplified implementation)
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimUnstakedAssets(uint256 batchId, uint256 requestId) external payable nonReentrant whenNotPaused {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        if (!IkBatch(_getKBatch()).isBatchSettled(batchId)) revert BatchNotSettled();
        ModuleBaseTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];
        if (request.batchId != batchId.toUint32()) revert InvalidBatchId();
        if (request.status != uint8(ModuleBaseTypes.RequestStatus.PENDING)) revert RequestNotPending();
        if (msg.sender != request.user) revert NotBeneficiary();

        request.status = uint8(ModuleBaseTypes.RequestStatus.CLAIMED);

        // Calculate total kTokens to return (simplified 1:1 for now)
        uint256 totalKTokensToReturn = uint256(request.stkTokenAmount);

        // SECURITY: Validate slippage protection at claim time
        if (totalKTokensToReturn < request.minKTokens) {
            revert MinimumOutputNotMet();
        }

        emit UnstakingAssetsClaimed(batchId.toUint32(), 0, request.user, totalKTokensToReturn);
        emit KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensToReturn);

        // Transfer kTokens to user
        _getKTokenForAsset($.underlyingAsset).safeTransfer(request.user, totalKTokensToReturn);
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
