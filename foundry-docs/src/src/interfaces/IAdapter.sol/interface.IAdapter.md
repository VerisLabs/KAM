# IAdapter
[Git Source](https://github.com/VerisLabs/KAM/blob/bbd875989135c7d3f313fa3fcc61e94d6afb4346/src/interfaces/IAdapter.sol)

Interface for protocol adapters that manage external strategy integrations

*All adapters must implement this interface for kAssetRouter integration*


## Functions
### deposit

Deposits assets to external strategy on behalf of a vault


```solidity
function deposit(address asset, uint256 amount, address onBehalfOf) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset to deposit|
|`amount`|`uint256`|The amount to deposit|
|`onBehalfOf`|`address`|The vault address this deposit is for|


### redeem

Redeems assets from external strategy on behalf of a vault


```solidity
function redeem(address asset, uint256 amount, address onBehalfOf) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`asset`|`address`|The asset to redeem|
|`amount`|`uint256`|The amount to redeem|
|`onBehalfOf`|`address`|The vault address this redemption is for|


### processRedemption

Processes a pending redemption


```solidity
function processRedemption(uint256 requestId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`uint256`|The request ID to process|


### setTotalAssets

Sets the total assets for a given vault


```solidity
function setTotalAssets(address vault, address asset, uint256 totalAssets_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`|The asset address|
|`totalAssets_`|`uint256`|The total assets to set|


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


### convertToAssets

Converts shares to assets


```solidity
function convertToAssets(address vault, uint256 shares) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`shares`|`uint256`|The number of shares to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of assets converted from shares|


### totalAssets

Returns the current total assets in the external strategy


```solidity
function totalAssets(address vault, address asset) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault to query|
|`asset`|`address`|The asset to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total assets currently deployed in strategy|


### getPendingRedemption

Returns the pending redemption for a request ID


```solidity
function getPendingRedemption(uint256 requestId)
    external
    view
    returns (address vault, address asset, uint256 shares, bool processed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`uint256`|The request ID to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|
|`asset`|`address`|The asset address|
|`shares`|`uint256`|The number of shares being redeemed|
|`processed`|`bool`|Whether the redemption has been processed|


### getPendingRedemptions

Returns the pending redemptions for a vault


```solidity
function getPendingRedemptions(address vault) external view returns (uint256[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|The vault address|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256[]`|Pending redemptions for the vault|


### registered

Returns whether this adapter is registered


```solidity
function registered() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if adapter is registered and active|


### name

Returns the adapter's name for identification


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


