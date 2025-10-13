# IVaultAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/IVaultAdapter.sol)

**Inherits:**
[IVersioned](/src/interfaces/IVersioned.sol/interface.IVersioned.md)


## Functions
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


### execute

Allows the relayer to execute arbitrary calls on behalf of the protocol

*This function enables the relayer role to perform flexible interactions with external contracts
as part of protocol operations. Key aspects of this function include: (1) Authorization restricted to relayer
role to prevent misuse, (2) Pause state check to ensure operations are halted during emergencies, (3) Validates
target addresses are non-zero to prevent calls to the zero address, (4) Uses low-level calls to enable arbitrary
function execution*


```solidity
function execute(
    address[] calldata targets,
    bytes[] calldata data,
    uint256[] calldata values
)
    external
    payable
    returns (bytes[] memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`targets`|`address[]`|Array of target contracts to make calls to|
|`data`|`bytes[]`|Array of calldata to send to each target contract|
|`values`|`uint256[]`|Array of asset amounts to send with each call|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes[]`|The combined return data from all calls|


### setTotalAssets

Sets the last recorded total assets for vault accounting and performance tracking

*This function allows the admin to update the lastTotalAssets variable, which is
used for various accounting and performance metrics within the vault adapter. Key aspects
of this function include: (1) Authorization restricted to admin role to prevent misuse,
(2) Directly updates the lastTotalAssets variable in storage.*


```solidity
function setTotalAssets(uint256 totalAssets_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`totalAssets_`|`uint256`|The new total assets value to set.|


### totalAssets

Retrieves the last recorded total assets for vault accounting and performance tracking

*This function returns the lastTotalAssets variable, which is used for various accounting
and performance metrics within the vault adapter. This provides a snapshot of the total assets
managed by the vault at the last recorded time.*


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The last recorded total assets value.|


## Events
### ContractInitialized
Emitted when the kMinter contract is initialized


```solidity
event ContractInitialized(address indexed registry);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`address`|The address of the registry contract used for protocol configuration|

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

### Executed
Emitted when the relayer executes an arbitrary call on behalf of the protocol

*This event provides transparency into all external interactions initiated by the relayer.
It logs the caller, target contract, function data, value sent, and the resulting returndata.
This is critical for auditing and monitoring protocol actions executed via the relayer role.*


```solidity
event Executed(address indexed caller, address indexed target, bytes data, uint256 value, bytes result);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`caller`|`address`|The relayer address that initiated the call|
|`target`|`address`|The target contract address that was called|
|`data`|`bytes`|The calldata sent to the target contract|
|`value`|`uint256`|The amount of assets sent with the call|
|`result`|`bytes`|The returndata returned from the call|

### TransferExecuted
Emmited when the relayer executes a transfer of assets on behalf of the protocol

*This event provides transparency into all asset transfers initiated by the relayer.
It logs the caller, asset, recipient, and amount transferred. This is critical for auditing
and monitoring protocol asset movements executed via the relayer role.*


```solidity
event TransferExecuted(address indexed asset, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset address that was transferred (address(0) for native ETH)|
|`to`|`address`|The recipient address that received the assets|
|`amount`|`uint256`|The quantity of assets transferred|

