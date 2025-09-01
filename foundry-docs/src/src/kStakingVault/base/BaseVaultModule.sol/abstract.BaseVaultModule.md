# BaseVaultModule
[Git Source](https://github.com/VerisLabs/KAM/blob/e655bf086c79b14fd5ccde0a4ddfa1609e381102/src/kStakingVault/base/BaseVaultModule.sol)

**Inherits:**
ERC20, ReentrancyGuardTransient

Base contract for all modules

*Provides shared storage, roles, and common functionality*


## State Variables
### K_ASSET_ROUTER

```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### K_MINTER

```solidity
bytes32 internal constant K_MINTER = keccak256("K_MINTER");
```


### DECIMALS_MASK

```solidity
uint256 internal constant DECIMALS_MASK = 0xFF;
```


### DECIMALS_SHIFT

```solidity
uint256 internal constant DECIMALS_SHIFT = 0;
```


### HURDLE_RATE_MASK

```solidity
uint256 internal constant HURDLE_RATE_MASK = 0xFFFF;
```


### HURDLE_RATE_SHIFT

```solidity
uint256 internal constant HURDLE_RATE_SHIFT = 8;
```


### PERFORMANCE_FEE_MASK

```solidity
uint256 internal constant PERFORMANCE_FEE_MASK = 0xFFFF;
```


### PERFORMANCE_FEE_SHIFT

```solidity
uint256 internal constant PERFORMANCE_FEE_SHIFT = 24;
```


### MANAGEMENT_FEE_MASK

```solidity
uint256 internal constant MANAGEMENT_FEE_MASK = 0xFFFF;
```


### MANAGEMENT_FEE_SHIFT

```solidity
uint256 internal constant MANAGEMENT_FEE_SHIFT = 40;
```


### INITIALIZED_MASK

```solidity
uint256 internal constant INITIALIZED_MASK = 0x1;
```


### INITIALIZED_SHIFT

```solidity
uint256 internal constant INITIALIZED_SHIFT = 56;
```


### PAUSED_MASK

```solidity
uint256 internal constant PAUSED_MASK = 0x1;
```


### PAUSED_SHIFT

```solidity
uint256 internal constant PAUSED_SHIFT = 57;
```


### IS_HARD_HURDLE_RATE_MASK

```solidity
uint256 internal constant IS_HARD_HURDLE_RATE_MASK = 0x1;
```


### IS_HARD_HURDLE_RATE_SHIFT

```solidity
uint256 internal constant IS_HARD_HURDLE_RATE_SHIFT = 58;
```


### LAST_FEES_CHARGED_MANAGEMENT_MASK

```solidity
uint256 internal constant LAST_FEES_CHARGED_MANAGEMENT_MASK = 0xFFFFFFFFFFFFFFFF;
```


### LAST_FEES_CHARGED_MANAGEMENT_SHIFT

```solidity
uint256 internal constant LAST_FEES_CHARGED_MANAGEMENT_SHIFT = 59;
```


### LAST_FEES_CHARGED_PERFORMANCE_MASK

```solidity
uint256 internal constant LAST_FEES_CHARGED_PERFORMANCE_MASK = 0xFFFFFFFFFFFFFFFF;
```


### LAST_FEES_CHARGED_PERFORMANCE_SHIFT

```solidity
uint256 internal constant LAST_FEES_CHARGED_PERFORMANCE_SHIFT = 123;
```


### MODULE_BASE_STORAGE_LOCATION

```solidity
bytes32 internal constant MODULE_BASE_STORAGE_LOCATION =
    0x50bc60b877273d55cac3903fd4818902e5fd7aa256278ee2dc6b212f256c0b00;
```


## Functions
### _getBaseVaultModuleStorage

Returns the base vault storage struct using ERC-7201 pattern


```solidity
function _getBaseVaultModuleStorage() internal pure returns (BaseVaultModuleStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`BaseVaultModuleStorage`|Storage reference for base vault state variables|


### _getDecimals


```solidity
function _getDecimals(BaseVaultModuleStorage storage $) internal view returns (uint8);
```

### _setDecimals


```solidity
function _setDecimals(BaseVaultModuleStorage storage $, uint8 value) internal;
```

### _getHurdleRate


```solidity
function _getHurdleRate(BaseVaultModuleStorage storage $) internal view returns (uint16);
```

### _setHurdleRate


```solidity
function _setHurdleRate(BaseVaultModuleStorage storage $, uint16 value) internal;
```

### _getPerformanceFee


```solidity
function _getPerformanceFee(BaseVaultModuleStorage storage $) internal view returns (uint16);
```

### _setPerformanceFee


```solidity
function _setPerformanceFee(BaseVaultModuleStorage storage $, uint16 value) internal;
```

### _getManagementFee


```solidity
function _getManagementFee(BaseVaultModuleStorage storage $) internal view returns (uint16);
```

### _setManagementFee


```solidity
function _setManagementFee(BaseVaultModuleStorage storage $, uint16 value) internal;
```

### _getInitialized


```solidity
function _getInitialized(BaseVaultModuleStorage storage $) internal view returns (bool);
```

### _setInitialized


```solidity
function _setInitialized(BaseVaultModuleStorage storage $, bool value) internal;
```

### _getPaused


```solidity
function _getPaused(BaseVaultModuleStorage storage $) internal view returns (bool);
```

### _setPaused


```solidity
function _setPaused(BaseVaultModuleStorage storage $, bool value) internal;
```

### _getIsHardHurdleRate


```solidity
function _getIsHardHurdleRate(BaseVaultModuleStorage storage $) internal view returns (bool);
```

### _setIsHardHurdleRate


```solidity
function _setIsHardHurdleRate(BaseVaultModuleStorage storage $, bool value) internal;
```

### _getLastFeesChargedManagement


```solidity
function _getLastFeesChargedManagement(BaseVaultModuleStorage storage $) internal view returns (uint64);
```

### _setLastFeesChargedManagement


```solidity
function _setLastFeesChargedManagement(BaseVaultModuleStorage storage $, uint64 value) internal;
```

### _getLastFeesChargedPerformance


```solidity
function _getLastFeesChargedPerformance(BaseVaultModuleStorage storage $) internal view returns (uint64);
```

### _setLastFeesChargedPerformance


```solidity
function _setLastFeesChargedPerformance(BaseVaultModuleStorage storage $, uint64 value) internal;
```

### __BaseVaultModule_init

Initializes the base contract with registry and pause state

*Can only be called once during initialization*


```solidity
function __BaseVaultModule_init(address registry_, bool paused_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|
|`paused_`|`bool`|Initial pause state|


### _registry

Returns the registry contract interface

*Internal helper for typed registry access*


```solidity
function _registry() internal view returns (IkRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IkRegistry`|IkRegistry interface for registry interaction|


### _getKMinter

Gets the kMinter singleton contract address

*Reverts if kMinter not set in registry*


```solidity
function _getKMinter() internal view returns (address minter);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The kMinter contract address|


### _getKAssetRouter

Gets the kAssetRouter singleton contract address

*Reverts if kAssetRouter not set in registry*


```solidity
function _getKAssetRouter() internal view returns (address router);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`router`|`address`|The kAssetRouter contract address|


### _getDNVaultByAsset

Gets the DN vault address for a given asset

*Reverts if asset not supported*


```solidity
function _getDNVaultByAsset(address asset_) internal view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The corresponding DN vault address|


### name

Returns the vault shares token name


```solidity
function name() public view override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Token name|


### symbol

Returns the vault shares token symbol


```solidity
function symbol() public view override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Token symbol|


### decimals


```solidity
function decimals() public view override returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|Token decimals|


### _setPaused

Sets the pause state of the contract

*Only callable internally by inheriting contracts*


```solidity
function _setPaused(bool paused_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|New pause state|


### _convertToAssets

Converts shares to assets


```solidity
function _convertToAssets(uint256 shares) internal view returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of shares to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of assets|


### _convertToShares

Converts assets to shares


```solidity
function _convertToShares(uint256 assets) internal view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|Amount of assets to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|Amount of shares|


### _sharePrice

Calculates share price for stkToken


```solidity
function _sharePrice() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|sharePrice Price per stkToken in underlying asset terms (18 decimals)|


### _totalAssets

Returns the total assets in the vault


```solidity
function _totalAssets() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalAssets Total assets in the vault|


### _totalNetAssets

Returns the total net assets in the vault


```solidity
function _totalNetAssets() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|totalNetAssets Total net assets in the vault|


### _accumulatedFees

Calculates accumulated fees


```solidity
function _accumulatedFees() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|accumulatedFees Accumulated fees|


### _isAdmin

Checks if an address is a admin


```solidity
function _isAdmin(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a admin|


### _isEmergencyAdmin

Checks if an address is a emergencyAdmin


```solidity
function _isEmergencyAdmin(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a emergencyAdmin|


### _isRelayer

Checks if an address is a relayer


```solidity
function _isRelayer(address user) internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a relayer|


### _isPaused

Checks if an address is a institution


```solidity
function _isPaused() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a institution|


### _isKAssetRouter

Gets the kMinter singleton contract address

*Reverts if kMinter not set in registry*


```solidity
function _isKAssetRouter(address kAssetRouter_) internal view returns (bool);
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
### StakeRequestCreated

```solidity
event StakeRequestCreated(
    bytes32 indexed requestId,
    address indexed user,
    address indexed kToken,
    uint256 amount,
    address recipient,
    bytes32 batchId
);
```

### StakeRequestRedeemed

```solidity
event StakeRequestRedeemed(bytes32 indexed requestId);
```

### StakeRequestCancelled

```solidity
event StakeRequestCancelled(bytes32 indexed requestId);
```

### UnstakeRequestCreated

```solidity
event UnstakeRequestCreated(
    bytes32 indexed requestId, address indexed user, uint256 amount, address recipient, bytes32 batchId
);
```

### UnstakeRequestCancelled

```solidity
event UnstakeRequestCancelled(bytes32 indexed requestId);
```

### Paused

```solidity
event Paused(bool paused);
```

### Initialized

```solidity
event Initialized(address registry, string name, string symbol, uint8 decimals, address asset);
```

## Errors
### ZeroAddress

```solidity
error ZeroAddress();
```

### InvalidRegistry

```solidity
error InvalidRegistry();
```

### NotInitialized

```solidity
error NotInitialized();
```

### ContractNotFound

```solidity
error ContractNotFound(bytes32 identifier);
```

### ZeroAmount

```solidity
error ZeroAmount();
```

### AmountBelowDustThreshold

```solidity
error AmountBelowDustThreshold();
```

### Closed

```solidity
error Closed();
```

### Settled

```solidity
error Settled();
```

### RequestNotFound

```solidity
error RequestNotFound();
```

### RequestNotEligible

```solidity
error RequestNotEligible();
```

### InvalidVault

```solidity
error InvalidVault();
```

### IsPaused

```solidity
error IsPaused();
```

### AlreadyInit

```solidity
error AlreadyInit();
```

### WrongRole

```solidity
error WrongRole();
```

### WrongAsset

```solidity
error WrongAsset();
```

### TransferFailed

```solidity
error TransferFailed();
```

### NotClosed

```solidity
error NotClosed();
```

## Structs
### BaseVaultModuleStorage
**Note:**
storage-location: erc7201.kam.storage.BaseVaultModule


```solidity
struct BaseVaultModuleStorage {
    uint128 sharePriceWatermark;
    uint128 totalPendingStake;
    uint256 currentBatch;
    bytes32 currentBatchId;
    address registry;
    address receiverImplementation;
    address underlyingAsset;
    address kToken;
    uint256 config;
    string name;
    string symbol;
    mapping(bytes32 => BaseVaultModuleTypes.BatchInfo) batches;
    mapping(bytes32 => BaseVaultModuleTypes.StakeRequest) stakeRequests;
    mapping(bytes32 => BaseVaultModuleTypes.UnstakeRequest) unstakeRequests;
    mapping(address => EnumerableSetLib.Bytes32Set) userRequests;
}
```

