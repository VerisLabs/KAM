# kBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/d9f3bcfb40b15ca7c34b1d780c519322be4b7590/src/kBatchReceiver.sol)

**Inherits:**
[IkBatchReceiver](/src/interfaces/IkBatchReceiver.sol/interface.IkBatchReceiver.md)

Minimal proxy contract that holds and distributes settled assets for batch redemptions

*Deployed per batch to isolate asset distribution and enable efficient settlement*


## State Variables
### kMinter

```solidity
address public immutable kMinter;
```


### asset

```solidity
address public asset;
```


### batchId

```solidity
bytes32 public batchId;
```


## Functions
### constructor

Sets the kMinter address immutably

*Sets kMinter as immutable variable*


```solidity
constructor(address _kMinter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_kMinter`|`address`|Address of the kMinter contract (only authorized caller)|


### initialize

Initializes the batch receiver with batch parameters

*Sets batch ID and asset, then emits initialization event*


```solidity
function initialize(bytes32 _batchId, address _asset) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID this receiver serves|
|`_asset`|`address`|Address of the asset contract|


### pullAssets

Transfers assets from kMinter to the specified receiver

*Only callable by kMinter, transfers assets from caller to receiver*


```solidity
function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|Address to receive the assets|
|`amount`|`uint256`|Amount of assets to transfer|
|`_batchId`|`bytes32`|Batch ID for validation (must match this receiver's batch)|


