# IVaultBatch
[Git Source](https://github.com/VerisLabs/KAM/blob/77168a37e8e40e14b0fd1320a6e90f9203339144/src/interfaces/modules/IVaultBatch.sol)


## Functions
### createNewBatch

Creates a new batch for processing requests

*Only callable by RELAYER_ROLE, typically called at batch intervals*


```solidity
function createNewBatch() external;
```

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
function createBatchReceiver(bytes32 _batchId) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|Batch ID to deploy receiver for|


