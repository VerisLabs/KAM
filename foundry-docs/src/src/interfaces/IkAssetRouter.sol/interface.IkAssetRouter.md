# IkAssetRouter
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/IkAssetRouter.sol)

**Inherits:**
[IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

Central money flow coordinator for the KAM protocol managing all asset movements and settlements

*This interface defines the core functionality for kAssetRouter, which serves as the primary coordinator
for all asset movements within the KAM protocol ecosystem. Key responsibilities include: (1) Managing asset
flows from kMinter institutional deposits to DN vaults for yield generation, (2) Coordinating asset transfers
between kStakingVaults for optimal allocation, (3) Processing batch settlements with yield distribution through
kToken minting/burning, (4) Maintaining virtual balance tracking across all vaults, (5) Implementing settlement
cooldown periods for security, (6) Executing peg protection mechanisms during market stress. The router acts as
the central hub that enables efficient capital allocation while maintaining the 1:1 backing guarantee of kTokens
through precise yield distribution and loss management across the protocol's vault network.*


## Functions
### kAssetPush

Pushes assets from kMinter institutional deposits to the designated DN vault for yield generation

*This function is called by kMinter when institutional users deposit underlying assets. The process
involves: (1) receiving assets already transferred from kMinter, (2) forwarding them to the appropriate
DN vault for the asset type, (3) updating virtual balance tracking for accurate accounting. This enables
immediate kToken minting (1:1 with deposits) while assets begin generating yield in the vault system.
The assets enter the current batch for eventual settlement and yield distribution back to kToken holders.*


```solidity
function kAssetPush(address _asset, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The underlying asset address being deposited (must be registered in protocol)|
|`amount`|`uint256`|The quantity of assets being pushed to the vault for yield generation|
|`batchId`|`bytes32`|The current batch identifier from the DN vault for tracking and settlement|


### kAssetRequestPull

Requests asset withdrawal from vault to fulfill institutional redemption through kMinter

*This function initiates the first phase of the institutional redemption process. The workflow
involves: (1) registering the redemption request with the vault, (2) creating a kBatchReceiver minimal
proxy to hold assets for distribution, (3) updating virtual balance accounting, (4) preparing for
batch settlement. The actual asset transfer occurs later during batch settlement when the vault
processes all pending requests together. This two-phase approach optimizes gas costs and ensures
fair settlement across all institutional redemption requests in the batch.*


```solidity
function kAssetRequestPull(address _asset, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The underlying asset address being redeemed|
|`amount`|`uint256`|The quantity of assets requested for redemption|
|`batchId`|`bytes32`|The batch identifier for coordinating this redemption with other requests|


### kAssetTransfer

Transfers assets between kStakingVaults for optimal capital allocation and yield optimization

*This function enables dynamic rebalancing of assets across the vault network to optimize yields
and manage capacity. The transfer is virtual in nature - actual underlying assets may remain in the
same physical vault while accounting balances are updated. This mechanism allows for: (1) moving
assets from lower-yield to higher-yield opportunities, (2) rebalancing vault capacity during high
demand periods, (3) optimizing capital efficiency across the protocol. The batch system ensures
all transfers are processed fairly during settlement periods.*


```solidity
function kAssetTransfer(
    address sourceVault,
    address targetVault,
    address _asset,
    uint256 amount,
    bytes32 batchId
)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The kStakingVault address transferring assets (will lose virtual balance)|
|`targetVault`|`address`|The kStakingVault address receiving assets (will gain virtual balance)|
|`_asset`|`address`|The underlying asset address being transferred between vaults|
|`amount`|`uint256`|The quantity of assets to transfer for rebalancing|
|`batchId`|`bytes32`|The batch identifier for coordinating this transfer with settlement|


### kSharesRequestPush

Requests shares to be pushed for kStakingVault staking operations and batch processing

*This function is part of the share-based accounting system for retail users in kStakingVaults.
When users stake kTokens, the vault requests shares to be pushed to track their ownership. The
process coordinates: (1) conversion of kTokens to vault shares at current share price, (2) updating
user balances in the vault system, (3) preparing for batch settlement. Share requests are batched
to optimize gas costs and ensure fair pricing across all users in the same settlement period.*


```solidity
function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The kStakingVault address requesting share push operations|
|`amount`|`uint256`|The quantity of shares being requested for push to users|
|`batchId`|`bytes32`|The batch identifier for coordinating share operations with settlement|


### kSharesRequestPull

Requests shares to be pulled for kStakingVault redemption operations

*This function handles the share-based redemption process for retail users withdrawing from
kStakingVaults. The process involves: (1) calculating share amounts to redeem based on user
requests, (2) preparing for conversion back to kTokens at settlement time, (3) coordinating
with the batch settlement system for fair pricing. Unlike institutional redemptions through
kMinter, this uses share-based accounting to handle smaller, more frequent retail operations
efficiently through the vault's batch processing system.*


```solidity
function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The kStakingVault address requesting share pull for redemptions|
|`amount`|`uint256`|The quantity of shares being requested for pull from users|
|`batchId`|`bytes32`|The batch identifier for coordinating share redemptions with settlement|


### proposeSettleBatch

Proposes a batch settlement for a vault with yield distribution through kToken minting/burning

*This is the core function that initiates yield distribution in the KAM protocol. The settlement
process involves: (1) calculating final yields after a batch period, (2) determining net new deposits/
redemptions, (3) creating a proposal with cooldown period for security verification, (4) preparing for
kToken supply adjustment to maintain 1:1 backing. Positive yields result in kToken minting (distributing
gains to all holders), while losses result in kToken burning (socializing losses). The cooldown period
allows guardians to verify calculations before execution, ensuring protocol integrity.*


```solidity
function proposeSettleBatch(
    address asset,
    address vault,
    bytes32 batchId,
    uint256 totalAssets,
    uint64 lastFeesChargedManagement,
    uint64 lastFeesChargedPerformance
)
    external
    payable
    returns (bytes32 proposalId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address being settled (USDC, WBTC, etc.)|
|`vault`|`address`|The DN vault address where yield was generated|
|`batchId`|`bytes32`|The batch identifier for this settlement period|
|`totalAssets`|`uint256`|Total asset value in the vault after yield generation/loss|
|`lastFeesChargedManagement`|`uint64`|Last management fees charged|
|`lastFeesChargedPerformance`|`uint64`|Last performance fees charged|


### executeSettleBatch

Executes a settlement proposal after the security cooldown period has elapsed

*This function completes the yield distribution process by: (1) verifying the cooldown period has
passed, (2) executing the actual kToken minting/burning to distribute yield or account for losses,
(3) updating all vault balances and user accounting, (4) processing any pending redemption requests
from the batch. This is where the 1:1 backing is maintained - the kToken supply is adjusted to exactly
reflect the underlying asset changes, ensuring every kToken remains backed by real assets plus distributed
yield.*


```solidity
function executeSettleBatch(bytes32 proposalId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the settlement proposal to execute|


### cancelProposal

Cancels a settlement proposal before execution if errors are detected

*Provides a safety mechanism for guardians to cancel potentially incorrect settlement proposals.
This can be used when: (1) yield calculations appear incorrect, (2) system errors are detected,
(3) market conditions require recalculation. Cancellation allows for proposal correction and
resubmission with accurate data, preventing incorrect yield distribution that could affect the
protocol's 1:1 backing guarantee. Only callable before the proposal execution.*


```solidity
function cancelProposal(bytes32 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the settlement proposal to cancel|


### setSettlementCooldown

Sets the security cooldown period for settlement proposals

*The cooldown period provides critical security by requiring a delay between proposal creation
and execution. This allows: (1) protocol guardians to verify yield calculations, (2) detection of
potential errors or malicious proposals, (3) emergency intervention if needed. The cooldown should
balance security (longer is safer) with operational efficiency (shorter enables faster yield
distribution). Only admin roles can modify this parameter as it affects protocol safety.*


```solidity
function setSettlementCooldown(uint256 cooldown) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cooldown`|`uint256`|The new cooldown period in seconds before settlement proposals can be executed|


### setMaxAllowedDelta

Updates the yield tolerance threshold for settlement proposals

*This function allows protocol governance to adjust the maximum acceptable yield deviation before
settlement proposals are rejected. The yield tolerance acts as a safety mechanism to prevent settlement
proposals with extremely high or low yield values that could indicate calculation errors, data corruption,
or potential manipulation attempts. Setting an appropriate tolerance balances protocol safety with
operational flexibility, allowing normal yield fluctuations while blocking suspicious proposals.
Only admin roles can modify this parameter as it affects protocol safety.*


```solidity
function setMaxAllowedDelta(uint256 tolerance_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tolerance_`|`uint256`|The new yield tolerance in basis points (e.g., 1000 = 10%)|


### getPendingProposals

Retrieves all pending settlement proposals for a specific vault

*Returns proposal IDs that have been created but not yet executed or cancelled.
Used for monitoring and management of the settlement queue. Essential for guardians
to track proposals awaiting verification during the cooldown period.*


```solidity
function getPendingProposals(address vault_) external view returns (bytes32[] memory pendingProposals);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|The vault address to query for pending settlement proposals|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pendingProposals`|`bytes32[]`|Array of proposal IDs currently pending execution|


### getDNVaultByAsset

Gets the DN vault address responsible for yield generation for a specific asset

*Each supported asset (USDC, WBTC, etc.) has a designated DN vault that handles
yield farming strategies. This mapping is critical for routing institutional deposits
and coordinating settlement processes across the protocol's vault network.*


```solidity
function getDNVaultByAsset(address asset) external view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The DN vault address that generates yield for this asset|


### getBatchIdBalances

Retrieves the virtual balance accounting for a specific batch in a vault

*Returns the deposited and requested amounts that are tracked virtually for batch
processing. These balances coordinate institutional flows (kMinter) and retail flows
(kStakingVault) within the same settlement period, ensuring fair processing and accurate
yield distribution across all participants in the batch.*


```solidity
function getBatchIdBalances(
    address vault,
    bytes32 batchId
)
    external
    view
    returns (uint256 deposited, uint256 requested);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to query batch balances for|
|`batchId`|`bytes32`|The batch identifier to retrieve balance information|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`deposited`|`uint256`|Total amount of assets deposited into this batch|
|`requested`|`uint256`|Total amount of assets requested for redemption from this batch|


### getRequestedShares

Retrieves the total shares requested for redemption in a specific vault batch

*Tracks share-based redemption requests from retail users in kStakingVaults.
This is separate from asset-based tracking and enables the protocol to coordinate
both institutional (asset-based) and retail (share-based) operations within the
same batch settlement process, ensuring consistent share price calculations.*


```solidity
function getRequestedShares(address vault, bytes32 batchId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The kStakingVault address to query|
|`batchId`|`bytes32`|The batch identifier for the redemption period|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total amount of shares requested for redemption in this batch|


### isPaused

Checks if the kAssetRouter contract is currently paused

*When paused, all critical functions (asset movements, settlements) are halted
for emergency protection. This affects the entire protocol's money flow coordination,
preventing new deposits, redemptions, and yield distributions until unpaused.*


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the contract is paused and operations are halted|


### getSettlementProposal

Retrieves complete details of a specific settlement proposal

*Returns the full VaultSettlementProposal struct containing all parameters needed
for yield distribution verification. Essential for guardians to review proposal accuracy
during the cooldown period before execution. Contains asset amounts, yield calculations,
and timing information for comprehensive proposal analysis.*


```solidity
function getSettlementProposal(bytes32 proposalId) external view returns (VaultSettlementProposal memory proposal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the settlement proposal to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposal`|`VaultSettlementProposal`|The complete settlement proposal struct with all details|


### canExecuteProposal

Checks if a settlement proposal is ready for execution with detailed status

*Validates all execution requirements: (1) proposal exists and is pending, (2) cooldown
period has elapsed, (3) proposal hasn't been cancelled. Returns both boolean result and
human-readable reason for failures, enabling better error handling and user feedback.*


```solidity
function canExecuteProposal(bytes32 proposalId) external view returns (bool canExecute, string memory reason);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the proposal to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`canExecute`|`bool`|True if the proposal can be executed immediately|
|`reason`|`string`|Descriptive message explaining why execution is blocked (if applicable)|


### getSettlementCooldown

Gets the current security cooldown period for settlement proposals

*The cooldown period determines how long proposals must wait before execution.
This security mechanism allows guardians to verify yield calculations and prevents
immediate execution of potentially malicious or incorrect proposals. Critical for
maintaining protocol integrity during yield distribution processes.*


```solidity
function getSettlementCooldown() external view returns (uint256 cooldown);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`cooldown`|`uint256`|The current cooldown period in seconds|


### getMaxAllowedDelta

Gets the current yield tolerance threshold for settlement proposals

*The yield tolerance determines the maximum acceptable yield deviation before settlement proposals
are automatically rejected. This acts as a safety mechanism to prevent processing of settlement proposals
with excessive yield values that could indicate calculation errors or potential manipulation. The tolerance
is expressed in basis points where 10000 equals 100%.*


```solidity
function getMaxAllowedDelta() external view returns (uint256 tolerance);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tolerance`|`uint256`|The current yield tolerance in basis points|


### virtualBalance

Retrieves the virtual balance of assets for a vault across all its adapters

*This function aggregates asset balances across all adapters connected to a vault to determine
the total virtual balance available for operations. Essential for coordination between physical
asset locations and protocol accounting. Used for settlement calculations and ensuring sufficient
assets are available for redemptions and transfers within the money flow system.*


```solidity
function virtualBalance(address vault, address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to calculate virtual balance for|
|`asset`|`address`|The underlying asset of the vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|balance The total virtual asset balance across all vault adapters|


## Events
### ContractInitialized
Emitted when the kAssetRouter contract is initialized with registry configuration


```solidity
event ContractInitialized(address indexed registry);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`address`|The address of the kRegistry contract that manages protocol configuration|

### AssetsPushed
Emitted when assets are pushed from kMinter to a DN vault for yield generation

*This occurs when institutional users deposit assets through kMinter, and the router
forwards these assets to the appropriate DN vault for yield farming strategies*


```solidity
event AssetsPushed(address indexed from, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address initiating the asset push (typically kMinter)|
|`amount`|`uint256`|The quantity of assets being pushed to the vault|

### AssetsRequestPulled
Emitted when assets are requested for pull from a vault to fulfill kMinter redemptions

*Part of the two-phase redemption process - assets are first requested, then later pulled
after batch settlement. The batchReceiver is deployed to hold assets for distribution.*


```solidity
event AssetsRequestPulled(address indexed vault, address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address from which assets are being requested|
|`asset`|`address`|The underlying asset address being requested for redemption|
|`amount`|`uint256`|The quantity of assets requested for redemption|

### AssetsTransfered
Emitted when assets are transferred between kStakingVaults for optimal allocation

*This is a virtual transfer for accounting purposes - actual assets may remain in the same
physical location while vault balances are updated to reflect the new allocation*


```solidity
event AssetsTransfered(address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault transferring assets (losing virtual balance)|
|`targetVault`|`address`|The vault receiving assets (gaining virtual balance)|
|`asset`|`address`|The underlying asset address being transferred|
|`amount`|`uint256`|The quantity of assets being transferred between vaults|

### SharesRequestedPushed
Emitted when shares are requested for push operations in kStakingVault flows

*Part of the share-based accounting system for retail users in kStakingVaults*


```solidity
event SharesRequestedPushed(address indexed vault, bytes32 indexed batchId, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The kStakingVault requesting the share push operation|
|`batchId`|`bytes32`|The batch identifier for this operation|
|`amount`|`uint256`|The quantity of shares being pushed|

### SharesRequestedPulled
Emitted when shares are requested for pull operations in kStakingVault redemptions

*Coordinates share-based redemptions for retail users through the batch system*


```solidity
event SharesRequestedPulled(address indexed vault, bytes32 indexed batchId, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The kStakingVault requesting the share pull operation|
|`batchId`|`bytes32`|The batch identifier for this redemption batch|
|`amount`|`uint256`|The quantity of shares being pulled for redemption|

### SharesSettled
Emitted when shares are settled across multiple vaults with calculated share prices

*Marks the completion of a cross-vault settlement with final share price determination*


```solidity
event SharesSettled(
    address[] vaults, bytes32 indexed batchId, uint256 totalRequestedShares, uint256[] totalAssets, uint256 sharePrice
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vaults`|`address[]`|Array of vault addresses participating in the settlement|
|`batchId`|`bytes32`|The batch identifier for this settlement period|
|`totalRequestedShares`|`uint256`|Total shares requested across all vaults in this settlement|
|`totalAssets`|`uint256[]`|Array of total assets for each vault after settlement|
|`sharePrice`|`uint256`|The final calculated share price for this settlement period|

### BatchSettled
Emitted when a vault batch is settled with final asset accounting

*Indicates completion of yield distribution and final asset allocation for a batch*


```solidity
event BatchSettled(address indexed vault, bytes32 indexed batchId, uint256 totalAssets);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address that completed batch settlement|
|`batchId`|`bytes32`|The batch identifier that was settled|
|`totalAssets`|`uint256`|The final total asset value in the vault after settlement|

### PegProtectionActivated
Emitted when peg protection mechanism is activated due to vault shortfall

*Triggered when a vault cannot fulfill redemption requests, requiring asset transfers
from other vaults to maintain the protocol's 1:1 backing guarantee*


```solidity
event PegProtectionActivated(address indexed vault, uint256 shortfall);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault experiencing shortfall that triggered peg protection|
|`shortfall`|`uint256`|The amount of assets needed to fulfill pending redemption requests|

### PegProtectionExecuted
Emitted when peg protection transfers assets between vaults to cover shortfalls

*Maintains protocol solvency by redistributing assets from surplus to deficit vaults*


```solidity
event PegProtectionExecuted(address indexed sourceVault, address indexed targetVault, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault providing assets to cover the shortfall|
|`targetVault`|`address`|The vault receiving assets to fulfill its redemption obligations|
|`amount`|`uint256`|The quantity of assets transferred for peg protection|

### YieldDistributed
Emitted when yield is distributed through kToken minting/burning operations

*This is the core mechanism for maintaining 1:1 backing while distributing yield.
Positive yield increases kToken supply, negative yield (losses) decreases supply.*


```solidity
event YieldDistributed(address indexed vault, int256 yield);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault that generated the yield being distributed|
|`yield`|`int256`|The amount of yield (positive or negative) being distributed|

### Deposited
Emitted when assets are deposited into a vault through various protocol mechanisms

*Tracks all asset deposits whether from kMinter institutional flows or other sources*


```solidity
event Deposited(address indexed vault, address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address receiving the deposit|
|`asset`|`address`|The underlying asset address being deposited|
|`amount`|`uint256`|The quantity of assets deposited|

### SettlementProposed
Emitted when a new settlement proposal is created with cooldown period

*Begins the settlement process with a security cooldown to allow verification*


```solidity
event SettlementProposed(
    bytes32 indexed proposalId,
    address indexed vault,
    bytes32 indexed batchId,
    uint256 totalAssets,
    int256 netted,
    int256 yield,
    uint256 executeAfter,
    uint256 lastFeesChargedManagement,
    uint256 lastFeesChargedPerformance
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier for this settlement proposal|
|`vault`|`address`|The vault address for which settlement is proposed|
|`batchId`|`bytes32`|The batch identifier being settled|
|`totalAssets`|`uint256`|Total asset value in the vault after yield generation|
|`netted`|`int256`|Net amount of new deposits/redemptions in this batch|
|`yield`|`int256`|Absolute yield amount generated in this batch|
|`executeAfter`|`uint256`|Timestamp after which the proposal can be executed|
|`lastFeesChargedManagement`|`uint256`|Last management fees charged|
|`lastFeesChargedPerformance`|`uint256`|Last performance fees charged|

### SettlementExecuted
Emitted when a settlement proposal is successfully executed

*Marks completion of the settlement process with yield distribution*


```solidity
event SettlementExecuted(bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId, address executor);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the executed proposal|
|`vault`|`address`|The vault address that was settled|
|`batchId`|`bytes32`|The batch identifier that was settled|
|`executor`|`address`|The address that executed the settlement (guardian or admin)|

### SettlementCancelled
Emitted when a settlement proposal is cancelled before execution

*Allows guardians to cancel potentially incorrect settlement proposals*


```solidity
event SettlementCancelled(bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the cancelled proposal|
|`vault`|`address`|The vault address for which settlement was cancelled|
|`batchId`|`bytes32`|The batch identifier for which settlement was cancelled|

### SettlementUpdated
Emitted when a settlement proposal is updated with new yield calculation data

*Allows for correction of settlement proposals before execution if needed*


```solidity
event SettlementUpdated(bytes32 indexed proposalId, uint256 totalAssets, uint256 netted, uint256 yield, bool profit);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier of the updated proposal|
|`totalAssets`|`uint256`|Updated total asset value in the vault|
|`netted`|`uint256`|Updated net amount of deposits/redemptions|
|`yield`|`uint256`|Updated yield amount for distribution|
|`profit`|`bool`|Updated profit flag (true for gains, false for losses)|

### SettlementCooldownUpdated
Emitted when the settlement cooldown period is updated by protocol governance

*Cooldown provides security by allowing time to verify settlement proposals before execution*


```solidity
event SettlementCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldCooldown`|`uint256`|The previous cooldown period in seconds|
|`newCooldown`|`uint256`|The new cooldown period in seconds|

### MaxAllowedDeltaUpdated
Emitted when the yield tolerance threshold is updated by protocol governance

*Yield tolerance acts as a safety mechanism to prevent settlement proposals with excessive
yield deviations that could indicate calculation errors or potential manipulation attempts*


```solidity
event MaxAllowedDeltaUpdated(uint256 oldTolerance, uint256 newTolerance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldTolerance`|`uint256`|The previous yield tolerance in basis points|
|`newTolerance`|`uint256`|The new yield tolerance in basis points|

### YieldExceedsMaxDeltaWarning
Emitted when yield exceeds the tolerance threshold


```solidity
event YieldExceedsMaxDeltaWarning(address vault, address asset, bytes32 batchId, int256 yield, uint256 maxAllowedYield);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The DN vault address|
|`asset`|`address`|The underlying asset address|
|`batchId`|`bytes32`|The batch identifier|
|`yield`|`int256`|The yield amount|
|`maxAllowedYield`|`uint256`|The maximum allowed yield|

## Structs
### Balances
Tracks requested and deposited asset amounts for batch processing coordination

*Used by kAssetRouter to maintain virtual balance accounting across vaults and coordinate
asset flows between kMinter redemption requests and vault settlements. Enables efficient
batch processing by tracking pending operations before physical asset movement occurs.*


```solidity
struct Balances {
    uint128 requested;
    uint128 deposited;
}
```

### VaultSettlementProposal
Contains all parameters for a batch settlement proposal in the yield distribution system

*Settlement proposals implement a cooldown mechanism for security, allowing guardians to verify
yield calculations before execution. Once executed, the proposal triggers kToken minting/burning to
distribute yield or account for losses, maintaining the 1:1 backing ratio across all kTokens.*


```solidity
struct VaultSettlementProposal {
    address asset;
    address vault;
    bytes32 batchId;
    uint256 totalAssets;
    int256 netted;
    int256 yield;
    uint64 executeAfter;
    uint64 lastFeesChargedManagement;
    uint64 lastFeesChargedPerformance;
}
```

