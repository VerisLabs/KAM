# IkRegistry
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/interfaces/IkRegistry.sol)


## Functions
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


### registerAsset

Registers a new underlying asset in the protocol and deploys its corresponding kToken

*This function performs critical asset onboarding: (1) Validates the asset isn't already registered,
(2) Adds asset to the supported set and singleton registry, (3) Deploys a new kToken contract with
matching decimals, (4) Establishes bidirectional asset-kToken mapping, (5) Grants minting privileges
to kMinter. The function automatically inherits decimals from the underlying asset for consistency.
Only callable by ADMIN_ROLE to maintain protocol security and prevent unauthorized token creation.*


```solidity
function registerAsset(
    string memory name,
    string memory symbol,
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
|`name`|`string`|The name for the kToken (e.g., "KAM USDC")|
|`symbol`|`string`|The symbol for the kToken (e.g., "kUSDC")|
|`asset`|`address`|The underlying asset contract address to register|
|`id`|`bytes32`|The unique identifier for singleton asset storage (e.g., USDC, WBTC)|
|`maxMintPerBatch`|`uint256`||
|`maxRedeemPerBatch`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The deployed kToken contract address|


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


### registerAdapter

Registers an external protocol adapter for a vault

*Enables yield strategy integrations through external DeFi protocols. Only callable by ADMIN_ROLE.*


```solidity
function registerAdapter(address vault, address adapter) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address receiving the adapter|
|`adapter`|`address`|The adapter contract address|


### removeAdapter

Removes an adapter from a vault's registered adapter set

*This disables a specific external protocol integration for the vault. Only callable by ADMIN_ROLE
to ensure proper risk assessment before removing yield strategies.*


```solidity
function removeAdapter(address vault, address adapter) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to remove the adapter from|
|`adapter`|`address`|The adapter address to remove|


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


### getContractById

Retrieves a singleton contract address by identifier

*Reverts if contract not registered. Used for protocol contract discovery.*


```solidity
function getContractById(bytes32 id) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|Contract identifier (e.g., K_MINTER, K_ASSET_ROUTER)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The contract address|


### getAssetById

Retrieves a singleton asset address by identifier

*Reverts if asset not registered. Provides named access to common assets.*


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
|`<none>`|`address`|The asset address|


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


### getCoreContracts

Retrieves core protocol contract addresses in one call

*Optimized getter for frequently accessed contracts. Reverts if either not set.*


```solidity
function getCoreContracts() external view returns (address kMinter, address kAssetRouter);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`kMinter`|`address`|The kMinter contract address|
|`kAssetRouter`|`address`|The kAssetRouter contract address|


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


### getAdapters

Gets all adapters registered for a specific vault

*Returns external protocol integrations enabling yield strategies.*


```solidity
function getAdapters(address vault) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|Array of adapter addresses for the vault|


### isAdapterRegistered

Checks if a specific adapter is registered for a vault

*Used to validate adapter-vault relationships before operations.*


```solidity
function isAdapterRegistered(address vault, address adapter) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to check|
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


### getHurdleRate

Gets the hurdle rate for a specific asset

*Returns minimum performance threshold in basis points for yield distribution.
Asset must be registered to query hurdle rate.*


```solidity
function getHurdleRate(address asset) external view returns (uint16);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|The hurdle rate in basis points|


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


### setAssetBatchLimits

Sets maximum mint and redeem amounts per batch for an asset

*Only callable by ADMIN_ROLE. Helps manage liquidity and risk for high-volume assets*


```solidity
function setAssetBatchLimits(address asset, uint256 maxMintPerBatch_, uint256 maxRedeemPerBatch_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to set limits for|
|`maxMintPerBatch_`|`uint256`|Maximum amount of the asset that can be minted in a single batch|
|`maxRedeemPerBatch_`|`uint256`|Maximum amount of the asset that can be redeemed in a single batch|


### getMaxMintPerBatch

Gets the maximum mint amount per batch for an asset

*Used to enforce minting limits for liquidity and risk management*


```solidity
function getMaxMintPerBatch(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The maximum mint amount per batch|


### getMaxRedeemPerBatch

Gets the maximum redeem amount per batch for an asset

*Used to enforce redemption limits for liquidity and risk management*


```solidity
function getMaxRedeemPerBatch(address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The maximum redeem amount per batch|


## Events
### SingletonContractSet
Emitted when a singleton contract is registered in the protocol


```solidity
event SingletonContractSet(bytes32 indexed id, address indexed contractAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes32`|The unique identifier for the contract (e.g., K_MINTER, K_ASSET_ROUTER)|
|`contractAddress`|`address`|The address of the registered singleton contract|

### VaultRegistered
Emitted when a new vault is registered in the protocol


```solidity
event VaultRegistered(address indexed vault, address indexed asset, VaultType indexed vaultType);
```

<<<<<<< HEAD
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault contract address|
|`asset`|`address`|The underlying asset the vault manages|
|`vaultType`|`VaultType`|The classification type of the vault|

### VaultRemoved
Emitted when a vault is removed from the protocol

=======
### VaultRemoved
>>>>>>> main

```solidity
event VaultRemoved(address indexed vault);
```

<<<<<<< HEAD
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault contract address being removed|

=======
>>>>>>> main
### AssetRegistered
Emitted when an asset and its kToken are registered


```solidity
event AssetRegistered(address indexed asset, address indexed kToken);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset address|
|`kToken`|`address`|The corresponding kToken address|

### AssetSupported
Emitted when an asset is added to the supported set


```solidity
event AssetSupported(address indexed asset);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The newly supported asset address|

### AdapterRegistered
Emitted when an adapter is registered for a vault


```solidity
event AdapterRegistered(address indexed vault, address indexed adapter);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault receiving the adapter|
|`adapter`|`address`|The adapter contract address|

### AdapterRemoved
Emitted when an adapter is removed from a vault


```solidity
event AdapterRemoved(address indexed vault, address indexed adapter);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault losing the adapter|
|`adapter`|`address`|The adapter being removed|

### KTokenDeployed
Emitted when a new kToken is deployed


```solidity
event KTokenDeployed(address indexed kTokenContract, string name_, string symbol_, uint8 decimals_);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kTokenContract`|`address`|The deployed kToken address|
|`name_`|`string`|The kToken name|
|`symbol_`|`string`|The kToken symbol|
|`decimals_`|`uint8`|The kToken decimals (matches underlying)|

### KTokenImplementationSet
Emitted when the kToken implementation is updated


```solidity
event KTokenImplementationSet(address indexed implementation);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`implementation`|`address`|The new implementation address|

### RescuedAssets
Emitted when ERC20 assets are rescued from the contract


```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The rescued asset address|
|`to`|`address`|The recipient address|
|`amount`|`uint256`|The amount rescued|

### RescuedETH
Emitted when ETH is rescued from the contract


```solidity
event RescuedETH(address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The recipient address (asset field for consistency)|
|`amount`|`uint256`|The amount of ETH rescued|

### TreasurySet
Emitted when the treasury address is updated


```solidity
event TreasurySet(address indexed treasury);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`treasury`|`address`|The new treasury address|

### HurdleRateSet
Emitted when a hurdle rate is set for an asset


```solidity
event HurdleRateSet(address indexed asset, uint16 hurdleRate);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset receiving the hurdle rate|
|`hurdleRate`|`uint16`|The hurdle rate in basis points|

## Enums
### VaultType

```solidity
enum VaultType {
    MINTER,
    DN,
    ALPHA,
    BETA,
    GAMMA,
    DELTA,
    EPSILON,
    ZETA,
    ETA,
    THETA,
    IOTA,
    KAPPA,
    LAMBDA,
    MU,
    NU,
    XI,
    OMICRON,
    PI,
    RHO,
    SIGMA,
    TAU,
    UPSILON,
    PHI,
    CHI,
    PSI,
    OMEGA,
    VAULT_27,
    VAULT_28,
    VAULT_29,
    VAULT_30,
    VAULT_31,
    VAULT_32,
    VAULT_33,
    VAULT_34,
    VAULT_35,
    VAULT_36,
    VAULT_37,
    VAULT_38,
    VAULT_39,
    VAULT_40,
    VAULT_41,
    VAULT_42,
    VAULT_43,
    VAULT_44,
    VAULT_45,
    VAULT_46,
    VAULT_47,
    VAULT_48,
    VAULT_49,
    VAULT_50,
    VAULT_51,
    VAULT_52,
    VAULT_53,
    VAULT_54,
    VAULT_55,
    VAULT_56,
    VAULT_57,
    VAULT_58,
    VAULT_59,
    VAULT_60,
    VAULT_61,
    VAULT_62,
    VAULT_63,
    VAULT_64,
    VAULT_65,
    VAULT_66,
    VAULT_67,
    VAULT_68,
    VAULT_69,
    VAULT_70,
    VAULT_71,
    VAULT_72,
    VAULT_73,
    VAULT_74,
    VAULT_75,
    VAULT_76,
    VAULT_77,
    VAULT_78,
    VAULT_79,
    VAULT_80,
    VAULT_81,
    VAULT_82,
    VAULT_83,
    VAULT_84,
    VAULT_85,
    VAULT_86,
    VAULT_87,
    VAULT_88,
    VAULT_89,
    VAULT_90,
    VAULT_91,
    VAULT_92,
    VAULT_93,
    VAULT_94,
    VAULT_95,
    VAULT_96,
    VAULT_97,
    VAULT_98,
    VAULT_99,
    VAULT_100,
    VAULT_101,
    VAULT_102,
    VAULT_103,
    VAULT_104,
    VAULT_105,
    VAULT_106,
    VAULT_107,
    VAULT_108,
    VAULT_109,
    VAULT_110,
    VAULT_111,
    VAULT_112,
    VAULT_113,
    VAULT_114,
    VAULT_115,
    VAULT_116,
    VAULT_117,
    VAULT_118,
    VAULT_119,
    VAULT_120,
    VAULT_121,
    VAULT_122,
    VAULT_123,
    VAULT_124,
    VAULT_125,
    VAULT_126,
    VAULT_127,
    VAULT_128,
    VAULT_129,
    VAULT_130,
    VAULT_131,
    VAULT_132,
    VAULT_133,
    VAULT_134,
    VAULT_135,
    VAULT_136,
    VAULT_137,
    VAULT_138,
    VAULT_139,
    VAULT_140,
    VAULT_141,
    VAULT_142,
    VAULT_143,
    VAULT_144,
    VAULT_145,
    VAULT_146,
    VAULT_147,
    VAULT_148,
    VAULT_149,
    VAULT_150,
    VAULT_151,
    VAULT_152,
    VAULT_153,
    VAULT_154,
    VAULT_155,
    VAULT_156,
    VAULT_157,
    VAULT_158,
    VAULT_159,
    VAULT_160,
    VAULT_161,
    VAULT_162,
    VAULT_163,
    VAULT_164,
    VAULT_165,
    VAULT_166,
    VAULT_167,
    VAULT_168,
    VAULT_169,
    VAULT_170,
    VAULT_171,
    VAULT_172,
    VAULT_173,
    VAULT_174,
    VAULT_175,
    VAULT_176,
    VAULT_177,
    VAULT_178,
    VAULT_179,
    VAULT_180,
    VAULT_181,
    VAULT_182,
    VAULT_183,
    VAULT_184,
    VAULT_185,
    VAULT_186,
    VAULT_187,
    VAULT_188,
    VAULT_189,
    VAULT_190,
    VAULT_191,
    VAULT_192,
    VAULT_193,
    VAULT_194,
    VAULT_195,
    VAULT_196,
    VAULT_197,
    VAULT_198,
    VAULT_199,
    VAULT_200,
    VAULT_201,
    VAULT_202,
    VAULT_203,
    VAULT_204,
    VAULT_205,
    VAULT_206,
    VAULT_207,
    VAULT_208,
    VAULT_209,
    VAULT_210,
    VAULT_211,
    VAULT_212,
    VAULT_213,
    VAULT_214,
    VAULT_215,
    VAULT_216,
    VAULT_217,
    VAULT_218,
    VAULT_219,
    VAULT_220,
    VAULT_221,
    VAULT_222,
    VAULT_223,
    VAULT_224,
    VAULT_225,
    VAULT_226,
    VAULT_227,
    VAULT_228,
    VAULT_229,
    VAULT_230,
    VAULT_231,
    VAULT_232,
    VAULT_233,
    VAULT_234,
    VAULT_235,
    VAULT_236,
    VAULT_237,
    VAULT_238,
    VAULT_239,
    VAULT_240,
    VAULT_241,
    VAULT_242,
    VAULT_243,
    VAULT_244,
    VAULT_245,
    VAULT_246,
    VAULT_247,
    VAULT_248,
    VAULT_249,
    VAULT_250,
    VAULT_251,
    VAULT_252,
    VAULT_253,
    VAULT_254,
    VAULT_255
}
```

