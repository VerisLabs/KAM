// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for kBatchReceiver
interface IkBatchReceiver {
    function receiveAssets(address recipient, address asset, uint256 amount, uint256 batchId) external payable;
}
