# OptimizedFixedPointMathLib
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/libraries/OptimizedFixedPointMathLib.sol)

**Authors:**
Originally by Solady (https://github.com/vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol), Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)

Arithmetic library with operations for fixed-point numbers.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary fixed-point math functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


## Functions
### fullMulDiv

*Calculates `floor(x * y / d)` with full precision.
Throws if result overflows a uint256 or when `d` is zero.
Credit to Remco Bloemen under MIT license: https://2π.com/21/muldiv*


```solidity
function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z);
```

## Errors
### FullMulDivFailed
*The full precision multiply-divide operation failed, either due
to the result being larger than 256 bits, or a division by a zero.*


```solidity
error FullMulDivFailed();
```

