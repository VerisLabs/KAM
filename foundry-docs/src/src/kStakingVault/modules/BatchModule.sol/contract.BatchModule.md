# BatchModule
[Git Source](https://github.com/VerisLabs/KAM/blob/2198994c086118bce5be2d9d0775637d0ef500f3/src/kStakingVault/modules/BatchModule.sol)

**Inherits:**
[BaseVaultModule](/src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.md)

Handles batch operations for staking and unstaking

*Contains batch functions for staking and unstaking operations*


## Functions
### createNewBatch

Creates a new batch for processing requests

*Only callable by RELAYER_ROLE, typically called at batch intervals*


```solidity
function createNewBatch() external onlyRelayer returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The new batch ID|


### closeBatch

*Only callable by RELAYER_ROLE, typically called at cutoff time*


```solidity
function closeBatch(bytes32 _batchId, bool _create) external onlyRelayer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID to close|
|`_create`|`bool`||


### settleBatch

Marks a batch as settled

*Only callable by kMinter, indicates assets have been distributed*


```solidity
function settleBatch(bytes32 _batchId) external onlyKAssetRouter;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID to settle|


### createBatchReceiver

Deploys BatchReceiver for specific batch

*Only callable by kAssetRouter*


```solidity
function createBatchReceiver(bytes32 _batchId) external onlyKAssetRouter returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|Batch ID to deploy receiver for|


### _newBatch


```solidity
function _newBatch() internal returns (bytes32);
```

### selectors

Returns the selectors for functions in this module


```solidity
function selectors() external pure returns (bytes4[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4[]`|selectors Array of function selectors|


## Events
### BatchCreated

```solidity
event BatchCreated(bytes32 indexed batchId);
```

### BatchReceiverDeployed

```solidity
event BatchReceiverDeployed(bytes32 indexed batchId, address indexed receiver);
```

### BatchSettled

```solidity
event BatchSettled(bytes32 indexed batchId);
```

### BatchClosed

```solidity
event BatchClosed(bytes32 indexed batchId);
```

### BatchReceiverSet

```solidity
event BatchReceiverSet(address indexed batchReceiver, bytes32 indexed batchId);
```

### BatchReceiverCreated

```solidity
event BatchReceiverCreated(address indexed receiver, bytes32 indexed batchId);
```

