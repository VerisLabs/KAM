# CallContextChecker
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/vendor/solady/utils/UUPSUpgradeable.sol)

**Author:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/CallContextChecker.sol)

Call context checker mixin.


## State Variables
### __self
*For checking if the context is a delegate call.
Note: To enable use cases with an immutable default implementation in the bytecode,
(see: ERC6551Proxy), we don't require that the proxy address must match the
value stored in the implementation slot, which may not be initialized.*


```solidity
uint256 private immutable __self = uint256(uint160(address(this)));
```


## Functions
### _onEIP7702Authority

*Returns whether the current call context is on a EIP7702 authority
(i.e. externally owned account).*


```solidity
function _onEIP7702Authority() internal view virtual returns (bool result);
```

### _selfImplementation

*Returns the implementation of this contract.*


```solidity
function _selfImplementation() internal view virtual returns (address);
```

### _onImplementation

*Returns whether the current call context is on the implementation itself.*


```solidity
function _onImplementation() internal view virtual returns (bool);
```

### _checkOnlyEIP7702Authority

*Requires that the current call context is performed via a EIP7702 authority.*


```solidity
function _checkOnlyEIP7702Authority() internal view virtual;
```

### _checkOnlyProxy

*Requires that the current call context is performed via a proxy.*


```solidity
function _checkOnlyProxy() internal view virtual;
```

### _checkNotDelegated

*Requires that the current call context is NOT performed via a proxy.
This is the opposite of `checkOnlyProxy`.*


```solidity
function _checkNotDelegated() internal view virtual;
```

### onlyEIP7702Authority

*Requires that the current call context is performed via a EIP7702 authority.*


```solidity
modifier onlyEIP7702Authority() virtual;
```

### onlyProxy

*Requires that the current call context is performed via a proxy.*


```solidity
modifier onlyProxy() virtual;
```

### notDelegated

*Requires that the current call context is NOT performed via a proxy.
This is the opposite of `onlyProxy`.*


```solidity
modifier notDelegated() virtual;
```

### _revertUnauthorizedCallContext


```solidity
function _revertUnauthorizedCallContext() private pure;
```

## Errors
### UnauthorizedCallContext
*The call is from an unauthorized call context.*


```solidity
error UnauthorizedCallContext();
```

