# ReaderModule
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/kStakingVault/modules/ReaderModule.sol)

**Inherits:**
[BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md), [Extsload](/src/abstracts/Extsload.sol/abstract.Extsload.md)

Contains all the public getters for the Staking Vault


## State Variables
### MANAGEMENT_FEE_INTERVAL
Interval for management fee (1 month)


```solidity
uint256 constant MANAGEMENT_FEE_INTERVAL = 657_436;
```


### PERFORMANCE_FEE_INTERVAL
Interval for performance fee (3 months)


```solidity
uint256 constant PERFORMANCE_FEE_INTERVAL = 7_889_238;
```


### MAX_BPS
Maximum basis points


```solidity
uint256 constant MAX_BPS = 10_000;
```


### SECS_PER_YEAR
Number of seconds in a year


```solidity
uint256 constant SECS_PER_YEAR = 31_556_952;
```


## Functions
### registry

GENERAL


```solidity
function registry() external view returns (address);
```

### asset

Returns the underlying asset address (for compatibility)


```solidity
function asset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Asset address|


### underlyingAsset

Returns the underlying asset address


```solidity
function underlyingAsset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Asset address|


### computeLastBatchFees

FEES

Computes the last fee batch


```solidity
function computeLastBatchFees()
    external
    view
    returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`managementFees`|`uint256`|The management fees for the last batch|
|`performanceFees`|`uint256`|The performance fees for the last batch|
|`totalFees`|`uint256`|The total fees for the last batch|


### lastFeesChargedManagement

Returns the last time management fees were charged


```solidity
function lastFeesChargedManagement() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|lastFeesChargedManagement Timestamp of last management fee charge|


### lastFeesChargedPerformance

Returns the last time performance fees were charged


```solidity
function lastFeesChargedPerformance() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|lastFeesChargedPerformance Timestamp of last performance fee charge|


### hurdleRate

Returns the current hurdle rate used for performance fee calculations


```solidity
function hurdleRate() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The hurdle rate in basis points (e.g., 500 = 5%)|


### performanceFee

Returns the current performance fee percentage


```solidity
function performanceFee() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The performance fee in basis points (e.g., 2000 = 20%)|


### nextPerformanceFeeTimestamp

Returns the next performance fee timestamp so the backend can schedule the fee collection


```solidity
function nextPerformanceFeeTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The next performance fee timestamp|


### nextManagementFeeTimestamp

Returns the next management fee timestamp so the backend can schedule the fee collection


```solidity
function nextManagementFeeTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The next management fee timestamp|


### managementFee

Returns the current management fee percentage


```solidity
function managementFee() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The management fee in basis points (e.g., 100 = 1%)|


### sharePriceWatermark

Returns the high watermark for share price used in performance fee calculations


```solidity
function sharePriceWatermark() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The share price watermark value|


### isBatchClosed

Returns whether the current batch is closed


```solidity
function isBatchClosed() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the current batch is closed|


### isBatchSettled

Returns whether the current batch is settled


```solidity
function isBatchSettled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the current batch is settled|


### getBatchIdInfo

Returns the current batch ID, whether it is closed, and whether it is settled


```solidity
function getBatchIdInfo()
    external
    view
    returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Current batch ID|
|`batchReceiver`|`address`|Current batch receiver|
|`isClosed`|`bool`|Whether the current batch is closed|
|`isSettled`|`bool`|Whether the current batch is settled|


### getBatchReceiver

Returns the batch receiver for a given batch (alias for getBatchIdReceiver)


```solidity
function getBatchReceiver(bytes32 batchId) external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Batch receiver|


### getSafeBatchReceiver

Returns the batch receiver for a given batch (alias for getBatchIdReceiver)

*Throws if the batch is settled*


```solidity
function getSafeBatchReceiver(bytes32 batchId) external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Batch receiver|


### sharePrice

Calculates the price of stkTokens in underlying asset terms

*Uses the last total assets and total supply to calculate the price*


```solidity
function sharePrice() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price Price per stkToken in underlying asset terms|


### totalAssets

Returns the current total assets


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets currently deployed in strategies|


### totalNetAssets

Returns the current total assets after fees


```solidity
function totalNetAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total net assets currently deployed in strategies|


### getBatchId

Returns the current batch


```solidity
function getBatchId() public view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Batch|


### getSafeBatchId

Returns the safe batch


```solidity
function getSafeBatchId() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Batch|


### contractName

Returns the contract name


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Contract name|


### contractVersion

Returns the contract version


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Contract version|


### selectors

Returns the selectors for functions in this module


```solidity
function selectors() public pure returns (bytes4[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4[]`|selectors Array of function selectors|


