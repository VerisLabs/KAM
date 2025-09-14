# kMinter
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/kMinter.sol)

**Inherits:**
[IkMinter](/src/interfaces/IkMinter.sol/interface.IkMinter.md), [Initializable](/src/vendor/solady/utils/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/solady/utils/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [kBase](/src/base/kBase.sol/contract.kBase.md), [Extsload](/src/vendor/uniswap/Extsload.sol/abstract.Extsload.md)

Institutional gateway for kToken minting and redemption with batch settlement processing

*This contract serves as the primary interface for qualified institutions to interact with the KAM protocol,
enabling them to mint kTokens by depositing underlying assets and burn them through a sophisticated batch
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


### requestBurn

Initiates a two-phase institutional redemption by creating a batch request for underlying asset
withdrawal

*This function implements the first phase of the redemption process for qualified institutions. The workflow
consists of: (1) transferring kTokens from the caller to this contract for escrow (not burned yet), (2)
generating
a unique request ID for tracking, (3) creating a BurnRequest struct with PENDING status, (4) registering the
request with kAssetRouter for batch processing. The kTokens remain in escrow until the batch is settled and the
user calls burn() to complete the process. This two-phase approach is necessary because redemptions are
processed
in batches through the DN vault system, which requires waiting for batch settlement to ensure proper asset
availability and yield distribution. The request can be cancelled before batch closure/settlement.*


```solidity
function requestBurn(address asset_, address to_, uint256 amount_) external payable returns (bytes32 requestId);
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


### burn

Completes the second phase of institutional redemption by executing a settled batch request

*This function finalizes the redemption process initiated by requestBurn(). It can only be called after
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
function burn(bytes32 requestId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the redemption request to execute (obtained from requestBurn)|


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
|`requestId`|`bytes32`|The unique identifier of the redemption request to cancel (obtained from requestBurn)|


### createNewBatch

Creates a new batch for a specific asset


```solidity
function createNewBatch(address asset_) external returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset for which to create a new batch|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The batch ID of the newly created batch|


### closeBatch

Closes a specific batch and optionally creates a new one


```solidity
function closeBatch(bytes32 _batchId, bool _create) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID to close|
|`_create`|`bool`|Whether to create a new batch for the same asset|


### settleBatch

Settles a closed batch (unchanged functionality)


```solidity
function settleBatch(bytes32 _batchId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID to settle|


### createBatchReceiver

Creates a batch receiver contract for a specific batch


```solidity
function createBatchReceiver(bytes32 _batchId) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch ID to create a receiver for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the created batch receiver|


### _createBatchReceiver

Creates a batch receiver for the specified batch (unchanged functionality)


```solidity
function _createBatchReceiver(bytes32 _batchId) internal returns (address);
```

### _createNewBatch

Internal function to create deterministic batch IDs with collision resistance per asset

*This function generates unique batch identifiers per asset using multiple entropy sources for security.
The ID generation process: (1) Increments asset-specific batch counter to ensure uniqueness within the vault
per asset, (2) Combines vault address, asset-specific batch number, chain ID, timestamp, and asset address
for collision resistance, (3) Uses optimized hashing function for gas efficiency, (4) Initializes batch
storage with default state for new requests. The deterministic approach enables consistent batch identification
across different contexts while the multiple entropy sources prevent prediction or collision attacks. Each
batch starts in open state ready to accept user requests until explicitly closed by relayers.*


```solidity
function _createNewBatch(address asset_) private returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset for which to create a new batch|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|newBatchId Deterministic batch identifier for the newly created batch period for the specific asset|


### getBatchId

Get the current active batch ID for a specific asset


```solidity
function getBatchId(address asset_) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The current batch ID for the asset, or bytes32(0) if no batch exists|


### _currentBatchId

Get the current active batch ID for a specific asset


```solidity
function _currentBatchId(address asset_) internal view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The current batch ID for the asset, or bytes32(0) if no batch exists|


### _checkBatchId

Checks if a batch exists for a specific asset


```solidity
function _checkBatchId(address asset_) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to check|


### getCurrentBatchNumber

Get the current batch number for a specific asset


```solidity
function getCurrentBatchNumber(address asset_) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current batch number for the asset|


### hasActiveBatch

Check if an asset has an active (open) batch


```solidity
function hasActiveBatch(address asset_) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to check|


### getBatchInfo

Get batch info for a specific batch ID


```solidity
function getBatchInfo(bytes32 batchId_) external view returns (IkMinter.BatchInfo memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId_`|`bytes32`|The batch ID to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IkMinter.BatchInfo`|The batch information|


### getBatchReceiver

Gets the batch receiver address for a specific batch


```solidity
function getBatchReceiver(bytes32 batchId_) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId_`|`bytes32`|The batch ID to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the batch receiver|


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


### _checkRelayer

Check if caller is a relayer


```solidity
function _checkRelayer(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkRouter

Check if caller is the AssetRouter


```solidity
function _checkRouter(address user) private view;
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


### _createBurnRequestId

Generates a request ID


```solidity
function _createBurnRequestId(address user, uint256 amount, uint256 timestamp) private returns (bytes32);
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


### getBurnRequest

Retrieves details of a specific redemption request

*Returns the complete BurnRequest struct containing all request information*


```solidity
function getBurnRequest(bytes32 requestId) external view returns (BurnRequest memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`BurnRequest`|The complete BurnRequest struct with status, amounts, and batch information|


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

Returns the human-readable name identifier for this contract type

*Used for contract identification and logging purposes. The name should be consistent
across all versions of the same contract type. This enables external systems and other
contracts to identify the contract's purpose and role within the protocol ecosystem.*


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract name as a string (e.g., "kMinter", "kAssetRouter", "kRegistry")|


### contractVersion

Returns the version identifier for this contract implementation

*Used for upgrade management and compatibility checking within the protocol. The version
string should follow semantic versioning (e.g., "1.0.0") to clearly indicate major, minor,
and patch updates. This enables the protocol governance and monitoring systems to track
deployed versions and ensure compatibility between interacting components.*


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract version as a string following semantic versioning (e.g., "1.0.0")|


## Structs
### kMinterStorage
Core storage structure for kMinter using ERC-7201 namespaced storage pattern

*This structure manages all state for institutional minting and redemption operations.
Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.*

**Note:**
storage-location: erc7201:kam.storage.kMinter


```solidity
struct kMinterStorage {
    uint64 requestCounter;
    address receiverImplementation;
    mapping(bytes32 => uint256) mintedInBatch;
    mapping(bytes32 => uint256) burnedInBatch;
    mapping(address => uint256) totalLockedAssets;
    mapping(bytes32 => BurnRequest) burnRequests;
    mapping(address => OptimizedBytes32EnumerableSetLib.Bytes32Set) userRequests;
    mapping(address => uint256) assetBatchCounters;
    mapping(address => bytes32) currentBatchIds;
    mapping(bytes32 => IkMinter.BatchInfo) batches;
}
```

