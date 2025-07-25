// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title kMinterTypes
/// @notice Library containing all data structures used in the kMinter contract
/// @dev Defines standardized data types for cross-contract communication and storage
library kMinterTypes {
    /// @notice Status enumeration for tracking redemption request lifecycle
    /// @dev Used to prevent double-spending and track request processing
    enum RequestStatus {
        PENDING, // Request submitted but not yet processed (tokens escrowed, not burned)
        REDEEMED, // Request successfully completed and claimed
        CANCELLED // Request cancelled before processing (tokens returned to user)

    }

    struct RedeemRequest {
        bytes32 id;
        address user;
        uint96 amount;
        address asset;
        uint64 requestTimestamp;
        uint8 status;
        uint24 batchId;
        address recipient;
    }
}
