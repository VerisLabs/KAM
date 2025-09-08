# BaseAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/adapters/BaseAdapter.sol)

**Inherits:**
[OptimizedReentrancyGuardTransient](/src/abstracts/OptimizedReentrancyGuardTransient.sol/abstract.OptimizedReentrancyGuardTransient.md)

Foundation contract providing essential shared functionality for all protocol adapter implementations

*This abstract contract serves as the base layer for adapter pattern implementations that integrate external
yield strategies (CEX, DeFi protocols, custodial solutions) with the KAM protocol. Key responsibilities include:
(1) Registry integration to maintain protocol-wide configuration consistency and access control, (2) Asset rescue
mechanisms to recover stuck funds while protecting protocol assets from unauthorized extraction, (3) Standardized
initialization patterns ensuring proper setup across all adapter types, (4) Version tracking for upgrade management
and compatibility checks, (5) Role-based access control validation through registry lookups. Adapters enable the
protocol to generate yield from diverse sources while maintaining a unified interface for the kAssetRouter. Each
adapter implementation (CustodialAdapter, AaveAdapter, etc.) extends this base to handle strategy-specific logic
while inheriting critical safety features and protocol integration. The ERC-7201 storage pattern prevents collisions
during upgrades and enables safe composition with other base contracts.*


## State Variables
### K_ASSET_ROUTER
Registry lookup key for the kAssetRouter singleton contract

*Used to retrieve and validate the kAssetRouter address from registry. Only kAssetRouter
can trigger adapter deposits/redemptions, ensuring centralized control over asset flows.*


```solidity
bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
```


### BASE_ADAPTER_STORAGE_LOCATION

```solidity
bytes32 private constant BASE_ADAPTER_STORAGE_LOCATION =
    0x5547882c17743d50a538cd94a34f6308d65f7005fe26b376dcedda44d3aab800;
```


## Functions
### _getBaseAdapterStorage

*Returns the base adapter storage pointer*


```solidity
function _getBaseAdapterStorage() internal pure returns (BaseAdapterStorage storage $);
```

### __BaseAdapter_init

Initializes the base adapter with registry integration and metadata

*This internal initialization establishes the foundation for all adapter implementations. The process:
(1) Validates initialization hasn't occurred to prevent reinitialization in proxy patterns, (2) Ensures
registry address is valid since all access control depends on it, (3) Sets adapter metadata for tracking
and identification, (4) Marks initialization complete. Must be called by inheriting adapter contracts
during their initialization phase to establish proper protocol integration. The internal visibility
ensures only inheriting contracts can initialize, preventing external manipulation.*


```solidity
function __BaseAdapter_init(address registry_, string memory name_, string memory version_) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|The kRegistry contract address for protocol configuration and access control|
|`name_`|`string`|Human-readable adapter identifier (e.g., "CustodialAdapter", "AaveV3Adapter")|
|`version_`|`string`|Semantic version string for upgrade management (e.g., "1.0.0")|


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


```solidity
function _registry() internal view returns (IkRegistry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IkRegistry`|IkRegistry interface for registry interaction|


### rescueAssets

Rescues accidentally sent assets preventing permanent loss in the adapter

*Critical safety mechanism for recovering tokens or ETH stuck in the adapter through user error
or airdrops. The rescue process: (1) Validates admin authorization to prevent unauthorized extraction,
(2) Ensures recipient address validity to prevent burning funds, (3) For ETH (asset_=address(0)):
validates balance and uses low-level call for transfer, (4) For ERC20: critically verifies the token
is NOT a registered protocol asset to protect user deposits, then validates balance and uses
SafeTransferLib. Protocol assets are blocked to prevent admin abuse and maintain user trust. This
function is essential for adapter contracts that may receive unexpected transfers.*


```solidity
function rescueAssets(address asset_, address to_, uint256 amount_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset_`|`address`|The asset to rescue (address(0) for ETH, token address for ERC20)|
|`to_`|`address`|The recipient address for rescued assets (cannot be zero address)|
|`amount_`|`uint256`|The quantity to rescue (must not exceed available balance)|


### name

Returns the adapter's name


```solidity
function name() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Human readable adapter name|


### version

Returns the adapter's version


```solidity
function version() external view returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version string|


### _isAdmin

Checks if an address has admin role for adapter management

*Admins can rescue assets and configure adapter parameters. Access control through registry.*


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
|`<none>`|`bool`|Whether the address is registered as an admin|


### _isKAssetRouter

Checks if an address is the kAssetRouter contract

*Only kAssetRouter can trigger deposits/redemptions in adapters, ensuring centralized control
over asset flows between vaults and external strategies. Critical for maintaining protocol integrity.*


```solidity
function _isKAssetRouter(address user) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to validate against kAssetRouter|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the address is the registered kAssetRouter|


### _isAsset

Checks if an asset is registered in the protocol

*Registered assets (USDC, WBTC, etc.) cannot be rescued to protect user deposits.
This distinction ensures protocol assets remain under vault control.*


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
|`<none>`|`bool`|Whether the asset is a registered protocol asset|


## Events
### RescuedAssets
Emitted when ERC20 tokens are rescued from the adapter to prevent permanent loss

*Rescue mechanism restricted to non-protocol assets to protect user funds. Typically recovers
accidentally sent tokens or airdrops that would otherwise be locked in the adapter contract.*


```solidity
event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The ERC20 token address being rescued (must not be a registered protocol asset)|
|`to`|`address`|The recipient address receiving the rescued tokens|
|`amount`|`uint256`|The quantity of tokens rescued|

### RescuedETH
Emitted when native ETH is rescued from the adapter contract

*Separate from ERC20 rescue due to different transfer mechanisms. Prevents ETH from being
permanently locked if sent to the adapter accidentally.*


```solidity
event RescuedETH(address indexed to, uint256 amount);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address receiving the rescued ETH|
|`amount`|`uint256`|The quantity of ETH rescued in wei|

## Structs
### BaseAdapterStorage
*Storage struct following ERC-7201 namespaced storage pattern for upgrade safety.
Prevents storage collisions when adapters inherit from multiple base contracts.*

**Note:**
storage-location: erc7201:kam.storage.BaseAdapter


```solidity
struct BaseAdapterStorage {
    address registry;
    bool initialized;
    string name;
    string version;
}
```

