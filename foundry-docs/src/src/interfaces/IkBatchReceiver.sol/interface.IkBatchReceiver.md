# IkBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/interfaces/IkBatchReceiver.sol)

Interface for minimal proxy contracts that manage asset distribution for completed batch redemptions

*kBatchReceiver contracts are deployed as minimal proxies (one per batch) to efficiently manage the distribution
of settled assets to users who requested redemptions. This design pattern provides: (1) gas-efficient deployment
since each batch gets its own isolated distribution contract, (2) clear asset segregation preventing cross-batch
contamination, (3) simplified accounting where each receiver holds exactly the assets needed for one batch.
The contract serves as a temporary holding mechanism - kMinter transfers settled assets to the receiver, then users
can pull their proportional share. This architecture ensures fair distribution and prevents front-running during
the redemption settlement process. Only the originating kMinter contract can interact with receivers, maintaining
strict access control throughout the asset distribution phase.*


## Functions
### kMinter

Retrieves the address of the kMinter contract authorized to interact with this receiver

*Returns the immutable kMinter address set during receiver deployment. This address has
exclusive permission to call pullAssets() and rescueAssets(), ensuring only the originating
kMinter can manage asset distribution for this batch. Critical for maintaining access control
and preventing unauthorized asset movements during the redemption settlement process.*


```solidity
function kMinter() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the kMinter contract with administrative permissions over this receiver|


### asset

Retrieves the underlying asset contract address managed by this receiver

*Returns the asset address configured during initialization (e.g., USDC, WBTC). This
determines which token type the receiver will distribute to redemption users. The asset type
must match the asset that was originally deposited and requested for redemption in the batch.*


```solidity
function asset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The contract address of the underlying asset this receiver distributes|


### batchId

Retrieves the unique batch identifier this receiver serves

*Returns the batch ID set during initialization, which links this receiver to a specific
batch of redemption requests. Used for validation when pulling assets to ensure operations
are performed on the correct batch. Essential for maintaining batch isolation and preventing
cross-contamination between different settlement periods.*


```solidity
function batchId() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|The unique batch identifier as a bytes32 hash|


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


## Events
### BatchReceiverInitialized
Emitted when a new batch receiver is initialized and ready for asset distribution

*This event marks the successful deployment and configuration of a minimal proxy receiver
for a specific batch. Essential for tracking the lifecycle of batch settlement processes and
enabling off-chain systems to monitor when settlement assets can begin flowing to receivers.*


```solidity
event BatchReceiverInitialized(address indexed kMinter, bytes32 indexed batchId, address asset);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kMinter`|`address`|The address of the kMinter contract authorized to interact with this receiver|
|`batchId`|`bytes32`|The unique identifier of the batch this receiver will serve|
|`asset`|`address`|The underlying asset address (USDC, WBTC, etc.) this receiver will distribute|

### PulledAssets
Emitted when assets are successfully distributed from the receiver to a redemption user

*This event tracks the actual fulfillment of redemption requests, recording when users
receive their settled assets. Critical for reconciliation and ensuring all batch participants
receive their proportional share during the distribution phase.*


```solidity
event PulledAssets(address indexed receiver, address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|The address that received the distributed assets (the redeeming user)|
|`asset`|`address`|The asset contract address that was transferred|
|`amount`|`uint256`|The quantity of assets successfully distributed to the receiver|

### RescuedAssets
Emitted when accidentally sent ERC20 tokens are rescued from the receiver contract

*Provides a safety mechanism for recovering tokens that were mistakenly sent to the receiver
outside of normal operations. This prevents permanent loss of assets while maintaining security.*


```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the ERC20 token contract that was rescued|
|`to`|`address`|The address that received the rescued tokens (typically the kMinter)|
|`amount`|`uint256`|The quantity of tokens that were successfully rescued|

### RescuedETH
Emitted when accidentally sent ETH is rescued from the receiver contract

*Handles recovery of native ETH that was mistakenly sent to the contract, ensuring no
value is permanently locked in the receiver contracts during their operational lifecycle.*


```solidity
event RescuedETH(address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address that received the rescued ETH (typically the kMinter)|
|`amount`|`uint256`|The amount of ETH (in wei) that was successfully rescued|

