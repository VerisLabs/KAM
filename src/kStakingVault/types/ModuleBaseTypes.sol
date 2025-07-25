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

    struct StakeRequest {
        uint256 id;
        address user;
        uint96 kTokenAmount;
        address recipient;
        uint64 requestTimestamp;
        uint8 status;
        uint96 minStkTokens;
        uint32 batchId;
    }

    struct UnstakeRequest {
        uint256 id;
        address user;
        uint96 stkTokenAmount;
        address recipient;
        uint64 requestTimestamp;
        uint8 status;
        uint96 minKTokens;
        uint32 batchId;
    }
}
