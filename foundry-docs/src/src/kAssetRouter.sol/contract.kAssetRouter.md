# kAssetRouter
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/kAssetRouter.sol)

**Inherits:**
[IkAssetRouter](/src/interfaces/IkAssetRouter.sol/interface.IkAssetRouter.md), [Initializable](/src/vendor/solady/utils/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/solady/utils/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [kBase](/src/base/kBase.sol/contract.kBase.md), [Multicallable](/src/vendor/solady/utils/Multicallable.sol/abstract.Multicallable.md)

Central money flow coordinator for the KAM protocol, orchestrating all asset movements and yield
distribution

*This contract serves as the heart of the KAM protocol's financial infrastructure, coordinating complex
interactions between institutional flows (kMinter), retail flows (kStakingVaults), and yield generation (DN vaults).
Key responsibilities include: (1) Managing asset pushes from kMinter institutional deposits to DN vaults for yield
generation, (2) Coordinating virtual asset transfers between kStakingVaults for optimal capital allocation,
(3) Processing batch settlements with yield distribution through precise kToken minting/burning operations,
(4) Maintaining virtual balance tracking across all vaults for accurate accounting, (5) Implementing security
cooldown periods for settlement proposals, (6) Executing peg protection mechanisms during market stress.
The contract ensures protocol integrity by maintaining the 1:1 backing guarantee through carefully orchestrated
money flows while enabling efficient capital utilization across the entire vault network.*


## State Variables
### DEFAULT_VAULT_SETTLEMENT_COOLDOWN
Default cooldown period for vault settlement proposals (1 hour)

*Provides initial security delay between proposal creation and execution, allowing guardians
to verify yield calculations and detect potential errors before irreversible yield distribution*


```solidity
uint256 private constant DEFAULT_VAULT_SETTLEMENT_COOLDOWN = 1 hours;
```


### MAX_VAULT_SETTLEMENT_COOLDOWN
Maximum allowed cooldown period for vault settlement proposals (1 day)

*Caps the maximum security delay to balance protocol safety with operational efficiency.
Prevents excessive delays that could harm user experience while maintaining security standards*


```solidity
uint256 private constant MAX_VAULT_SETTLEMENT_COOLDOWN = 1 days;
```


### DEFAULT_MAX_DELTA
Default yield tolerance for settlement proposals (10%)

*Provides initial yield deviation threshold to prevent settlements with excessive yield changes
that could indicate errors in yield calculation or potential manipulation attempts*


```solidity
uint256 private constant DEFAULT_MAX_DELTA = 1000;
```


### KASSETROUTER_STORAGE_LOCATION

```solidity
bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
    0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;
```


## Functions
### _getkAssetRouterStorage

Retrieves the kAssetRouter storage struct from its designated storage slot

*Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
storage variables in future upgrades without affecting existing storage layout.*


```solidity
function _getkAssetRouterStorage() private pure returns (kAssetRouterStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`kAssetRouterStorage`|The kAssetRouterStorage struct reference for state modifications|


### constructor

Disables initializers to prevent implementation contract initialization

*Ensures the implementation contract cannot be initialized directly, only through proxies*


```solidity
constructor();
```

### initialize

Initializes the kAssetRouter with protocol configuration and default parameters

*Sets up the contract with protocol registry connection and default settlement cooldown.
Must be called immediately after proxy deployment to establish connection with the protocol
registry and initialize the money flow coordination system.*


```solidity
function initialize(address registry_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract that manages protocol configuration|


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
    uint256 totalAssets_,
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
|`totalAssets_`|`uint256`||
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


### _executeSettlement

Internal function to execute the core settlement logic with yield distribution

*This function performs the critical yield distribution process: (1) mints or burns kTokens
to reflect yield gains/losses, (2) updates vault accounting and batch tracking, (3) coordinates
the 1:1 backing maintenance. This is where the protocol's fundamental promise is maintained -
the kToken supply is adjusted to precisely match underlying asset changes plus distributed yield.*


```solidity
function _executeSettlement(VaultSettlementProposal storage proposal) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposal`|`VaultSettlementProposal`|The settlement proposal storage reference containing all settlement parameters|


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
operational flexibility, allowing normal yield fluctuations while blocking suspicious proposals.*


```solidity
function setMaxAllowedDelta(uint256 maxDelta_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxDelta_`|`uint256`|The new yield tolerance in basis points (e.g., 1000 = 10%)|


### getPendingProposals

Retrieves all pending settlement proposals for a specific vault

*Returns proposal IDs that have been created but not yet executed or cancelled.
Used for monitoring and management of the settlement queue. Essential for guardians
to track proposals awaiting verification during the cooldown period.*


```solidity
function getPendingProposals(address vault) external view returns (bytes32[] memory pendingProposals);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pendingProposals`|`bytes32[]`|Array of proposal IDs currently pending execution|


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
function getSettlementCooldown() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|cooldown The current cooldown period in seconds|


### getYieldTolerance

Gets the current yield tolerance threshold for settlement proposals

*The yield tolerance determines the maximum acceptable yield deviation before settlement proposals
are automatically rejected. This acts as a safety mechanism to prevent processing of settlement proposals
with excessive yield values that could indicate calculation errors or potential manipulation. The tolerance
is expressed in basis points where 10000 equals 100%.*


```solidity
function getYieldTolerance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|tolerance The current yield tolerance in basis points|


### virtualBalance


```solidity
function virtualBalance(address vault, address asset) external view returns (uint256);
```

### _virtualBalance

Calculates the virtual balance of assets for a vault across all its adapters

*This function aggregates asset balances across all adapters connected to a vault to determine
the total virtual balance available for operations. Essential for coordination between physical
asset locations and protocol accounting. Used for settlement calculations and ensuring sufficient
assets are available for redemptions and transfers within the money flow system.*


```solidity
function _virtualBalance(address vault, address asset) private view returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to calculate virtual balance for|
|`asset`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The total virtual asset balance across all vault adapters|


### _checkKMinter

Validates that the caller is an authorized kMinter contract

*Ensures only kMinter can push assets and request pulls for institutional operations.
Critical for maintaining proper access control in the money flow coordination system.*


```solidity
function _checkKMinter(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to validate as authorized kMinter|


### _checkVault

Validates that the caller is an authorized kStakingVault contract

*Ensures only registered vaults can request share operations and asset transfers.
Essential for maintaining protocol security and preventing unauthorized money flows.*


```solidity
function _checkVault(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to validate as authorized vault|


### _checkAmountNotZero

Validates that an amount parameter is not zero to prevent invalid operations

*Prevents zero-amount operations that could cause accounting errors or waste gas*


```solidity
function _checkAmountNotZero(uint256 amount) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount`|`uint256`|The amount value to validate|


### _checkAddressNotZero

Validates that an address parameter is not the zero address

*Prevents operations with invalid zero addresses that could cause loss of funds*


```solidity
function _checkAddressNotZero(address addr) private pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to validate|


### _checkSufficientVirtualBalance

Check if virtual balance is sufficient


```solidity
function _checkSufficientVirtualBalance(address vault, address asset, uint256 requiredAmount) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address|
|`asset`|`address`||
|`requiredAmount`|`uint256`|Required amount|


### _checkAdmin

Check if caller is an admin


```solidity
function _checkAdmin(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkPaused

Verifies contract is not paused


```solidity
function _checkPaused() private view;
```

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


### _authorizeUpgrade

Authorize contract upgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|New implementation address|


### receive

Receive ETH (for gas refunds, etc.)


```solidity
receive() external payable;
```

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
### kAssetRouterStorage
Core storage structure for kAssetRouter using ERC-7201 namespaced storage pattern

*This structure manages all state for money flow coordination and settlement operations.
Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.*

**Note:**
storage-location: erc7201:kam.storage.kAssetRouter


```solidity
struct kAssetRouterStorage {
    uint256 proposalCounter;
    uint256 vaultSettlementCooldown;
    uint256 maxAllowedDelta;
    OptimizedBytes32EnumerableSetLib.Bytes32Set executedProposalIds;
    OptimizedBytes32EnumerableSetLib.Bytes32Set batchIds;
    mapping(address vault => OptimizedBytes32EnumerableSetLib.Bytes32Set) vaultPendingProposalIds;
    mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
    mapping(address vault => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
    mapping(bytes32 proposalId => VaultSettlementProposal) settlementProposals;
}
```

