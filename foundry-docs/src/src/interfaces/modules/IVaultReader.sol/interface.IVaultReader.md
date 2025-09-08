# IVaultReader
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/interfaces/modules/IVaultReader.sol)

Read-only interface for querying vault state, calculations, and metrics without modifying contract state

*This interface provides comprehensive access to vault information for external integrations, front-ends, and
analytics without gas costs or state modifications. The interface covers several key areas: (1) Configuration:
Registry references, underlying assets, and fee parameters, (2) Financial Metrics: Share prices, total assets,
and fee calculations for accurate vault valuation, (3) Batch Information: Current and historical batch states
for settlement tracking, (4) Fee Calculations: Real-time fee accruals and next fee timestamps, (5) Safety Functions:
Validated batch ID and receiver retrieval preventing errors. This read-only approach enables efficient monitoring
and integration while maintaining clear separation from state-modifying operations. All calculations reflect current
vault state including pending fees and accrued yields, providing accurate real-time vault metrics for users and
integrations.*


## Functions
### registry

Returns the protocol registry address for configuration and role management


```solidity
function registry() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the kRegistry contract managing protocol-wide settings|


### asset

Returns the vault's share token (stkToken) address for ERC20 operations


```solidity
function asset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of this vault's stkToken contract representing user shares|


### underlyingAsset

Returns the underlying asset address that this vault generates yield on


```solidity
function underlyingAsset() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the base asset (USDC, WBTC, etc.) managed by this vault|


### computeLastBatchFees

Calculates accumulated fees for the current period including management and performance components

*Computes real-time fee accruals based on time elapsed and vault performance since last fee charge.
Management fees accrue continuously based on assets under management and time passed. Performance fees
are calculated on share price appreciation above watermarks and hurdle rates. This function provides
accurate fee projections for settlement planning and user transparency without modifying state.*


```solidity
function computeLastBatchFees()
    external
    view
    returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`managementFees`|`uint256`|Accrued management fees in underlying asset terms|
|`performanceFees`|`uint256`|Accrued performance fees in underlying asset terms|
|`totalFees`|`uint256`|Combined management and performance fees for total fee burden|


### lastFeesChargedManagement

Returns the timestamp when management fees were last processed


```solidity
function lastFeesChargedManagement() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Timestamp of last management fee charge for accrual calculations|


### lastFeesChargedPerformance

Returns the timestamp when performance fees were last processed


```solidity
function lastFeesChargedPerformance() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Timestamp of last performance fee charge for watermark tracking|


### hurdleRate

Returns the hurdle rate threshold for performance fee calculations


```solidity
function hurdleRate() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|Hurdle rate in basis points that vault performance must exceed|


### performanceFee

Returns the current performance fee rate charged on excess returns


```solidity
function performanceFee() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|Performance fee rate in basis points (1% = 100)|


### nextPerformanceFeeTimestamp

Calculates the next timestamp when performance fees can be charged


```solidity
function nextPerformanceFeeTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Projected timestamp for next performance fee evaluation|


### nextManagementFeeTimestamp

Calculates the next timestamp when management fees can be charged


```solidity
function nextManagementFeeTimestamp() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Projected timestamp for next management fee evaluation|


### managementFee

Returns the current management fee rate charged on assets under management


```solidity
function managementFee() external view returns (uint16);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint16`|Management fee rate in basis points (1% = 100)|


### sharePriceWatermark

Returns the high watermark used for performance fee calculations

*The watermark tracks the highest share price achieved, ensuring performance fees are only
charged on new highs and preventing double-charging on recovered losses. Reset occurs when new
high watermarks are achieved, establishing a new baseline for future performance fee calculations.*


```solidity
function sharePriceWatermark() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Current high watermark share price in underlying asset terms|


### isBatchClosed

Checks if the current batch is closed to new requests


```solidity
function isBatchClosed() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if current batch is closed and awaiting settlement|


### isBatchSettled

Checks if the current batch has been settled with finalized prices


```solidity
function isBatchSettled() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if current batch is settled and ready for claims|


### getBatchIdInfo

Returns comprehensive information about the current batch


```solidity
function getBatchIdInfo()
    external
    view
    returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|Current batch identifier|
|`batchReceiver`|`address`|Address of batch receiver contract (may be zero if not created)|
|`isClosed`|`bool`|Whether the batch is closed to new requests|
|`isSettled`|`bool`|Whether the batch has been settled|


### getBatchReceiver

Returns the batch receiver address for a specific batch ID


```solidity
function getBatchReceiver(bytes32 batchId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The batch identifier to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the batch receiver (may be zero if not deployed)|


### getSafeBatchReceiver

Returns batch receiver address with validation, creating if necessary


```solidity
function getSafeBatchReceiver(bytes32 batchId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The batch identifier to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address of the batch receiver (guaranteed non-zero)|


### sharePrice

Calculates current share price including all accrued yields

*Returns gross share price before fee deductions, reflecting total vault performance.
Used for settlement calculations and performance tracking.*


```solidity
function sharePrice() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Share price per stkToken in underlying asset terms (scaled to token decimals)|


### totalAssets

Returns total assets under management including pending fees


```solidity
function totalAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total asset value managed by the vault in underlying asset terms|


### totalNetAssets

Returns net assets after deducting accumulated fees

*Provides user-facing asset value after management and performance fee deductions.
Used for accurate user balance calculations and net yield reporting.*


```solidity
function totalNetAssets() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Net asset value available to users after fee deductions|


### getBatchId

Returns the current active batch identifier


```solidity
function getBatchId() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Current batch ID for new requests|


### getSafeBatchId

Returns current batch ID with safety validation


```solidity
function getSafeBatchId() external view returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Current batch ID (guaranteed to be valid and initialized)|


### convertToShares

Converts a given amount of shares to assets


```solidity
function convertToShares(uint256 shares) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|The amount of shares to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The equivalent amount of assets|


### convertToAssets

Converts a given amount of assets to shares


```solidity
function convertToAssets(uint256 assets) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`|The amount of assets to convert|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The equivalent amount of shares|


### contractName

Returns the human-readable contract name for identification


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Contract name string for display and logging purposes|


### contractVersion

Returns the contract version for upgrade tracking and compatibility


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|Version string indicating current implementation version|


