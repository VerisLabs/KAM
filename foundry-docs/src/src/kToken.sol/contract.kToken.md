# kToken
[Git Source](https://github.com/VerisLabs/KAM/blob/98bf94f655b7cb7ee02d37c9adf34075fa170b4b/src/kToken.sol)

**Inherits:**
[ERC20](/src/vendor/ERC20.sol/abstract.ERC20.md), [OptimizedOwnableRoles](/src/libraries/OptimizedOwnableRoles.sol/abstract.OptimizedOwnableRoles.md), [OptimizedReentrancyGuardTransient](/src/abstracts/OptimizedReentrancyGuardTransient.sol/abstract.OptimizedReentrancyGuardTransient.md), [Multicallable](/src/vendor/Multicallable.sol/abstract.Multicallable.md)

ERC20 representation of underlying assets with guaranteed 1:1 backing in the KAM protocol

*This contract serves as the tokenized wrapper for protocol-supported underlying assets (USDC, WBTC, etc.).
Each kToken maintains a strict 1:1 relationship with its underlying asset through controlled minting and burning.
Key characteristics: (1) Authorized minters (kMinter for institutional deposits, kAssetRouter for yield
distribution)
can create/destroy tokens, (2) kMinter mints tokens 1:1 when assets are deposited and burns during redemptions,
(3) kAssetRouter mints tokens to distribute positive yield to vaults and burns tokens for negative yield/losses,
(4) Implements three-tier role system: ADMIN_ROLE for management, EMERGENCY_ADMIN_ROLE for emergency operations,
MINTER_ROLE for token creation/destruction, (5) Features emergency pause mechanism to halt all transfers during
protocol emergencies, (6) Supports emergency asset recovery for accidentally sent tokens. The contract ensures
protocol integrity by maintaining that kToken supply accurately reflects the underlying asset backing plus any
distributed yield, while enabling efficient yield distribution without physical asset transfers.*


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
Emergency pause state flag for halting all token operations during crises

*When true, prevents all transfers, minting, and burning through _beforeTokenTransfer hook*


```solidity
bool _isPaused;
```


### _name
Human-readable name of the kToken (e.g., "KAM USDC")

*Stored privately to override ERC20 default implementation with custom naming*


```solidity
string private _name;
```


### _symbol
Trading symbol of the kToken (e.g., "kUSDC")

*Stored privately to provide consistent protocol naming convention*


```solidity
string private _symbol;
```


### _decimals
Number of decimal places for the kToken, matching the underlying asset

*Critical for maintaining 1:1 exchange rates with underlying assets*


```solidity
uint8 private _decimals;
```


## Functions
### constructor

Deploys and initializes a new kToken with specified parameters and role assignments

*This constructor is called by kRegistry during asset registration to create the kToken wrapper.
The process establishes: (1) ownership hierarchy with owner at the top, (2) role assignments for protocol
operations, (3) token metadata matching the underlying asset. The decimals parameter is particularly
important as it must match the underlying asset to maintain accurate 1:1 exchange rates.*


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
|`owner_`|`address`|The contract owner (typically kRegistry or protocol governance)|
|`admin_`|`address`|Address to receive ADMIN_ROLE for managing minters and emergency admins|
|`emergencyAdmin_`|`address`|Address to receive EMERGENCY_ADMIN_ROLE for pause/emergency operations|
|`minter_`|`address`|Address to receive initial MINTER_ROLE (typically kMinter contract)|
|`name_`|`string`|Human-readable token name (e.g., \"KAM USDC\")|
|`symbol_`|`string`|Token symbol for trading (e.g., \"kUSDC\")|
|`decimals_`|`uint8`|Decimal places matching the underlying asset for accurate conversions|


### mint

Creates new kTokens and assigns them to the specified address

*This function serves two critical purposes in the KAM protocol: (1) kMinter calls this when institutional
users deposit underlying assets, minting kTokens 1:1 to maintain backing ratio, (2) kAssetRouter calls this
to distribute positive yield to vaults, increasing the kToken supply to reflect earned returns. The function
is restricted to MINTER_ROLE holders (kMinter, kAssetRouter) and requires the contract to not be paused.
All minting operations emit a Minted event for transparency and tracking.*


```solidity
function mint(address _to, uint256 _amount) external onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_to`|`address`|The address that will receive the newly minted kTokens|
|`_amount`|`uint256`|The quantity of kTokens to create (matches asset amount for deposits, yield amount for distributions)|


### burn

Destroys kTokens from the specified address

*This function handles token destruction for two main scenarios: (1) kMinter burns escrowed kTokens during
successful redemptions, reducing total supply to match the underlying assets being withdrawn, (2) kAssetRouter
burns kTokens from vaults when negative yield/losses occur, ensuring the kToken supply accurately reflects the
reduced underlying asset value. The burn operation is permanent and irreversible, requiring careful validation.
Only MINTER_ROLE holders can execute burns, and the contract must not be paused.*


```solidity
function burn(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address from which kTokens will be permanently destroyed|
|`_amount`|`uint256`|The quantity of kTokens to burn (matches redeemed assets or loss amounts)|


### burnFrom

Destroys kTokens from a specified address using the ERC20 allowance mechanism

*This function enables more complex burning scenarios where the token holder has pre-approved the burn
operation. The process involves: (1) checking and consuming the allowance between token owner and the minter,
(2) burning the specified amount from the owner's balance. This is useful for automated systems or contracts
that need to burn tokens on behalf of users, such as complex redemption flows or third-party integrations.
The allowance model provides additional security by requiring explicit approval before token destruction.*


```solidity
function burnFrom(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_from`|`address`|The address from which kTokens will be burned (must have approved the burn amount)|
|`_amount`|`uint256`|The quantity of kTokens to burn using the allowance mechanism|


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

Grants administrative privileges to a new address

*Only the contract owner can grant admin roles, establishing the highest level of access control.
Admins can manage emergency admins and minter roles but cannot bypass owner-only functions.*


```solidity
function grantAdminRole(address admin) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address to receive administrative privileges|


### revokeAdminRole

Removes administrative privileges from an address

*Only the contract owner can revoke admin roles, maintaining strict access control hierarchy.
Revoking admin status prevents the address from managing emergency admins and minter roles.*


```solidity
function revokeAdminRole(address admin) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`admin`|`address`|The address to lose administrative privileges|


### grantEmergencyRole

Grants emergency administrative privileges for protocol safety operations

*Emergency admins can pause/unpause the contract and execute emergency withdrawals during crises.
This role is critical for protocol security and should only be granted to trusted addresses with
operational procedures in place. Only existing admins can grant emergency roles.*


```solidity
function grantEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergency`|`address`|The address to receive emergency administrative privileges|


### revokeEmergencyRole

Removes emergency administrative privileges from an address

*Removes the ability to pause contracts and execute emergency operations. This should be done
carefully as it reduces the protocol's ability to respond to emergencies.*


```solidity
function revokeEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`emergency`|`address`|The address to lose emergency administrative privileges|


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

Activates or deactivates the emergency pause mechanism

*When paused, all token transfers, minting, and burning operations are halted to protect the protocol
during security incidents or system maintenance. Only emergency admins can trigger pause/unpause to ensure
rapid response capability. The pause state affects all token operations through the _beforeTokenTransfer hook.*


```solidity
function setPaused(bool isPaused_) external onlyRoles(EMERGENCY_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`isPaused_`|`bool`|True to pause all operations, false to resume normal operations|


### emergencyWithdraw

Emergency recovery function for accidentally sent assets

*This function provides a safety mechanism to recover tokens or ETH accidentally sent to the kToken
contract.
It's designed for emergency situations where users mistakenly transfer assets to the wrong address.
The function can handle both ERC20 tokens and native ETH. Only emergency admins can execute withdrawals
to prevent unauthorized asset extraction. This should not be used for regular operations.*


```solidity
function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The token contract address to withdraw (use address(0) for native ETH)|
|`to`|`address`|The destination address to receive the recovered assets|
|`amount`|`uint256`|The quantity of tokens or ETH to recover|


### _checkPaused

Internal function to validate that the contract is not in emergency pause state

*Called before all token operations (transfers, mints, burns) to enforce emergency stops.
Reverts with KTOKEN_IS_PAUSED if the contract is paused, effectively halting all token activity.*


```solidity
function _checkPaused() private view;
```

### _beforeTokenTransfer

Internal hook that executes before any token transfer, mint, or burn operation

*This critical function enforces the pause mechanism across all token operations by checking the pause
state before allowing any balance changes. It intercepts transfers, mints (from=0), and burns (to=0) to
ensure protocol-wide emergency stops work correctly. The hook pattern allows centralized control over
all token movements while maintaining ERC20 compatibility.*


```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The source address (address(0) for minting operations)|
|`to`|`address`|The destination address (address(0) for burning operations)|
|`amount`|`uint256`|The quantity of tokens being transferred/minted/burned|


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

