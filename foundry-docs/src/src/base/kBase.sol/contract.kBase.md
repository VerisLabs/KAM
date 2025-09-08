# kBase
<<<<<<< HEAD
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/base/kBase.sol)
=======
[Git Source](https://github.com/VerisLabs/KAM/blob/e655bf086c79b14fd5ccde0a4ddfa1609e381102/src/base/kBase.sol)
>>>>>>> main

**Inherits:**
[OptimizedReentrancyGuardTransient](/src/abstracts/OptimizedReentrancyGuardTransient.sol/abstract.OptimizedReentrancyGuardTransient.md)

Foundation contract providing essential shared functionality and registry integration for all KAM protocol
contracts

*This abstract contract serves as the architectural foundation for the entire KAM protocol, establishing
critical patterns and utilities that ensure consistency across all protocol components. Key responsibilities
include: (1) Registry integration through a singleton pattern that enables dynamic protocol configuration and
contract discovery, (2) Role-based access control validation that enforces protocol governance permissions,
(3) Emergency pause functionality for protocol-wide risk mitigation during critical events, (4) Asset rescue
mechanisms to recover stuck funds while protecting protocol assets, (5) Vault and asset validation to ensure
only registered components interact, (6) Batch processing coordination through ID management and receiver tracking.
The contract employs ERC-7201 namespaced storage to prevent storage collisions during upgrades and enable safe
inheritance patterns. All inheriting contracts (kMinter, kAssetRouter, etc.) leverage these utilities to maintain
protocol integrity, reduce code duplication, and ensure consistent security checks across the ecosystem. The
registry serves as the single source of truth for protocol configuration, making the system highly modular and
upgradeable.*


## State Variables
### K_MINTER
Registry lookup key for the kMinter singleton contract

*This hash is used to retrieve the kMinter address from the registry's contract mapping.
kMinter handles institutional minting/redemption flows, so many contracts need to identify it
for access control and routing decisions. The hash ensures consistent lookups across the protocol.*


```solidity
bytes32 internal constant K_MINTER = keccak256("K_MINTER");
```


### K_ASSET_ROUTER
Registry lookup key for the kAssetRouter singleton contract

*This hash is used to retrieve the kAssetRouter address from the registry's contract mapping.
kAssetRouter coordinates all asset movements and settlements, making it a critical dependency
for vaults and other protocol components. The hash-based lookup enables dynamic upgrades.*


```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### KBASE_STORAGE_LOCATION
*ERC-7201 storage location calculated as: keccak256(abi.encode(uint256(keccak256("kam.storage.kBase")) - 1))
& ~bytes32(uint256(0xff))
This specific slot is chosen to avoid any possible collision with standard storage layouts while maintaining
deterministic addressing. The calculation ensures the storage location is unique to this namespace and won't
conflict with other inherited contracts or future upgrades. The 0xff mask ensures proper alignment.*


```solidity
bytes32 private constant KBASE_STORAGE_LOCATION = 0xe91688684975c4d7d54a65dd96da5d4dcbb54b8971c046d5351d3c111e43a800;
```


## Functions
### _getBaseStorage

*Returns the kBase storage pointer using ERC-7201 namespaced storage pattern*


```solidity
function _getBaseStorage() internal pure returns (kBaseStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`kBaseStorage`|Storage pointer to the kBaseStorage struct at the designated storage location This function uses inline assembly to directly set the storage pointer to our namespaced location, ensuring efficient access to storage variables while maintaining upgrade safety. The pure modifier is used because we're only returning a storage pointer, not reading storage values.|


### __kBase_init

Initializes the base contract with registry integration and default operational state

*This internal initialization function establishes the foundational connection between any inheriting
contract and the protocol's registry system. The initialization process: (1) Validates that initialization
hasn't occurred to prevent reinitialization attacks in proxy patterns, (2) Ensures registry address is valid
since the registry is critical for all protocol operations, (3) Sets the contract to unpaused state enabling
normal operations, (4) Marks initialization complete to prevent future calls. This function MUST be called
by all inheriting contracts during their initialization phase to establish proper protocol integration.
The internal visibility ensures only inheriting contracts can initialize, preventing external manipulation.*


```solidity
function __kBase_init(address registry_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|The kRegistry contract address that serves as the protocol's configuration and discovery hub|


### setPaused

Toggles the emergency pause state affecting all protocol operations in this contract

*This function provides critical risk management capability by allowing emergency admins to halt
contract operations during security incidents or market anomalies. The pause mechanism: (1) Affects all
state-changing operations in inheriting contracts that check _isPaused(), (2) Does not affect view/pure
functions ensuring protocol state remains readable, (3) Enables rapid response to potential exploits by
halting operations protocol-wide, (4) Requires emergency admin role ensuring only authorized governance
can trigger pauses. Inheriting contracts should check _isPaused() modifier in critical functions to
respect the pause state. The external visibility with role check prevents unauthorized pause manipulation.*


```solidity
function setPaused(bool paused_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|The desired pause state (true = halt operations, false = resume normal operation)|


### rescueAssets

Rescues accidentally sent assets (ETH or ERC20 tokens) preventing permanent loss of funds

*This function implements a critical safety mechanism for recovering tokens or ETH that become stuck
in the contract through user error or airdrops. The rescue process: (1) Validates admin authorization to
prevent unauthorized fund extraction, (2) Ensures recipient address is valid to prevent burning funds,
(3) For ETH rescue (asset_=address(0)): validates balance sufficiency and uses low-level call for transfer,
(4) For ERC20 rescue: critically checks the token is NOT a registered protocol asset (USDC, WBTC, etc.) to
protect user deposits and protocol integrity, then validates balance and uses SafeTransferLib for secure
transfer. The distinction between ETH and ERC20 handling accounts for their different transfer mechanisms.
Protocol assets are explicitly blocked from rescue to prevent admin abuse and maintain user trust.*


```solidity
function rescueAssets(address asset_, address to_, uint256 amount_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to rescue (use address(0) for native ETH, otherwise ERC20 token address)|
|`to_`|`address`|The recipient address that will receive the rescued assets (cannot be zero address)|
|`amount_`|`uint256`|The quantity to rescue (must not exceed available balance)|


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


### _getBatchId

Gets the current batch ID for a given vault

*Reverts if vault not registered*


```solidity
function _getBatchId(address vault) internal view returns (bytes32 batchId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The current batch ID|


### _getBatchReceiver

Gets the current batch receiver for a given batchId

*Reverts if vault not registered*


```solidity
function _getBatchReceiver(address vault_, bytes32 batchId_) internal view returns (address batchReceiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|The vault address|
|`batchId_`|`bytes32`|The batch ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchReceiver`|`address`|The address of the batchReceiver where tokens will be sent|


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


### _getDNVaultByAsset

Gets the DN vault address for a given asset

*Reverts if asset not supported*


```solidity
function _getDNVaultByAsset(address asset) internal view returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The corresponding DN vault address|


### _isAdmin

Checks if an address has admin role in the protocol governance

*Admins can execute critical functions like asset rescue and protocol configuration changes.
This validation is used throughout inheriting contracts to enforce permission boundaries.*


```solidity
function _isAdmin(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check for admin privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is registered as an admin in the registry|


### _isEmergencyAdmin

Checks if an address has emergency admin role for critical protocol interventions

*Emergency admins can pause/unpause contracts during security incidents or market anomalies.
This elevated role enables rapid response to threats while limiting scope to emergency functions only.*


```solidity
function _isEmergencyAdmin(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check for emergency admin privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is registered as an emergency admin in the registry|


### _isGuardian

Checks if an address has guardian role for protocol monitoring and verification

*Guardians verify settlement proposals and can cancel incorrect settlements during cooldown periods.
This role provides an additional security layer for yield distribution accuracy.*


```solidity
function _isGuardian(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check for guardian privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is registered as a guardian in the registry|


### _isRelayer

Checks if an address has relayer role for automated protocol operations

*Relayers execute batched operations and trigger settlements on behalf of users to optimize gas costs.
This role enables automation while maintaining security through limited permissions.*


```solidity
function _isRelayer(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check for relayer privileges|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is registered as a relayer in the registry|


### _isInstitution

Checks if an address is registered as an institutional user

*Institutions have special privileges in kMinter for large-scale minting and redemption operations.
This distinction enables optimized flows for high-volume users while maintaining retail accessibility.*


```solidity
function _isInstitution(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check for institutional status|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is registered as an institution in the registry|


### _isPaused

Checks if the contract is currently in emergency pause state

*Used by inheriting contracts to halt operations during emergencies. When paused, state-changing
functions should revert while view functions remain accessible for protocol monitoring.*


```solidity
function _isPaused() internal view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the contract is currently paused|


### _isKMinter

Checks if an address is the kMinter contract

*Validates if the caller is the protocol's kMinter singleton for access control in vault operations.
Used to ensure only kMinter can trigger institutional deposit and redemption flows.*


```solidity
function _isKMinter(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check against kMinter|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is the registered kMinter contract|


### _isVault

Checks if an address is a registered vault


```solidity
function _isVault(address vault) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The address to check|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is a registered vault|


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
### Paused
Emitted when the emergency pause state is toggled for protocol-wide risk mitigation

*This event signals a critical protocol state change that affects all inheriting contracts.
When paused=true, protocol operations are halted to prevent potential exploits or manage emergencies.
Only emergency admins can trigger this, providing rapid response capability during security incidents.*


```solidity
event Paused(bool paused_);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`paused_`|`bool`|The new pause state (true = operations halted, false = normal operation)|

### RescuedAssets
Emitted when ERC20 tokens are rescued from the contract to prevent permanent loss

*This rescue mechanism is restricted to non-protocol assets only - registered assets (USDC, WBTC, etc.)
cannot be rescued to protect user funds and maintain protocol integrity. Typically used to recover
accidentally sent tokens or airdrops. Only admin role can execute rescues as a security measure.*


```solidity
event RescuedAssets(address indexed asset_, address indexed to_, uint256 amount_);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The ERC20 token address being rescued (must not be a registered protocol asset)|
|`to_`|`address`|The recipient address receiving the rescued tokens (cannot be zero address)|
|`amount_`|`uint256`|The quantity of tokens rescued (must not exceed contract balance)|

### RescuedETH
Emitted when native ETH is rescued from the contract to recover stuck funds

*ETH rescue is separate from ERC20 rescue due to different transfer mechanisms. This prevents
ETH from being permanently locked if sent to the contract accidentally. Uses low-level call for
ETH transfer with proper success checking. Only admin role authorized for security.*


```solidity
event RescuedETH(address indexed to_, uint256 amount_);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to_`|`address`|The recipient address receiving the rescued ETH (cannot be zero address)|
|`amount_`|`uint256`|The quantity of ETH rescued in wei (must not exceed contract balance)|

## Structs
### kBaseStorage
*Storage struct following ERC-7201 namespaced storage pattern to prevent collisions during upgrades.
This pattern ensures that storage layout remains consistent across proxy upgrades and prevents
accidental overwriting when contracts inherit from multiple base contracts. The namespace
"kam.storage.kBase" uniquely identifies this storage area within the contract's storage space.*

**Note:**
storage-location: erc7201:kam.storage.kBase


```solidity
struct kBaseStorage {
    address registry;
    bool initialized;
    bool paused;
}
```

