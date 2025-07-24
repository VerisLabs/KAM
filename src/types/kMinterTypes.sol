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

    /// @notice Comprehensive redemption request structure with full tracking data
    /// @dev Stored internally to track redemption requests through the batch settlement process
    struct RedeemRequest {
        bytes32 id; // Unique identifier for this redemption request
        address user; // Address of the user who made the request
        address asset; // Address of the asset to redeem
        uint96 amount; // Amount of kTokens being redeemed (gas-optimized)
        address recipient; // Address that will receive the underlying assets
        uint64 requestTimestamp; // Timestamp when the request was created (gas-optimized)
        RequestStatus status; // Current status of the redemption request
        uint256 batchId; // Batch ID of the redemption request
    }
}
