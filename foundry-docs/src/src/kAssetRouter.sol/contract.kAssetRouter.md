# kAssetRouter
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/kAssetRouter.sol)

**Inherits:**
[IkAssetRouter](/src/interfaces/IkAssetRouter.sol/interface.IkAssetRouter.md), [Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [kBase](/src/base/kBase.sol/contract.kBase.md), [Multicallable](/src/vendor/Multicallable.sol/abstract.Multicallable.md)

Router contract for managing all the money flows between protocol actors

*Inherits from kBase and Multicallable*


## State Variables
### DEFAULT_VAULT_SETTLEMENT_COOLDOWN
Default cooldown period for vault settlements


```solidity
uint256 private constant DEFAULT_VAULT_SETTLEMENT_COOLDOWN = 1 hours;
```


### MAX_VAULT_SETTLEMENT_COOLDOWN
Maximum cooldown period for vault settlements


```solidity
uint256 private constant MAX_VAULT_SETTLEMENT_COOLDOWN = 1 days;
```


### KASSETROUTER_STORAGE_LOCATION

```solidity
bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
    0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;
```


## Functions
### _getkAssetRouterStorage

*Returns the kAssetRouter storage pointer*


```solidity
function _getkAssetRouterStorage() private pure returns (kAssetRouterStorage storage $);
```

### constructor


```solidity
constructor();
```

### initialize

Initialize the kAssetRouter with asset and admin configuration


```solidity
function initialize(address registry_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|


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
|`_vault`|`address`||
|`amount`|`uint256`|Amount requested for redemption|
|`batchId`|`bytes32`|The batch ID for this redemption|


### kAssetTransfer

Transfer assets between kStakingVaults

It's only a virtual transfer, no assets are moved


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

Request to pull shares for kStakingVault redemptions


```solidity
function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault to redeem shares from|
|`amount`|`uint256`|Amount requested for redemption|
|`batchId`|`bytes32`|The batch ID for this redemption|


### kSharesRequestPull

Request to pull shares for kStakingVault redemptions


```solidity
function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault to redeem shares from|
|`amount`|`uint256`|Amount requested for redemption|
|`batchId`|`bytes32`|The batch ID for this redemption|


### proposeSettleBatch

Propose a settlement for a vault's batch, including all new accounting


```solidity
function proposeSettleBatch(
    address asset,
    address vault,
    bytes32 batchId,
    uint256 totalAssets_,
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
|`totalAssets_`|`uint256`|Total assets in the vault with Deposited and Requested and Shares|
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
function executeSettleBatch(bytes32 proposalId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to execute|


### cancelProposal

Cancel a settlement proposal before execution

Guardian can cancel a settlement proposal if some data is wrong


```solidity
function cancelProposal(bytes32 proposalId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to cancel|


### _executeSettlement

Internal function to execute settlement logic


```solidity
function _executeSettlement(VaultSettlementProposal storage proposal) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposal`|`VaultSettlementProposal`|The settlement proposal to execute|


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
function getPendingProposals(address vault) external view returns (bytes32[] memory pendingProposals);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pendingProposals`|`bytes32[]`|An array of proposalIds|


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
function getSettlementCooldown() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|cooldown The cooldown period in seconds|


### _virtualBalance

gets the virtual balance of a vault


```solidity
function _virtualBalance(address vault, address asset) internal view returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|the vault address|
|`asset`|`address`|the asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|the balance of the vault in all adapters.|


### _isPendingProposal

verifies if a proposal is pending or not


```solidity
function _isPendingProposal(address vault, bytes32 proposalId) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|the vault address|
|`proposalId`|`bytes32`|the proposalId to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|bool proposal exists or not|


### isPaused

Check if contract is paused


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if paused|


### getDNVaultByAsset

Gets the DN vault address for a given asset

*Reverts if asset not supported*


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
### kAssetRouterStorage
**Note:**
storage-location: erc7201:kam.storage.kAssetRouter


```solidity
struct kAssetRouterStorage {
    uint256 proposalCounter;
    uint256 vaultSettlementCooldown;
    OptimizedBytes32EnumerableSetLib.Bytes32Set executedProposalIds;
    OptimizedBytes32EnumerableSetLib.Bytes32Set batchIds;
    mapping(address vault => OptimizedBytes32EnumerableSetLib.Bytes32Set) vaultPendingProposalIds;
    mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
    mapping(address vault => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
    mapping(bytes32 proposalId => VaultSettlementProposal) settlementProposals;
}
```

