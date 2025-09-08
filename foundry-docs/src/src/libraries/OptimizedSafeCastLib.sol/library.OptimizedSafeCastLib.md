# OptimizedSafeCastLib
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/libraries/OptimizedSafeCastLib.sol)

**Authors:**
Originally by Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeCastLib.sol), Modified from OpenZeppelin
(https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)

Safe integer casting library that reverts on overflow.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary safe casting functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


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

