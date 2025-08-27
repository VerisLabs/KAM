# IkAssetRouter
[Git Source](https://github.com/VerisLabs/KAM/blob/20318b955ccd8109bf3be0a23f88fb6d93069dbe/src/interfaces/IkAssetRouter.sol)

Interface for kAssetRouter for asset routing and settlement


## Functions
### kAssetPush

Push assets from kMinter to designated DN vault


```solidity
function kAssetPush(address _asset, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The asset being deposited|
|`amount`|`uint256`|Amount of assets being pushed|
|`batchId`|`bytes32`|The batch ID from the DN vault|


### kAssetRequestPull

Request to pull assets for kMinter redemptions


```solidity
function kAssetRequestPull(address _asset, address _vault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_asset`|`address`|The asset to redeem|
|`_vault`|`address`|The vault to pull from|
|`amount`|`uint256`|Amount requested for redemption|
|`batchId`|`bytes32`|The batch ID for this redemption|


### kAssetTransfer

Transfer assets between kStakingVaults


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
|`sourceVault`|`address`|The vault to transfer assets from|
|`targetVault`|`address`|The vault to transfer assets to|
|`_asset`|`address`|The asset to transfer|
|`amount`|`uint256`|Amount of assets to transfer|
|`batchId`|`bytes32`|The batch ID for this transfer|


### kSharesRequestPush

Request to push shares for kStakingVault operations


```solidity
function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault to push shares from|
|`amount`|`uint256`|Amount of shares to push|
|`batchId`|`bytes32`|The batch ID for this operation|


### kSharesRequestPull

Request to pull shares for kStakingVault operations


```solidity
function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault to pull shares from|
|`amount`|`uint256`|Amount of shares to pull|
|`batchId`|`bytes32`|The batch ID for this operation|


### proposeSettleBatch

Propose a settlement for a vault's batch


```solidity
function proposeSettleBatch(
    address asset,
    address vault,
    bytes32 batchId,
    uint256 totalAssets,
    uint256 netted,
    uint256 yield,
    bool profit
)
    external
    payable
    returns (bytes32 proposalId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address|
|`vault`|`address`|Vault address to settle|
|`batchId`|`bytes32`|Batch ID to settle|
|`totalAssets`|`uint256`|Total assets in the vault|
|`netted`|`uint256`|Netted amount in current batch|
|`yield`|`uint256`|Yield in current batch|
|`profit`|`bool`|Whether the batch is profitable|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The unique identifier for this proposal|


### executeSettleBatch

Execute a settlement proposal after cooldown period


```solidity
function executeSettleBatch(bytes32 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to execute|


### cancelProposal

Cancel a settlement proposal before execution


```solidity
function cancelProposal(bytes32 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to cancel|


### setPaused

Set contract pause state


```solidity
function setPaused(bool paused) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused`|`bool`|New pause state|


### setSettlementCooldown

Set the cooldown period for settlement proposals


```solidity
function setSettlementCooldown(uint256 cooldown) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cooldown`|`uint256`|New cooldown period in seconds|


### getPendingProposals

Get All the pendingProposals


```solidity
function getPendingProposals(address vault_) external view returns (bytes32[] memory pendingProposals);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pendingProposals`|`bytes32[]`|An array of proposalIds|


### getDNVaultByAsset

Gets the DN vault address for a given asset


```solidity
function getDNVaultByAsset(address asset) external view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The corresponding DN vault address|


### getBatchIdBalances

Get batch balances for a vault


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
|`vault`|`address`|Vault address|
|`batchId`|`bytes32`|Batch ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`deposited`|`uint256`|Amount deposited in this batch|
|`requested`|`uint256`|Amount requested in this batch|


### getRequestedShares

Get requested shares for a vault batch


```solidity
function getRequestedShares(address vault, bytes32 batchId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address|
|`batchId`|`bytes32`|Batch ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Requested shares amount|


### isPaused

Check if contract is paused


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused|


### getSettlementProposal

Get details of a settlement proposal


```solidity
function getSettlementProposal(bytes32 proposalId) external view returns (VaultSettlementProposal memory proposal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`proposal`|`VaultSettlementProposal`|The settlement proposal details|


### canExecuteProposal

Check if a proposal can be executed


```solidity
function canExecuteProposal(bytes32 proposalId) external view returns (bool canExecute, string memory reason);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`canExecute`|`bool`|Whether the proposal can be executed|
|`reason`|`string`|Reason if cannot execute|


### getSettlementCooldown

Get the current settlement cooldown period


```solidity
function getSettlementCooldown() external view returns (uint256 cooldown);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`cooldown`|`uint256`|The cooldown period in seconds|


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


## Events
### ContractInitialized

```solidity
event ContractInitialized(address indexed registry);
```

### AssetsPushed

```solidity
event AssetsPushed(address indexed from, uint256 amount);
```

### AssetsRequestPulled

```solidity
event AssetsRequestPulled(address indexed vault, address indexed asset, address indexed batchReceiver, uint256 amount);
```

### AssetsTransfered

```solidity
event AssetsTransfered(address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount);
```

### SharesRequestedPushed

```solidity
event SharesRequestedPushed(address indexed vault, bytes32 indexed batchId, uint256 amount);
```

### SharesRequestedPulled

```solidity
event SharesRequestedPulled(address indexed vault, bytes32 indexed batchId, uint256 amount);
```

### SharesSettled

```solidity
event SharesSettled(
    address[] vaults, bytes32 indexed batchId, uint256 totalRequestedShares, uint256[] totalAssets, uint256 sharePrice
);
```

### BatchSettled

```solidity
event BatchSettled(address indexed vault, bytes32 indexed batchId, uint256 totalAssets);
```

### PegProtectionActivated

```solidity
event PegProtectionActivated(address indexed vault, uint256 shortfall);
```

### PegProtectionExecuted

```solidity
event PegProtectionExecuted(address indexed sourceVault, address indexed targetVault, uint256 amount);
```

### YieldDistributed

```solidity
event YieldDistributed(address indexed vault, uint256 yield, bool isProfit);
```

### Deposited

```solidity
event Deposited(address indexed vault, address indexed asset, uint256 amount, bool isKMinter);
```

### SettlementProposed

```solidity
event SettlementProposed(
    bytes32 indexed proposalId,
    address indexed vault,
    bytes32 indexed batchId,
    uint256 totalAssets,
    uint256 netted,
    uint256 yield,
    bool profit,
    uint256 executeAfter
);
```

### SettlementExecuted

```solidity
event SettlementExecuted(bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId, address executor);
```

### SettlementCancelled

```solidity
event SettlementCancelled(bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId);
```

### SettlementUpdated

```solidity
event SettlementUpdated(bytes32 indexed proposalId, uint256 totalAssets, uint256 netted, uint256 yield, bool profit);
```

### SettlementCooldownUpdated

```solidity
event SettlementCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);
```

## Errors
### InsufficientVirtualBalance

```solidity
error InsufficientVirtualBalance();
```

### ContractPaused

```solidity
error ContractPaused();
```

### ProposalNotFound

```solidity
error ProposalNotFound();
```

### ProposalAlreadyExecuted

```solidity
error ProposalAlreadyExecuted();
```

### ProposalCancelled

```solidity
error ProposalCancelled();
```

### ProposalAlreadyExists

```solidity
error ProposalAlreadyExists();
```

### ZeroProposals

```solidity
error ZeroProposals();
```

### BatchIdAlreadyProposed

```solidity
error BatchIdAlreadyProposed();
```

### CooldownNotPassed

```solidity
error CooldownNotPassed();
```

### InvalidCooldown

```solidity
error InvalidCooldown();
```

## Structs
### Balances

```solidity
struct Balances {
    uint128 requested;
    uint128 deposited;
}
```

### VaultSettlementProposal

```solidity
struct VaultSettlementProposal {
    address asset;
    address vault;
    bytes32 batchId;
    uint256 totalAssets;
    uint256 netted;
    uint256 yield;
    bool profit;
    uint256 executeAfter;
}
```

