# MultiFacetProxy
[Git Source](https://github.com/VerisLabs/KAM/blob/9795d1f125ce213b0546f9362ce72f5e0331817f/src/base/MultiFacetProxy.sol)

**Inherits:**
[Proxy](/src/abstracts/Proxy.sol/abstract.Proxy.md), OwnableRoles

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

Returns the MultiFacetProxy storage struct using ERC-7201 pattern


```solidity
function _getMultiFacetProxyStorage() internal pure returns (MultiFacetProxyStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`MultiFacetProxyStorage`|Storage reference for MultiFacetProxy state variables|


### __MultiFacetProxy__init

Initializes the proxy contract

*Can only be called once during initialization*


```solidity
function __MultiFacetProxy__init(uint256 _proxyAdminRole_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_proxyAdminRole_`|`uint256`|The proxy admin role|


### _proxyAdminRole

Returns the proxy admin role


```solidity
function _proxyAdminRole() internal view returns (uint256 role);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`role`|`uint256`|The proxy admin role|


### addFunction

Adds a function selector mapping to an implementation address

*Only callable by admin role*


```solidity
function addFunction(bytes4 selector, address implementation, bool forceOverride) public onlyRoles(_proxyAdminRole());
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`selector`|`bytes4`|The function selector to add|
|`implementation`|`address`|The implementation contract address|
|`forceOverride`|`bool`|If true, allows overwriting existing mappings|


### addFunctions

Adds multiple function selector mappings to an implementation


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
function removeFunction(bytes4 selector) public onlyRoles(_proxyAdminRole());
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

```solidity
struct MultiFacetProxyStorage {
    mapping(bytes4 => address) selectorToImplementation;
    uint256 proxyAdminRole;
}
```

