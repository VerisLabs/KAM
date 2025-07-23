// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title MockkBatch
/// @notice Mock implementation of kBatch for testing
contract MockkBatch {
    uint256 private _currentBatchId = 1;
    mapping(uint256 => bool) private _batchSettled;
    mapping(uint256 => address) private _batchReceivers;

    function initialize(
        address, // kMinterUSD
        address, // kMinterBTC
        address, // USDC
        address, // WBTC
        address // admin
    )
        external
    {
        // Mock initialization - no-op
    }

    function getCurrentBatchId() external view returns (uint256) {
        return _currentBatchId;
    }

    function updateBatchInfo(uint256, address, int256) external {
        // Mock implementation - no-op
    }

    function isBatchSettled(uint256 batchId) external view returns (bool) {
        return _batchSettled[batchId];
    }

    function getBatchReceiver(uint256 batchId) external view returns (address) {
        return _batchReceivers[batchId];
    }

    // Test helper functions
    function mockSetBatchSettled(uint256 batchId, bool settled) external {
        _batchSettled[batchId] = settled;
    }

    function mockSetBatchReceiver(uint256 batchId, address receiver) external {
        _batchReceivers[batchId] = receiver;
    }

    function mockIncrementBatchId() external {
        _currentBatchId++;
    }
}
