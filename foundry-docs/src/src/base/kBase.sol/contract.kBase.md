# kBase
[Git Source](https://github.com/VerisLabs/KAM/blob/2cfac335d9060b60757c350b6581b2ed1a8a6b82/src/base/kBase.sol)

**Inherits:**
OwnableRoles, ReentrancyGuardTransient

Base contract providing common functionality for all KAM protocol contracts

*Includes registry integration, role management, pause functionality, and helper methods*


## State Variables
### ADMIN_ROLE

```solidity
uint256 internal constant ADMIN_ROLE = _ROLE_0;
```


### EMERGENCY_ADMIN_ROLE

```solidity
uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
```


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
function __kBase_init(address registry_, address owner_, address admin_, bool paused_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|
|`owner_`|`address`||
|`admin_`|`address`||
|`paused_`|`bool`|Initial pause state|


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


### _getRelayer

Checks if an address is a relayer


```solidity
function _getRelayer() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a relayer|


### _getGuardian

Checks if an address is a guardian


```solidity
function _getGuardian() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a guardian|


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


### _isAssetRegistered

Checks if an asset is supported by the protocol


```solidity
function _isAssetRegistered(address asset) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the asset is supported|


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


### _isRegisteredAsset

Checks if an asset is registered


```solidity
function _isRegisteredAsset(address asset) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the asset is registered|


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


### onlyKMinter

Restricts function access to the kMinter contract


```solidity
modifier onlyKMinter();
```

### onlyRelayer

Restricts function access to the relayer

*Only callable internally by inheriting contracts*


```solidity
modifier onlyRelayer();
```

### onlyGuardian

Restricts function access to the guardian

*Only callable internally by inheriting contracts*


```solidity
modifier onlyGuardian();
```

### onlyRegisteredAsset

Ensures the asset is supported by the protocol


```solidity
modifier onlyRegisteredAsset(address asset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to validate|


## Events
### Paused

```solidity
event Paused(bool paused);
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidRegistry

```solidity
error InvalidRegistry();
```

### NotInitialized

```solidity
error NotInitialized();
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

### OnlyKMinter

```solidity
error OnlyKMinter();
```

### OnlyGuardian

```solidity
error OnlyGuardian();
```

### OnlyRelayer

```solidity
error OnlyRelayer();
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

