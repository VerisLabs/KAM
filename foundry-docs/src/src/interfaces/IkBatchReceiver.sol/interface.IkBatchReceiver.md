# IkBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/2cfac335d9060b60757c350b6581b2ed1a8a6b82/src/interfaces/IkBatchReceiver.sol)

Interface for kBatchReceiver


## Functions
### kMinter


```solidity
function kMinter() external view returns (address);
```

### asset


```solidity
function asset() external view returns (address);
```

### batchId


```solidity
function batchId() external view returns (bytes32);
```

### pullAssets


```solidity
function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external;
```

## Events
### BatchReceiverInitialized

```solidity
event BatchReceiverInitialized(address indexed kMinter, bytes32 indexed batchId, address asset);
```

### PulledAssets

```solidity
event PulledAssets(address indexed receiver, address indexed asset, uint256 amount);
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### OnlyKMinter

```solidity
error OnlyKMinter();
```

### InvalidBatchId

```solidity
error InvalidBatchId();
```

### ZeroAmount

```solidity
error ZeroAmount();
```

