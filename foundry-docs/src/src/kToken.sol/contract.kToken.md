# kToken
[Git Source](https://github.com/VerisLabs/KAM/blob/26924a026af1e1620e830002fd931ff7e42525b6/src/kToken.sol)

**Inherits:**
[ERC20](/src/vendor/ERC20.sol/abstract.ERC20.md), [OptimizedOwnableRoles](/src/libraries/OptimizedOwnableRoles.sol/abstract.OptimizedOwnableRoles.md), [OptimizedReentrancyGuardTransient](/src/abstracts/OptimizedReentrancyGuardTransient.sol/abstract.OptimizedReentrancyGuardTransient.md), [Multicallable](/src/vendor/Multicallable.sol/abstract.Multicallable.md)

ERC20 token with role-based minting and burning capabilities

*Implements UUPS upgradeable pattern with 1:1 backing by underlying assets*


## State Variables
### ADMIN_ROLE
Role constants


```solidity
uint256 public constant ADMIN_ROLE = _ROLE_0;
```


### EMERGENCY_ADMIN_ROLE

```solidity
uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
```


### MINTER_ROLE

```solidity
uint256 public constant MINTER_ROLE = _ROLE_2;
```


### _isPaused
Pause state


```solidity
bool _isPaused;
```


### _name
Name of the token


```solidity
string private _name;
```


### _symbol
Symbol of the token


```solidity
string private _symbol;
```


### _decimals
Decimals of the token


```solidity
uint8 private _decimals;
```


## Functions
### constructor

Initializes the kToken contract


```solidity
constructor(
    address owner_,
    address admin_,
    address emergencyAdmin_,
    address minter_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_
);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|Contract owner address|
|`admin_`|`address`|Admin role recipient|
|`emergencyAdmin_`|`address`|Emergency admin role recipient|
|`minter_`|`address`|Minter role recipient|
|`name_`|`string`|Name of the token|
|`symbol_`|`string`|Symbol of the token|
|`decimals_`|`uint8`|Decimals of the token|


### mint

Creates new tokens and assigns them to the specified address

*Calls internal _mint function and emits Minted event, restricted to MINTER_ROLE*


```solidity
function mint(address _to, uint256 _amount) external onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address that will receive the newly minted tokens|
|`_amount`|`uint256`|The quantity of tokens to create and assign|


### burn

Destroys tokens from the specified address

*Calls internal _burn function and emits Burned event, restricted to MINTER_ROLE*


```solidity
function burn(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address from which tokens will be destroyed|
|`_amount`|`uint256`|The quantity of tokens to destroy|


### burnFrom

Destroys tokens from specified address using allowance mechanism

*Consumes allowance before burning, calls _spendAllowance then _burn, restricted to MINTER_ROLE*


```solidity
function burnFrom(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address from which tokens will be destroyed|
|`_amount`|`uint256`|The quantity of tokens to destroy from the allowance|


### name

Retrieves the human-readable name of the token

*Returns the name stored in contract storage during initialization*


```solidity
function name() public view virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token name as a string|


### symbol

Retrieves the abbreviated symbol of the token

*Returns the symbol stored in contract storage during initialization*


```solidity
function symbol() public view virtual override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token symbol as a string|


### decimals

Retrieves the number of decimal places for the token

*Returns the decimals value stored in contract storage during initialization*


```solidity
function decimals() public view virtual override returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimal places as uint8|


### isPaused

Checks whether the contract is currently in paused state

*Reads the isPaused flag from contract storage*


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Boolean indicating if contract operations are paused|


### grantAdminRole

Grant admin role


```solidity
function grantAdminRole(address admin) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address to grant admin role to|


### revokeAdminRole

Revoke admin role


```solidity
function revokeAdminRole(address admin) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|Address to revoke admin role from|


### grantEmergencyRole

Grant emergency role


```solidity
function grantEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergency`|`address`|Address to grant emergency role to|


### revokeEmergencyRole

Revoke emergency role


```solidity
function revokeEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergency`|`address`|Address to revoke emergency role from|


### grantMinterRole

Assigns minter role privileges to the specified address

*Calls internal _grantRoles function to assign MINTER_ROLE*


```solidity
function grantMinterRole(address minter) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The address that will receive minter role privileges|


### revokeMinterRole

Removes minter role privileges from the specified address

*Calls internal _removeRoles function to remove MINTER_ROLE*


```solidity
function revokeMinterRole(address minter) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The address that will lose minter role privileges|


### setPaused

Sets the pause state of the contract

*Updates the isPaused flag in storage and emits PauseState event*


```solidity
function setPaused(bool isPaused_) external onlyRoles(EMERGENCY_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isPaused_`|`bool`|Boolean indicating whether to pause (true) or unpause (false) the contract|


### emergencyWithdraw

Emergency withdrawal of tokens sent by mistake

*Can only be called by emergency admin when contract is paused*


```solidity
function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token address to withdraw (use address(0) for ETH)|
|`to`|`address`|Recipient address|
|`amount`|`uint256`|Amount to withdraw|


### _beforeTokenTransfer

Internal hook that executes before any token transfer

*Applies whenNotPaused modifier to prevent transfers during pause, then calls parent implementation*


```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address tokens are being transferred from|
|`to`|`address`|The address tokens are being transferred to|
|`amount`|`uint256`|The quantity of tokens being transferred|


## Events
### Minted
Emitted when tokens are minted


```solidity
event Minted(address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to which the tokens are minted|
|`amount`|`uint256`|The quantity of tokens minted|

### Burned
Emitted when tokens are burned


```solidity
event Burned(address indexed from, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address from which tokens are burned|
|`amount`|`uint256`|The quantity of tokens burned|

### TokenCreated
Emitted when a new token is created


```solidity
event TokenCreated(address indexed token, address owner, string name, string symbol, uint8 decimals);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the new token|
|`owner`|`address`|The owner of the new token|
|`name`|`string`|The name of the new token|
|`symbol`|`string`|The symbol of the new token|
|`decimals`|`uint8`|The decimals of the new token|

### PauseState
Emitted when the pause state is changed


```solidity
event PauseState(bool isPaused);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isPaused`|`bool`|The new pause state|

### AuthorizedCallerUpdated
Emitted when an authorized caller is updated


```solidity
event AuthorizedCallerUpdated(address indexed caller, bool authorized);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The address of the caller|
|`authorized`|`bool`|Whether the caller is authorized|

### EmergencyWithdrawal
Emitted when an emergency withdrawal is requested


```solidity
event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token|
|`to`|`address`|The address to which the tokens will be sent|
|`amount`|`uint256`|The amount of tokens to withdraw|
|`admin`|`address`|The address of the admin|

### RescuedAssets
Emitted when assets are rescued


```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset|
|`to`|`address`|The address to which the assets will be sent|
|`amount`|`uint256`|The amount of assets rescued|

### RescuedETH
Emitted when ETH is rescued


```solidity
event RescuedETH(address indexed asset, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The address of the asset|
|`amount`|`uint256`|The amount of ETH rescued|

