// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";

/// @title kBatchTypes
/// @notice Library containing all data structures used in the kBatch contract
/// @dev Defines standardized data types for cross-contract communication and storage
library kBatchTypes {
    struct BatchInfo {
        uint32 batchId;
        address batchReceiver;
        bool isClosed;
        bool isSettled;
        EnumerableSetLib.AddressSet vaults;
        EnumerableSetLib.AddressSet assets;
    }
}
