# IkStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/bbd875989135c7d3f313fa3fcc61e94d6afb4346/src/interfaces/IkStakingVault.sol)

**Inherits:**
[IVaultBatch](/src/interfaces/modules/IVaultBatch.sol/interface.IVaultBatch.md), [IVaultClaim](/src/interfaces/modules/IVaultClaim.sol/interface.IVaultClaim.md), [IVaultFees](/src/interfaces/modules/IVaultFees.sol/interface.IVaultFees.md)

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

### updateLastTotalAssets


```solidity
function updateLastTotalAssets(uint256 totalAssets) external;
```

### asset


```solidity
function asset() external view returns (address);
```

### owner


```solidity
function owner() external view returns (address);
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256);
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

### totalAssets


```solidity
function totalAssets() external view returns (uint256);
```

### totalNetAssets


```solidity
function totalNetAssets() external view returns (uint256);
```

### balanceOf


```solidity
function balanceOf(address account) external view returns (uint256);
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

