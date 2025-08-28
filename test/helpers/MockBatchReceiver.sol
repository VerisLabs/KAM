// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

/// @title MockBatchReceiver
/// @notice Mock implementation of BatchReceiver for testing
contract MockBatchReceiver {
    /// @notice Receives assets during settlement
    receive() external payable { }

    /// @notice Mock function to handle batch processing
    function processBatch() external pure returns (bool) {
        return true;
    }

    /// @notice Mock function to receive assets during settlement
    /// @param recipient The address to receive the assets
    /// @param asset The asset address
    /// @param amount The amount to transfer
    /// @param batchId The batch ID
    function receiveAssets(address recipient, address asset, uint256 amount, bytes32 batchId) external payable {
        // Mock implementation - transfer assets to recipient
        // In a real implementation, this would handle the actual asset transfer
        // For testing, we'll transfer the assets to the recipient
        IERC20(asset).transfer(recipient, amount);
    }
}
