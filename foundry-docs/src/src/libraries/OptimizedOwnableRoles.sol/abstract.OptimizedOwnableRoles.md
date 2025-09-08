# OptimizedOwnableRoles
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/libraries/OptimizedOwnableRoles.sol)

**Inherits:**
[Ownable](/src/vendor/Ownable.sol/abstract.Ownable.md)

**Author:**
Originally by Solady (https://github.com/vectorized/solady/blob/main/src/auth/OwnableRoles.sol)

Simple single owner and multiroles authorization mixin.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary roles functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


## State Variables
### _ROLES_UPDATED_EVENT_SIGNATURE
*`keccak256(bytes("RolesUpdated(address,uint256)"))`.*


```solidity
uint256 private constant _ROLES_UPDATED_EVENT_SIGNATURE =
    0x715ad5ce61fc9595c7b415289d59cf203f23a94fa06f04af7e489a0a76e1fe26;
```


### _ROLE_SLOT_SEED
*The role slot of `user` is given by:
```
mstore(0x00, or(shl(96, user), _ROLE_SLOT_SEED))
let roleSlot := keccak256(0x00, 0x20)
```
This automatically ignores the upper bits of the `user` in case
they are not clean, as well as keep the `keccak256` under 32-bytes.
Note: This is equivalent to `uint32(bytes4(keccak256("_OWNER_SLOT_NOT")))`.*


```solidity
uint256 private constant _ROLE_SLOT_SEED = 0x8b78c6d8;
```


### _ROLE_0

```solidity
uint256 internal constant _ROLE_0 = 1 << 0;
```


### _ROLE_1

```solidity
uint256 internal constant _ROLE_1 = 1 << 1;
```


### _ROLE_2

```solidity
uint256 internal constant _ROLE_2 = 1 << 2;
```


### _ROLE_3

```solidity
uint256 internal constant _ROLE_3 = 1 << 3;
```


### _ROLE_4

```solidity
uint256 internal constant _ROLE_4 = 1 << 4;
```


### _ROLE_5

```solidity
uint256 internal constant _ROLE_5 = 1 << 5;
```


### _ROLE_6

```solidity
uint256 internal constant _ROLE_6 = 1 << 6;
```


### _ROLE_7

```solidity
uint256 internal constant _ROLE_7 = 1 << 7;
```


### _ROLE_8

```solidity
uint256 internal constant _ROLE_8 = 1 << 8;
```


### _ROLE_9

```solidity
uint256 internal constant _ROLE_9 = 1 << 9;
```


### _ROLE_10

```solidity
uint256 internal constant _ROLE_10 = 1 << 10;
```


### _ROLE_11

```solidity
uint256 internal constant _ROLE_11 = 1 << 11;
```


### _ROLE_12

```solidity
uint256 internal constant _ROLE_12 = 1 << 12;
```


### _ROLE_13

```solidity
uint256 internal constant _ROLE_13 = 1 << 13;
```


### _ROLE_14

```solidity
uint256 internal constant _ROLE_14 = 1 << 14;
```


### _ROLE_15

```solidity
uint256 internal constant _ROLE_15 = 1 << 15;
```


### _ROLE_16

```solidity
uint256 internal constant _ROLE_16 = 1 << 16;
```


### _ROLE_17

```solidity
uint256 internal constant _ROLE_17 = 1 << 17;
```


### _ROLE_18

```solidity
uint256 internal constant _ROLE_18 = 1 << 18;
```


### _ROLE_19

```solidity
uint256 internal constant _ROLE_19 = 1 << 19;
```


### _ROLE_20

```solidity
uint256 internal constant _ROLE_20 = 1 << 20;
```


### _ROLE_21

```solidity
uint256 internal constant _ROLE_21 = 1 << 21;
```


### _ROLE_22

```solidity
uint256 internal constant _ROLE_22 = 1 << 22;
```


### _ROLE_23

```solidity
uint256 internal constant _ROLE_23 = 1 << 23;
```


### _ROLE_24

```solidity
uint256 internal constant _ROLE_24 = 1 << 24;
```


### _ROLE_25

```solidity
uint256 internal constant _ROLE_25 = 1 << 25;
```


### _ROLE_26

```solidity
uint256 internal constant _ROLE_26 = 1 << 26;
```


### _ROLE_27

```solidity
uint256 internal constant _ROLE_27 = 1 << 27;
```


### _ROLE_28

```solidity
uint256 internal constant _ROLE_28 = 1 << 28;
```


### _ROLE_29

```solidity
uint256 internal constant _ROLE_29 = 1 << 29;
```


### _ROLE_30

```solidity
uint256 internal constant _ROLE_30 = 1 << 30;
```


### _ROLE_31

```solidity
uint256 internal constant _ROLE_31 = 1 << 31;
```


### _ROLE_32

```solidity
uint256 internal constant _ROLE_32 = 1 << 32;
```


### _ROLE_33

```solidity
uint256 internal constant _ROLE_33 = 1 << 33;
```


### _ROLE_34

```solidity
uint256 internal constant _ROLE_34 = 1 << 34;
```


### _ROLE_35

```solidity
uint256 internal constant _ROLE_35 = 1 << 35;
```


### _ROLE_36

```solidity
uint256 internal constant _ROLE_36 = 1 << 36;
```


### _ROLE_37

```solidity
uint256 internal constant _ROLE_37 = 1 << 37;
```


### _ROLE_38

```solidity
uint256 internal constant _ROLE_38 = 1 << 38;
```


### _ROLE_39

```solidity
uint256 internal constant _ROLE_39 = 1 << 39;
```


### _ROLE_40

```solidity
uint256 internal constant _ROLE_40 = 1 << 40;
```


### _ROLE_41

```solidity
uint256 internal constant _ROLE_41 = 1 << 41;
```


### _ROLE_42

```solidity
uint256 internal constant _ROLE_42 = 1 << 42;
```


### _ROLE_43

```solidity
uint256 internal constant _ROLE_43 = 1 << 43;
```


### _ROLE_44

```solidity
uint256 internal constant _ROLE_44 = 1 << 44;
```


### _ROLE_45

```solidity
uint256 internal constant _ROLE_45 = 1 << 45;
```


### _ROLE_46

```solidity
uint256 internal constant _ROLE_46 = 1 << 46;
```


### _ROLE_47

```solidity
uint256 internal constant _ROLE_47 = 1 << 47;
```


### _ROLE_48

```solidity
uint256 internal constant _ROLE_48 = 1 << 48;
```


### _ROLE_49

```solidity
uint256 internal constant _ROLE_49 = 1 << 49;
```


### _ROLE_50

```solidity
uint256 internal constant _ROLE_50 = 1 << 50;
```


## Functions
### _setRoles

*Overwrite the roles directly without authorization guard.*


```solidity
function _setRoles(address user, uint256 roles) internal virtual;
```

### _updateRoles

*Updates the roles directly without authorization guard.
If `on` is true, each set bit of `roles` will be turned on,
otherwise, each set bit of `roles` will be turned off.*


```solidity
function _updateRoles(address user, uint256 roles, bool on) internal virtual;
```

### _grantRoles

*Grants the roles directly without authorization guard.
Each bit of `roles` represents the role to turn on.*


```solidity
function _grantRoles(address user, uint256 roles) internal virtual;
```

### _removeRoles

*Removes the roles directly without authorization guard.
Each bit of `roles` represents the role to turn off.*


```solidity
function _removeRoles(address user, uint256 roles) internal virtual;
```

### _checkRoles

*Throws if the sender does not have any of the `roles`.*


```solidity
function _checkRoles(uint256 roles) internal view virtual;
```

### _checkOwnerOrRoles

*Throws if the sender is not the owner,
and does not have any of the `roles`.
Checks for ownership first, then lazily checks for roles.*


```solidity
function _checkOwnerOrRoles(uint256 roles) internal view virtual;
```

### _checkRolesOrOwner

*Throws if the sender does not have any of the `roles`,
and is not the owner.
Checks for roles first, then lazily checks for ownership.*


```solidity
function _checkRolesOrOwner(uint256 roles) internal view virtual;
```

### _rolesFromOrdinals

*Convenience function to return a `roles` bitmap from an array of `ordinals`.
This is meant for frontends like Etherscan, and is therefore not fully optimized.
Not recommended to be called on-chain.
Made internal to conserve bytecode. Wrap it in a public function if needed.*


```solidity
function _rolesFromOrdinals(uint8[] memory ordinals) internal pure returns (uint256 roles);
```

### _ordinalsFromRoles

*Convenience function to return an array of `ordinals` from the `roles` bitmap.
This is meant for frontends like Etherscan, and is therefore not fully optimized.
Not recommended to be called on-chain.
Made internal to conserve bytecode. Wrap it in a public function if needed.*


```solidity
function _ordinalsFromRoles(uint256 roles) internal pure returns (uint8[] memory ordinals);
```

### grantRoles

*Allows the owner to grant `user` `roles`.
If the `user` already has a role, then it will be an no-op for the role.*


```solidity
function grantRoles(address user, uint256 roles) public payable virtual onlyOwner;
```

### revokeRoles

*Allows the owner to remove `user` `roles`.
If the `user` does not have a role, then it will be an no-op for the role.*


```solidity
function revokeRoles(address user, uint256 roles) public payable virtual onlyOwner;
```

### renounceRoles

*Allow the caller to remove their own roles.
If the caller does not have a role, then it will be an no-op for the role.*


```solidity
function renounceRoles(uint256 roles) public payable virtual;
```

### rolesOf

*Returns the roles of `user`.*


```solidity
function rolesOf(address user) public view virtual returns (uint256 roles);
```

### hasAnyRole

*Returns whether `user` has any of `roles`.*


```solidity
function hasAnyRole(address user, uint256 roles) public view virtual returns (bool);
```

### hasAllRoles

*Returns whether `user` has all of `roles`.*


```solidity
function hasAllRoles(address user, uint256 roles) public view virtual returns (bool);
```

### onlyRoles

*Marks a function as only callable by an account with `roles`.*


```solidity
modifier onlyRoles(uint256 roles) virtual;
```

### onlyOwnerOrRoles

*Marks a function as only callable by the owner or by an account
with `roles`. Checks for ownership first, then lazily checks for roles.*


```solidity
modifier onlyOwnerOrRoles(uint256 roles) virtual;
```

### onlyRolesOrOwner

*Marks a function as only callable by an account with `roles`
or the owner. Checks for roles first, then lazily checks for ownership.*


```solidity
modifier onlyRolesOrOwner(uint256 roles) virtual;
```

## Events
### RolesUpdated
*The `user`'s roles is updated to `roles`.
Each bit of `roles` represents whether the role is set.*


```solidity
event RolesUpdated(address indexed user, uint256 indexed roles);
```

