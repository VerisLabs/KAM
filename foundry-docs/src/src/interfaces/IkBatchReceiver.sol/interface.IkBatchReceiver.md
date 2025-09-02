# IkBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/b791d077a3cd28e980c0943d5d7b30be3d8c14e2/src/interfaces/IkBatchReceiver.sol)

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
function rescueAssets(address asset_) external payable;
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

### RescuedETH

```solidity
event RescuedETH(address indexed asset, uint256 amount);
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

### IsInitialised

```solidity
error IsInitialised();
```

### TransferFailed

```solidity
error TransferFailed();
```

