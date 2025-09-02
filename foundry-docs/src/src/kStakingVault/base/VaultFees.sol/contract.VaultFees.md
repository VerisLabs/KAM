# VaultFees
[Git Source](https://github.com/VerisLabs/KAM/blob/b791d077a3cd28e980c0943d5d7b30be3d8c14e2/src/kStakingVault/base/VaultFees.sol)

**Inherits:**
[BaseVaultModule](/src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.md)

Handles batch operations for staking and unstaking

*Contains batch functions for staking and unstaking operations*


## State Variables
### MAX_BPS
Maximum basis points


```solidity
uint256 constant MAX_BPS = 10_000;
```


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


### _updateGlobalWatermark

Updates the share price watermark

*Updates the high water mark if the current share price exceeds the previous mark*


```solidity
function _updateGlobalWatermark() private;
```

## Events
### ManagementFeeUpdated
Emitted when the management fee is updated


```solidity
event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldFee`|`uint16`|Previous management fee in basis points|
|`newFee`|`uint16`|New management fee in basis points|

### PerformanceFeeUpdated
Emitted when the performance fee is updated


```solidity
event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldFee`|`uint16`|Previous performance fee in basis points|
|`newFee`|`uint16`|New performance fee in basis points|

### FeesAssesed
Emitted when fees are charged to the vault


```solidity
event FeesAssesed(uint256 managementFees, uint256 performanceFees);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`managementFees`|`uint256`|Amount of management fees collected|
|`performanceFees`|`uint256`|Amount of performance fees collected|

### HurdleRateUpdated
Emitted when the hurdle rate is updated


```solidity
event HurdleRateUpdated(uint16 newRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRate`|`uint16`|New hurdle rate in basis points|

### HardHurdleRateUpdated
Emitted when the hard hurdle rate is updated


```solidity
event HardHurdleRateUpdated(bool newRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newRate`|`bool`|New hard hurdle rate in basis points|

### ManagementFeesCharged
Emitted when management fees are charged


```solidity
event ManagementFeesCharged(uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Timestamp of the fee charge|

### PerformanceFeesCharged
Emitted when performance fees are charged


```solidity
event PerformanceFeesCharged(uint256 timestamp);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Timestamp of the fee charge|

