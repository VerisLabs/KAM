# OptimizedLibCall
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/vendor/solady/utils/OptimizedLibCall.sol)

**Authors:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibCall.sol), Modified from ExcessivelySafeCall (https://github.com/nomad-xyz/ExcessivelySafeCall)

Optimized Library for making calls.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary contract calls functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


## Functions
### callContract

*Makes a call to `target`, with `data` and `value`.*


```solidity
function callContract(address target, uint256 value, bytes memory data) internal returns (bytes memory result);
```

## Errors
### TargetIsNotContract
*The target of the call is not a contract.*


```solidity
error TargetIsNotContract();
```

