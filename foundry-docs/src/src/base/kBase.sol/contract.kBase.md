# kBase
[Git Source](https://github.com/VerisLabs/KAM/blob/7fe450d42e02311faf605d62cd48b6af1b05e41f/src/base/kBase.sol)

**Inherits:**
ReentrancyGuardTransient

Base contract providing common functionality for all KAM protocol contracts

*Includes registry integration, role management, pause functionality, and helper methods*


## State Variables
### K_MINTER

```solidity
bytes32 internal constant K_MINTER = keccak256("K_MINTER");
```


### K_ASSET_ROUTER

```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### KBASE_STORAGE_LOCATION

```solidity
bytes32 private constant KBASE_STORAGE_LOCATION = 0xe91688684975c4d7d54a65dd96da5d4dcbb54b8971c046d5351d3c111e43a800;
```


## Functions
### _getBaseStorage

Returns the kBase storage


```solidity
function _getBaseStorage() internal pure returns (kBaseStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`kBaseStorage`|Storage struct containing registry, initialized, and paused states|


### __kBase_init

Initializes the base contract with registry and pause state

*Can only be called once during initialization*


```solidity
function __kBase_init(address registry_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|


### _setPaused

Sets the pause state of the contract

*Only callable internally by inheriting contracts*


```solidity
function _setPaused(bool paused_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|New pause state|


### _rescueAssets

rescues locked assets in the contract


```solidity
function _rescueAssets(address asset_, address to_, uint256 amount_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|the asset_ to rescue address|
|`to_`|`address`|the address that will receive the assets|
|`amount_`|`uint256`||


### registry

Returns the registry contract address

*Reverts if contract not initialized*


```solidity
function registry() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The kRegistry contract address|


### _registry

Returns the registry contract interface

*Internal helper for typed registry access*


```solidity
function _registry() internal view returns (IkRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IkRegistry`|IkRegistry interface for registry interaction|


### _getBatchId

Gets the current batch ID for a given vault

*Reverts if vault not registered*


```solidity
function _getBatchId(address vault) internal view returns (bytes32 batchId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The current batch ID|


### _getBatchReceiver

Gets the current batch receiver for a given batchId

*Reverts if vault not registered*


```solidity
function _getBatchReceiver(address vault_, bytes32 batchId_) internal view returns (address batchReceiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|The vault address|
|`batchId_`|`bytes32`|The batch ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchReceiver`|`address`|The address of the batchReceiver where tokens will be sent|


### _getKMinter

Gets the kMinter singleton contract address

*Reverts if kMinter not set in registry*


```solidity
function _getKMinter() internal view returns (address minter);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The kMinter contract address|


### _getKAssetRouter

Gets the kAssetRouter singleton contract address

*Reverts if kAssetRouter not set in registry*


```solidity
function _getKAssetRouter() internal view returns (address router);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The kAssetRouter contract address|


### _getKTokenForAsset

Gets the kToken address for a given asset

*Reverts if asset not supported*


```solidity
function _getKTokenForAsset(address asset) internal view returns (address kToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`kToken`|`address`|The corresponding kToken address|


### _getVaultAssets

Gets the asset managed by a vault

*Reverts if vault not registered*


```solidity
function _getVaultAssets(address vault) internal view returns (address[] memory assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`address[]`|The asset address managed by the vault|


### _getDNVaultByAsset

Gets the DN vault address for a given asset

*Reverts if asset not supported*


```solidity
function _getDNVaultByAsset(address asset) internal view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The corresponding DN vault address|


### _isAdmin

Checks if an address is a admin


```solidity
function _isAdmin(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a admin|


### _isEmergencyAdmin

Checks if an address is a emergencyAdmin


```solidity
function _isEmergencyAdmin(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a emergencyAdmin|


### _isGuardian

Checks if an address is a guardian


```solidity
function _isGuardian(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a guardian|


### _isRelayer

Checks if an address is a relayer


```solidity
function _isRelayer(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a relayer|


### _isInstitution

Checks if an address is a institution


```solidity
function _isInstitution(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a institution|


### _isPaused

Checks if an address is a institution


```solidity
function _isPaused() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a institution|


### _isKMinter

Gets the kMinter singleton contract address

*Reverts if kMinter not set in registry*


```solidity
function _isKMinter(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|minter The kMinter contract address|


### _isVault

Checks if an address is a registered vault


```solidity
function _isVault(address vault) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a registered vault|


### _isAsset

Checks if an asset is registered


```solidity
function _isAsset(address asset) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the asset is registered|


## Events
### Paused

```solidity
event Paused(bool paused);
```

### RescuedAssets

```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### ZeroAmount

```solidity
error ZeroAmount();
```

### InvalidRegistry

```solidity
error InvalidRegistry();
```

### NotInitialized

```solidity
error NotInitialized();
```

### AlreadyInitialized

```solidity
error AlreadyInitialized();
```

### ContractNotFound

```solidity
error ContractNotFound(bytes32 identifier);
```

### AssetNotSupported

```solidity
error AssetNotSupported(address asset);
```

### InvalidVault

```solidity
error InvalidVault(address vault);
```

### IsPaused

```solidity
error IsPaused();
```

### IsNotAdmin

```solidity
error IsNotAdmin();
```

### WrongRole

```solidity
error WrongRole();
```

### WrongAsset

```solidity
error WrongAsset();
```

### OnlyMinter

```solidity
error OnlyMinter();
```

### OnlyStakingVault

```solidity
error OnlyStakingVault();
```

## Structs
### kBaseStorage
**Note:**
storage-location: erc7201:kam.storage.kBase


```solidity
struct kBaseStorage {
    address registry;
    bool initialized;
    bool paused;
}
```

