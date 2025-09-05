// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IVaultReader {
    function registry() external view returns (address);
    function asset() external view returns (address);
    function underlyingAsset() external view returns (address);
    function computeLastBatchFees()
        external
        view
        returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees);
    function lastFeesChargedManagement() external view returns (uint256);
    function lastFeesChargedPerformance() external view returns (uint256);
    function hurdleRate() external view returns (uint16);
    function performanceFee() external view returns (uint16);
    function nextPerformanceFeeTimestamp() external view returns (uint256);
    function nextManagementFeeTimestamp() external view returns (uint256);
    function managementFee() external view returns (uint16);
    function sharePriceWatermark() external view returns (uint256);
    function isBatchClosed() external view returns (bool);
    function isBatchSettled() external view returns (bool);
    function getBatchIdInfo()
        external
        view
        returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled);
    function getBatchReceiver(bytes32 batchId) external view returns (address);
    function getSafeBatchReceiver(bytes32 batchId) external view returns (address);
    function sharePrice() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalNetAssets() external view returns (uint256);
    function getBatchId() external view returns (bytes32);
    function getSafeBatchId() external view returns (bytes32);
    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
