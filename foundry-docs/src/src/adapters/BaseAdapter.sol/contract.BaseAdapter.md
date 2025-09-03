# BaseAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/77168a37e8e40e14b0fd1320a6e90f9203339144/src/adapters/BaseAdapter.sol)

**Inherits:**
ReentrancyGuardTransient

Abstract base contract for all protocol adapters

*Provides common functionality and virtual balance tracking for external strategy integrations*


## State Variables
### K_ASSET_ROUTER

```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### BASE_ADAPTER_STORAGE_LOCATION

```solidity
bytes32 private constant BASE_ADAPTER_STORAGE_LOCATION =
    0x5547882c17743d50a538cd94a34f6308d65f7005fe26b376dcedda44d3aab800;
```


## Functions
### _getBaseAdapterStorage


```solidity
function _getBaseAdapterStorage() internal pure returns (BaseAdapterStorage storage $);
```

### __BaseAdapter_init

Initializes the base adapter


```solidity
function __BaseAdapter_init(address registry_, string memory name_, string memory version_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|
|`name_`|`string`|Human readable name for this adapter|
|`version_`|`string`|Version string for this adapter|


### registry

Returns the registry contract address

*Reverts if contract not initialized*


```solidity
function registry() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The kRegistry contract address|


### _registry

Returns the registry contract interface


```solidity
function _registry() internal view returns (IkRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IkRegistry`|IkRegistry interface for registry interaction|


### rescueAssets

rescues locked assets (ETH or ERC20) in the contract


```solidity
function rescueAssets(address asset_, address to_, uint256 amount_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|the asset to rescue (use address(0) for ETH)|
|`to_`|`address`|the address that will receive the assets|
|`amount_`|`uint256`|the amount to rescue|


### name

Returns the adapter's name


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Human readable adapter name|


### version

Returns the adapter's version


```solidity
function version() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version string|


### _isAdmin

Checks if an address is a admin


```solidity
function _isAdmin(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a admin|


### _isKAssetRouter

Gets the kMinter singleton contract address

*Reverts if kMinter not set in registry*


```solidity
function _isKAssetRouter(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|minter The kMinter contract address|


### _isAsset

Checks if an asset is registered


```solidity
function _isAsset(address asset) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the asset is registered|


## Events
### RescuedAssets

```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

### RescuedETH

```solidity
event RescuedETH(address indexed asset, uint256 amount);
```

## Structs
### BaseAdapterStorage
**Note:**
storage-location: erc7201:kam.storage.BaseAdapter


```solidity
struct BaseAdapterStorage {
    address registry;
    bool initialized;
    string name;
    string version;
}
```

