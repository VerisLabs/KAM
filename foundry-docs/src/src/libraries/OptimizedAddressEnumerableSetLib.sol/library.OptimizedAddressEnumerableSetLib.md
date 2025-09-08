# OptimizedAddressEnumerableSetLib
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/libraries/OptimizedAddressEnumerableSetLib.sol)

**Author:**
Originally by Solady (https://github.com/vectorized/solady/blob/main/src/utils/EnumerableSetLib.sol)

Library for managing enumerable sets in storage.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


## State Variables
### NOT_FOUND
*The index to represent a value that does not exist.*


```solidity
uint256 internal constant NOT_FOUND = type(uint256).max;
```


### _ZERO_SENTINEL
*A sentinel value to denote the zero value in storage.
No elements can be equal to this value.
`uint72(bytes9(keccak256(bytes("_ZERO_SENTINEL"))))`.*


```solidity
uint256 private constant _ZERO_SENTINEL = 0xfbb67fda52d4bfb8bf;
```


### _ENUMERABLE_ADDRESS_SET_SLOT_SEED
*The storage layout is given by:
```
mstore(0x04, _ENUMERABLE_ADDRESS_SET_SLOT_SEED)
mstore(0x00, set.slot)
let rootSlot := keccak256(0x00, 0x24)
mstore(0x20, rootSlot)
mstore(0x00, shr(96, shl(96, value)))
let positionSlot := keccak256(0x00, 0x40)
let valueSlot := add(rootSlot, sload(positionSlot))
let valueInStorage := shr(96, sload(valueSlot))
let lazyLength := shr(160, shl(160, sload(rootSlot)))
```*


```solidity
uint256 private constant _ENUMERABLE_ADDRESS_SET_SLOT_SEED = 0x978aab92;
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
function length(AddressSet storage set) internal view returns (uint256 result);
```

### contains

*Returns whether `value` is in the set.*


```solidity
function contains(AddressSet storage set, address value) internal view returns (bool result);
```

### add

*Adds `value` to the set. Returns whether `value` was not in the set.*


```solidity
function add(AddressSet storage set, address value) internal returns (bool result);
```

### remove

*Removes `value` from the set. Returns whether `value` was in the set.*


```solidity
function remove(AddressSet storage set, address value) internal returns (bool result);
```

### values

*Returns all of the values in the set.
Note: This can consume more gas than the block gas limit for large sets.*


```solidity
function values(AddressSet storage set) internal view returns (address[] memory result);
```

### at

*Returns the element at index `i` in the set. Reverts if `i` is out-of-bounds.*


```solidity
function at(AddressSet storage set, uint256 i) internal view returns (address result);
```

### indexOf

*Returns the index of `value`. Returns `NOT_FOUND` if the value does not exist.*


```solidity
function indexOf(AddressSet storage set, address value) internal view returns (uint256 result);
```

### _rootSlot

*Returns the root slot.*


```solidity
function _rootSlot(AddressSet storage s) private pure returns (bytes32 r);
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
### AddressSet
*An enumerable address set in storage.*


```solidity
struct AddressSet {
    uint256 _spacer;
}
```

