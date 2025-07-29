// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ModuleBaseTypes
/// @notice Library containing all data structures used in the ModuleBase
/// @dev Defines standardized data types for cross-contract communication and storage
library BaseModuleTypes {
    enum RequestStatus {
        PENDING,
        CLAIMED,
        CANCELLED
    }

    struct StakeRequest {
        uint256 id;           // 32 bytes (slot 1)
        address user;         // 20 bytes (slot 2)
        uint96 kTokenAmount;  // 12 bytes (slot 3)
        address recipient;    // 20 bytes (slot 4)
        uint64 requestTimestamp; // 8 bytes (slot 5)
        uint8 status;         // 1 byte (slot 5)
        uint96 minStkTokens;  // 12 bytes (slot 6)
        uint32 batchId;       // 4 bytes (slot 6)
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

    struct BatchInfo {
        uint32 batchId;
        address batchReceiver;
        bool isClosed;
        bool isSettled;
    }
}
