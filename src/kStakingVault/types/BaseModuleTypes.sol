// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ModuleBaseTypes
/// @notice Library containing all data structures used in the ModuleBase
/// @dev Defines standardized data types for cross-contract communication and storage
library BaseModuleTypes {
    enum RequestStatus {
        PENDING,
        CLAIMED,
        FAILED,
        CANCELLED
    }

    struct StakeRequest {
        uint256 id; // 32 bytes - Slot 0
        address user; // 20 bytes ┐
        uint96 kTokenAmount; // 12 bytes ┘ Slot 1 (32 bytes total)
        address recipient; // 20 bytes ┐
        uint256 batchId; // 32 bytes - Slot 3
        uint64 requestTimestamp; // 8 bytes  ┐
        uint8 status; // 1 byte   ┘ Slot 4 (9 bytes, 23 padding)
    }

    struct UnstakeRequest {
        uint256 id; // 32 bytes - Slot 0
        address user; // 20 bytes ┐
        uint96 stkTokenAmount; // 12 bytes ┘ Slot 1
        address recipient; // 20 bytes ┐
        uint256 batchId; // 32 bytes - Slot 3
        uint64 requestTimestamp; // 8 bytes  ┐
        uint8 status; // 1 byte   ┘ Slot 4
    }

    struct BatchInfo {
        uint256 batchId; // 32 bytes - Slot 0
        address batchReceiver; // 20 bytes ┐
        bool isClosed; // 1 byte   │
        bool isSettled; // 1 byte   ┘ Slot 1 (22 bytes, 10 padding)
    }
}
