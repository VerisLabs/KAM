# kStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/kStakingVault/kStakingVault.sol)

**Inherits:**
[Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [Ownable](/src/vendor/Ownable.sol/abstract.Ownable.md), [BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md), [MultiFacetProxy](/src/base/MultiFacetProxy.sol/abstract.MultiFacetProxy.md), [VaultFees](/src/kStakingVault/base/VaultFees.sol/contract.VaultFees.md), [VaultClaims](/src/kStakingVault/base/VaultClaims.sol/contract.VaultClaims.md), [VaultBatches](/src/kStakingVault/base/VaultBatches.sol/contract.VaultBatches.md)

Pure ERC20 vault with dual accounting for minter and user pools

*Implements automatic yield distribution from minter to user pools with modular architecture*


## Functions
### constructor

Disables initializers to prevent implementation contract initialization


```solidity
constructor();
```

### initialize

Initializes the kStakingVault contract (stack optimized)

*Phase 1: Core initialization without strings to avoid stack too deep*


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
|`owner_`|`address`||
|`registry_`|`address`|The registry address|
|`paused_`|`bool`|If the vault is paused_|
|`name_`|`string`|Token name|
|`symbol_`|`string`|Token symbol|
|`decimals_`|`uint8`|Token decimals|
|`asset_`|`address`|Underlying asset address|


### requestStake

Request to stake kTokens for stkTokens (rebase token)


```solidity
function requestStake(address to, uint256 amount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Address to receive the stkTokens|
|`amount`|`uint256`|Amount of kTokens to stake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID for this staking request|


### requestUnstake

Request to unstake stkTokens for kTokens + yield

*Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)*


```solidity
function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`||
|`stkTokenAmount`|`uint256`|Amount of stkTokens to unstake|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Request ID for this unstaking request|


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

