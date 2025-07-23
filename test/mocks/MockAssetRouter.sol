// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title MockAssetRouter
/// @notice Mock asset router for testing kMinter functionality
contract MockAssetRouter {
    mapping(address => bool) private _registeredAssets;

    function isRegisteredAsset(address asset) external view returns (bool) {
        return _registeredAssets[asset];
    }

    function registerAsset(address asset, bool isRegistered) external {
        _registeredAssets[asset] = isRegistered;
    }

    function kAssetPush(address, address, uint256, uint256) external {
        // Mock implementation - just succeed
    }

    function kAssetRequestPull(address, address, uint256, uint256) external {
        // Mock implementation - just succeed
    }
}
