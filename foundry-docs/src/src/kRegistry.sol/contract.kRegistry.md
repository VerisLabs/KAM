# kRegistry
[Git Source](https://github.com/VerisLabs/KAM/blob/26924a026af1e1620e830002fd931ff7e42525b6/src/kRegistry.sol)

**Inherits:**
[IkRegistry](/src/interfaces/IkRegistry.sol/interface.IkRegistry.md), [Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [OptimizedOwnableRoles](/src/libraries/OptimizedOwnableRoles.sol/abstract.OptimizedOwnableRoles.md)

Central registry for KAM protocol contracts

*Manages singleton contracts, vault registration, asset support, and kToken mapping*


## State Variables
### ADMIN_ROLE
Admin role for authorized operations


```solidity
uint256 internal constant ADMIN_ROLE = _ROLE_0;
```


### EMERGENCY_ADMIN_ROLE
Emergency admin role for emergency operations


```solidity
uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
```


### GUARDIAN_ROLE
Guardian role as a circuit breaker for settlement proposals


```solidity
uint256 internal constant GUARDIAN_ROLE = _ROLE_2;
```


### RELAYER_ROLE
Relayer role for external vaults


```solidity
uint256 internal constant RELAYER_ROLE = _ROLE_3;
```


### INSTITUTION_ROLE
Reserved role for special whitelisted addresses


```solidity
uint256 internal constant INSTITUTION_ROLE = _ROLE_4;
```


### VENDOR_ROLE
Vendor role for vendor vaults


```solidity
uint256 internal constant VENDOR_ROLE = _ROLE_5;
```


### K_MINTER
kMinter key


```solidity
bytes32 public constant K_MINTER = keccak256("K_MINTER");
```


### K_ASSET_ROUTER
kAssetRouter key


```solidity
bytes32 public constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### USDC
USDC key


```solidity
bytes32 public constant USDC = keccak256("USDC");
```


### WBTC
WBTC key


```solidity
bytes32 public constant WBTC = keccak256("WBTC");
```


### KREGISTRY_STORAGE_LOCATION

```solidity
bytes32 private constant KREGISTRY_STORAGE_LOCATION = 0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;
```


## Functions
### _getkRegistryStorage

*Returns the kRegistry storage pointer*


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
function initialize(
    address owner_,
    address admin_,
    address emergencyAdmin_,
    address guardian_,
    address relayer_,
    address treasury_
)
    external
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|Contract owner address|
|`admin_`|`address`|Admin role recipient|
|`emergencyAdmin_`|`address`|Emergency admin role recipient|
|`guardian_`|`address`|Guardian role recipient|
|`relayer_`|`address`|Relayer role recipient|
|`treasury_`|`address`|Treasury address|


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


### setSingletonContract

Set a singleton contract address

*Only callable by ADMIN_ROLE*


```solidity
function setSingletonContract(bytes32 id, address contractAddress) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|Contract identifier (e.g., K_MINTER, K_BATCH)|
|`contractAddress`|`address`|Address of the singleton contract|


### grantInstitutionRole

grant the institution role to a given address

*Only callable by VENDOR_ROLE*


```solidity
function grantInstitutionRole(address institution_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`institution_`|`address`|the institution address|


### grantVendorRole

grant the vendor role to a given address

*Only callable by ADMIN_ROLE*


```solidity
function grantVendorRole(address vendor_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vendor_`|`address`|the vendor address|


### grantRelayerRole

grant the relayer role to a given address

*Only callable by ADMIN_ROLE*


```solidity
function grantRelayerRole(address relayer_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayer_`|`address`|the relayer address|


### registerAsset

Register support for a new asset and its corresponding kToken

*Only callable by ADMIN_ROLE, establishes bidirectional mapping*


```solidity
function registerAsset(
    string memory name_,
    string memory symbol_,
    address asset,
    bytes32 id
)
    external
    payable
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`||
|`symbol_`|`string`||
|`asset`|`address`|Underlying asset address (e.g., USDC, WBTC)|
|`id`|`bytes32`||


### registerVault

Register a new vault in the protocol

*Only callable by ADMIN_ROLE, sets as primary if first of its type*


```solidity
function registerVault(address vault, VaultType type_, address asset) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|Vault contract address|
|`type_`|`VaultType`|Type of vault (MINTER, DN, ALPHA, BETA)|
|`asset`|`address`|Underlying asset the vault manages|


### removeVault


```solidity
function removeVault(address vault) external payable;
```

### setTreasury

Sets the treasury address


```solidity
function setTreasury(address treasury_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury_`|`address`|The new treasury address|


### registerAdapter

Registers an adapter for a specific vault


```solidity
function registerAdapter(address vault, address adapter) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`adapter`|`address`|The adapter address|


### removeAdapter

Removes an adapter for a specific vault


```solidity
function removeAdapter(address vault, address adapter) external payable;
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


### getAllVaults

Get all vaults registered in the protocol


```solidity
function getAllVaults() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of vault addresses|


### getTreasury

Get the treasury address


```solidity
function getTreasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The treasury address|


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


### isAdmin

Check if caller is the Admin


```solidity
function isAdmin(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is a Admin|


### isEmergencyAdmin

Check if caller is the EmergencyAdmin


```solidity
function isEmergencyAdmin(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is a EmergencyAdmin|


### isGuardian

Check if caller is the Guardian


```solidity
function isGuardian(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is a Guardian|


### isRelayer

Check if the caller is the relayer


```solidity
function isRelayer(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is the relayer|


### isInstitution

Check if the caller is a institution


```solidity
function isInstitution(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is a institution|


### isVendor

Check if the caller is a vendor


```solidity
function isVendor(address user) external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the caller is a vendor|


### isAsset

Check if an asset is supported


```solidity
function isAsset(address asset) external view returns (bool);
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
function isAdapterRegistered(address vault, address adapter) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`||
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


### _hasRole

check if the user has the given role


```solidity
function _hasRole(address user, uint256 role_) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Wether the caller have the given role|


### _tryGetAssetDecimals

*Helper function to get the decimals of the underlying asset.
Useful for setting the return value of `_underlyingDecimals` during initialization.
If the retrieval succeeds, `success` will be true, and `result` will hold the result.
Otherwise, `success` will be false, and `result` will be zero.
Example usage:
```
(bool success, uint8 result) = _tryGetAssetDecimals(underlying);
_decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
```*


```solidity
function _tryGetAssetDecimals(address underlying) internal view returns (bool success, uint8 result);
```

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
    OptimizedAddressEnumerableSetLib.AddressSet supportedAssets;
    OptimizedAddressEnumerableSetLib.AddressSet allVaults;
    address treasury;
    mapping(bytes32 => address) singletonContracts;
    mapping(address => uint8 vaultType) vaultType;
    mapping(address => mapping(uint8 vaultType => address)) assetToVault;
    mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAsset;
    mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultsByAsset;
    mapping(bytes32 => address) singletonAssets;
    mapping(address => address) assetToKToken;
    mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAdapters;
    mapping(address => bool) registeredAdapters;
}
```

