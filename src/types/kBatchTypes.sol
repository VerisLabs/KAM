// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title kBatchTypes
/// @notice Library containing all data structures used in the kBatch contract
/// @dev Defines standardized data types for cross-contract communication and storage
library kBatchTypes {
    struct BatchInfo {
        uint256 batchId;
        uint64 startTime;
        uint64 cutoffTime;
        uint64 settlementTime;
        mapping(address => int256) assetNetPositions; // asset => net position
        mapping(address => bool) assetsInBatch;
        mapping(address => address) vaultsInBatch; // vault => asset => is in batch
        address batchReceiver;
        bool isClosed;
        bool isSettled;
    }
}
