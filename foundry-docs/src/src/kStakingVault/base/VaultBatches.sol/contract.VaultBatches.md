# VaultBatches
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/kStakingVault/base/VaultBatches.sol)

**Inherits:**
[BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md)

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
|`_create`|`bool`|Whether to create a new batch after closing|


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
function createBatchReceiver(bytes32 _batchId) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|Batch ID to deploy receiver for|


### _createNewBatch

Creates a new batch for processing requests

*Only callable by RELAYER_ROLE, typically called at batch intervals*


```solidity
function _createNewBatch() internal returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The new batch ID|


## Events
### BatchCreated
Emitted when a new batch is created


```solidity
event BatchCreated(bytes32 indexed batchId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The batch ID of the new batch|

### BatchSettled
Emitted when a batch is settled


```solidity
event BatchSettled(bytes32 indexed batchId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The batch ID of the settled batch|

### BatchClosed
Emitted when a batch is closed


```solidity
event BatchClosed(bytes32 indexed batchId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The batch ID of the closed batch|

### BatchReceiverCreated
Emitted when a BatchReceiver is created


```solidity
event BatchReceiverCreated(address indexed receiver, bytes32 indexed batchId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address of the created BatchReceiver|
|`batchId`|`bytes32`|The batch ID of the BatchReceiver|

