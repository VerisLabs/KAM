# CustodialAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/adapters/CustodialAdapter.sol)

**Inherits:**
[BaseAdapter](/src/adapters/BaseAdapter.sol/contract.BaseAdapter.md), [Initializable](/src/vendor/Initializable.sol/abstract.Initializable.md), [UUPSUpgradeable](/src/vendor/UUPSUpgradeable.sol/abstract.UUPSUpgradeable.md)

Specialized adapter enabling yield generation through custodial services like CEX staking and institutional
platforms

*This adapter implements the bridge between KAM protocol vaults and external custodial yield sources
(centralized
exchanges, CEFFU, institutional staking providers). Key functionality includes: (1) Virtual balance tracking that
maintains on-chain accounting while assets are held off-chain, (2) Configurable custodial destinations per vault
allowing flexible routing to different providers, (3) Two-phase deposit/redemption flow where deposits are tracked
virtually and actual transfers happen through manual processes, (4) Total assets management for accurate yield
calculation during settlements, (5) Request ID system for tracking redemption operations. The adapter operates on
a trust-minimized model where admin-controlled totalAssets updates reflect off-chain yields, which are then
distributed
through the settlement process. This design enables institutional-grade yield opportunities while maintaining the
protocol's unified settlement and distribution mechanisms. The virtual balance system ensures accurate accounting
even when assets are temporarily off-chain for yield generation.*


## State Variables
### CUSTODIAL_ADAPTER_STORAGE_LOCATION

```solidity
bytes32 private constant CUSTODIAL_ADAPTER_STORAGE_LOCATION =
    0x6096605776f37a069e5fb3b2282c592b4e41a8f7c82e8665fde33e5acbdbaf00;
```


## Functions
### _getCustodialAdapterStorage

*Returns the custodial adapter storage pointer*


```solidity
function _getCustodialAdapterStorage() internal pure returns (CustodialAdapterStorage storage $);
```

### constructor

Empty constructor to ensure clean initialization state


```solidity
constructor();
```

### initialize

Initializes the CustodialAdapter with registry integration and request tracking

*Initialization process: (1) Calls BaseAdapter initialization for registry setup and metadata,
(2) Initializes request ID counter for redemption tracking, (3) Emits initialization event for
monitoring. The adapter starts with no vault destinations configured - these must be set by admin
before deposits can occur. Uses OpenZeppelin's initializer modifier for reentrancy protection.*


```solidity
function initialize(address registry_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|The kRegistry contract address for protocol configuration and access control|


### deposit

Virtually deposits assets for custodial yield generation while maintaining on-chain accounting

*This function handles the on-chain accounting when assets are routed to custodial services. Process:
(1) Validates caller is kAssetRouter ensuring centralized control over deposits, (2) Validates parameters
to prevent zero deposits or invalid addresses, (3) Checks vault has configured custodial destination,
(4) Verifies adapter has received the assets from kAssetRouter, (5) Updates virtual balance tracking
for accurate accounting. Note: This doesn't transfer to custodial address - that happens through separate
manual processes. The virtual tracking ensures the protocol knows asset locations even when off-chain.
This two-phase approach enables yield generation through custodial services while maintaining protocol
accounting integrity for settlements.*


```solidity
function deposit(address asset, uint256 amount, address onBehalfOf) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset being deposited (must be protocol-registered)|
|`amount`|`uint256`|The quantity being virtually deposited (must be non-zero)|
|`onBehalfOf`|`address`|The vault that owns these assets for yield attribution|


### redeem

Virtually redeems assets from custodial holdings by updating on-chain accounting

*Handles the accounting for asset redemptions from custodial services. Process: (1) Validates
caller is kAssetRouter for centralized control, (2) Validates parameters preventing invalid redemptions,
(3) Checks vault has configured destination ensuring proper setup, (4) Decrements virtual balance
reflecting the redemption request. Like deposits, actual asset return from custodial address happens
through manual processes. The virtual balance update ensures accurate protocol accounting during the
redemption period. This function is virtual allowing specialized implementations to add custom logic
while maintaining base redemption accounting.*


```solidity
function redeem(address asset, uint256 amount, address onBehalfOf) external virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset being redeemed|
|`amount`|`uint256`|The quantity to redeem (must not exceed virtual balance)|
|`onBehalfOf`|`address`|The vault requesting redemption of its assets|


### totalEstimatedAssets

Returns the current total assets across all custodial addresses for this asset


```solidity
function totalEstimatedAssets(address vault, address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault to query|
|`asset`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets currently held across all custodial addresses managed by this adapter|


### totalVirtualAssets

Returns the total assets in storage for a given vault


```solidity
function totalVirtualAssets(address vault, address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets currently held in storage for this vault|


### totalAssets

Returns the total assets for a given vault and asset


```solidity
function totalAssets(address vault, address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets currently held for this vault and asset|


### getLastTotalAssets

Returns the last total assets for a given vault and asset


```solidity
function getLastTotalAssets(address vault, address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`|The asset address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The last total assets for the vault and asset|


### getVaultDestination

Returns the custodial address for a given vault


```solidity
function getVaultDestination(address vault) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The custodial address for the vault|


### setVaultDestination

Configures the custodial destination address for a specific vault's assets

*Admin function to map vaults to their custodial service providers. Process: (1) Validates admin
authorization for security, (2) Ensures both addresses are valid preventing misconfiguration,
(3) Validates vault is registered in protocol ensuring only authorized vaults use custodial services,
(4) Updates mapping and emits event for tracking. Each vault can have a unique destination enabling
diversification across custodial providers. Must be configured before deposits can occur.*


```solidity
function setVaultDestination(address vault, address custodialAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address to configure custodial destination for|
|`custodialAddress`|`address`|The off-chain custodial address (CEX wallet, institutional account)|


### setTotalAssets

Updates total assets to reflect off-chain yields for settlement calculations

*Critical function for yield distribution - allows kAssetRouter to update asset values based on
off-chain performance. Process: (1) Validates caller is kAssetRouter ensuring only settlement process
can update, (2) Sets new total reflecting yields or losses from custodial services, (3) Emits event
for tracking. The difference between previous and new totalAssets represents yield to be distributed
during settlement. This trust-minimized approach requires careful monitoring but enables access to
institutional yield opportunities not available on-chain.*


```solidity
function setTotalAssets(address vault, address asset, uint256 totalAssets_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault whose assets are being updated|
|`asset`|`address`|The specific asset being updated|
|`totalAssets_`|`uint256`|The new total value including any yields or losses|


### _authorizeUpgrade

Authorizes contract upgrades through UUPS pattern with admin validation

*Security-critical function controlling adapter upgrades. Only admin can authorize ensuring
governance control over adapter evolution. Validates new implementation address preventing
accidental upgrades to zero address. Part of UUPS upgrade pattern for gas-efficient upgrades.*


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The new adapter implementation contract address|


## Events
### VaultDestinationUpdated
Emitted when a vault's custodial destination address is configured or updated

*Custodial addresses represent off-chain destinations (CEX wallets, institutional accounts) where
assets are sent for yield generation. Each vault can have its own destination for segregation.*


```solidity
event VaultDestinationUpdated(address indexed vault, address indexed oldAddress, address indexed newAddress);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address whose custodial destination is being updated|
|`oldAddress`|`address`|The previous custodial address (address(0) if first configuration)|
|`newAddress`|`address`|The new custodial address for this vault's assets|

### TotalAssetsUpdated
Emitted when total assets are updated to reflect off-chain yields or losses

*This update mechanism allows the protocol to account for yields generated in custodial accounts.
The kAssetRouter uses these values during settlement to calculate and distribute yields.*


```solidity
event TotalAssetsUpdated(address indexed vault, uint256 totalAssets);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address whose total assets are being updated|
|`totalAssets`|`uint256`|The new total asset value including any yields or losses|

### Deposited
Emitted when assets are virtually deposited for custodial yield generation

*Marks the virtual accounting update when kAssetRouter routes assets to this adapter.
Actual transfer to custodial address happens separately through manual processes.*


```solidity
event Deposited(address indexed asset, uint256 amount, address indexed onBehalfOf);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset being deposited (USDC, WBTC, etc.)|
|`amount`|`uint256`|The quantity of assets being virtually deposited|
|`onBehalfOf`|`address`|The vault address that owns these deposited assets|

### RedemptionRequested
Emitted when redemption is requested from custodial holdings

*Initiates the redemption process by updating virtual balances. Actual asset return
from custodial address happens through manual processes coordinated off-chain.*


```solidity
event RedemptionRequested(address indexed asset, uint256 amount, address indexed onBehalfOf);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The underlying asset being redeemed|
|`amount`|`uint256`|The quantity requested for redemption|
|`onBehalfOf`|`address`|The vault requesting the redemption|

### RedemptionProcessed
Emitted when a redemption is processed


```solidity
event RedemptionProcessed(uint256 indexed requestId, uint256 assets);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`uint256`|The request ID|
|`assets`|`uint256`|The amount of assets processed|

### AdapterBalanceUpdated
Emitted when the adapter balance is updated


```solidity
event AdapterBalanceUpdated(address indexed vault, address indexed asset, uint256 newBalance);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`|The asset address|
|`newBalance`|`uint256`|The new balance|

### Initialised
Emitted when the adapter is initialized


```solidity
event Initialised(address indexed registry);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`address`|The registry address|

## Structs
### CustodialAdapterStorage
*Storage layout using ERC-7201 pattern for upgrade safety and collision prevention*

**Note:**
storage-location: erc7201:kam.storage.CustodialAdapter


```solidity
struct CustodialAdapterStorage {
    uint256 nextRequestId;
    mapping(address vault => mapping(address asset => uint256 balance)) balanceOf;
    mapping(address vault => mapping(address asset => uint256 totalAssets)) totalAssets;
    mapping(address vault => address custodialAddress) vaultDestinations;
}
```

