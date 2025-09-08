# VaultClaims
[Git Source](https://github.com/VerisLabs/KAM/blob/7c4c002fe2cce8e1d11c6bc539e18f776ee440fc/src/kStakingVault/modules/VaultClaims.sol)

**Inherits:**
[BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md)

Handles claim operations for settled batches

*Contains claim functions for staking and unstaking operations*


## Functions
### claimStakedShares

Claims stkTokens from a settled staking batch


```solidity
function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Batch ID to claim from|
|`requestId`|`bytes32`|Request ID to claim|


### claimUnstakedAssets

Claims kTokens from a settled unstaking batch (simplified implementation)


```solidity
function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable nonReentrant;
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

