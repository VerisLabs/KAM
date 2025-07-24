// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for kBatchReceiver
interface IkBatchReceiver {
    function pullAssets(address receiver, address asset, uint256 amount, uint256 _batchId) external;
}
