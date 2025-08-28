// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ModuleBaseTypes
/// @notice Library containing all data structures used in the ModuleBase
/// @dev Defines standardized data types for cross-contract communication and storage
library BaseVaultModuleTypes {
    enum RequestStatus {
        PENDING,
        CLAIMED,
        CANCELLED
    }

    struct StakeRequest {
        address user;
        uint128 kTokenAmount;
        address recipient;
        bytes32 batchId;
        uint64 requestTimestamp;
        RequestStatus status;
    }

    struct UnstakeRequest {
        address user;
        uint128 stkTokenAmount;
        address recipient;
        bytes32 batchId;
        uint64 requestTimestamp;
        RequestStatus status;
    }

    struct BatchInfo {
        bytes32 batchId;
        address batchReceiver;
        bool isClosed;
        bool isSettled;
    }
}
