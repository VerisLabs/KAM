# VaultClaims
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/kStakingVault/base/VaultClaims.sol)

**Inherits:**
[BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md)

Handles claim operations for settled batches

*Contains claim functions for staking and unstaking operations*


## Functions
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


## Events
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

### StkTokensIssued
Emitted when stkTokens are issued


```solidity
event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
```

### KTokenUnstaked
Emitted when kTokens are unstaked


```solidity
event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
```

