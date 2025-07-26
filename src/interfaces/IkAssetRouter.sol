// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for kAssetRouter push model
interface IkAssetRouter {
    function kAssetPush(address _asset, uint256 amount, uint256 batchId) external payable;
    function kAssetRequestPull(address _asset, uint256 amount, uint256 batchId) external payable;
    function routeToBatchReceiver(address batchReceiver, address sourceVault, uint256 amount) external payable;
    function isRegisteredAsset(address _asset) external view returns (bool);
    function kSharesRequestPull(address sourceVault, uint256 amount, uint256 batchId) external payable;
    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        uint256 batchId
    )
        external
        payable;
}
