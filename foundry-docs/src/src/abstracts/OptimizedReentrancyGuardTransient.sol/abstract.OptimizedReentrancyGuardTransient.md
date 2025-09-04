# OptimizedReentrancyGuardTransient
[Git Source](https://github.com/VerisLabs/KAM/blob/a83c1c8f27c68e09f3c0973bbaca147b539ef93b/src/abstracts/OptimizedReentrancyGuardTransient.sol)

**Author:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/ReentrancyGuardTransient.sol)

Optimized reentrancy guard mixin (transient storage variant).

*This implementation utilizes a internal function instead of a modifier
to check the reentrant condition, with the purpose of reducing contract size*


## State Variables
### _REENTRANCY_GUARD_SLOT
*Equivalent to: `uint32(bytes4(keccak256("Reentrancy()"))) | 1 << 71`.
9 bytes is large enough to avoid collisions in practice,
but not too large to result in excessive bytecode bloat.*


```solidity
uint256 private constant _REENTRANCY_GUARD_SLOT = 0x8000000000ab143c06;
```


## Functions
### _lockReentrant


```solidity
function _lockReentrant() internal;
```

### _unlockReentrant


```solidity
function _unlockReentrant() internal;
```

### _useTransientReentrancyGuardOnlyOnMainnet

*For widespread compatibility with L2s.
Only Ethereum mainnet is expensive anyways.*


```solidity
function _useTransientReentrancyGuardOnlyOnMainnet() internal view virtual returns (bool);
```

## Errors
### Reentrancy
*Unauthorized reentrant call.*


```solidity
error Reentrancy();
```

