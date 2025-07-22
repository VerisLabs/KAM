// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kBatchTypes } from "src/types/kBatchTypes.sol";

interface IkBatch {
    function getCurrentBatchId() external view returns (uint256);
    function isBatchSettled(uint256 _batchId) external view returns (bool);
    function getBatchInfo(uint256 _batchId)
        external
        view
        returns (
            uint256 batchId,
            uint256 startTime,
            uint256 cutoffTime,
            uint256 settlementTime,
            address batchReceiver,
            bool isClosed,
            bool isSettled
        );
    function getBatchReceiver(uint256 _batchId) external view returns (address);
    function getBatchAssets(uint256 _batchId) external view returns (address[] memory);
    function getBatchVaults(uint256 _batchId) external view returns (address[] memory);
    function isAssetInBatch(uint256 _batchId, address _asset) external view returns (bool);
    function isVaultInBatch(uint256 _batchId, address _vault) external view returns (bool);
    function getAssetInVaultBatch(uint256 _batchId, address _vault) external view returns (address);
    function settleBatch(uint256 _batchId) external;
    function batchToUse() external returns (uint256);
    function updateBatchInfo(uint256 _batchId, address _asset, int256 _netPosition) external;
}
