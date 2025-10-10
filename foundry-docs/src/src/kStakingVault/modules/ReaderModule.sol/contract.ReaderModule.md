# ReaderModule
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/kStakingVault/modules/ReaderModule.sol)

**Inherits:**
[BaseVault](/src/kStakingVault/base/BaseVault.sol/abstract.BaseVault.md), [Extsload](/src/vendor/uniswap/Extsload.sol/abstract.Extsload.md), [IVaultReader](/src/interfaces/modules/IVaultReader.sol/interface.IVaultReader.md), [IModule](/src/interfaces/modules/IModule.sol/interface.IModule.md)

Contains all the public getters for the Staking Vault


## State Variables
### MANAGEMENT_FEE_INTERVAL
Interval for management fee (1 month)


```solidity
uint256 constant MANAGEMENT_FEE_INTERVAL = 657_436;
```


### PERFORMANCE_FEE_INTERVAL
Interval for performance fee (3 months)


```solidity
uint256 constant PERFORMANCE_FEE_INTERVAL = 7_889_238;
```


### MAX_BPS
Maximum basis points


```solidity
uint256 constant MAX_BPS = 10_000;
```


### SECS_PER_YEAR
Number of seconds in a year


```solidity
uint256 constant SECS_PER_YEAR = 31_556_952;
```


## Functions
### registry

GENERAL


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

FEES

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
function lastFeesChargedManagement() public view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Timestamp of last management fee charge for accrual calculations|


### lastFeesChargedPerformance

Returns the timestamp when performance fees were last processed


```solidity
function lastFeesChargedPerformance() public view returns (uint256);
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


### isHardHurdleRate

Returns whether the current hurdle rate is a hard hurdle rate


```solidity
function isHardHurdleRate() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True if the current hurdle rate is a hard hurdle rate, false otherwise|


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


### getCurrentBatchInfo

Returns comprehensive information about the current batch


```solidity
function getCurrentBatchInfo()
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


### getBatchIdInfo

Returns comprehensive information about a specific batch


```solidity
function getBatchIdInfo(bytes32 batchId)
    external
    view
    returns (address batchReceiver, bool isClosed, bool isSettled, uint256 sharePrice, uint256 netSharePrice);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`batchId`|`bytes32`|The batch identifier to query|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`batchReceiver`|`address`|Address of batch receiver contract (may be zero if not deployed)|
|`isClosed`|`bool`|Whether the batch is closed to new requests|
|`isSettled`|`bool`|Whether the batch has been settled|
|`sharePrice`|`uint256`|Share price of settlement|
|`netSharePrice`|`uint256`|Net share price of settlement|


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


### netSharePrice

Calculates current share price including all accrued yields

*Returns net share price after fee deductions, reflecting total vault performance.
Used for settlement calculations and performance tracking.*


```solidity
function netSharePrice() external view returns (uint256);
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
function getBatchId() public view returns (bytes32);
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


### convertToSharesWithTotals

Converts a given amount of assets to shares with a specified total assets


```solidity
function convertToSharesWithTotals(uint256 shares, uint256 totalAssets_) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`||
|`totalAssets_`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The equivalent amount of shares|


### convertToAssetsWithTotals

Converts a given amount of shares to assets with a specified total assets


```solidity
function convertToAssetsWithTotals(uint256 assets, uint256 totalAssets_) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`assets`|`uint256`||
|`totalAssets_`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The equivalent amount of assets|


### getTotalPendingStake

Returns the total pending stake amount


```solidity
function getTotalPendingStake() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Total pending stake amount|


### getUserRequests

REQUEST GETTERS

Gets all request IDs associated with a user


```solidity
function getUserRequests(address user) external view returns (bytes32[] memory requestIds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address to query requests for|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestIds`|`bytes32[]`|An array of all request IDs (both stake and unstake) for the user|


### getStakeRequest

Gets the details of a specific stake request


```solidity
function getStakeRequest(bytes32 requestId) external view returns (BaseVaultTypes.StakeRequest memory stakeRequest);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the stake request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`stakeRequest`|`BaseVaultTypes.StakeRequest`|The stake request struct containing all request details|


### getUnstakeRequest

Gets the details of a specific unstake request


```solidity
function getUnstakeRequest(bytes32 requestId)
    external
    view
    returns (BaseVaultTypes.UnstakeRequest memory unstakeRequest);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|The unique identifier of the unstake request|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`unstakeRequest`|`BaseVaultTypes.UnstakeRequest`|The unstake request struct containing all request details|


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


### selectors

Returns the selectors for functions in this module


```solidity
function selectors() external pure returns (bytes4[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4[]`|moduleSelectors Array of function selectors|


