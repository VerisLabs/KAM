# OptimizedBytes32EnumerableSetLib
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/libraries/OptimizedBytes32EnumerableSetLib.sol)

**Author:**
Solady(https://github.com/Vectorized/solady/blob/main/src/utils/OptimizedBytes32EnumerableSetLib.sol)

Library for managing enumerable sets in storage.

*The library size has been reduced to only use bytes32 sets*


## State Variables
### _ZERO_SENTINEL
*A sentinel value to denote the zero value in storage.
No elements can be equal to this value.
`uint72(bytes9(keccak256(bytes("_ZERO_SENTINEL"))))`.*


```solidity
uint256 private constant _ZERO_SENTINEL = 0xfbb67fda52d4bfb8bf;
```


### _ENUMERABLE_WORD_SET_SLOT_SEED
*The storage layout is given by:
```
mstore(0x04, _ENUMERABLE_WORD_SET_SLOT_SEED)
mstore(0x00, set.slot)
let rootSlot := keccak256(0x00, 0x24)
mstore(0x20, rootSlot)
mstore(0x00, value)
let positionSlot := keccak256(0x00, 0x40)
let valueSlot := add(rootSlot, sload(positionSlot))
let valueInStorage := sload(valueSlot)
let lazyLength := sload(not(rootSlot))
```*


```solidity
uint256 private constant _ENUMERABLE_WORD_SET_SLOT_SEED = 0x18fb5864;
```


## Functions
### length

*Returns the number of elements in the set.*


```solidity
function length(Bytes32Set storage set) internal view returns (uint256 result);
```

### contains

*Returns whether `value` is in the set.*


```solidity
function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool result);
```

### add

*Adds `value` to the set. Returns whether `value` was not in the set.*


```solidity
function add(Bytes32Set storage set, bytes32 value) internal returns (bool result);
```

### add

*Adds `value` to the set. Returns whether `value` was not in the set.
Reverts if the set grows bigger than the custom on-the-fly capacity `cap`.*


```solidity
function add(Bytes32Set storage set, bytes32 value, uint256 cap) internal returns (bool result);
```

### remove

*Removes `value` from the set. Returns whether `value` was in the set.*


```solidity
function remove(Bytes32Set storage set, bytes32 value) internal returns (bool result);
```

### update

*Shorthand for `isAdd ? set.add(value, cap) : set.remove(value)`.*


```solidity
function update(Bytes32Set storage set, bytes32 value, bool isAdd, uint256 cap) internal returns (bool);
```

### values

*Returns all of the values in the set.
Note: This can consume more gas than the block gas limit for large sets.*


```solidity
function values(Bytes32Set storage set) internal view returns (bytes32[] memory result);
```

### at

*Returns the element at index `i` in the set. Reverts if `i` is out-of-bounds.*


```solidity
function at(Bytes32Set storage set, uint256 i) internal view returns (bytes32 result);
```

### _rootSlot

*Returns the root slot.*


```solidity
function _rootSlot(Bytes32Set storage s) private pure returns (bytes32 r);
```

## Errors
### IndexOutOfBounds
*The index must be less than the length.*


```solidity
error IndexOutOfBounds();
```

### ValueIsZeroSentinel
*The value cannot be the zero sentinel.*


```solidity
error ValueIsZeroSentinel();
```

### ExceedsCapacity
*Cannot accommodate a new unique value with the capacity.*


```solidity
error ExceedsCapacity();
```

## Structs
### Bytes32Set
*An enumerable bytes32 set in storage.*


```solidity
struct Bytes32Set {
    uint256 _spacer;
}
```

