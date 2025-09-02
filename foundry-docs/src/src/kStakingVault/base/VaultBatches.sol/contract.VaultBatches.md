# VaultBatches
[Git Source](https://github.com/VerisLabs/KAM/blob/b791d077a3cd28e980c0943d5d7b30be3d8c14e2/src/kStakingVault/base/VaultBatches.sol)

**Inherits:**
[BaseVaultModule](/src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.md)

Handles batch operations for staking and unstaking

*Contains batch functions for staking and unstaking operations*


## Functions
### createNewBatch

Creates a new batch for processing requests

*Only callable by RELAYER_ROLE, typically called at batch intervals*


```solidity
function createNewBatch() external returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The new batch ID|


### closeBatch

Closes a batch to prevent new requests

*Only callable by RELAYER_ROLE, typically called at cutoff time*


```solidity
function closeBatch(bytes32 _batchId, bool _create) external;
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
function settleBatch(bytes32 _batchId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID to settle|


### createBatchReceiver

Deploys BatchReceiver for specific batch

*Only callable by kAssetRouter*


```solidity
function createBatchReceiver(bytes32 _batchId) external nonReentrant returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|Batch ID to deploy receiver for|


### _createNewBatch


```solidity
function _createNewBatch() internal returns (bytes32);
```

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

