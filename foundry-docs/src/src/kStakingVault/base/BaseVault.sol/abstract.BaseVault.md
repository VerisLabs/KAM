# BaseVault
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/kStakingVault/base/BaseVault.sol)

**Inherits:**
[ERC20](/src/vendor/ERC20.sol/abstract.ERC20.md), [OptimizedReentrancyGuardTransient](/src/abstracts/OptimizedReentrancyGuardTransient.sol/abstract.OptimizedReentrancyGuardTransient.md)

Foundation contract providing essential shared functionality for all kStakingVault implementations

*This abstract contract serves as the architectural foundation for the retail staking system, establishing
critical patterns and utilities that ensure consistency across vault implementations. Key responsibilities include:
(1) ERC-7201 namespaced storage preventing upgrade collisions while enabling safe inheritance, (2) Registry
integration for protocol-wide configuration and role-based access control, (3) Share accounting mathematics
for accurate conversion between assets and stkTokens, (4) Fee calculation framework supporting management and
performance fees with hurdle rate mechanisms, (5) Batch processing coordination for gas-efficient settlement,
(6) Virtual balance tracking for pending operations and accurate share price calculations. The contract employs
optimized storage packing in the config field to minimize gas costs while maintaining extensive configurability.
Mathematical operations use the OptimizedFixedPointMathLib for precision and overflow protection in share
calculations. All inheriting vault implementations leverage these utilities to maintain protocol integrity
while reducing code duplication and ensuring consistent behavior across the vault network.*


## State Variables
### K_ASSET_ROUTER
kAssetRouter key


```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### K_MINTER
kMinter key


```solidity
bytes32 internal constant K_MINTER = keccak256("K_MINTER");
```


### DECIMALS_MASK
*Bitmask and shift constants for module configuration*


```solidity
uint256 internal constant DECIMALS_MASK = 0xFF;
```


### DECIMALS_SHIFT

```solidity
uint256 internal constant DECIMALS_SHIFT = 0;
```


### PERFORMANCE_FEE_MASK

```solidity
uint256 internal constant PERFORMANCE_FEE_MASK = 0xFFFF;
```


### PERFORMANCE_FEE_SHIFT

```solidity
uint256 internal constant PERFORMANCE_FEE_SHIFT = 8;
```


### MANAGEMENT_FEE_MASK

```solidity
uint256 internal constant MANAGEMENT_FEE_MASK = 0xFFFF;
```


### MANAGEMENT_FEE_SHIFT

```solidity
uint256 internal constant MANAGEMENT_FEE_SHIFT = 24;
```


### INITIALIZED_MASK

```solidity
uint256 internal constant INITIALIZED_MASK = 0x1;
```


### INITIALIZED_SHIFT

```solidity
uint256 internal constant INITIALIZED_SHIFT = 40;
```


### PAUSED_MASK

```solidity
uint256 internal constant PAUSED_MASK = 0x1;
```


### PAUSED_SHIFT

```solidity
uint256 internal constant PAUSED_SHIFT = 41;
```


### IS_HARD_HURDLE_RATE_MASK

```solidity
uint256 internal constant IS_HARD_HURDLE_RATE_MASK = 0x1;
```


### IS_HARD_HURDLE_RATE_SHIFT

```solidity
uint256 internal constant IS_HARD_HURDLE_RATE_SHIFT = 42;
```


### LAST_FEES_CHARGED_MANAGEMENT_MASK

```solidity
uint256 internal constant LAST_FEES_CHARGED_MANAGEMENT_MASK = 0xFFFFFFFFFFFFFFFF;
```


### LAST_FEES_CHARGED_MANAGEMENT_SHIFT

```solidity
uint256 internal constant LAST_FEES_CHARGED_MANAGEMENT_SHIFT = 43;
```


### LAST_FEES_CHARGED_PERFORMANCE_MASK

```solidity
uint256 internal constant LAST_FEES_CHARGED_PERFORMANCE_MASK = 0xFFFFFFFFFFFFFFFF;
```


### LAST_FEES_CHARGED_PERFORMANCE_SHIFT

```solidity
uint256 internal constant LAST_FEES_CHARGED_PERFORMANCE_SHIFT = 107;
```


### MODULE_BASE_STORAGE_LOCATION

```solidity
bytes32 internal constant MODULE_BASE_STORAGE_LOCATION =
    0x50bc60b877273d55cac3903fd4818902e5fd7aa256278ee2dc6b212f256c0b00;
```


## Functions
### _getBaseVaultStorage

Returns the base vault storage struct using ERC-7201 pattern


```solidity
function _getBaseVaultStorage() internal pure returns (BaseVaultStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`BaseVaultStorage`|Storage reference for base vault state variables|


### _getDecimals


```solidity
function _getDecimals(BaseVaultStorage storage $) internal view returns (uint8);
```

### _setDecimals


```solidity
function _setDecimals(BaseVaultStorage storage $, uint8 value) internal;
```

### _getHurdleRate


```solidity
function _getHurdleRate(BaseVaultStorage storage $) internal view returns (uint16);
```

### _getPerformanceFee


```solidity
function _getPerformanceFee(BaseVaultStorage storage $) internal view returns (uint16);
```

### _setPerformanceFee


```solidity
function _setPerformanceFee(BaseVaultStorage storage $, uint16 value) internal;
```

### _getManagementFee


```solidity
function _getManagementFee(BaseVaultStorage storage $) internal view returns (uint16);
```

### _setManagementFee


```solidity
function _setManagementFee(BaseVaultStorage storage $, uint16 value) internal;
```

### _getInitialized


```solidity
function _getInitialized(BaseVaultStorage storage $) internal view returns (bool);
```

### _setInitialized


```solidity
function _setInitialized(BaseVaultStorage storage $, bool value) internal;
```

### _getPaused


```solidity
function _getPaused(BaseVaultStorage storage $) internal view returns (bool);
```

### _setPaused


```solidity
function _setPaused(BaseVaultStorage storage $, bool value) internal;
```

### _getIsHardHurdleRate


```solidity
function _getIsHardHurdleRate(BaseVaultStorage storage $) internal view returns (bool);
```

### _setIsHardHurdleRate


```solidity
function _setIsHardHurdleRate(BaseVaultStorage storage $, bool value) internal;
```

### _getLastFeesChargedManagement


```solidity
function _getLastFeesChargedManagement(BaseVaultStorage storage $) internal view returns (uint64);
```

### _setLastFeesChargedManagement


```solidity
function _setLastFeesChargedManagement(BaseVaultStorage storage $, uint64 value) internal;
```

### _getLastFeesChargedPerformance


```solidity
function _getLastFeesChargedPerformance(BaseVaultStorage storage $) internal view returns (uint64);
```

### _setLastFeesChargedPerformance


```solidity
function _setLastFeesChargedPerformance(BaseVaultStorage storage $, uint64 value) internal;
```

### __BaseVault_init

Initializes the base vault foundation with registry integration and operational state

*This internal initialization function establishes the core foundation for all vault implementations.
The initialization process: (1) Validates single initialization to prevent reinitialization attacks in proxy
patterns, (2) Ensures registry address is valid since all protocol operations depend on it, (3) Sets initial
operational state enabling normal vault operations or emergency pause, (4) Initializes fee tracking timestamps
to current block time for accurate fee accrual calculations, (5) Marks initialization complete to prevent
future calls. The registry serves as the single source of truth for protocol configuration, role management,
and contract discovery. Fee timestamps are initialized to prevent immediate fee charges on new vaults.*


```solidity
function __BaseVault_init(address registry_, bool paused_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|The kRegistry contract address providing protocol configuration and role management|
|`paused_`|`bool`|Initial operational state (true = paused, false = active)|


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

Updates the vault's operational pause state for emergency risk management

*This internal function enables vault implementations to halt operations during emergencies or maintenance.
The pause mechanism: (1) Validates vault initialization to prevent invalid state changes, (2) Updates the
packed config storage with new pause state, (3) Emits event for monitoring and user notification. When paused,
state-changing operations should be blocked while view functions remain accessible for monitoring. The pause
state is stored in packed config for gas efficiency. This function provides the foundation for emergency
controls while maintaining transparency through event emission.*


```solidity
function _setPaused(bool paused_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|The desired pause state (true = halt operations, false = resume normal operation)|


### _convertToAssets

Converts stkToken shares to underlying asset value based on current vault performance

*This function implements the core share accounting mechanism that determines asset value for stkToken
holders. The conversion process: (1) Handles edge case where total supply is zero by returning 1:1 conversion,
(2) Uses precise fixed-point math to calculate proportional asset value based on share ownership percentage,
(3) Applies current total net assets (after fees) to ensure accurate user valuations. The calculation
maintains precision through fullMulDiv to prevent rounding errors that could accumulate over time. This
function is critical for determining redemption values, share price calculations, and user balance queries.*


```solidity
function _convertToAssets(uint256 shares) internal view returns (uint256 assets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The quantity of stkTokens to convert to underlying asset terms|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The equivalent value in underlying assets based on current vault performance|


### _convertToShares

Converts underlying asset amount to equivalent stkToken shares at current vault valuation

*This function determines how many stkTokens should be issued for a given asset deposit based on current
vault performance. The conversion process: (1) Handles edge case of zero total supply with 1:1 initial pricing,
(2) Calculates proportional share amount based on current vault valuation and total outstanding shares,
(3) Uses total net assets to ensure new shares are priced fairly relative to existing holders. The precise
fixed-point mathematics prevent dilution attacks and ensure fair pricing for all participants. This function
is essential for determining share issuance during staking operations and maintaining equitable vault ownership.*


```solidity
function _convertToShares(uint256 assets) internal view returns (uint256 shares);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The underlying asset amount to convert to share terms|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The equivalent stkToken amount based on current share price|


### _netSharePrice

Calculates net share price per stkToken after deducting accumulated fees

*This function provides the user-facing share price that reflects actual value after management and
performance fee deductions. The calculation: (1) Uses vault decimals for proper scaling to match token
precision, (2) Calls _convertToAssets with unit share amount to determine per-token value, (3) Reflects
total net assets which exclude accrued but unpaid fees. This net pricing ensures users see accurate
value after all fee obligations, providing transparent visibility into their true vault position value.
Used primarily for user-facing calculations and accurate balance reporting.*


```solidity
function _netSharePrice() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Net price per stkToken in underlying asset terms (scaled to vault decimals)|


### _sharePrice

Calculates gross share price per stkToken including accumulated fees

*This function provides the total vault performance-based share price before fee deductions. The
calculation:
(1) Handles zero total supply edge case with 1:1 initial pricing, (2) Uses total gross assets including accrued
fees for complete performance measurement, (3) Applies precise fixed-point mathematics for accurate pricing.
This gross pricing is used for settlement calculations, performance fee assessments, and watermark tracking.
The inclusion of fees provides complete vault performance measurement for fee calculations and settlement
coordination.*


```solidity
function _sharePrice() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Gross price per stkToken in underlying asset terms (scaled to vault decimals)|


### _totalAssets

Calculates total assets under management including pending stakes and accrued yields

*This function determines the complete asset base managed by the vault for share price calculations.
The calculation: (1) Starts with total kToken balance held by the vault contract, (2) Subtracts pending
stakes that haven't yet been converted to stkTokens to avoid double-counting during settlement periods,
(3) Includes all accrued yields and performance gains. The pending stake adjustment is crucial for accurate
share pricing during batch processing periods when assets are deposited but shares haven't been issued.
This total forms the basis for both gross and net share price calculations.*


```solidity
function _totalAssets() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total asset value managed by the vault including yields but excluding pending operations|


### _totalNetAssets

Calculates net assets available to users after deducting accumulated fees

*This function provides the user-facing asset value by removing management and performance fee obligations.
The calculation: (1) Takes total gross assets as the starting point, (2) Subtracts accumulated fees calculated
by the fee computation module, (3) Results in the net value attributable to stkToken holders. This net asset
calculation is critical for fair share pricing, ensuring new entrants pay appropriate prices and existing
holders receive accurate valuations. The fee deduction prevents users from claiming value that belongs to
vault operators through fee mechanisms.*


```solidity
function _totalNetAssets() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Net asset value available to users after all fee deductions|


### _accumulatedFees

Delegates fee calculation to the vault reader module for comprehensive fee computation

*This function serves as a gateway to the modular fee calculation system implemented in the vault reader.
The delegation pattern: (1) Calls the reader module which implements detailed fee calculation logic including
management fee accrual and performance fee assessment, (2) Returns total accumulated fees for asset
calculations,
(3) Maintains separation of concerns by isolating complex fee logic in dedicated modules. The reader module
handles time-based management fees, watermark-based performance fees, and hurdle rate calculations.
This modular approach enables upgradeable fee calculation logic while maintaining consistent interfaces.*


```solidity
function _accumulatedFees() internal view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total accumulated fees (management + performance) in underlying asset terms|


### _isAdmin

Validates admin role permissions for vault configuration and emergency functions

*Queries the protocol registry to verify admin status for access control. Admins can execute
critical vault management functions including fee parameter changes and emergency interventions.*


```solidity
function _isAdmin(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to validate for admin privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address is registered as an admin in the protocol registry|


### _isEmergencyAdmin

Validates emergency admin role for critical pause/unpause operations

*Emergency admins have elevated privileges to halt vault operations during security incidents
or market anomalies. This role provides rapid response capability for risk management.*


```solidity
function _isEmergencyAdmin(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to validate for emergency admin privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address is registered as an emergency admin in the protocol registry|


### _isRelayer

Validates relayer role for automated batch processing operations

*Relayers execute scheduled operations including batch creation, closure, and settlement
coordination. This role enables automation while maintaining security through limited permissions.*


```solidity
function _isRelayer(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to validate for relayer privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address is registered as a relayer in the protocol registry|


### _isKAssetRouter

Validates kAssetRouter contract identity for settlement coordination

*Only the protocol's kAssetRouter singleton can trigger vault settlements and coordinate
cross-vault asset flows. This validation ensures settlement integrity and prevents unauthorized access.*


```solidity
function _isKAssetRouter(address kAssetRouter_) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`kAssetRouter_`|`address`|The address to validate against the registered kAssetRouter|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the address matches the registered kAssetRouter contract|


## Events
### StakeRequestCreated
Emitted when a stake request is created


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

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the stake request|
|`user`|`address`|The address of the user who created the request|
|`kToken`|`address`|The address of the kToken associated with the request|
|`amount`|`uint256`|The amount of kTokens requested|
|`recipient`|`address`|The address to which the kTokens will be sent|
|`batchId`|`bytes32`|The batch ID associated with the request|

### StakeRequestRedeemed
Emitted when a stake request is redeemed


```solidity
event StakeRequestRedeemed(bytes32 indexed requestId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the stake request|

### StakeRequestCancelled
Emitted when a stake request is cancelled


```solidity
event StakeRequestCancelled(bytes32 indexed requestId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the stake request|

### UnstakeRequestCreated
Emitted when an unstake request is created


```solidity
event UnstakeRequestCreated(
    bytes32 indexed requestId, address indexed user, uint256 amount, address recipient, bytes32 batchId
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the unstake request|
|`user`|`address`|The address of the user who created the request|
|`amount`|`uint256`|The amount of kTokens requested|
|`recipient`|`address`|The address to which the kTokens will be sent|
|`batchId`|`bytes32`|The batch ID associated with the request|

### UnstakeRequestCancelled
Emitted when an unstake request is cancelled


```solidity
event UnstakeRequestCancelled(bytes32 indexed requestId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the unstake request|

### Paused
Emitted when the vault is paused


```solidity
event Paused(bool paused);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused`|`bool`|The new paused state|

### Initialized
Emitted when the vault is initialized


```solidity
event Initialized(address registry, string name, string symbol, uint8 decimals, address asset);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`address`|The registry address|
|`name`|`string`|The name of the vault|
|`symbol`|`string`|The symbol of the vault|
|`decimals`|`uint8`|The decimals of the vault|
|`asset`|`address`|The asset of the vault|

## Structs
### BaseVaultStorage
**Note:**
storage-location: erc7201.kam.storage.BaseVault


```solidity
struct BaseVaultStorage {
    uint256 config;
    uint128 sharePriceWatermark;
    uint128 totalPendingStake;
    uint256 currentBatch;
    bytes32 currentBatchId;
    address registry;
    address receiverImplementation;
    address underlyingAsset;
    address kToken;
    string name;
    string symbol;
    mapping(bytes32 => BaseVaultTypes.BatchInfo) batches;
    mapping(bytes32 => BaseVaultTypes.StakeRequest) stakeRequests;
    mapping(bytes32 => BaseVaultTypes.UnstakeRequest) unstakeRequests;
    mapping(address => OptimizedBytes32EnumerableSetLib.Bytes32Set) userRequests;
}
```

