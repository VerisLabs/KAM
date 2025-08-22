# IkStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/2198994c086118bce5be2d9d0775637d0ef500f3/src/interfaces/IkStakingVault.sol)

Interface for kStakingVault that manages minter operations and user staking

*Matches kStakingVault implementation*


## Functions
### requestStake


```solidity
function requestStake(address to, uint256 kTokensAmount) external payable returns (bytes32 requestId);
```

### requestUnstake


```solidity
function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
```

### claimStakedShares


```solidity
function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable;
```

### claimUnstakedAssets


```solidity
function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable;
```

### updateLastTotalAssets


```solidity
function updateLastTotalAssets(uint256 totalAssets) external;
```

### createBatchReceiver


```solidity
function createBatchReceiver(bytes32 batchId) external returns (address);
```

### closeBatch


```solidity
function closeBatch(bytes32 _batchId, bool _create) external;
```

### settleBatch


```solidity
function settleBatch(bytes32 _batchId) external;
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256);
```

### asset


```solidity
function asset() external view returns (address);
```

### underlyingAsset


```solidity
function underlyingAsset() external view returns (address);
```

### name


```solidity
function name() external view returns (string memory);
```

### symbol


```solidity
function symbol() external view returns (string memory);
```

### decimals


```solidity
function decimals() external view returns (uint8);
```

### calculateStkTokenPrice


```solidity
function calculateStkTokenPrice(uint256 totalAssets) external view returns (uint256);
```

### lastTotalAssets


```solidity
function lastTotalAssets() external view returns (uint256);
```

### kToken


```solidity
function kToken() external view returns (address);
```

### getBatchId


```solidity
function getBatchId() external view returns (bytes32);
```

### getSafeBatchId


```solidity
function getSafeBatchId() external view returns (bytes32);
```

### getSafeBatchReceiver


```solidity
function getSafeBatchReceiver(bytes32 batchId) external view returns (address);
```

### isBatchClosed


```solidity
function isBatchClosed() external view returns (bool);
```

### isBatchSettled


```solidity
function isBatchSettled() external view returns (bool);
```

### getBatchIdInfo


```solidity
function getBatchIdInfo()
    external
    view
    returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled);
```

### getBatchReceiver


```solidity
function getBatchReceiver(bytes32 batchId) external view returns (address);
```

### getBatchIdReceiver


```solidity
function getBatchIdReceiver(bytes32 batchId) external view returns (address);
```

### sharePrice


```solidity
function sharePrice() external view returns (uint256);
```

### contractName


```solidity
function contractName() external pure returns (string memory);
```

### contractVersion


```solidity
function contractVersion() external pure returns (string memory);
```

