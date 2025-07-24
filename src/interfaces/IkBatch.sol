// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IkBatch {
    function createNewBatch() external returns (uint256);
    function closeBatch(uint256 _batchId) external;
    function settleBatch(uint256 _batchId) external;
    function pushVault(uint256 _batchId) external;
    function deployBatchReceiver(uint256 _batchId) external returns (address);
    function getCurrentBatchId() external view returns (uint256);
    function isBatchClosed(uint256 _batchId) external view returns (bool);
    function isBatchSettled(uint256 _batchId) external view returns (bool);
    function isVaultInBatch(uint256 _batchId, address _vault) external view returns (bool);
    function isAssetInBatch(uint256 _batchId, address _asset) external view returns (bool);
    function getBatchInfo(uint256 _batchId)
        external
        view
        returns (uint256 batchId, address batchReceiver, bool isClosed, bool isSettled, address[] memory vaults);
    function getBatchReceiver(uint256 _batchId) external view returns (address);
    function getBatchVaults(uint256 _batchId) external view returns (address[] memory);
    function getBatchAssets(uint256 _batchId) external view returns (address[] memory);
}
