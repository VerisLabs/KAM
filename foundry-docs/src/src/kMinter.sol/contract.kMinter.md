# kMinter
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/kMinter.sol)

**Inherits:**
[IkMinter](/src/interfaces/IkMinter.sol/interface.IkMinter.md), [Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [kBase](/src/base/kBase.sol/contract.kBase.md), [Extsload](/src/abstracts/Extsload.sol/abstract.Extsload.md)

Institutional gateway for kToken minting and redemption with batch settlement processing

*This contract serves as the primary interface for qualified institutions to interact with the KAM protocol,
enabling them to mint kTokens by depositing underlying assets and redeem them through a sophisticated batch
settlement system. Key features include: (1) Immediate 1:1 kToken minting upon asset deposit, bypassing the
share-based accounting used for retail users, (2) Two-phase redemption process that handles requests through
batch settlements to optimize gas costs and maintain protocol efficiency, (3) Integration with kStakingVault
for yield generation on deposited assets, (4) Request tracking and management system with unique IDs for each
redemption, (5) Cancellation mechanism for pending requests before batch closure. The contract enforces strict
access control, ensuring only verified institutions can access these privileged operations while maintaining
the security and integrity of the protocol's asset backing.*


## State Variables
### KMINTER_STORAGE_LOCATION

```solidity
bytes32 private constant KMINTER_STORAGE_LOCATION = 0xd0574379115d2b8497bfd9020aa9e0becaffc59e5509520aa5fe8c763e40d000;
```


## Functions
### _getkMinterStorage

Retrieves the kMinter storage struct from its designated storage slot

*Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
storage variables in future upgrades without affecting existing storage layout.*


```solidity
function _getkMinterStorage() private pure returns (kMinterStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`kMinterStorage`|The kMinterStorage struct reference for state modifications|


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

Executes institutional minting of kTokens through immediate 1:1 issuance against deposited assets

*This function enables qualified institutions to mint kTokens by depositing underlying assets. The process
involves: (1) transferring assets from the caller to kAssetRouter, (2) pushing assets into the current batch
of the designated DN vault for yield generation, and (3) immediately minting an equivalent amount of kTokens
to the recipient. Unlike retail operations, institutional mints bypass share-based accounting and provide
immediate token issuance without waiting for batch settlement. The deposited assets are tracked separately
to maintain the 1:1 backing ratio and will participate in vault yield strategies through the batch system.*


```solidity
function mint(address asset_, address to_, uint256 amount_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`||
|`to_`|`address`||
|`amount_`|`uint256`||


### requestRedeem

Initiates a two-phase institutional redemption by creating a batch request for underlying asset
withdrawal

*This function implements the first phase of the redemption process for qualified institutions. The workflow
consists of: (1) transferring kTokens from the caller to this contract for escrow (not burned yet), (2)
generating
a unique request ID for tracking, (3) creating a RedeemRequest struct with PENDING status, (4) registering the
request with kAssetRouter for batch processing. The kTokens remain in escrow until the batch is settled and the
user calls redeem() to complete the process. This two-phase approach is necessary because redemptions are
processed
in batches through the DN vault system, which requires waiting for batch settlement to ensure proper asset
availability and yield distribution. The request can be cancelled before batch closure/settlement.*


```solidity
function requestRedeem(address asset_, address to_, uint256 amount_) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`||
|`to_`|`address`||
|`amount_`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|A unique bytes32 identifier for tracking and executing this redemption request|


### redeem

Completes the second phase of institutional redemption by executing a settled batch request

*This function finalizes the redemption process initiated by requestRedeem(). It can only be called after
the batch containing this request has been settled through the kAssetRouter settlement process. The execution
involves: (1) validating the request exists and is in PENDING status, (2) updating the request status to
REDEEMED,
(3) removing the request from tracking, (4) burning the escrowed kTokens permanently, (5) instructing the
kBatchReceiver contract to transfer the underlying assets to the recipient. The kBatchReceiver is a minimal
proxy
deployed per batch that holds the settled assets and ensures isolated distribution. This function will revert if
the batch is not yet settled, ensuring assets are only distributed when available. The separation between
request
and redemption phases allows for efficient batch processing of multiple redemptions while maintaining asset
safety.*


```solidity
function redeem(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the redemption request to execute (obtained from requestRedeem)|


### cancelRequest

Cancels a pending redemption request and returns the escrowed kTokens to the user

*This function allows institutions to cancel their redemption requests before the batch is closed or
settled.
The cancellation process involves: (1) validating the request exists and is in PENDING status, (2) checking that
the batch is neither closed nor settled (once closed, cancellation is not possible as the batch is being
processed),
(3) updating the request status to CANCELLED, (4) removing the request from tracking, (5) returning the escrowed
kTokens back to the original requester. This mechanism provides flexibility for institutions to manage their
liquidity needs, allowing them to reverse redemption decisions if market conditions change or if they need
immediate
access to their kTokens. The function enforces strict timing constraints - cancellation is only permitted while
the
batch remains open, ensuring batch integrity and preventing manipulation of settled redemptions.*


```solidity
function cancelRequest(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the redemption request to cancel (obtained from requestRedeem)|


### _checkNotPaused

Check if contract is not paused


```solidity
function _checkNotPaused() private view;
```

### _checkInstitution

Check if caller is an institution


```solidity
function _checkInstitution(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkAdmin

Check if caller is an admin


```solidity
function _checkAdmin(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkValidAsset

Check if asset is valid/supported


```solidity
function _checkValidAsset(address asset) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address to check|


### _checkAmountNotZero

Check if amount is not zero


```solidity
function _checkAmountNotZero(uint256 amount) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|Amount to check|


### _checkAddressNotZero

Check if address is not zero


```solidity
function _checkAddressNotZero(address addr) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|Address to check|


### _createRedeemRequestId

Generates a request ID


```solidity
function _createRedeemRequestId(address user, uint256 amount, uint256 timestamp) private returns (bytes32);
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

Emergency admin function to recover stuck assets from a batch receiver contract

*This function provides a recovery mechanism for assets that may become stuck in kBatchReceiver contracts
due to failed redemptions or system errors. The process involves two steps: (1) calling rescueAssets on the
kBatchReceiver to transfer assets back to this contract, and (2) using the inherited rescueAssets function
from kBase to forward them to the specified destination. This two-step process ensures proper access control
and maintains the security model where only authorized contracts can interact with batch receivers. This
function should only be used in emergency situations and requires admin privileges to prevent abuse.*


```solidity
function rescueReceiverAssets(address batchReceiver, address asset_, address to_, uint256 amount_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchReceiver`|`address`|The address of the kBatchReceiver contract holding the stuck assets|
|`asset_`|`address`||
|`to_`|`address`||
|`amount_`|`uint256`||


### isPaused

Checks if the contract is currently paused

*Returns the paused state from the base storage for operational control*


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused, false otherwise|


### getRedeemRequest

Retrieves details of a specific redemption request

*Returns the complete RedeemRequest struct containing all request information*


```solidity
function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`RedeemRequest`|The complete RedeemRequest struct with status, amounts, and batch information|


### getUserRequests

Gets all redemption request IDs for a specific user

*Returns request IDs from the user's enumerable set for efficient tracking*


```solidity
function getUserRequests(address user) external view returns (bytes32[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The user address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32[]`|Array of request IDs belonging to the user|


### getRequestCounter

Gets the current request counter value

*Returns the monotonically increasing counter used for generating unique request IDs*


```solidity
function getRequestCounter() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current counter used for generating unique request IDs|


### getTotalLockedAssets

Gets the total locked assets for a specific asset

*Returns the cumulative amount of assets deposited through mint operations for accounting*


```solidity
function getTotalLockedAssets(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount of assets locked in the protocol|


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
Core storage structure for kMinter using ERC-7201 namespaced storage pattern

*This structure manages all state for institutional minting and redemption operations.
Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.*

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

