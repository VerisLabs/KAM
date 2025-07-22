// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title MockBatchReceiver
/// @notice Mock implementation of BatchReceiver for testing
contract MockBatchReceiver {
    /// @notice Receives assets during settlement
    receive() external payable { }

    /// @notice Mock function to handle batch processing
    function processBatch() external pure returns (bool) {
        return true;
    }
}
