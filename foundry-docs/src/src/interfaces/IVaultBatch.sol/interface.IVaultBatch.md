# IVaultBatch
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/interfaces/IVaultBatch.sol)

Interface for batch lifecycle management enabling gas-efficient settlement of multiple user operations

*This interface defines the batch processing system that aggregates individual staking/unstaking requests
for efficient settlement. The batch lifecycle consists of three distinct phases: (1) Open Phase: New requests
can be added to the current batch, enabling users to join the settlement period, (2) Closed Phase: No new
requests accepted, batch is prepared for settlement with final share price calculations, (3) Settled Phase:
Assets distributed and share prices fixed, users can claim their rewards/redemptions. This system provides
several key benefits: gas cost optimization through bulk processing, fair pricing through synchronized settlement,
coordination with kAssetRouter for cross-vault yield distribution, and minimal proxy deployment for isolated
asset distribution. The batch system is critical for maintaining protocol scalability while ensuring equitable
treatment of all participants within each settlement period.*


## Functions
### createNewBatch

Creates a new batch to begin aggregating user requests for the next settlement period

*This function initializes a fresh batch period for collecting staking and unstaking requests. Process:
(1) Increments internal batch counter for unique identification, (2) Generates deterministic batch ID using
chain-specific parameters (vault address, batch number, chainid, timestamp, asset) for collision resistance,
(3) Initializes batch storage with open state enabling new request acceptance, (4) Updates vault's current
batch tracking for request routing. Only relayers can call this function as part of the automated settlement
schedule. The timing is typically coordinated with institutional settlement cycles to optimize capital
efficiency
across the protocol. Each batch remains open until explicitly closed by relayers or governance.*


```solidity
function createNewBatch() external returns (bytes32 batchId);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Unique deterministic identifier for the newly created batch period|


### closeBatch

Closes a batch to prevent new requests and prepare for settlement processing

*This function transitions a batch from open to closed state, finalizing the request set for settlement.
Process: (1) Validates batch exists and is currently open to prevent double-closing, (2) Marks batch as closed
preventing new stake/unstake requests from joining, (3) Optionally creates new batch for continued operations
if _create flag is true, enabling seamless transitions. Once closed, the batch awaits settlement by kAssetRouter
which will calculate final share prices and distribute yields. Only relayers can execute batch closure as part
of the coordinated settlement schedule across all protocol vaults. The timing typically aligns with DN vault
yield calculations to ensure accurate price discovery.*


```solidity
function closeBatch(bytes32 _batchId, bool _create) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The specific batch identifier to close (must be currently open)|
|`_create`|`bool`|Whether to immediately create a new batch after closing for continued operations|


### settleBatch

Marks a batch as settled after yield distribution and enables user claiming

*This function finalizes batch settlement by recording final asset values and enabling claims. Process:
(1) Validates batch is closed and not already settled to prevent duplicate processing, (2) Snapshots both
gross and net share prices at settlement time for accurate reward calculations, (3) Marks batch as settled
enabling users to claim their staked shares or unstaked assets, (4) Completes the batch lifecycle allowing
reward distribution through the claiming mechanism. Only kAssetRouter can settle batches as it coordinates
yield calculations across DN vaults and manages cross-vault asset flows. Settlement triggers share price
finalization based on vault performance during the batch period.*


```solidity
function settleBatch(bytes32 _batchId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch identifier to mark as settled (must be closed, not previously settled)|


### createBatchReceiver

Deploys a minimal proxy BatchReceiver for isolated asset distribution to unstaking users

*This function creates batch-specific receivers for secure unstaking asset distribution. Process:
(1) Checks if receiver already exists for batch to prevent duplicate deployments, (2) Clones minimal proxy
from receiver implementation to minimize gas costs while maintaining isolation, (3) Initializes receiver with
batch ID and asset type for proper operation, (4) Stores receiver address in batch info for claiming access.
The receiver pattern provides several benefits: asset isolation between batches preventing cross-contamination,
gas-efficient deployment through EIP-1167 minimal proxies, security through single-batch operation scope,
and simplified distribution logic for unstaking claims. Only kAssetRouter can create receivers as part of
settlement coordination.*


```solidity
function createBatchReceiver(bytes32 _batchId) external returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The batch identifier requiring a receiver for asset distribution|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the deployed BatchReceiver contract for this specific batch|


