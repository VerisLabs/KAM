# kStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/kStakingVault/kStakingVault.sol)

**Inherits:**
[IVault](/src/interfaces/IVault.sol/interface.IVault.md), [BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md), [Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [Ownable](/src/vendor/Ownable.sol/abstract.Ownable.md), [MultiFacetProxy](/src/base/MultiFacetProxy.sol/abstract.MultiFacetProxy.md)

Retail staking vault enabling kToken holders to earn yield through batch-processed share tokens

*This contract implements the complete retail staking system for the KAM protocol, providing individual
kToken holders access to institutional-grade yield opportunities through a share-based mechanism. The implementation
combines several architectural patterns: (1) Dual-token system where kTokens convert to yield-bearing stkTokens,
(2) Batch processing for gas-efficient operations and fair pricing across multiple users, (3) Virtual balance
coordination with kAssetRouter for cross-vault yield optimization, (4) Two-phase operations (request → claim)
ensuring accurate settlement and preventing MEV attacks, (5) Fee management system supporting both management
and performance fees with hurdle rate mechanisms. The vault integrates with the broader protocol through
kAssetRouter for asset flow coordination and yield distribution. Gas optimizations include packed storage,
minimal proxy deployment for batch receivers, and efficient batch settlement processing. The modular architecture
enables upgrades while maintaining state integrity through UUPS pattern and ERC-7201 storage.*


## Functions
### constructor

Disables initializers to prevent implementation contract initialization


```solidity
constructor();
```

### initialize

Initializes the kStakingVault with complete protocol integration and share token configuration

*This function establishes the vault's integration with the KAM protocol ecosystem. The initialization
process: (1) Validates asset address to prevent deployment with invalid configuration, (2) Initializes
BaseVault foundation with registry and operational state, (3) Sets up ownership and access control through
Ownable pattern, (4) Configures share token metadata and decimals for ERC20 functionality, (5) Establishes
kToken integration through registry lookup for asset-to-token mapping, (6) Sets initial share price watermark
for performance fee calculations, (7) Deploys BatchReceiver implementation for settlement asset distribution.
The initialization creates a complete retail staking solution integrated with the protocol's institutional
flows.*


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
|`owner_`|`address`|The address that will have administrative control over the vault|
|`registry_`|`address`|The kRegistry contract address for protocol configuration integration|
|`paused_`|`bool`|Initial operational state (true = paused, false = active)|
|`name_`|`string`|ERC20 token name for the stkToken (e.g., "Staked kUSDC")|
|`symbol_`|`string`|ERC20 token symbol for the stkToken (e.g., "stkUSDC")|
|`decimals_`|`uint8`|Token decimals matching the underlying asset precision|
|`asset_`|`address`|Underlying asset address that this vault will generate yield on|


### requestStake

Initiates kToken staking request for yield-generating stkToken shares in a batch processing system

*This function begins the retail staking process by: (1) Validating user has sufficient kToken balance
and vault is not paused, (2) Creating a pending stake request with user-specified recipient and current
batch ID for fair settlement, (3) Transferring kTokens from user to vault while updating pending stake
tracking for accurate share calculations, (4) Coordinating with kAssetRouter to virtually move underlying
assets from DN vault to staking vault, enabling proper asset allocation across the protocol. The request
enters pending state until batch settlement, when the final share price is calculated based on vault
performance. Users must later call claimStakedShares() after settlement to receive their stkTokens at
the settled price. This two-phase approach ensures fair pricing for all users within a batch period.*


```solidity
function requestStake(address to, uint256 amount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address that will receive the stkTokens after successful settlement and claiming|
|`amount`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Unique identifier for tracking this staking request through settlement and claiming|


### requestUnstake

Initiates stkToken unstaking request for kToken redemption plus accrued yield through batch processing

*This function begins the retail unstaking process by: (1) Validating user has sufficient stkToken balance
and vault is operational, (2) Creating pending unstake request with current batch ID for settlement
coordination,
(3) Transferring stkTokens from user to vault contract to maintain stable share price during settlement period,
(4) Notifying kAssetRouter of share redemption request for proper accounting across vault network. The stkTokens
remain locked in the vault until settlement when they are burned and equivalent kTokens (including yield) are
made available. Users must later call claimUnstakedAssets() after settlement to receive their kTokens from
the batch receiver contract. This two-phase design ensures accurate yield calculations and prevents share
price manipulation during the settlement process.*


```solidity
function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address that will receive the kTokens after successful settlement and claiming|
|`stkTokenAmount`|`uint256`|The quantity of stkTokens to unstake (must not exceed user balance, cannot be zero)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Unique identifier for tracking this unstaking request through settlement and claiming|


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
function createNewBatch() external returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|batchId Unique deterministic identifier for the newly created batch period|


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


### _createNewBatch

Internal function to create deterministic batch IDs with collision resistance

*This function generates unique batch identifiers using multiple entropy sources for security. The ID
generation process: (1) Increments internal batch counter to ensure uniqueness within the vault, (2) Combines
vault address, batch number, chain ID, timestamp, and asset address for collision resistance, (3) Uses
optimized hashing function for gas efficiency, (4) Initializes batch storage with default state for new
requests. The deterministic approach enables consistent batch identification across different contexts while
the multiple entropy sources prevent prediction or collision attacks. Each batch starts in open state ready
to accept user requests until explicitly closed by relayers.*


```solidity
function _createNewBatch() private returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Deterministic batch identifier for the newly created batch period|


### _checkPaused

Validates vault operational state preventing actions during emergency pause

*This internal validation function ensures vault safety by blocking operations when paused. Emergency
pause can be triggered by emergency admins during security incidents or market anomalies. The function
provides consistent pause checking across all vault operations while maintaining gas efficiency through
direct storage access. When paused, users cannot create new requests but can still query vault state.*


```solidity
function _checkPaused(BaseVaultStorage storage $) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`$`|`BaseVaultStorage`|Direct storage pointer for gas-efficient pause state access|


### _checkAmountNotZero

Validates non-zero amounts preventing invalid operations

*This utility function prevents zero-amount operations that would waste gas or create invalid state.
Zero amounts are rejected for staking, unstaking, and fee operations to maintain data integrity and
prevent operational errors. The pure function enables gas-efficient validation without state access.*


```solidity
function _checkAmountNotZero(uint256 amount) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount value to validate (must be greater than zero)|


### _checkValidBPS

Validates basis point values preventing excessive fee configuration

*This function ensures fee parameters remain within acceptable bounds (0-10000 bp = 0-100%) to
protect users from excessive fee extraction. The 10000 bp limit enforces the maximum fee cap while
enabling flexible fee configuration within reasonable ranges. Used for both management and performance
fee validation to maintain consistent fee bounds across all fee types.*


```solidity
function _checkValidBPS(uint256 bps) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`bps`|`uint256`|The basis point value to validate (must be <= 10000)|


### _checkRelayer

Validates relayer role authorization for batch management operations

*This access control function ensures only authorized relayers can execute batch lifecycle operations.
Relayers are responsible for automated batch creation, closure, and coordination with settlement processes.
The role-based access prevents unauthorized manipulation of batch timing while enabling protocol automation.*


```solidity
function _checkRelayer(address relayer) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayer`|`address`|The address to validate against registered relayer roles|


### _checkRouter

Validates kAssetRouter authorization for settlement and asset coordination

*This critical access control ensures only the protocol's kAssetRouter can trigger settlement operations
and coordinate cross-vault asset flows. The router manages complex settlement logic including yield distribution
and virtual balance coordination, making this validation essential for protocol integrity and security.*


```solidity
function _checkRouter(address router) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The address to validate against the registered kAssetRouter contract|


### _checkAdmin

Validates admin role authorization for vault configuration changes

*This access control function restricts administrative operations to authorized admin addresses.
Admins can modify fee parameters, update vault settings, and execute emergency functions requiring
elevated privileges. The role validation maintains security while enabling necessary governance operations.*


```solidity
function _checkAdmin(address admin) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address to validate against registered admin roles|


### _validateTimestamp

Validates timestamp progression preventing manipulation and ensuring logical sequence

*This function ensures fee timestamp updates follow logical progression and remain within valid ranges.
Validation checks: (1) New timestamp must be >= last timestamp to prevent backwards time manipulation,
(2) New timestamp must be <= current block time to prevent future-dating. These validations are critical
for accurate fee calculations and preventing temporal manipulation attacks on the fee system.*


```solidity
function _validateTimestamp(uint256 timestamp, uint256 lastTimestamp) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`timestamp`|`uint256`|The new timestamp being set for fee tracking|
|`lastTimestamp`|`uint256`|The previous timestamp for progression validation|


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

