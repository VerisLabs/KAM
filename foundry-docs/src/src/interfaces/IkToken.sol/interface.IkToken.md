# IkToken
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/IkToken.sol)

**Inherits:**
[IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)

Interface for kToken with role-based minting and burning capabilities

*Defines the standard interface for kToken implementations with ERC20 compatibility*


## Functions
### mint

Creates new tokens and assigns them to the specified address

*Only callable by addresses with MINTER_ROLE, emits Minted event*


```solidity
function mint(address to, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address that will receive the newly minted tokens|
|`amount`|`uint256`|The quantity of tokens to create and assign|


### burn

Destroys tokens from the specified address

*Only callable by addresses with MINTER_ROLE, emits Burned event*


```solidity
function burn(address from, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address from which tokens will be destroyed|
|`amount`|`uint256`|The quantity of tokens to destroy|


### burnFrom

Destroys tokens from an address using allowance mechanism

*Reduces allowance and burns tokens, only callable by addresses with MINTER_ROLE*


```solidity
function burnFrom(address from, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address from which tokens will be destroyed|
|`amount`|`uint256`|The quantity of tokens to destroy|


### name

Returns the name of the token


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The name of the token as a string|


### symbol

Returns the symbol of the token


```solidity
function symbol() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The symbol of the token as a string|


### decimals

Returns the number of decimal places for the token


```solidity
function decimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimal places as uint8|


### totalSupply

Returns the total amount of tokens in existence


```solidity
function totalSupply() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply of tokens|


### balanceOf

Returns the token balance of a specific account


```solidity
function balanceOf(address account) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to query the balance for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The token balance of the specified account|


### transfer

Transfers tokens from the caller to another address


```solidity
function transfer(address to, uint256 amount) external returns (bool success);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to transfer tokens to|
|`amount`|`uint256`|The amount of tokens to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|True if the transfer succeeded, false otherwise|


### allowance

Returns the amount of tokens that spender is allowed to spend on behalf of owner


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address that owns the tokens|
|`spender`|`address`|The address that is approved to spend the tokens|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of tokens the spender is allowed to spend|


### approve

Sets approval for another address to spend tokens on behalf of the caller


```solidity
function approve(address spender, uint256 amount) external returns (bool success);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|The address that is approved to spend the tokens|
|`amount`|`uint256`|The amount of tokens the spender is approved to spend|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|True if the approval succeeded, false otherwise|


### transferFrom

Transfers tokens from one address to another using allowance mechanism


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool success);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address to transfer tokens from|
|`to`|`address`|The address to transfer tokens to|
|`amount`|`uint256`|The amount of tokens to transfer|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`success`|`bool`|True if the transfer succeeded, false otherwise|


### isPaused

Returns the current pause state of the contract


```solidity
function isPaused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the contract is paused, false otherwise|


### setPaused

Sets the pause state of the contract

*Only callable by addresses with EMERGENCY_ADMIN_ROLE*


```solidity
function setPaused(bool _isPaused) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_isPaused`|`bool`|True to pause the contract, false to unpause|


### grantAdminRole

Grants administrative privileges to an address

*Only callable by the contract owner*


```solidity
function grantAdminRole(address admin) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address to grant admin role to|


### revokeAdminRole

Revokes administrative privileges from an address

*Only callable by the contract owner*


```solidity
function revokeAdminRole(address admin) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address to revoke admin role from|


### grantEmergencyRole

Grants emergency administrative privileges to an address

*Only callable by addresses with ADMIN_ROLE*


```solidity
function grantEmergencyRole(address emergency) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergency`|`address`|The address to grant emergency admin role to|


### revokeEmergencyRole

Revokes emergency administrative privileges from an address

*Only callable by addresses with ADMIN_ROLE*


```solidity
function revokeEmergencyRole(address emergency) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergency`|`address`|The address to revoke emergency admin role from|


### grantMinterRole

Grants minting privileges to an address

*Only callable by addresses with ADMIN_ROLE*


```solidity
function grantMinterRole(address minter) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The address to grant minter role to|


### revokeMinterRole

Revokes minting privileges from an address

*Only callable by addresses with ADMIN_ROLE*


```solidity
function revokeMinterRole(address minter) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minter`|`address`|The address to revoke minter role from|


