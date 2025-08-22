# ClaimModule
[Git Source](https://github.com/VerisLabs/KAM/blob/dd71a4088db684fce979bc8cf7c38882ee6bb8a4/src/kStakingVault/modules/ClaimModule.sol)

**Inherits:**
[BaseVaultModule](/src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.md)

Handles claim operations for settled batches

*Contains claim functions for staking and unstaking operations*


## Functions
### claimStakedShares

Claims stkTokens from a settled staking batch


```solidity
function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Batch ID to claim from|
|`requestId`|`bytes32`|Request ID to claim|


### claimUnstakedAssets

Claims kTokens from a settled unstaking batch (simplified implementation)


```solidity
function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable nonReentrant whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Batch ID to claim from|
|`requestId`|`bytes32`|Request ID to claim|


### selectors

Returns the selectors for functions in this module


```solidity
function selectors() external pure returns (bytes4[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4[]`|selectors Array of function selectors|


## Events
### StakingSharesClaimed
ERC20 Transfer event for stkToken operations


```solidity
event StakingSharesClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 shares);
```

### UnstakingAssetsClaimed

```solidity
event UnstakingAssetsClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 assets);
```

### StkTokensIssued

```solidity
event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
```

### KTokenUnstaked

```solidity
event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
```

## Errors
### BatchNotSettled

```solidity
error BatchNotSettled();
```

### InvalidBatchId

```solidity
error InvalidBatchId();
```

### RequestNotPending

```solidity
error RequestNotPending();
```

### NotBeneficiary

```solidity
error NotBeneficiary();
```

### MinimumOutputNotMet

```solidity
error MinimumOutputNotMet();
```

