# IkBatchReceiver
[Git Source](https://github.com/VerisLabs/KAM/blob/20318b955ccd8109bf3be0a23f88fb6d93069dbe/src/interfaces/IkBatchReceiver.sol)

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

### WrongRole

```solidity
error WrongRole();
```

### IsInitialised

```solidity
error IsInitialised();
```

