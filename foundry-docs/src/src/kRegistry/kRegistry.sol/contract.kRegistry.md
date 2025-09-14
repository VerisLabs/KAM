# kRegistry
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/kRegistry/kRegistry.sol)

**Inherits:**
[IkRegistry](/src/interfaces/IkRegistry.sol/interface.IkRegistry.md), [kBaseRoles](/src/base/kBaseRoles.sol/contract.kBaseRoles.md), [Initializable](/src/vendor/solady/utils/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/solady/utils/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md), [MultiFacetProxy](/src/base/MultiFacetProxy.sol/abstract.MultiFacetProxy.md)

Central configuration hub and contract registry for the KAM protocol ecosystem

*This contract serves as the protocol's backbone for configuration management and access control. It provides
five critical functions: (1) Singleton contract management - registers and tracks core protocol contracts like
kMinter and kAssetRouter ensuring single source of truth, (2) Asset and kToken management - handles asset
whitelisting, kToken deployment, and maintains bidirectional mappings between underlying assets and their
corresponding kTokens, (3) Vault registry - manages vault registration, classification (DN, ALPHA, BETA, etc.),
and routing logic to direct assets to appropriate vaults based on type and strategy, (4) Role-based access
control - implements a hierarchical permission system with ADMIN, EMERGENCY_ADMIN, GUARDIAN, RELAYER, INSTITUTION,
and VENDOR roles to enforce protocol security, (5) Adapter management - registers and tracks external protocol
adapters per vault enabling yield strategy integrations. The registry uses upgradeable architecture with UUPS
pattern and ERC-7201 namespaced storage to ensure future extensibility while maintaining state consistency.*


## State Variables
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


### MAX_BPS
Maximum basis points (100%)


```solidity
uint256 constant MAX_BPS = 10_000;
```


### KREGISTRY_STORAGE_LOCATION

```solidity
bytes32 private constant KREGISTRY_STORAGE_LOCATION = 0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;
```


## Functions
### _getkRegistryStorage

Retrieves the kRegistry storage struct from its designated storage slot

*Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
storage variables in future upgrades without affecting existing storage layout.*


```solidity
function _getkRegistryStorage() private pure returns (kRegistryStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`kRegistryStorage`|The kRegistryStorage struct reference for state modifications|


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


### setSingletonContract

Registers a core singleton contract in the protocol

*Only callable by ADMIN_ROLE. Ensures single source of truth for protocol contracts.*


```solidity
function setSingletonContract(bytes32 id, address contractAddress) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|Unique contract identifier (e.g., K_MINTER, K_ASSET_ROUTER)|
|`contractAddress`|`address`|Address of the singleton contract|


### grantInstitutionRole

Grants institution role to enable privileged protocol access

*Only callable by VENDOR_ROLE. Institutions gain access to kMinter and other premium features.*


```solidity
function grantInstitutionRole(address institution_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`institution_`|`address`|The address to grant institution privileges|


### grantVendorRole

Grants vendor role for vendor management capabilities

*Only callable by ADMIN_ROLE. Vendors can grant institution roles and manage vendor vaults.*


```solidity
function grantVendorRole(address vendor_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vendor_`|`address`|The address to grant vendor privileges|


### grantRelayerRole

Grants relayer role for external vault operations

*Only callable by ADMIN_ROLE. Relayers manage external vaults and set hurdle rates.*


```solidity
function grantRelayerRole(address relayer_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`relayer_`|`address`|The address to grant relayer privileges|


### grantManagerRole

Grants manager role for vault adapter operations

*Only callable by ADMIN_ROLE. Relayers manage external vaults and set hurdle rates.*


```solidity
function grantManagerRole(address manager_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`manager_`|`address`|The address to grant manager privileges|


### setTreasury

Sets the treasury address

*Treasury receives protocol fees and serves as emergency fund holder. Only callable by ADMIN_ROLE.*


```solidity
function setTreasury(address treasury_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury_`|`address`|The new treasury address|


### setHurdleRate

Sets the hurdle rate for a specific asset

*Only relayer can set hurdle rates (performance thresholds). Ensures hurdle rate doesn't exceed 100%.
Asset must be registered before setting hurdle rate. Sets minimum performance threshold for yield distribution.*


```solidity
function setHurdleRate(address asset, uint16 hurdleRate) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to set hurdle rate for|
|`hurdleRate`|`uint16`|The hurdle rate in basis points (100 = 1%)|


### rescueAssets

Emergency function to rescue accidentally sent assets (ETH or ERC20) from the contract

*This function provides a recovery mechanism for assets mistakenly sent to the registry. It includes
critical safety checks: (1) Only callable by ADMIN_ROLE to prevent unauthorized access, (2) Cannot rescue
registered protocol assets to prevent draining legitimate funds, (3) Validates amounts and balances.
For ETH rescue, use address(0) as the asset parameter. The function ensures protocol integrity by
preventing rescue of assets that are part of normal protocol operations.*


```solidity
function rescueAssets(address asset_, address to_, uint256 amount_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset address to rescue (use address(0) for ETH)|
|`to_`|`address`|The destination address that will receive the rescued assets|
|`amount_`|`uint256`|The amount of assets to rescue (must not exceed contract balance)|


### setAssetBatchLimits

Set the maximum mint and redeem limits for a given asset

*Only callable by ADMIN_ROLE*


```solidity
function setAssetBatchLimits(address asset_, uint256 maxMintPerBatch_, uint256 maxRedeemPerBatch_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset address|
|`maxMintPerBatch_`|`uint256`|The maximum mint amount per batch|
|`maxRedeemPerBatch_`|`uint256`|The maximum redeem amount per batch|


### registerAsset

Register support for a new asset and its corresponding kToken

*Only callable by ADMIN_ROLE, establishes bidirectional mapping*


```solidity
function registerAsset(
    string memory name_,
    string memory symbol_,
    address asset,
    bytes32 id,
    uint256 maxMintPerBatch,
    uint256 maxRedeemPerBatch
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
|`maxMintPerBatch`|`uint256`||
|`maxRedeemPerBatch`|`uint256`||


### registerVault

Registers a new vault contract in the protocol's vault management system

*This function integrates vaults into the protocol by: (1) Validating the vault isn't already registered,
(2) Verifying the asset is supported by the protocol, (3) Classifying the vault by type for routing,
(4) Establishing vault-asset relationships for both forward and reverse lookups, (5) Setting as primary
vault for the asset-type combination if it's the first registered. The vault type determines routing
logic and strategy selection (DN for institutional, ALPHA/BETA for different risk profiles).
Only callable by ADMIN_ROLE to ensure proper vault vetting and integration.*


```solidity
function registerVault(address vault, VaultType type_, address asset) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault contract address to register|
|`type_`|`VaultType`|The vault classification type (DN, ALPHA, BETA, etc.) determining its role|
|`asset`|`address`|The underlying asset address this vault will manage|


### removeVault

Removes a vault from the protocol registry

*This function deregisters a vault, removing it from the active vault set. This operation should be
used carefully as it affects routing and asset management. Only callable by ADMIN_ROLE to ensure proper
decommissioning procedures are followed. Note that this doesn't clear all vault mappings for gas efficiency.*


```solidity
function removeVault(address vault) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault contract address to remove from the registry|


### registerAdapter

Registers an external protocol adapter for a vault

*Enables yield strategy integrations through external DeFi protocols. Only callable by ADMIN_ROLE.*


```solidity
function registerAdapter(address vault, address asset, address adapter) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address receiving the adapter|
|`asset`|`address`|The vault underlying asset|
|`adapter`|`address`|The adapter contract address|


### removeAdapter

Removes an adapter from a vault's registered adapter set

*This disables a specific external protocol integration for the vault. Only callable by ADMIN_ROLE
to ensure proper risk assessment before removing yield strategies.*


```solidity
function removeAdapter(address vault, address asset, address adapter) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to remove the adapter from|
|`asset`|`address`|The vault underlying asset|
|`adapter`|`address`|The adapter address to remove|


### getMaxMintPerBatch

Gets the max mint per batch for a specific asset


```solidity
function getMaxMintPerBatch(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The max mint per batch|


### getMaxRedeemPerBatch

Gets the max redeem per batch for a specific asset


```solidity
function getMaxRedeemPerBatch(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The max redeem per batch|


### getHurdleRate

Gets the hurdle rate for a specific asset


```solidity
function getHurdleRate(address asset) external view returns (uint16);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The hurdle rate in basis points|


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


### getAllAssets

Gets all protocol-supported asset addresses

*Returns the complete whitelist of supported underlying assets.*


```solidity
function getAllAssets() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of all supported asset addresses|


### getAllVaults

Gets all registered vaults in the protocol

*Returns array of all vault addresses that have been registered through addVault().
Includes both active and inactive vaults. Used for protocol monitoring and management operations.*


```solidity
function getAllVaults() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of all registered vault addresses|


### getTreasury

Gets the protocol treasury address

*Treasury receives protocol fees and serves as emergency fund holder.*


```solidity
function getTreasury() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The treasury address|


### getCoreContracts

Retrieves core protocol contract addresses in one call

*Optimized getter for frequently accessed contracts. Reverts if either not set.*


```solidity
function getCoreContracts() external view returns (address, address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|kMinter The kMinter contract address|
|`<none>`|`address`|kAssetRouter The kAssetRouter contract address|


### getVaultsByAsset

Gets all vaults that support a specific asset

*Enables discovery of all vaults capable of handling an asset across different types.*


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
|`<none>`|`address[]`|Array of vault addresses supporting the asset|


### getVaultByAssetAndType

Retrieves the primary vault for an asset-type combination

*Used for routing operations to the appropriate vault. Reverts if not found.*


```solidity
function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|
|`vaultType`|`uint8`|The vault type classification|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The vault address for the asset-type pair|


### getVaultType

Gets the classification type of a vault

*Returns the VaultType enum value for routing and strategy selection.*


```solidity
function getVaultType(address vault) external view returns (uint8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The vault's type classification|


### isAdmin

Checks if an address has admin privileges

*Admin role has broad protocol management capabilities.*


```solidity
function isAdmin(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has ADMIN_ROLE|


### isEmergencyAdmin

Checks if an address has emergency admin privileges

*Emergency admin can perform critical safety operations.*


```solidity
function isEmergencyAdmin(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has EMERGENCY_ADMIN_ROLE|


### isGuardian

Checks if an address has guardian privileges

*Guardian acts as circuit breaker for settlement proposals.*


```solidity
function isGuardian(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has GUARDIAN_ROLE|


### isRelayer

Checks if an address has relayer privileges

*Relayer manages external vault operations and hurdle rates.*


```solidity
function isRelayer(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has RELAYER_ROLE|


### isInstitution

Checks if an address is a qualified institution

*Institutions have access to privileged operations like kMinter.*


```solidity
function isInstitution(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has INSTITUTION_ROLE|


### isVendor

Checks if an address has vendor privileges

*Vendors can grant institution roles and manage vendor vaults.*


```solidity
function isVendor(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has VENDOR_ROLE|


### isManager

Checks if an address has manager privileges

*Managers can Execute calls in the vault adapter*


```solidity
function isManager(address user) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if address has VENDOR_ROLE|


### isAsset

Checks if an asset is supported by the protocol

*Used for validation before operations. Checks supportedAssets set membership.*


```solidity
function isAsset(address asset) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if asset is in the protocol whitelist|


### isVault

Checks if a vault is registered in the protocol

*Used for validation before vault operations. Checks allVaults set membership.*


```solidity
function isVault(address vault) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if vault is registered|


### getAdapter

Gets all adapters registered for a specific vault

*Returns external protocol integrations enabling yield strategies.*


```solidity
function getAdapter(address vault, address asset) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to query|
|`asset`|`address`|The underlying asset of the vault|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Array of adapter addresses for the vault|


### isAdapterRegistered

Checks if a specific adapter is registered for a vault

*Used to validate adapter-vault relationships before operations.*


```solidity
function isAdapterRegistered(address vault, address asset, address adapter) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to check|
|`asset`|`address`|The underlying asset of the vault|
|`adapter`|`address`|The adapter address to verify|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if adapter is registered for the vault|


### getVaultAssets

Gets all assets managed by a specific vault

*Most vaults manage single asset, some (like kMinter) handle multiple.*


```solidity
function getVaultAssets(address vault) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of asset addresses the vault manages|


### assetToKToken

Gets the kToken address for a specific underlying asset

*Critical for minting/redemption operations. Reverts if no kToken exists.*


```solidity
function assetToKToken(address asset) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The corresponding kToken address|


### _checkAssetNotRegistered

Validates that an asset is not already registered in the protocol

*Reverts with KREGISTRY_ALREADY_REGISTERED if the asset exists in supportedAssets set.
Used to prevent duplicate registrations and maintain protocol integrity.*


```solidity
function _checkAssetNotRegistered(address asset) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to validate|


### _checkAssetRegistered

Validates that an asset is registered in the protocol

*Reverts with KREGISTRY_ASSET_NOT_SUPPORTED if the asset doesn't exist in supportedAssets set.
Used to ensure operations only occur on whitelisted assets.*


```solidity
function _checkAssetRegistered(address asset) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to validate|


### _checkVaultRegistered

Validates that a vault is registered in the protocol

*Reverts with KREGISTRY_ASSET_NOT_SUPPORTED if the vault doesn't exist in allVaults set.
Used to ensure operations only occur on registered vaults. Note: error message could be improved.*


```solidity
function _checkVaultRegistered(address vault) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to validate|


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
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|New implementation address|


### _authorizeModifyFunctions

Authorize function modification

*This allows modifying functions while keeping modules separate*


```solidity
function _authorizeModifyFunctions(address sender) internal override;
```

### receive

Fallback function to receive ETH transfers

*Allows the contract to receive ETH for gas refunds, donations, or accidental transfers.
Received ETH can be rescued using the rescueAssets function with address(0).*


```solidity
receive() external payable;
```

### contractName

Returns the human-readable name identifier for this contract type

*Used for contract identification and logging purposes. The name should be consistent
across all versions of the same contract type. This enables external systems and other
contracts to identify the contract's purpose and role within the protocol ecosystem.*


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract name as a string (e.g., "kMinter", "kAssetRouter", "kRegistry")|


### contractVersion

Returns the version identifier for this contract implementation

*Used for upgrade management and compatibility checking within the protocol. The version
string should follow semantic versioning (e.g., "1.0.0") to clearly indicate major, minor,
and patch updates. This enables the protocol governance and monitoring systems to track
deployed versions and ensure compatibility between interacting components.*


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract version as a string following semantic versioning (e.g., "1.0.0")|


## Structs
### kRegistryStorage
Core storage structure for kRegistry using ERC-7201 namespaced storage pattern

*This structure maintains all protocol configuration state including contracts, assets, vaults, and
permissions.
Uses the diamond storage pattern to prevent storage collisions in upgradeable contracts.*

**Note:**
storage-location: erc7201:kam.storage.kRegistry


```solidity
struct kRegistryStorage {
    OptimizedAddressEnumerableSetLib.AddressSet supportedAssets;
    OptimizedAddressEnumerableSetLib.AddressSet allVaults;
    address treasury;
    mapping(address => uint256) maxMintPerBatch;
    mapping(address => uint256) maxRedeemPerBatch;
    mapping(bytes32 => address) singletonContracts;
    mapping(address => uint8 vaultType) vaultType;
    mapping(address => mapping(uint8 vaultType => address)) assetToVault;
    mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAsset;
    mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultsByAsset;
    mapping(address => address) assetToKToken;
    mapping(address => mapping(address => address)) vaultAdaptersByAsset;
    mapping(address => bool) registeredAdapters;
    mapping(address => uint16) assetHurdleRate;
}
```

