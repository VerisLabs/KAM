# IProcessRouter
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/modules/IProcessRouter.sol)

SPDX-License-Identifier: MIT


## Functions
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
function getfunctionSelector(string memory functionSignature) external view returns (bytes4 selector);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`functionSignature`|`string`|The function signature to get the selector for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The selector for the function signature|


