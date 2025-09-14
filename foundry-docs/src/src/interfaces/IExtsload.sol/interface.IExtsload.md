# IExtsload
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/interfaces/IExtsload.sol)

Interface for external storage access


## Functions
### extsload

Reads a single storage slot


```solidity
function extsload(bytes32 slot) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slot`|`bytes32`|Storage slot to read|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Value at the storage slot|


### extsload

Reads multiple consecutive storage slots


```solidity
function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startSlot`|`bytes32`|Starting storage slot|
|`nSlots`|`uint256`|Number of slots to read|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Array of values from the storage slots|


### extsload

Reads multiple arbitrary storage slots


```solidity
function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`slots`|`bytes32[]`|Array of storage slots to read|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Array of values from the storage slots|


