# kAssetRouter
[Git Source](https://github.com/VerisLabs/KAM/blob/2198994c086118bce5be2d9d0775637d0ef500f3/src/kAssetRouter.sol)

**Inherits:**
[IkAssetRouter](/src/interfaces/IkAssetRouter.sol/interface.IkAssetRouter.md), Initializable, UUPSUpgradeable, [kBase](/src/base/kBase.sol/contract.kBase.md), Multicallable


## State Variables
### KASSETROUTER_STORAGE_LOCATION

```solidity
bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
    0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;
```


### DEFAULT_VAULT_SETTLEMENT_COOLDOWN

```solidity
uint256 private constant DEFAULT_VAULT_SETTLEMENT_COOLDOWN = 1 hours;
```


### MAX_VAULT_SETTLEMENT_COOLDOWN

```solidity
uint256 private constant MAX_VAULT_SETTLEMENT_COOLDOWN = 1 days;
```


## Functions
### _getkAssetRouterStorage


```solidity
function _getkAssetRouterStorage() private pure returns (kAssetRouterStorage storage $);
```

### whenNotPaused


```solidity
modifier whenNotPaused();
```

### onlyStakingVault


```solidity
modifier onlyStakingVault();
```

### constructor


```solidity
constructor();
```

### initialize

Initialize the kAssetRouter with asset and admin configuration


```solidity
function initialize(address registry_, address owner_, address admin_, bool paused_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|
|`owner_`|`address`|Address of the owner|
|`admin_`|`address`|Address of the admin|
|`paused_`|`bool`|Initial pause state|


### kAssetPush

Push assets from kMinter to designated DN vault


```solidity
function kAssetPush(
    address _asset,
    uint256 amount,
    bytes32 batchId
)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyKMinter;
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
function kAssetRequestPull(
    address _asset,
    address _vault,
    uint256 amount,
    bytes32 batchId
)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyKMinter;
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


```solidity
function kAssetTransfer(
    address sourceVault,
    address targetVault,
    address _asset,
    uint256 amount,
    bytes32 batchId
)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyStakingVault;
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
function kSharesRequestPush(
    address sourceVault,
    uint256 amount,
    bytes32 batchId
)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyStakingVault;
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
function kSharesRequestPull(
    address sourceVault,
    uint256 amount,
    bytes32 batchId
)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyStakingVault;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sourceVault`|`address`|The vault to redeem shares from|
|`amount`|`uint256`|Amount requested for redemption|
|`batchId`|`bytes32`|The batch ID for this redemption|


### proposeSettleBatch

Propose a settlement for a vault's batch


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
    nonReentrant
    whenNotPaused
    onlyRelayer
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
function executeSettleBatch(bytes32 proposalId) external nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to execute|


### cancelProposal

Cancel a settlement proposal before execution


```solidity
function cancelProposal(bytes32 proposalId) external nonReentrant whenNotPaused onlyRelayer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to cancel|


### updateProposal

Update a settlement proposal before execution


```solidity
function updateProposal(
    bytes32 proposalId,
    uint256 totalAssets_,
    uint256 netted,
    uint256 yield,
    bool profit
)
    external
    nonReentrant
    whenNotPaused
    onlyRelayer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposalId`|`bytes32`|The proposal ID to update|
|`totalAssets_`|`uint256`|New total assets value|
|`netted`|`uint256`|New netted amount|
|`yield`|`uint256`|New yield amount|
|`profit`|`bool`|New profit status|


### _executeSettlement

Internal function to execute settlement logic


```solidity
function _executeSettlement(VaultSettlementProposal storage proposal) private;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proposal`|`VaultSettlementProposal`|The settlement proposal to execute|


### setPaused

Set contract pause state


```solidity
function setPaused(bool paused) external onlyRoles(EMERGENCY_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused`|`bool`|New pause state|


### setSettlementCooldown

Set the cooldown period for settlement proposals


```solidity
function setSettlementCooldown(uint256 cooldown) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`cooldown`|`uint256`|New cooldown period in seconds|


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
function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE);
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
    mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
    mapping(address vault => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
    mapping(bytes32 proposalId => VaultSettlementProposal) settlementProposals;
    uint256 vaultSettlementCooldown;
}
```

