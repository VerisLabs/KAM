# kStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/670f05acf8766190fcaa1d272341611f065917de/src/kStakingVault/kStakingVault.sol)

**Inherits:**
[Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [Ownable](/src/vendor/Ownable.sol/abstract.Ownable.md), [BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md), [MultiFacetProxy](/src/base/MultiFacetProxy.sol/abstract.MultiFacetProxy.md)

Pure ERC20 vault with dual accounting for minter and user pools

*Implements automatic yield distribution from minter to user pools with modular architecture*


## Functions
### constructor

Disables initializers to prevent implementation contract initialization


```solidity
constructor();
```

### initialize

Initializes the kStakingVault contract (stack optimized)

*Phase 1: Core initialization without strings to avoid stack too deep*


```solidity
function initialize(
    address owner_,
    address registry_,
    bool paused_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    address asset_
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`||
|`registry_`|`address`|The registry address|
|`paused_`|`bool`|If the vault is paused_|
|`name_`|`string`|Token name|
|`symbol_`|`string`|Token symbol|
|`decimals_`|`uint8`|Token decimals|
|`asset_`|`address`|Underlying asset address|


### requestStake

Request to stake kTokens for stkTokens (rebase token)


```solidity
function requestStake(address to, uint256 amount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to receive the stkTokens|
|`amount`|`uint256`|Amount of kTokens to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID for this staking request|


### requestUnstake

Request to unstake stkTokens for kTokens + yield

*Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)*


```solidity
function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`||
|`stkTokenAmount`|`uint256`|Amount of stkTokens to unstake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID for this unstaking request|


### cancelStakeRequest

Cancels a staking request


```solidity
function cancelStakeRequest(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID to cancel|


### cancelUnstakeRequest

Cancels an unstaking request


```solidity
function cancelUnstakeRequest(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID to cancel|


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


### _checkPaused

Checks if the vault is paused

*Only callable by RELAYER_ROLE*


```solidity
function _checkPaused(BaseVaultStorage storage $) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`BaseVaultStorage`|Storage pointer|


### _checkAmountNotZero

Checks if the amount is not zero


```solidity
function _checkAmountNotZero(uint256 amount) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to check|


### _checkValidBPS

Checks if the bps is valid


```solidity
function _checkValidBPS(uint256 bps) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bps`|`uint256`|BPS to check|


### _checkRelayer

*Only callable by RELAYER_ROLE*


```solidity
function _checkRelayer(address relayer) internal view;
```

### _checkRouter

*Only callable by kAssetRouter*


```solidity
function _checkRouter(address router) internal view;
```

### _checkAdmin

*Only callable by ADMIN_ROLE*


```solidity
function _checkAdmin(address admin) internal view;
```

### _validateTimestamp

*Validate timestamp*


```solidity
function _validateTimestamp(uint256 timestamp, uint256 lastTimestamp) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|Timestamp to validate|
|`lastTimestamp`|`uint256`|Last timestamp to validate|


### claimStakedShares

Claims stkTokens from a settled staking batch


```solidity
function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Batch ID to claim from|
|`requestId`|`bytes32`|Request ID to claim|


### claimUnstakedAssets

Claims kTokens from a settled unstaking batch (simplified implementation)


```solidity
function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Batch ID to claim from|
|`requestId`|`bytes32`|Request ID to claim|


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

### _createStakeRequestId

Creates a unique request ID for a staking request


```solidity
function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) private returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|
|`amount`|`uint256`|Amount of underlying assets|
|`timestamp`|`uint256`|Timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Request ID|


### setPaused

Sets the pause state of the contract

*Only callable internally by inheriting contracts*


```solidity
function setPaused(bool paused_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|New pause state|


### _authorizeUpgrade

Authorize upgrade (only owner can upgrade)

*This allows upgrading the main contract while keeping modules separate*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```

### _authorizeModifyFunctions

Authorize function modification

*This allows modifying functions while keeping modules separate*


```solidity
function _authorizeModifyFunctions(address sender) internal override;
```

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

### StakingSharesClaimed
Emitted when a user claims staking shares


```solidity
event StakingSharesClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 shares);
```

### UnstakingAssetsClaimed
Emitted when a user claims unstaking assets


```solidity
event UnstakingAssetsClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 assets);
```

### KTokenUnstaked
Emitted when kTokens are unstaked


```solidity
event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
```

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

