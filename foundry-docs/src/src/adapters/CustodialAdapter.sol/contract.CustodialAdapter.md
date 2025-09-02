# CustodialAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/b791d077a3cd28e980c0943d5d7b30be3d8c14e2/src/adapters/CustodialAdapter.sol)

**Inherits:**
[BaseAdapter](/src/adapters/BaseAdapter.sol/contract.BaseAdapter.md), Initializable, UUPSUpgradeable

Adapter for custodial address integrations (CEX, CEFFU, etc.)

*Simple adapter that transfers assets to custodial addresses and tracks virtual balances*


## State Variables
### CUSTODIAL_ADAPTER_STORAGE_LOCATION

```solidity
bytes32 private constant CUSTODIAL_ADAPTER_STORAGE_LOCATION =
    0x6096605776f37a069e5fb3b2282c592b4e41a8f7c82e8665fde33e5acbdbaf00;
```


## Functions
### _getCustodialAdapterStorage


```solidity
function _getCustodialAdapterStorage() internal pure returns (CustodialAdapterStorage storage $);
```

### constructor

Empty constructor to ensure clean initialization state


```solidity
constructor();
```

### initialize

Initializes the MetaVault adapter


```solidity
function initialize(address registry_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`registry_`|`address`|Address of the kRegistry contract|


### deposit

Deposits assets to external strategy


```solidity
function deposit(address asset, uint256 amount, address onBehalfOf) external nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset to deposit|
|`amount`|`uint256`|The amount to deposit|
|`onBehalfOf`|`address`|The vault address this deposit is for|


### redeem

Redeems assets from external strategy


```solidity
function redeem(address asset, uint256 amount, address onBehalfOf) external virtual nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset to redeem|
|`amount`|`uint256`|The amount to redeem|
|`onBehalfOf`|`address`|The vault address this redemption is for|


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

Sets the custodial address for a vault


```solidity
function setVaultDestination(address vault, address custodialAddress) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`custodialAddress`|`address`|The custodial address for this vault|


### setTotalAssets

Sets the total assets for a given vault


```solidity
function setTotalAssets(address vault, address asset, uint256 totalAssets_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`||
|`totalAssets_`|`uint256`|The total assets to set|


### _authorizeUpgrade

Authorize contract upgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal view override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|New implementation address|


## Events
### VaultDestinationUpdated

```solidity
event VaultDestinationUpdated(address indexed vault, address indexed oldAddress, address indexed newAddress);
```

### TotalAssetsUpdated

```solidity
event TotalAssetsUpdated(address indexed vault, uint256 totalAssets);
```

### Deposited

```solidity
event Deposited(address indexed asset, uint256 amount, address indexed onBehalfOf);
```

### RedemptionRequested

```solidity
event RedemptionRequested(address indexed asset, uint256 amount, address indexed onBehalfOf);
```

### RedemptionProcessed

```solidity
event RedemptionProcessed(uint256 indexed requestId, uint256 assets);
```

### AdapterBalanceUpdated

```solidity
event AdapterBalanceUpdated(address indexed vault, address indexed asset, uint256 newBalance);
```

### Initialised

```solidity
event Initialised(address indexed registry);
```

## Errors
### InvalidCustodialAddress

```solidity
error InvalidCustodialAddress();
```

### VaultDestinationNotSet

```solidity
error VaultDestinationNotSet();
```

### AssetsNotTranfered

```solidity
error AssetsNotTranfered();
```

## Structs
### CustodialAdapterStorage
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

