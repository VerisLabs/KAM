# MultiFacetProxy
<<<<<<< HEAD
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/base/MultiFacetProxy.sol)
=======
[Git Source](https://github.com/VerisLabs/KAM/blob/e655bf086c79b14fd5ccde0a4ddfa1609e381102/src/base/MultiFacetProxy.sol)
>>>>>>> main

**Inherits:**
[Proxy](/src/abstracts/Proxy.sol/abstract.Proxy.md)

A proxy contract that can route function calls to different implementation contracts

*Inherits from Base and OpenZeppelin's Proxy contract*


## State Variables
### MULTIFACET_PROXY_STORAGE_LOCATION

```solidity
bytes32 internal constant MULTIFACET_PROXY_STORAGE_LOCATION =
    0xfeaf205b5229ea10e902c7b89e4768733c756362b2becb0bfd65a97f71b02d00;
```


## Functions
### _getMultiFacetProxyStorage

<<<<<<< HEAD
*Returns the MultiFacetProxy storage pointer*
=======
Returns the MultiFacetProxy storage struct using ERC-7201 pattern
>>>>>>> main


```solidity
function _getMultiFacetProxyStorage() internal pure returns (MultiFacetProxyStorage storage $);
```
<<<<<<< HEAD
=======
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`MultiFacetProxyStorage`|Storage reference for MultiFacetProxy state variables|

>>>>>>> main

### addFunction

Adds a function selector mapping to an implementation address

*Only callable by admin role*


```solidity
function addFunction(bytes4 selector, address implementation, bool forceOverride) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector to add|
|`implementation`|`address`|The implementation contract address|
|`forceOverride`|`bool`|If true, allows overwriting existing mappings|


### addFunctions

Adds multiple function selector mappings to an implementation

*Only callable by admin role*


```solidity
function addFunctions(bytes4[] calldata selectors, address implementation, bool forceOverride) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selectors`|`bytes4[]`|Array of function selectors to add|
|`implementation`|`address`|The implementation contract address|
|`forceOverride`|`bool`|If true, allows overwriting existing mappings|


### removeFunction

Removes a function selector mapping

*Only callable by admin role*


```solidity
function removeFunction(bytes4 selector) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector to remove|


### removeFunctions

Removes multiple function selector mappings


```solidity
function removeFunctions(bytes4[] calldata selectors) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selectors`|`bytes4[]`|Array of function selectors to remove|


### _authorizeModifyFunctions

*Authorize the sender to modify functions*


```solidity
function _authorizeModifyFunctions(address sender) internal virtual;
```

### _implementation

Returns the implementation address for a function selector

*Required override from OpenZeppelin Proxy contract*


```solidity
function _implementation() internal view override returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The implementation contract address|


## Structs
### MultiFacetProxyStorage
<<<<<<< HEAD
**Note:**
storage-location: erc7201:kam.storage.MultiFacetProxy

=======
>>>>>>> main

```solidity
struct MultiFacetProxyStorage {
    mapping(bytes4 => address) selectorToImplementation;
}
```

