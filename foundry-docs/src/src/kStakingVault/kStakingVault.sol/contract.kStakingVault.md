# kStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/2198994c086118bce5be2d9d0775637d0ef500f3/src/kStakingVault/kStakingVault.sol)

**Inherits:**
Initializable, UUPSUpgradeable, [BaseVaultModule](/src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.md), [MultiFacetProxy](/src/base/MultiFacetProxy.sol/contract.MultiFacetProxy.md)

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
    address registry_,
    address owner_,
    address admin_,
    bool paused_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint128 dustAmount_,
    address emergencyAdmin_,
    address asset_,
    address feeCollector_
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`||
|`owner_`|`address`|Owner address|
|`admin_`|`address`|Admin address|
|`paused_`|`bool`|Initial pause state|
|`name_`|`string`|Token name|
|`symbol_`|`string`|Token symbol|
|`decimals_`|`uint8`|Token decimals|
|`dustAmount_`|`uint128`|Minimum amount threshold|
|`emergencyAdmin_`|`address`|Emergency admin address|
|`asset_`|`address`|Underlying asset address|
|`feeCollector_`|`address`||


### requestStake

Request to stake kTokens for stkTokens (rebase token)


```solidity
function requestStake(
    address to,
    uint256 amount
)
    external
    payable
    nonReentrant
    whenNotPaused
    returns (bytes32 requestId);
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
function requestUnstake(
    address to,
    uint256 stkTokenAmount
)
    external
    payable
    nonReentrant
    whenNotPaused
    returns (bytes32 requestId);
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
function cancelStakeRequest(bytes32 requestId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID to cancel|


### cancelUnstakeRequest

Cancels an unstaking request


```solidity
function cancelUnstakeRequest(bytes32 requestId) external payable nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID to cancel|


### _createStakeRequestId

Creates a unique request ID for a staking request


```solidity
function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32);
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
function setPaused(bool paused_) external onlyRoles(EMERGENCY_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|New pause state|


### calculateStkTokenPrice

Calculates stkToken price with safety checks

*Standard price calculation used across settlement modules*


```solidity
function calculateStkTokenPrice() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|price Price per stkToken in underlying asset terms|


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

Returns the current total assets from adapter (real-time)


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets currently deployed in strategies|


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


### getBatchIdReceiver

Returns the batch receiver for the current batch


```solidity
function getBatchIdReceiver(bytes32 batchId) external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Batch receiver|


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


```solidity
function getSafeBatchReceiver(bytes32 batchId) external view returns (address);
```

### _authorizeUpgrade

Authorize upgrade (only owner can upgrade)

*This allows upgrading the main contract while keeping modules separate*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE);
```

### receive

Accepts ETH transfers


```solidity
receive() external payable;
```

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


