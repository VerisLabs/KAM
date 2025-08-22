# BaseVaultModule
[Git Source](https://github.com/VerisLabs/KAM/blob/dd71a4088db684fce979bc8cf7c38882ee6bb8a4/src/kStakingVault/base/BaseVaultModule.sol)

**Inherits:**
OwnableRoles, ERC20, ReentrancyGuardTransient, [Extsload](/src/abstracts/Extsload.sol/abstract.Extsload.md)

Base contract for all modules

*Provides shared storage, roles, and common functionality*


## State Variables
### ADMIN_ROLE

```solidity
uint256 public constant ADMIN_ROLE = _ROLE_0;
```


### EMERGENCY_ADMIN_ROLE

```solidity
uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
```


### ONE_HUNDRED_PERCENT

```solidity
uint256 public constant ONE_HUNDRED_PERCENT = 10_000;
```


### K_ASSET_ROUTER

```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### K_MINTER

```solidity
bytes32 internal constant K_MINTER = keccak256("K_MINTER");
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


### __BaseVaultModule_init

Initializes the base contract with registry and pause state

*Can only be called once during initialization*


```solidity
function __BaseVaultModule_init(
    address registry_,
    address owner_,
    address admin_,
    address feeReceiver_,
    bool paused_
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|
|`owner_`|`address`||
|`admin_`|`address`||
|`feeReceiver_`|`address`||
|`paused_`|`bool`|Initial pause state|


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


### _getRelayer

Checks if an account has relayer role


```solidity
function _getRelayer(address account) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the account has relayer role|


### asset

Returns the underlying asset address (for compatibility)


```solidity
function asset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Asset address|


### underlyingAsset

Returns the underlying asset address


```solidity
function underlyingAsset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Asset address|


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

Returns the vault shares token decimals


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


### _calculateStkTokenPrice

Calculates stkToken price with safety checks

*Standard price calculation used across settlement modules*


```solidity
function _calculateStkTokenPrice() internal view returns (uint256 price);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price`|`uint256`|Price per stkToken in underlying asset terms (18 decimals)|


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


### _calculateStkTokensToMint

Calculates stkTokens to mint for given kToken amount

*Used in staking settlement operations*


```solidity
function _calculateStkTokensToMint(uint256 kTokenAmount) internal view returns (uint256 stkTokens);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kTokenAmount`|`uint256`|Amount of kTokens being staked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stkTokens`|`uint256`|Amount of stkTokens to mint|


### _calculateAssetValue

Calculates asset value for given stkToken amount

*Used in unstaking settlement operations*


```solidity
function _calculateAssetValue(uint256 stkTokenAmount) internal view returns (uint256 assetValue);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`stkTokenAmount`|`uint256`|Amount of stkTokens being unstaked|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assetValue`|`uint256`|Equivalent asset value|


### _sharePrice

Calculates share price for stkToken


```solidity
function _sharePrice() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|sharePrice Price per stkToken in underlying asset terms (18 decimals)|


### _totalAssetsVirtual

Returns the total assets in the vault


```solidity
function _totalAssetsVirtual() internal view returns (uint256);
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


### whenNotPaused

Modifier to restrict function execution when contract is paused

*Reverts with Paused() if isPaused is true*


```solidity
modifier whenNotPaused() virtual;
```

### onlyKAssetRouter

Restricts function access to the kAssetRouter contract


```solidity
modifier onlyKAssetRouter();
```

### onlyRelayer

Restricts function access to the relayer

*Only callable internally by inheriting contracts*


```solidity
modifier onlyRelayer();
```

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
event Initialized(address registry, address owner, address admin);
```

### TotalAssetsUpdated

```solidity
event TotalAssetsUpdated(uint256 oldTotalAssets, uint256 newTotalAssets);
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

### OnlyKAssetRouter

```solidity
error OnlyKAssetRouter();
```

### OnlyRelayer

```solidity
error OnlyRelayer();
```

### ZeroAmount

```solidity
error ZeroAmount();
```

### AmountBelowDustThreshold

```solidity
error AmountBelowDustThreshold();
```

### ContractPaused

```solidity
error ContractPaused();
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

## Structs
### BaseVaultModuleStorage
**Note:**
storage-location: erc7201.kam.storage.BaseVaultModule


```solidity
struct BaseVaultModuleStorage {
    uint256 currentBatch;
    bytes32 currentBatchId;
    uint256 sharePriceWatermark;
    uint256 requestCounter;
    address registry;
    address receiverImplementation;
    address underlyingAsset;
    address kToken;
    address feeReceiver;
    uint96 dustAmount;
    uint8 decimals;
    uint16 hurdleRate;
    uint16 performanceFee;
    uint16 managementFee;
    bool initialized;
    bool paused;
    bool isHardHurdleRate;
    uint64 lastFeesChargedManagement;
    uint64 lastFeesChargedPerformance;
    string name;
    string symbol;
    mapping(bytes32 => BaseVaultModuleTypes.BatchInfo) batches;
    mapping(bytes32 => BaseVaultModuleTypes.StakeRequest) stakeRequests;
    mapping(bytes32 => BaseVaultModuleTypes.UnstakeRequest) unstakeRequests;
    mapping(address => EnumerableSetLib.Bytes32Set) userRequests;
}
```

