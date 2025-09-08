# IkMinter
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/interfaces/IkMinter.sol)

Interface for institutional minting and redemption operations in the KAM protocol

*This interface defines the core functionality for qualified institutions to mint kTokens
by depositing underlying assets and redeem them through a batch settlement system. The interface
supports a two-phase redemption process to accommodate batch processing and yield distribution.*


## Functions
### mint

Executes institutional minting of kTokens through immediate 1:1 issuance against deposited assets

*This function enables qualified institutions to mint kTokens by depositing underlying assets. The process
involves: (1) transferring assets from the caller to kAssetRouter, (2) pushing assets into the current batch
of the designated DN vault for yield generation, and (3) immediately minting an equivalent amount of kTokens
to the recipient. Unlike retail operations, institutional mints bypass share-based accounting and provide
immediate token issuance without waiting for batch settlement. The deposited assets are tracked separately
to maintain the 1:1 backing ratio and will participate in vault yield strategies through the batch system.*


```solidity
function mint(address asset, address to, uint256 amount) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address to deposit (must be registered in the protocol)|
|`to`|`address`|The recipient address that will receive the newly minted kTokens|
|`amount`|`uint256`|The amount of underlying asset to deposit and kTokens to mint (1:1 ratio)|


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
function requestRedeem(address asset, address to, uint256 amount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address to redeem (must match the kToken's underlying asset)|
|`to`|`address`|The recipient address that will receive the underlying assets after batch settlement|
|`amount`|`uint256`|The amount of kTokens to redeem (will receive equivalent underlying assets)|

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


### rescueReceiverAssets

Emergency admin function to recover stuck assets from a batch receiver contract

*This function provides a recovery mechanism for assets that may become stuck in kBatchReceiver contracts
due to failed redemptions or system errors. The process involves two steps: (1) calling rescueAssets on the
kBatchReceiver to transfer assets back to this contract, and (2) using the inherited rescueAssets function
from kBase to forward them to the specified destination. This two-step process ensures proper access control
and maintains the security model where only authorized contracts can interact with batch receivers. This
function should only be used in emergency situations and requires admin privileges to prevent abuse.*


```solidity
function rescueReceiverAssets(address batchReceiver, address asset, address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchReceiver`|`address`|The address of the kBatchReceiver contract holding the stuck assets|
|`asset`|`address`|The address of the asset token to rescue (must not be a protocol asset)|
|`to`|`address`|The destination address to receive the rescued assets|
|`amount`|`uint256`|The amount of assets to rescue|


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


## Events
### ContractInitialized
Emitted when the kMinter contract is initialized


```solidity
event ContractInitialized(address indexed registry);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`address`|The address of the registry contract used for protocol configuration|

### Minted
Emitted when kTokens are successfully minted for an institution


```solidity
event Minted(address indexed to, uint256 amount, bytes32 batchId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address that received the minted kTokens|
|`amount`|`uint256`|The amount of kTokens minted (matches deposited asset amount)|
|`batchId`|`bytes32`|The batch identifier where the deposited assets were allocated|

### RedeemRequestCreated
Emitted when a new redemption request is created and enters the batch queue


```solidity
event RedeemRequestCreated(
    bytes32 indexed requestId,
    address indexed user,
    address indexed kToken,
    uint256 amount,
    address recipient,
    bytes32 batchId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier assigned to this redemption request|
|`user`|`address`|The address that initiated the redemption request|
|`kToken`|`address`|The kToken contract address being redeemed|
|`amount`|`uint256`|The amount of kTokens being redeemed|
|`recipient`|`address`|The address that will receive the underlying assets|
|`batchId`|`bytes32`|The batch identifier this request is associated with|

### Redeemed
Emitted when a redemption request is successfully executed after batch settlement


```solidity
event Redeemed(bytes32 indexed requestId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the executed redemption request|

### Cancelled
Emitted when a pending redemption request is cancelled before batch closure


```solidity
event Cancelled(bytes32 indexed requestId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the cancelled redemption request|

## Structs
### RedeemRequest
Contains all information related to a redemption request

*Stored on-chain to track redemption lifecycle and enable proper asset distribution*


```solidity
struct RedeemRequest {
    address user;
    uint256 amount;
    address asset;
    uint64 requestTimestamp;
    RequestStatus status;
    bytes32 batchId;
    address recipient;
}
```

## Enums
### RequestStatus
Represents the lifecycle status of a redemption request

*Used to track the progression of redemption requests through the batch system*


```solidity
enum RequestStatus {
    PENDING,
    REDEEMED,
    CANCELLED
}
```

