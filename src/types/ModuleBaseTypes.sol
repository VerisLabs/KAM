// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ModuleBaseTypes
/// @notice Library containing all data structures used in the ModuleBase
/// @dev Defines standardized data types for cross-contract communication and storage
library ModuleBaseTypes {
    /// @notice Status enumeration for tracking staking request lifecycle
    /// @dev Used to prevent double-spending and track request processing
    enum RequestStatus {
        PENDING, // Request submitted but not yet processed (tokens escrowed, not burned)
        CLAIMED, // Request successfully completed and claimed
        CANCELLED // Request cancelled before processing (tokens returned to user)

    }

    /// @notice Individual staking request structure for kToken to stkToken conversion
    /// @dev Represents a user's request to stake kTokens for yield-bearing stkTokens
    struct StakeRequest {
        uint256 id; // Unique identifier for this staking request
        address user; // Address of the user making the staking request
        address recipient; // Address that will receive the stkTokens
        uint96 kTokenAmount; // Amount of kTokens to stake
        uint96 minStkTokens; // Minimum stkTokens user expects to receive
        uint64 requestTimestamp; // Timestamp when the request was created
        RequestStatus status; // Current status of the staking request
        uint256 batchId; // Batch ID of the staking request
    }

    struct UnstakeRequest {
        uint256 id; // Unique identifier for this unstaking request
        address user; // Address of the user making the unstaking request
        address recipient; // Address that will receive the kTokens
        uint96 stkTokenAmount; // Amount of stkTokens to unstake
        uint96 minKTokens; // Minimum kTokens user expects to receive
        uint64 requestTimestamp; // Timestamp when the request was created
        RequestStatus status; // Current status of the unstaking request
        uint256 batchId; // Batch ID of the unstaking request
    }
}
