# kRegistry
[Git Source](https://github.com/VerisLabs/KAM/blob/d9f3bcfb40b15ca7c34b1d780c519322be4b7590/src/kRegistry.sol)

**Inherits:**
[IkRegistry](/src/interfaces/IkRegistry.sol/interface.IkRegistry.md), Initializable, UUPSUpgradeable, OwnableRoles

Central registry for KAM protocol contracts

*Manages singleton contracts, vault registration, asset support, and kToken mapping*


## State Variables
### ADMIN_ROLE

```solidity
uint256 internal constant ADMIN_ROLE = _ROLE_0;
```


### RELAYER_ROLE

```solidity
uint256 internal constant RELAYER_ROLE = _ROLE_1;
```


### GUARDIAN_ROLE

```solidity
uint256 internal constant GUARDIAN_ROLE = _ROLE_2;
```


### K_MINTER

```solidity
bytes32 public constant K_MINTER = keccak256("K_MINTER");
```


### K_ASSET_ROUTER

```solidity
bytes32 public constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### USDC

```solidity
bytes32 public constant USDC = keccak256("USDC");
```


### WBTC

```solidity
bytes32 public constant WBTC = keccak256("WBTC");
```


### KREGISTRY_STORAGE_LOCATION

```solidity
bytes32 private constant KREGISTRY_STORAGE_LOCATION = 0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;
```


## Functions
### _getkRegistryStorage


```solidity
function _getkRegistryStorage() private pure returns (kRegistryStorage storage $);
```

### constructor

Disables initializers to prevent implementation contract initialization


```solidity
constructor();
```

### initialize

Initializes the kRegistry contract


```solidity
function initialize(address owner_, address admin_, address relayer_, address guardian_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|Contract owner address|
|`admin_`|`address`|Admin role recipient|
|`relayer_`|`address`||
|`guardian_`|`address`||


### setSingletonContract

Set a singleton contract address

*Only callable by ADMIN_ROLE*


```solidity
function setSingletonContract(bytes32 id, address contractAddress) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|Contract identifier (e.g., K_MINTER, K_BATCH)|
|`contractAddress`|`address`|Address of the singleton contract|


### registerAsset

Register support for a new asset and its corresponding kToken

*Only callable by ADMIN_ROLE, establishes bidirectional mapping*


```solidity
function registerAsset(address asset, bytes32 id) external onlyRoles(ADMIN_ROLE) returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Underlying asset address (e.g., USDC, WBTC)|
|`id`|`bytes32`||


### registerVault

Register a new vault in the protocol

*Only callable by ADMIN_ROLE, sets as primary if first of its type*


```solidity
function registerVault(address vault, VaultType type_, address asset) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault contract address|
|`type_`|`VaultType`|Type of vault (MINTER, DN, ALPHA, BETA)|
|`asset`|`address`|Underlying asset the vault manages|


### registerAdapter

Registers an adapter for a specific vault


```solidity
function registerAdapter(address vault, address adapter) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`adapter`|`address`|The adapter address|


### removeAdapter

Removes an adapter for a specific vault


```solidity
function removeAdapter(address vault, address adapter) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`adapter`|`address`||


### getContractById

Get a singleton contract address by its identifier

*Reverts if contract not set*


```solidity
function getContractById(bytes32 id) public view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|Contract identifier (e.g., K_MINTER, K_BATCH)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Contract address|


### getAssetById

Get a singleton asset address by its identifier

*Reverts if asset not set*


```solidity
function getAssetById(bytes32 id) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|Asset identifier (e.g., USDC, WBTC)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Asset address|


### getAllAssets

Get all supported assets


```solidity
function getAllAssets() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of supported asset addresses|


### getCoreContracts

Get all core singleton contracts at once


```solidity
function getCoreContracts() external view returns (address, address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|kMinter The kMinter contract address|
|`<none>`|`address`|kAssetRouter The kAssetRouter contract address|


### getVaultsByAsset

Get all vaults registered for a specific asset


```solidity
function getVaultsByAsset(address asset) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of vault addresses|


### getVaultByAssetAndType

Get a vault address by asset and vault type

*Reverts if vault not found*


```solidity
function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address|
|`vaultType`|`uint8`|Vault type|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Vault address|


### getVaultType

Get the type of a vault


```solidity
function getVaultType(address vault) external view returns (uint8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|Vault type|


### isRelayer

Check if the caller is the relayer


```solidity
function isRelayer(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is the relayer|


### isGuardian

Check if caller is the Guardian


```solidity
function isGuardian(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is a Guardian|


### isRegisteredAsset

Check if an asset is supported


```solidity
function isRegisteredAsset(address asset) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the asset is supported|


### isVault

Check if a vault is registered


```solidity
function isVault(address vault) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the vault is registered|


### isSingletonContract

Check if a contract is a singleton contract


```solidity
function isSingletonContract(address contractAddress) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractAddress`|`address`|Contract address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the contract is a singleton contract|


### getAdapters

Get the adapter for a specific vault


```solidity
function getAdapters(address vault) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Adapter address (address(0) if none set)|


### isAdapterRegistered

Check if an adapter is registered


```solidity
function isAdapterRegistered(address adapter) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|Adapter address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if adapter is registered|


### getVaultAssets

Get the asset for a specific vault


```solidity
function getVaultAssets(address vault) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Asset address that the vault manages|


### assetToKToken

Get the kToken for a specific asset


```solidity
function assetToKToken(address asset) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|KToken address|


### _authorizeUpgrade

Authorizes contract upgrades

*Only callable by contract owner*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|New implementation address|


### receive

Receive ETH (for gas refunds, etc.)


```solidity
receive() external payable;
```

### contractName

Returns the contract name


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Contract name|


### contractVersion

Returns the contract version


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Contract version|


## Structs
### kRegistryStorage
**Note:**
storage-location: erc7201:kam.storage.kRegistry


```solidity
struct kRegistryStorage {
    mapping(bytes32 => address) singletonContracts;
    mapping(address => bool) isSingletonContract;
    mapping(address => bool) isVault;
    mapping(address => uint8 vaultType) vaultType;
    mapping(address => mapping(uint8 vaultType => address)) assetToVault;
    mapping(address => EnumerableSetLib.AddressSet) vaultAsset;
    EnumerableSetLib.AddressSet allVaults;
    mapping(address => EnumerableSetLib.AddressSet) vaultsByAsset;
    mapping(bytes32 => address) singletonAssets;
    mapping(address => address) assetToKToken;
    mapping(address => bool) isRegisteredAsset;
    EnumerableSetLib.AddressSet supportedAssets;
    mapping(address => EnumerableSetLib.AddressSet) vaultAdapters;
    mapping(address => bool) registeredAdapters;
}
```

