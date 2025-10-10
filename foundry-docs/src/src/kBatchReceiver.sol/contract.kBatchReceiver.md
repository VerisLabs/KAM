# kBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/kBatchReceiver.sol)

**Inherits:**
[IkBatchReceiver](/src/interfaces/IkBatchReceiver.sol/interface.IkBatchReceiver.md)

Minimal proxy contract implementation for isolated batch asset distribution in the KAM protocol

*This contract implements the minimal proxy pattern where each batch redemption gets its own dedicated
receiver instance for secure and efficient asset distribution. The implementation provides several key features:
(1) Minimal Proxy Pattern: Uses EIP-1167 minimal proxy deployment to reduce gas costs per batch while maintaining
full isolation between different settlement periods, (2) Batch Isolation: Each receiver handles exactly one batch,
preventing cross-contamination and simplifying accounting, (3) Access Control: Only the originating kMinter can
interact with receivers, ensuring strict security throughout the distribution process, (4) Asset Distribution:
Manages the final step of redemption where settled assets flow from kMinter to individual users, (5) Emergency
Recovery: Provides safety mechanisms for accidentally sent tokens while protecting settlement assets.
Technical Implementation Notes:
- Uses immutable kMinter reference set at construction for gas efficiency
- Implements strict batch ID validation to prevent operational errors
- Supports both ERC20 and native ETH rescue operations
- Emits comprehensive events for off-chain tracking and reconciliation*


## State Variables
### kMinter
Address of the kMinter contract authorized to interact with this receiver

*Immutable reference set at construction time for gas efficiency and security. This address
has exclusive permission to call pullAssets() and rescueAssets(), ensuring only the originating
kMinter can manage asset distribution for this specific batch. The immutable nature prevents
modification and reduces gas costs for access control checks.*


```solidity
address public immutable kMinter;
```


### asset
Address of the underlying asset contract this receiver will distribute

*Set during initialization to specify which token type (USDC, WBTC, etc.) this receiver
manages. Must match the asset type that was originally deposited and requested for redemption
in the associated batch. Used for asset transfer operations and rescue validation.*


```solidity
address public asset;
```


### batchId
Unique batch identifier linking this receiver to a specific redemption batch

*Set during initialization to establish the connection between this receiver and the batch
of redemption requests it serves. Used for validation in pullAssets() to ensure operations
are performed on the correct batch, preventing cross-contamination between settlement periods.*


```solidity
bytes32 public batchId;
```


### isInitialised
Initialization state flag preventing duplicate configuration

*Boolean flag that prevents re-initialization after the receiver has been configured.
Set to true during the initialize() call to ensure batch parameters can only be set once,
maintaining the integrity of the receiver's purpose and preventing operational errors.*


```solidity
bool public isInitialised;
```


## Functions
### constructor

Deploys a new kBatchReceiver with immutable kMinter authorization

*Constructor for minimal proxy implementation that establishes the sole authorized caller.
The kMinter address is set as immutable during deployment to ensure gas efficiency and prevent
unauthorized modifications. This constructor is called once per batch receiver deployment,
establishing the security foundation for all subsequent operations. The address validation
ensures no receiver can be deployed with invalid authorization.*


```solidity
constructor(address _kMinter);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_kMinter`|`address`|Address of the kMinter contract that will have exclusive interaction rights|


### initialize

Configures the receiver with batch-specific parameters after deployment

*Post-deployment initialization that links this receiver to a specific batch and asset type.
This two-step deployment pattern (constructor + initialize) enables efficient minimal proxy usage
where the implementation is deployed once and initialization customizes each instance. The function:
(1) prevents duplicate initialization with isInitialised flag, (2) validates asset address,
(3) stores batch parameters for operational use, (4) emits initialization event for tracking.
Only callable once per receiver instance to maintain batch isolation integrity.*


```solidity
function initialize(bytes32 _batchId, address _asset) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_batchId`|`bytes32`|The unique batch identifier this receiver will serve|
|`_asset`|`address`|Address of the underlying asset contract (USDC, WBTC, etc.) to distribute|


### pullAssets

Transfers settled assets from the receiver to a redemption user completing their withdrawal

*This is the core asset distribution function that fulfills redemption requests after batch settlement.
The process works as follows: (1) kMinter calls this function with user's proportional share, (2) receiver
validates the batch ID matches to prevent cross-batch contamination, (3) assets are transferred directly
to the user completing their redemption. Only callable by the authorized kMinter contract to maintain strict
access control. This function is typically called multiple times per batch as individual users claim their
settled redemptions, ensuring fair and orderly asset distribution.*


```solidity
function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address that will receive the settled assets (the user completing redemption)|
|`amount`|`uint256`|The quantity of assets to transfer based on the user's proportional share|
|`_batchId`|`bytes32`|The batch identifier for validation (must match this receiver's configured batch)|


### rescueAssets

Emergency recovery function for accidentally sent assets to prevent permanent loss

*Provides a safety mechanism for recovering tokens or ETH that were mistakenly sent to the receiver
outside of normal settlement operations. The function handles both ERC20 tokens and native ETH recovery.
For ERC20 tokens, it validates that the rescue asset is not the receiver's designated settlement asset
(to prevent interfering with normal operations). Only the authorized kMinter can execute rescues, ensuring
recovered assets return to the proper custodial system. Essential for maintaining protocol security while
preventing accidental asset loss during the receiver contract's operational lifecycle.*


```solidity
function rescueAssets(address asset_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The contract address of the asset to rescue (use address(0) for native ETH recovery)|


### _checkMinter

*Only callable by kMinter*


```solidity
function _checkMinter(address minter) private view;
```

### _checkAddressNotZero

*Checks address is not zero*


```solidity
function _checkAddressNotZero(address address_) private pure;
```

### _checkAmountNotZero

*Checks amount is not zero*


```solidity
function _checkAmountNotZero(uint256 amount) private pure;
```

