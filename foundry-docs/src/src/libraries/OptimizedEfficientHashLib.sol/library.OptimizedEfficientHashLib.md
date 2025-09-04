# OptimizedEfficientHashLib
[Git Source](https://github.com/VerisLabs/KAM/blob/670f05acf8766190fcaa1d272341611f065917de/src/libraries/OptimizedEfficientHashLib.sol)

**Author:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/OptimizedEfficientHashLib.sol)

Library for efficiently performing keccak256 hashes.

*To avoid stack-too-deep, you can use:
```
bytes32[] memory buffer = OptimizedEfficientHashLib.malloc(10);
OptimizedEfficientHashLib.set(buffer, 0, value0);
..
OptimizedEfficientHashLib.set(buffer, 9, value9);
bytes32 finalHash = OptimizedEfficientHashLib.hash(buffer);
```*


## Functions
### hash

*Returns `keccak256(abi.encode(v0, v1, v2, v3))`.*


```solidity
function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3) internal pure returns (bytes32 result);
```

### hash

*Returns `keccak256(abi.encode(v0, .., v4))`.*


```solidity
function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4) internal pure returns (bytes32 result);
```

