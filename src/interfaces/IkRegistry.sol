// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IkRegistry {
    enum VaultType {
        DN,
        ALPHA,
        BETA
    }

    function getContractById(bytes32 id) external view returns (address);
    function setSingletonContract(bytes32 id, address contractAddress) external;
    function registerAsset(address asset, address kToken, bytes32 id) external;
    function registerVault(address vault, VaultType type_, address asset) external;
    function getAssetById(bytes32 id) external view returns (address);
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address);
    function assetToKToken(address asset) external view returns (address);
    function kTokenToAsset(address kToken) external view returns (address);
    function vaultAsset(address vault) external view returns (address);
    function vaultType(address vault) external view returns (VaultType);
    function getVaultsByAsset(address asset) external view returns (address[] memory);
    function getVaultType(address vault) external view returns (uint8);
    function getPrimaryVault(address asset, VaultType type_) external view returns (address);
    function isSupportedAsset(address asset) external view returns (bool);
    function isVault(address vault) external view returns (bool);
    function isKToken(address kToken) external view returns (bool);
    function isSingletonContract(address contractAddress) external view returns (bool);
    function isRelayer(address account) external view returns (bool);

    // Adapter management functions
    function registerAdapter(address vault, address adapter) external;
    function removeAdapter(address vault) external;
    function notifyAdapterRemoval(address adapter) external;
    function getAdapter(address vault) external view returns (address);
    function isAdapterRegistered(address adapter) external view returns (bool);
    function getVaultAsset(address vault) external view returns (address);
    function grantRoles(address user, uint256 roles) external;
}
