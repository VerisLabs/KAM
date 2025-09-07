# IVault
[Git Source](https://github.com/VerisLabs/KAM/blob/39577197165fca22f4727dda301114283fca8759/src/interfaces/IVault.sol)

**Inherits:**
[IVaultBatch](/src/interfaces/IVaultBatch.sol/interface.IVaultBatch.md), [IVaultClaim](/src/interfaces/IVaultClaim.sol/interface.IVaultClaim.md), [IVaultFees](/src/interfaces/IVaultFees.sol/interface.IVaultFees.md)

Core interface for retail staking operations enabling kToken holders to earn yield through vault strategies

*This interface defines the primary user entry points for the KAM protocol's retail staking system. Vaults
implementing this interface provide a gateway for individual kToken holders to participate in yield generation
alongside institutional flows. The system operates on a dual-token model: (1) Users deposit kTokens (1:1 backed
tokens) and receive stkTokens (share tokens) that accrue yield, (2) Batch processing aggregates multiple user
operations for gas efficiency and fair pricing, (3) Two-phase operations (request → claim) enable optimal
settlement coordination with the broader protocol. Key features include: asset flow coordination with kAssetRouter
for virtual balance management, integration with DN vaults for yield source diversification, batch settlement
system for gas-efficient operations, and automated yield distribution through share price appreciation rather
than token rebasing. This approach maintains compatibility with existing DeFi infrastructure while providing
transparent yield accrual for retail participants.*


## Functions
### requestStake

Initiates kToken staking request for yield-generating stkToken shares in a batch processing system

*This function begins the retail staking process by: (1) Validating user has sufficient kToken balance
and vault is not paused, (2) Creating a pending stake request with user-specified recipient and current
batch ID for fair settlement, (3) Transferring kTokens from user to vault while updating pending stake
tracking for accurate share calculations, (4) Coordinating with kAssetRouter to virtually move underlying
assets from DN vault to staking vault, enabling proper asset allocation across the protocol. The request
enters pending state until batch settlement, when the final share price is calculated based on vault
performance. Users must later call claimStakedShares() after settlement to receive their stkTokens at
the settled price. This two-phase approach ensures fair pricing for all users within a batch period.*


```solidity
function requestStake(address to, uint256 kTokensAmount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address that will receive the stkTokens after successful settlement and claiming|
|`kTokensAmount`|`uint256`|The quantity of kTokens to stake (must not exceed user balance, cannot be zero)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Unique identifier for tracking this staking request through settlement and claiming|


### requestUnstake

Initiates stkToken unstaking request for kToken redemption plus accrued yield through batch processing

*This function begins the retail unstaking process by: (1) Validating user has sufficient stkToken balance
and vault is operational, (2) Creating pending unstake request with current batch ID for settlement
coordination,
(3) Transferring stkTokens from user to vault contract to maintain stable share price during settlement period,
(4) Notifying kAssetRouter of share redemption request for proper accounting across vault network. The stkTokens
remain locked in the vault until settlement when they are burned and equivalent kTokens (including yield) are
made available. Users must later call claimUnstakedAssets() after settlement to receive their kTokens from
the batch receiver contract. This two-phase design ensures accurate yield calculations and prevents share
price manipulation during the settlement process.*


```solidity
function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The recipient address that will receive the kTokens after successful settlement and claiming|
|`stkTokenAmount`|`uint256`|The quantity of stkTokens to unstake (must not exceed user balance, cannot be zero)|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`requestId`|`bytes32`|Unique identifier for tracking this unstaking request through settlement and claiming|


