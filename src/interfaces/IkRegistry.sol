// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IkRegistry {
    enum VaultType {
        DN_VAULT,
        STAKING_VAULT
    }

    function getSingletonContract(bytes32 id) external view returns (address);
    function getSingletonAsset(bytes32 id) external view returns (address);
    function assetToKToken(address asset) external view returns (address);
    function kTokenToAsset(address kToken) external view returns (address);
    function vaultAsset(address vault) external view returns (address);
    function vaultType(address vault) external view returns (VaultType);
    function getVaultsByAsset(address asset) external view returns (address[] memory);
    function getPrimaryVault(address asset, VaultType type_) external view returns (address);
    function isSupportedAsset(address asset) external view returns (bool);
    function isVault(address vault) external view returns (bool);
    function isKToken(address kToken) external view returns (bool);
    function isSingletonContract(address contractAddress) external view returns (bool);
    function isRelayer(address account) external view returns (bool);
}
