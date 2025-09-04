// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title BaseVaultTypes
/// @notice Library containing all data structures used in the ModuleBase
/// @dev Defines standardized data types for cross-contract communication and storage
library BaseVaultTypes {
    /// @notice Request status
    enum RequestStatus {
        PENDING,
        CLAIMED,
        CANCELLED
    }

    /// @notice Stake request structure
    struct StakeRequest {
        /// @notice User address
        address user;
        /// @notice kToken amount
        uint128 kTokenAmount;
        /// @notice Recipient address
        address recipient;
        /// @notice Batch ID at which the request was made
        bytes32 batchId;
        /// @notice Request timestamp
        uint64 requestTimestamp;
        /// @notice Request status
        RequestStatus status;
    }

    /// @notice Unstake request structure
    struct UnstakeRequest {
        /// @notice User address
        address user;
        /// @notice stkToken amount
        uint128 stkTokenAmount;
        /// @notice Recipient address
        address recipient;
        /// @notice Batch ID at which the request was made
        bytes32 batchId;
        /// @notice Request timestamp
        uint64 requestTimestamp;
        /// @notice Request status
        RequestStatus status;
    }

    /// @notice Batch information structure
    struct BatchInfo {
        /// @notice Batch receiver address
        address batchReceiver;
        /// @notice Whether the batch is closed
        bool isClosed;
        /// @notice Whether the batch is settled
        bool isSettled;
        /// @notice Batch ID
        bytes32 batchId;
        /// @notice Share price of settlement
        uint128 sharePrice;
        /// @notice Net share price of settlement(share price - fees)
        uint128 netSharePrice;
    }
}
