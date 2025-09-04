# OptimizedSafeCastLib
[Git Source](https://github.com/VerisLabs/KAM/blob/670f05acf8766190fcaa1d272341611f065917de/src/libraries/OptimizedSafeCastLib.sol)

**Authors:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeCastLib.sol), Modified from OpenZeppelin
(https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)

Safe integer casting library that reverts on overflow.

*Optimized for runtime gas for very high number of optimizer runs (i.e. >= 1000000).*


## Functions
### toUint64

*Casts `x` to a uint64. Reverts on overflow.*


```solidity
function toUint64(uint256 x) internal pure returns (uint64);
```

### toUint128

*Casts `x` to a uint128. Reverts on overflow.*


```solidity
function toUint128(uint256 x) internal pure returns (uint128);
```

### toUint256

*Casts `x` to a uint256. Reverts on overflow.*


```solidity
function toUint256(int256 x) internal pure returns (uint256);
```

### _revertOverflow


```solidity
function _revertOverflow() private pure;
```

## Errors
### Overflow
*Unable to cast to the target type due to overflow.*


```solidity
error Overflow();
```

