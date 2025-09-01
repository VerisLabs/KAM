# kToken
[Git Source](https://github.com/VerisLabs/KAM/blob/786bfc5b94e4c849db94b9fb47f71818d5cce1ab/src/kToken.sol)

**Inherits:**
ERC20, OwnableRoles, ReentrancyGuard, Multicallable

ERC20 token with role-based minting and burning capabilities

*Implements UUPS upgradeable pattern with 1:1 backing by underlying assets*


## State Variables
### ADMIN_ROLE

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

```solidity
bool _isPaused;
```


### _name

```solidity
string private _name;
```


### _symbol

```solidity
string private _symbol;
```


### _decimals

```solidity
uint8 private _decimals;
```


## Functions
### whenNotPaused

Prevents function execution when contract is in paused state

*Checks isPaused flag in storage and reverts with Paused error if true*


```solidity
modifier whenNotPaused();
```

### constructor

Disables initializers to prevent implementation contract from being initialized

*Calls _disableInitializers from Solady's Initializable to lock implementation*


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

### mint

Creates new tokens and assigns them to the specified address

*Calls internal _mint function and emits Minted event, restricted to MINTER_ROLE*


```solidity
function mint(address _to, uint256 _amount) external nonReentrant whenNotPaused onlyRoles(MINTER_ROLE);
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
function burn(address _from, uint256 _amount) external nonReentrant whenNotPaused onlyRoles(MINTER_ROLE);
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
function burnFrom(address _from, uint256 _amount) external nonReentrant whenNotPaused onlyRoles(MINTER_ROLE);
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
function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address tokens are being transferred from|
|`to`|`address`|The address tokens are being transferred to|
|`amount`|`uint256`|The quantity of tokens being transferred|


## Events
### Minted

```solidity
event Minted(address indexed to, uint256 amount);
```

### Burned

```solidity
event Burned(address indexed from, uint256 amount);
```

### TokenCreated

```solidity
event TokenCreated(address indexed token, address owner, string name, string symbol, uint8 decimals);
```

### PauseState

```solidity
event PauseState(bool isPaused);
```

### AuthorizedCallerUpdated

```solidity
event AuthorizedCallerUpdated(address indexed caller, bool authorized);
```

### EmergencyWithdrawal

```solidity
event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);
```

### RescuedAssets

```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

### RescuedETH

```solidity
event RescuedETH(address indexed asset, uint256 amount);
```

## Errors
### Paused

```solidity
error Paused();
```

### ZeroAddress

```solidity
error ZeroAddress();
```

### ZeroAmount

```solidity
error ZeroAmount();
```

### ContractNotPaused

```solidity
error ContractNotPaused();
```

### TransferFailed

```solidity
error TransferFailed();
```

