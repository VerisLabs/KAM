# kBaseRoles
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/base/kBaseRoles.sol)

**Inherits:**
[OptimizedOwnableRoles](/src/vendor/solady/auth/OptimizedOwnableRoles.sol/abstract.OptimizedOwnableRoles.md)

Foundation contract providing essential shared functionality and registry integration for all KAM protocol


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
Vendor role for Vendor vaults


```solidity
uint256 internal constant VENDOR_ROLE = _ROLE_5;
```


### MANAGER_ROLE
Vendor role for Manager vaults


```solidity
uint256 internal constant MANAGER_ROLE = _ROLE_6;
```


### KROLESBASE_STORAGE_LOCATION
This specific slot is chosen to avoid any possible collision with standard storage layouts while maintaining
deterministic addressing. The calculation ensures the storage location is unique to this namespace and won't
conflict with other inherited contracts or future upgrades. The 0xff mask ensures proper alignment.


```solidity
bytes32 private constant KROLESBASE_STORAGE_LOCATION =
    0x841668355433cc9fb8fc1984bd90b939822ef590acd27927baab4c6b4fb12900;
```


## Functions
### _getkBaseRolesStorage

*Returns the kBase storage pointer using ERC-7201 namespaced storage pattern*


```solidity
function _getkBaseRolesStorage() internal pure returns (kBaseRolesStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`kBaseRolesStorage`|Storage pointer to the kBaseStorage struct at the designated storage location This function uses inline assembly to directly set the storage pointer to our namespaced location, ensuring efficient access to storage variables while maintaining upgrade safety. The pure modifier is used because we're only returning a storage pointer, not reading storage values.|


### __kBaseRoles_init


```solidity
function __kBaseRoles_init(
    address owner_,
    address admin_,
    address emergencyAdmin_,
    address guardian_,
    address relayer_
)
    internal;
```

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


### _hasRole

Internal helper to check if a user has a specific role

*Wraps the OptimizedOwnableRoles hasAnyRole function for role verification*


```solidity
function _hasRole(address user, uint256 role_) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to check for role membership|
|`role_`|`uint256`|The role constant to check (e.g., ADMIN_ROLE, VENDOR_ROLE)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the user has the specified role, false otherwise|


### _checkAdmin

Check if caller has Admin role


```solidity
function _checkAdmin(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkEmergencyAdmin

Check if caller has Emergency Admin role


```solidity
function _checkEmergencyAdmin(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkGuardian

Check if caller has Guardian role


```solidity
function _checkGuardian(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkRelayer

Check if caller has relayer role


```solidity
function _checkRelayer(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkInstitution

Check if caller has Institution role


```solidity
function _checkInstitution(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkVendor

Check if caller has Vendor role


```solidity
function _checkVendor(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkManager

Check if caller has Manager role


```solidity
function _checkManager(address user) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkAddressNotZero

Check if address is not zero


```solidity
function _checkAddressNotZero(address addr) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|Address to check|


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

## Structs
### kBaseRolesStorage
*Storage struct following ERC-7201 namespaced storage pattern to prevent collisions during upgrades.
This pattern ensures that storage layout remains consistent across proxy upgrades and prevents
accidental overwriting when contracts inherit from multiple base contracts. The namespace
"kam.storage.kBaseRoles" uniquely identifies this storage area within the contract's storage space.*

**Note:**
storage-location: erc7201:kam.storage.kBaseRoles


```solidity
struct kBaseRolesStorage {
    bool initialized;
    bool paused;
}
```

