# MultiFacetProxy
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/base/MultiFacetProxy.sol)

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

*Returns the MultiFacetProxy storage pointer*


```solidity
function _getMultiFacetProxyStorage() internal pure returns (MultiFacetProxyStorage storage $);
```

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
**Note:**
storage-location: erc7201:kam.storage.MultiFacetProxy


```solidity
struct MultiFacetProxyStorage {
    mapping(bytes4 => address) selectorToImplementation;
}
```

