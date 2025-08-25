// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IVaultClaim {
    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable;

    /// @notice Claims kTokens from a settled unstaking batch (simplified implementation)
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable;
}
