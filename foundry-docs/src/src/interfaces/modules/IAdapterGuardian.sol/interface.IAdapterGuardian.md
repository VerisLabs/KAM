# IAdapterGuardian
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/interfaces/modules/IAdapterGuardian.sol)


## Functions
### setAdapterAllowedSelector

Set whether a selector is allowed for an adapter on a target contract

*Only callable by ADMIN_ROLE*


```solidity
function setAdapterAllowedSelector(address adapter, address target, bytes4 selector, bool isAllowed) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|
|`isAllowed`|`bool`|Whether the selector is allowed|


### setAdapterParametersChecker

Set a parameter checker for an adapter selector

*Only callable by ADMIN_ROLE*


```solidity
function setAdapterParametersChecker(
    address adapter,
    address target,
    bytes4 selector,
    address parametersChecker
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|
|`parametersChecker`|`address`|The parameter checker contract address (0x0 to remove)|


### authorizeAdapterCall

Check if an adapter is authorized to call a specific function on a target


```solidity
function authorizeAdapterCall(address target, bytes4 selector, bytes calldata params) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|
|`params`|`bytes`|The function parameters|


### isAdapterSelectorAllowed

Check if a selector is allowed for an adapter


```solidity
function isAdapterSelectorAllowed(address adapter, address target, bytes4 selector) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the selector is allowed|


### getAdapterParametersChecker

Get the parameter checker for an adapter selector


```solidity
function getAdapterParametersChecker(
    address adapter,
    address target,
    bytes4 selector
)
    external
    view
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The parameter checker address (address(0) if none)|


## Events
### AdapterRegistered
Emitted when an adapter is registered or unregistered


```solidity
event AdapterRegistered(address indexed adapter, bool registered);
```

### SelectorAllowed
Emitted when a selector is allowed or disallowed for an adapter


```solidity
event SelectorAllowed(address indexed adapter, address indexed target, bytes4 indexed selector, bool allowed);
```

### ParametersCheckerSet
Emitted when a parameter checker is set for an adapter selector


```solidity
event ParametersCheckerSet(
    address indexed adapter, address indexed target, bytes4 indexed selector, address parametersChecker
);
```

