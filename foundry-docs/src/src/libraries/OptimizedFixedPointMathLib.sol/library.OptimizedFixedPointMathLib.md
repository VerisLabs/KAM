# OptimizedFixedPointMathLib
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/libraries/OptimizedFixedPointMathLib.sol)

**Authors:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/OptimizedFixedPointMathLib.sol), Modified from Solmate
(https://github.com/transmissions11/solmate/blob/main/src/utils/OptimizedFixedPointMathLib.sol)

Arithmetic library with operations for fixed-point numbers.


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

