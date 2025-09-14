# VaultAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/adapters/VaultAdapter.sol)

**Inherits:**
[IVaultAdapter](/src/interfaces/IVaultAdapter.sol/interface.IVaultAdapter.md), [Initializable](/src/vendor/solady/utils/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/solady/utils/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md)


## State Variables
### VAULTADAPTER_STORAGE_LOCATION

```solidity
bytes32 private constant VAULTADAPTER_STORAGE_LOCATION =
    0xf3245d0f4654bfd28a91ebbd673859481bdc20aeda8fc19798f835927d79aa00;
```


## Functions
### _getVaultAdapterStorage

Retrieves the VaultAdapter storage struct from its designated storage slot

*Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
storage variables in future upgrades without affecting existing storage layout.*


```solidity
function _getVaultAdapterStorage() private pure returns (VaultAdapterStorage storage $);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`$`|`VaultAdapterStorage`|The VaultAdapterStorage struct reference for state modifications|


### constructor

Disables initializers to prevent implementation contract initialization


```solidity
constructor();
```

### initialize

Initializes the VaultAdapter contract


```solidity
function initialize(address registry_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the registry contract|


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
target address is non-zero to prevent calls to the zero address, (4) Uses low-level call to enable arbitrary
function execution*


```solidity
function execute(address target, bytes calldata data, uint256 value) external returns (bytes memory result);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The target contract to make a call to.|
|`data`|`bytes`|The data to send to the target contract.|
|`value`|`uint256`|The amount of assets to send with the call.|


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


### _checkAdmin

Check if caller has admin role


```solidity
function _checkAdmin(address user) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|Address to check|


### _checkPaused

Ensures the contract is not paused


```solidity
function _checkPaused() internal view;
```

### _checkVaultCanCallSelector

Validates that a vault can call a specific selector on a target

*This function enforces the new vault-specific permission model where each vault
has granular permissions for specific functions on specific targets. This replaces
the old global allowedTargets approach with better security isolation.*


```solidity
function _checkVaultCanCallSelector(address target, bytes4 selector) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The target contract to be called|
|`selector`|`bytes4`|The function selector being called|


### _checkZeroAddress

Reverts if its a zero address


```solidity
function _checkZeroAddress(address addr) internal pure;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|Address to check|


### _checkAsset

Reverts if the asset is not supported by the protocol


```solidity
function _checkAsset(address asset) private view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|Asset address to check|


### _authorizeUpgrade

Authorizes contract upgrades

*Only callable by ADMIN_ROLE*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|New implementation address|


### contractName

Returns the human-readable name identifier for this contract type

*Used for contract identification and logging purposes. The name should be consistent
across all versions of the same contract type. This enables external systems and other
contracts to identify the contract's purpose and role within the protocol ecosystem.*


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract name as a string (e.g., "kMinter", "kAssetRouter", "kRegistry")|


### contractVersion

Returns the version identifier for this contract implementation

*Used for upgrade management and compatibility checking within the protocol. The version
string should follow semantic versioning (e.g., "1.0.0") to clearly indicate major, minor,
and patch updates. This enables the protocol governance and monitoring systems to track
deployed versions and ensure compatibility between interacting components.*


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract version as a string following semantic versioning (e.g., "1.0.0")|


## Structs
### VaultAdapterStorage
Core storage structure for VaultAdapter using ERC-7201 namespaced storage pattern

*This structure manages all state for institutional minting and redemption operations.
Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.*

**Note:**
storage-location: erc7201:kam.storage.VaultAdapter


```solidity
struct VaultAdapterStorage {
    IRegistry registry;
    bool paused;
    uint256 lastTotalAssets;
}
```

