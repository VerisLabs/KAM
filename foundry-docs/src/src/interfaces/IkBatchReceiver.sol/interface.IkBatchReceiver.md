# IkBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/7fe450d42e02311faf605d62cd48b6af1b05e41f/src/interfaces/IkBatchReceiver.sol)

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

### rescueAssets


```solidity
function rescueAssets(address asset_) external;
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

### RescuedAssets

```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
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

### AssetCantBeRescue

```solidity
error AssetCantBeRescue();
```

