// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IkRegistry {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    enum VaultType {
        MINTER,
        DN,
        ALPHA,
        BETA
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event SingletonContractSet(bytes32 indexed id, address indexed contractAddress);
    event VaultRegistered(address indexed vault, address indexed asset, VaultType indexed vaultType);
    event KTokenRegistered(address indexed asset, address indexed kToken);
    event AssetSupported(address indexed asset);
    event AdapterRegistered(address indexed vault, address indexed adapter);
    event AdapterRemoved(address indexed vault, address indexed adapter);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error AlreadyRegistered();
    error AssetNotSupported();
    error ContractNotSet();
    error AdapterNotRegistered();
    error InvalidAdapter();
    error AdapterAlreadySet();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSingletonContract(bytes32 id, address contractAddress) external;
    function registerAsset(address asset, address kToken, bytes32 id) external;
    function registerVault(address vault, VaultType type_, address asset) external;
    function registerAdapter(address vault, address adapter) external;
    function removeAdapter(address vault, address adapter) external;

    function getContractById(bytes32 id) external view returns (address);
    function getAssetById(bytes32 id) external view returns (address);
    function getAllAssets() external view returns (address[] memory);
    function getCoreContracts() external view returns (address kMinter, address kAssetRouter);
    function getVaultsByAsset(address asset) external view returns (address[] memory);
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address);
    function getVaultType(address vault) external view returns (uint8);
    function isRelayer(address account) external view returns (bool);
    function isRegisteredAsset(address asset) external view returns (bool);
    function isVault(address vault) external view returns (bool);
    function isSingletonContract(address contractAddress) external view returns (bool);
    function isKToken(address kToken) external view returns (bool);
    function getAdapters(address vault) external view returns (address[] memory);
    function isAdapterRegistered(address adapter) external view returns (bool);
    function getVaultAssets(address vault) external view returns (address[] memory);
    function assetToKToken(address asset) external view returns (address);
}
