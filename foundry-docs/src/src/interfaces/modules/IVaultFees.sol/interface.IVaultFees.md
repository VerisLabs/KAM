# IVaultFees
[Git Source](https://github.com/VerisLabs/KAM/blob/7fe450d42e02311faf605d62cd48b6af1b05e41f/src/interfaces/modules/IVaultFees.sol)


## Functions
### setHurdleRate

Sets the yearly hurdle rate for the underlying asset

*Fee is a basis point (1% = 100)*


```solidity
function setHurdleRate(uint16 _hurdleRate) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_hurdleRate`|`uint16`|The new yearly hurdle rate|


### setHardHurdleRate

Sets the hard hurdle rate

*If true, performance fees will only be charged to the excess return*


```solidity
function setHardHurdleRate(bool _isHard) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_isHard`|`bool`|Whether the hard hurdle rate is enabled|


### setManagementFee

Sets the management fee

*Fee is a basis point (1% = 100)*


```solidity
function setManagementFee(uint16 _managementFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_managementFee`|`uint16`|The new management fee|


### setPerformanceFee

Sets the performance fee

*Fee is a basis point (1% = 100)*


```solidity
function setPerformanceFee(uint16 _performanceFee) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_performanceFee`|`uint16`|The new performance fee|


### notifyManagementFeesCharged

Notifies the module that management fees have been charged from backend

*Should only be called by the vault*


```solidity
function notifyManagementFeesCharged(uint64 _timestamp) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint64`|The timestamp of the fee charge|


### notifyPerformanceFeesCharged

Notifies the module that performance fees have been charged from backend

*Should only be called by the vault*


```solidity
function notifyPerformanceFeesCharged(uint64 _timestamp) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_timestamp`|`uint64`|The timestamp of the fee charge|


### computeLastBatchFees

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
function lastFeesChargedManagement() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|lastFeesChargedManagement Timestamp of last management fee charge|


### lastFeesChargedPerformance

Returns the last time performance fees were charged


```solidity
function lastFeesChargedPerformance() external view returns (uint256);
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


### feeReceiver

Returns the address that receives collected fees


```solidity
function feeReceiver() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The fee receiver address|


### sharePriceWatermark

Returns the high watermark for share price used in performance fee calculations


```solidity
function sharePriceWatermark() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The share price watermark value|


