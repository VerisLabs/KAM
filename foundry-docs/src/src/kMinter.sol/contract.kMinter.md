# kMinter
[Git Source](https://github.com/VerisLabs/KAM/blob/bbd875989135c7d3f313fa3fcc61e94d6afb4346/src/kMinter.sol)

**Inherits:**
[IkMinter](/src/interfaces/IkMinter.sol/interface.IkMinter.md), [Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [kBase](/src/base/kBase.sol/contract.kBase.md), [Extsload](/src/abstracts/Extsload.sol/abstract.Extsload.md)

Institutional minting and redemption manager for kTokens

*Manages deposits/redemptions through kStakingVault with batch settlement*


## State Variables
### KMINTER_STORAGE_LOCATION

```solidity
bytes32 private constant KMINTER_STORAGE_LOCATION = 0xd0574379115d2b8497bfd9020aa9e0becaffc59e5509520aa5fe8c763e40d000;
```


## Functions
### _getkMinterStorage


```solidity
function _getkMinterStorage() private pure returns (kMinterStorage storage $);
```

### constructor

Disables initializers to prevent implementation contract initialization


```solidity
constructor();
```

### initialize

Initializes the kMinter contract


```solidity
function initialize(address registry_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the registry contract|


### mint

Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio

*Validates request parameters, transfers assets, deposits to vault, and mints tokens*


```solidity
function mint(address asset_, address to_, uint256 amount_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|Address of the asset to mint|
|`to_`|`address`|Address of the recipient|
|`amount_`|`uint256`|Amount of the asset to mint|


### requestRedeem

Initiates redemption process by burning kTokens and creating batch redemption request

*Burns tokens immediately, generates unique request ID, and adds to batch for settlement*


```solidity
function requestRedeem(address kToken_, address to_, uint256 amount_) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kToken_`|`address`|Address of the asset to redeem|
|`to_`|`address`|Address of the recipient|
|`amount_`|`uint256`|Amount of the asset to redeem|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Unique identifier for tracking this redemption request|


### redeem

Executes redemption for a request in a settled batch


```solidity
function redeem(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID to execute|


### cancelRequest

Cancels a redemption request before batch settlement


```solidity
function cancelRequest(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID to cancel|


### _createRedeemRequestId

Generates a request ID


```solidity
function _createRedeemRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|
|`amount`|`uint256`|Amount|
|`timestamp`|`uint256`|Timestamp|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Request ID|


### rescueReceiverAssets

Rescue assets from batch receiver


```solidity
function rescueReceiverAssets(address batchReceiver, address asset_, address to_, uint256 amount_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchReceiver`|`address`|Batch receiver address|
|`asset_`|`address`|Asset address|
|`to_`|`address`|Destination address|
|`amount_`|`uint256`|Amount|


### isPaused

Check if contract is paused


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused|


### getRedeemRequest

Get a redeem request


```solidity
function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RedeemRequest`|Redeem request|


### getUserRequests

Get all redeem requests for a user


```solidity
function getUserRequests(address user) external view returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|User address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Redeem requests|


### getRequestCounter

Get the request counter


```solidity
function getRequestCounter() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Request counter|


### getTotalLockedAssets

Get total locked assets for a specific asset


```solidity
function getTotalLockedAssets(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total locked assets|


### _authorizeUpgrade

Authorizes contract upgrades

*Only callable by ADMIN_ROLE*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|New implementation address|


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


## Structs
### kMinterStorage
**Note:**
storage-location: erc7201:kam.storage.kMinter


```solidity
struct kMinterStorage {
    mapping(address => uint256) totalLockedAssets;
    uint64 requestCounter;
    mapping(bytes32 => RedeemRequest) redeemRequests;
    mapping(address => OptimizedBytes32EnumerableSetLib.Bytes32Set) userRequests;
}
```

