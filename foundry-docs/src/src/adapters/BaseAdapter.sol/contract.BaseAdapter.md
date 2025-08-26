# BaseAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/d9f3bcfb40b15ca7c34b1d780c519322be4b7590/src/adapters/BaseAdapter.sol)

**Inherits:**
OwnableRoles, ReentrancyGuardTransient

Abstract base contract for all protocol adapters

*Provides common functionality and virtual balance tracking for external strategy integrations*


## State Variables
### ADMIN_ROLE

```solidity
uint256 internal constant ADMIN_ROLE = _ROLE_0;
```


### EMERGENCY_ADMIN_ROLE

```solidity
uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
```


### K_MINTER

```solidity
bytes32 internal constant K_MINTER = keccak256("K_MINTER");
```


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
function __BaseAdapter_init(
    address registry_,
    address owner_,
    address admin_,
    string memory name_,
    string memory version_
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|
|`owner_`|`address`|Address of the owner|
|`admin_`|`address`|Address of the admin|
|`name_`|`string`|Human readable name for this adapter|
|`version_`|`string`|Version string for this adapter|


### _registry

Returns the registry contract interface


```solidity
function _registry() internal view returns (IkRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IkRegistry`|IkRegistry interface for registry interaction|


### _getKAssetRouter

Gets the kAssetRouter singleton contract address


```solidity
function _getKAssetRouter() internal view returns (address router);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The kAssetRouter contract address|


### _isRelayer

Checks if an address is a relayer


```solidity
function _isRelayer() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a relayer|


### _getKTokenForAsset

Gets the kToken address for a given asset

*Reverts if asset not supported*


```solidity
function _getKTokenForAsset(address asset) internal view returns (address kToken);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`kToken`|`address`|The corresponding kToken address|


### _getVaultAssets

Gets the asset managed by a vault

*Reverts if vault not registered*


```solidity
function _getVaultAssets(address vault) internal view returns (address[] memory assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`address[]`|The asset address managed by the vault|


### registered

Returns whether this adapter is registered


```solidity
function registered() public view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if adapter is registered and active|


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


### onlyKAssetRouter

Restricts function access to kAssetRouter only


```solidity
modifier onlyKAssetRouter();
```

### onlyRelayer

Restricts function access to the relayer


```solidity
modifier onlyRelayer();
```

### whenRegistered

Ensures the adapter is registered and active


```solidity
modifier whenRegistered();
```

## Errors
### OnlyKAssetRouter

```solidity
error OnlyKAssetRouter();
```

### ContractNotFound

```solidity
error ContractNotFound(bytes32 identifier);
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidRegistry

```solidity
error InvalidRegistry();
```

### AssetNotSupported

```solidity
error AssetNotSupported(address asset);
```

### InvalidAmount

```solidity
error InvalidAmount();
```

### InvalidAsset

```solidity
error InvalidAsset();
```

## Structs
### BaseAdapterStorage
**Note:**
storage-location: erc7201:kam.storage.BaseAdapter


```solidity
struct BaseAdapterStorage {
    address registry;
    bool registered;
    bool initialized;
    string name;
    string version;
}
```

