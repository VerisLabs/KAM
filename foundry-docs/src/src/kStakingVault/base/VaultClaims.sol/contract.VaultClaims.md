# VaultClaims
[Git Source](https://github.com/VerisLabs/KAM/blob/b791d077a3cd28e980c0943d5d7b30be3d8c14e2/src/kStakingVault/base/VaultClaims.sol)

**Inherits:**
[BaseVaultModule](/src/kStakingVault/base/BaseVaultModule.sol/abstract.BaseVaultModule.md)

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

