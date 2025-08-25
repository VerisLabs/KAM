// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IVaultBatch {
    /// @notice Creates a new batch for processing requests
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function createNewBatch() external;

    /// @notice Closes a batch to prevent new requests
    /// @param _batchId The batch ID to close
    /// @dev Only callable by RELAYER_ROLE, typically called at cutoff time
    function closeBatch(bytes32 _batchId, bool _create) external;

    /// @notice Marks a batch as settled
    /// @param _batchId The batch ID to settle
    /// @dev Only callable by kMinter, indicates assets have been distributed
    function settleBatch(bytes32 _batchId) external;

    /// @notice Deploys BatchReceiver for specific batch
    /// @param _batchId Batch ID to deploy receiver for
    /// @dev Only callable by kAssetRouter
    function createBatchReceiver(bytes32 _batchId) external returns (address);
}
