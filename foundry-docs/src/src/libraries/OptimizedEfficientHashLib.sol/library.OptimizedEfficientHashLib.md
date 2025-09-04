# OptimizedEfficientHashLib
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/libraries/OptimizedEfficientHashLib.sol)

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

