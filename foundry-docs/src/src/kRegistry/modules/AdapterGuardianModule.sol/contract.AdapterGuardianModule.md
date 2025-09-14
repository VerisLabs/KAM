# AdapterGuardianModule
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/kRegistry/modules/AdapterGuardianModule.sol)

**Inherits:**
[IAdapterGuardian](/src/interfaces/modules/IAdapterGuardian.sol/interface.IAdapterGuardian.md), [kBaseRoles](/src/base/kBaseRoles.sol/contract.kBaseRoles.md)

Module for managing adapter permissions and parameter checking in kRegistry

*Inherits from kBaseRoles for role-based access control*


## State Variables
### ADAPTERGUARDIANMODULE_STORAGE_LOCATION

```solidity
bytes32 private constant ADAPTERGUARDIANMODULE_STORAGE_LOCATION =
    0x82abb426e3b44c537e85e43273337421a20a3ea37d7e65190cbdd1a7dbb77100;
```


## Functions
### _getAdapterGuardianModuleStorage

Retrieves the AdapterGuardianModule storage struct from its designated storage slot

*Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
storage variables in future upgrades without affecting existing storage layout.*


```solidity
function _getAdapterGuardianModuleStorage() private pure returns (AdapterGuardianModuleStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`AdapterGuardianModuleStorage`|The AdapterGuardianModuleStorage struct reference for state modifications|


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


### selectors

Returns the selectors for functions in this module


```solidity
function selectors() public pure returns (bytes4[] memory moduleSelectors);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`moduleSelectors`|`bytes4[]`|Array of function selectors|


## Structs
### AdapterGuardianModuleStorage
Storage structure for AdapterGuardianModule using ERC-7201 namespaced storage pattern

*This structure maintains adapter permissions and parameter checkers*

**Note:**
storage-location: erc7201:kam.storage.AdapterGuardianModule


```solidity
struct AdapterGuardianModuleStorage {
    mapping(address => mapping(address => mapping(bytes4 => bool))) adapterAllowedSelectors;
    mapping(address => mapping(address => mapping(bytes4 => address))) adapterParametersChecker;
}
```

