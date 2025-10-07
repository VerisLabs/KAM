# ProcessRouterModule
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/kRegistry/modules/ProcessRouterModule.sol)

**Inherits:**
[IModule](/src/interfaces/modules/IModule.sol/interface.IModule.md), [IProcessRouter](/src/interfaces/modules/IProcessRouter.sol/interface.IProcessRouter.md), [kBaseRoles](/src/base/kBaseRoles.sol/contract.kBaseRoles.md)

Module for reading the registry

*Inherits from kBaseRoles for role-based access control*


## State Variables
### PROCESSROUTERMODULE_STORAGE_LOCATION

```solidity
bytes32 private constant PROCESSROUTERMODULE_STORAGE_LOCATION =
    0x554e3a023a6cce752a6c1cc2237cde172425f8630dbeddd5526e9dc09c304100;
```


## Functions
### _getProcessRouterModuleStorage

Retrieves the ProcessRouterModule storage struct from its designated storage slot

*Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
storage variables in future upgrades without affecting existing storage layout.*


```solidity
function _getProcessRouterModuleStorage() private pure returns (ProcessRouterModuleStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`ProcessRouterModuleStorage`|The AdapterGuardianModuleStorage struct reference for state modifications|


### setProcessId

*Sets the processId to target and selector*


```solidity
function setProcessId(bytes32 processId, address[] memory targets, bytes4[] memory selectors_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`processId`|`bytes32`|The processId to set|
|`targets`|`address[]`|The targets to set|
|`selectors_`|`bytes4[]`|The selectors to set|


### getProcess

*Gets the processId to target and selector*


```solidity
function getProcess(bytes32 processId) external view returns (address[] memory targets, bytes4[] memory selectors_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`processId`|`bytes32`|The processId to get|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`targets`|`address[]`|The targets to get|
|`selectors_`|`bytes4[]`|The selectors to get|


### getfunctionSelector

*Gets the function selector for a function signature*


```solidity
function getfunctionSelector(string memory functionSignature) external pure returns (bytes4 selector);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`functionSignature`|`string`|The function signature to get the selector for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The selector for the function signature|


### selectors

Returns the selectors for functions in this module


```solidity
function selectors() external pure returns (bytes4[] memory moduleSelectors);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`moduleSelectors`|`bytes4[]`|Array of function selectors|


## Structs
### ProcessRouterModuleStorage
Storage structure for AdapterGuardianModule using ERC-7201 namespaced storage pattern

*This structure maintains adapter permissions and parameter checkers*

**Note:**
storage-location: erc7201:kam.storage.AdapterGuardianModule


```solidity
struct ProcessRouterModuleStorage {
    mapping(bytes32 => address[]) processIdToTargets;
    mapping(bytes32 => bytes4[]) processIdToSelectors;
}
```

