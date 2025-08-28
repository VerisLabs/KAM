# KAM Protocol Interfaces

This document describes the interfaces that make up the KAM protocol. The protocol implements a dual-track institutional/retail system with batch processing, two-phase settlements, and virtual balance accounting.

## Core Protocol Interfaces

### IkMinter

The institutional gateway for minting and redeeming kTokens. Implements a push-pull model where institutions can deposit assets to mint kTokens 1:1, and request redemptions that are fulfilled through batch settlements.

**Core Operations**

- `mint()` - Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
- `requestRedeem()` - Initiates redemption process by escrowing kTokens and creating batch redemption request
- `redeem()` - Executes redemption for a request in a settled batch, burning kTokens and transferring assets
- `cancelRequest()` - Cancels a redemption request before batch settlement

**Request Management**

- Generates unique request IDs for tracking redemptions
- Maintains user request mappings for efficient lookups
- Supports request status tracking (PENDING, REDEEMED, CANCELLED)
- Integrates with batch settlement system for asset distribution

### IkAssetRouter

Central hub for asset flow coordination between vaults and external strategies. Manages virtual balance accounting, settlement proposals with timelock, and adapter integrations.

**Virtual Balance System**

- `kAssetPush()` - Records incoming asset flows to vault's virtual balance
- `kAssetRequestPull()` - Stages outgoing asset requests from vault's virtual balance
- `kSharesRequestPush()` - Records incoming share flows for unstaking
- `virtualBalance()` - Returns current virtual balance for vault-asset pair

**Settlement Operations**

- `proposeSettleBatch()` - Creates timelock settlement proposal with cooldown period
- `executeSettleBatch()` - Executes approved settlement after cooldown, handling adapter deposits/withdrawals
- `cancelProposal()` - Cancels settlement proposals during cooldown period

**Asset Transfer**

- `kAssetTransfer()` - Direct asset transfers between entities with virtual balance updates
- Implements explicit approval pattern for secure adapter interactions
- Coordinates with batch receivers for redemption distribution

### IkRegistry

Central registry managing protocol contracts, supported assets, vault registration, and adapter coordination. Acts as the source of truth for all protocol component relationships.

**Singleton Management**

- `setSingletonContract()` - Registers core protocol contracts (kMinter, kAssetRouter)
- `getContractById()` - Retrieves singleton contract addresses by identifier
- Maintains protocol-wide contract mappings with uniqueness validation

**Asset Management**

- `registerAsset()` - Establishes support for new assets and their corresponding kTokens
- `assetToKToken()` - Maps underlying assets to their kToken representations
- `getAllAssets()` - Returns all protocol-supported assets
- Bidirectional asset-kToken relationship management

**Vault Registry**

- `registerVault()` - Registers new vaults with type classification (MINTER, DN, ALPHA, BETA)
- `getVaultsByAsset()` - Returns all vaults managing a specific asset
- `getVaultByAssetAndType()` - Retrieves vault by asset and type combination
- Multi-vault-per-asset support with type differentiation

**Adapter Coordination**

- `registerAdapter()` - Associates adapters with specific vaults
- `getAdapters()` - Returns adapters for a given vault
- `isAdapterRegistered()` - Validates adapter registration status
- Supports multiple adapters per vault for strategy diversification

## Vault Interfaces

### IkStakingVault

ERC20 vault with dual accounting for minter and user pools. Implements automatic yield distribution and modular architecture through diamond pattern.

**Staking Operations**

- `requestStake()` - Request to stake kTokens for stkTokens (yield-bearing vault shares)
- `requestUnstake()` - Request to unstake stkTokens for kTokens plus accrued yield
- `cancelStakeRequest()` - Cancels pending staking requests before batch settlement
- `cancelUnstakeRequest()` - Cancels pending unstaking requests before batch settlement

**Batch Management**

- `getBatchId()` - Returns current batch identifier for request grouping
- `getSafeBatchId()` - Returns batch ID with safety checks (not closed/settled)
- `getBatchReceiver()` - Returns batch receiver contract for asset distribution
- `isBatchClosed()` - Checks if current batch is closed to new requests
- `isBatchSettled()` - Checks if current batch has completed settlement

**Pricing and Assets**

- `calculateStkTokenPrice()` - Calculates stkToken price with safety checks
- `sharePrice()` - Returns price per stkToken in underlying asset terms
- `totalAssets()` - Returns current total assets from adapter (real-time)
- Uses last snapshot for price calculations to prevent manipulation

### IkBatchReceiver

Minimal proxy contract that holds and distributes settled assets for batch redemptions. Deployed per batch to isolate asset distribution and enable efficient settlement.

**Initialization**

- `initialize()` - Sets batch parameters (batch ID, asset) after deployment
- One-time initialization prevents reuse across different batches
- Validates asset address and prevents double initialization

**Asset Distribution**

- `pullAssets()` - Transfers assets from contract to specified receiver
- Only callable by kMinter with proper batch ID validation
- Implements safety checks for amount and receiver validation
- Emits events for asset distribution tracking

**Access Control**

- Immutable kMinter address set at construction for security
- Batch ID validation prevents cross-batch asset distribution
- Zero address and zero amount validation for safety

## Token Interfaces

### IkToken

ERC20 token representing wrapped underlying assets in the KAM protocol. Implements institutional-only minting with standard transfer capabilities.

**Minting Operations**

- `mint()` - Creates new tokens (restricted to kMinter contract)
- `burn()` - Destroys tokens (restricted to kMinter contract)
- Institutional-only minting model ensures controlled token supply

**Standard ERC20**

- Implements full ERC20 interface for transfers and approvals
- Standard allowance mechanism for third-party integrations
- Event emission for all token operations

**Access Control**

- Role-based minting restrictions for protocol security
- Only authorized minting through kMinter contract
- Prevents unauthorized token creation

## External Integration Interfaces

### IAdapter

Interface for protocol adapters that manage external strategy integrations. All adapters must implement this interface for kAssetRouter integration.

**Core Operations**

- `deposit()` - Deposits assets to external strategy on behalf of a vault
- `redeem()` - Redeems assets from external strategy on behalf of a vault
- `processRedemption()` - Processes pending redemptions from external protocols
- `setTotalAssets()` - Updates total assets tracking for vault-asset pairs

**Asset Tracking**

- `totalAssets()` - Returns current total assets in external strategy
- `getLastTotalAssets()` - Returns last recorded total assets for vault-asset pair
- `convertToAssets()` - Converts strategy shares to underlying assets
- Real-time vs snapshot asset tracking capabilities

**Redemption Management**

- `getPendingRedemption()` - Returns details for specific redemption request
- `getPendingRedemptions()` - Returns all pending redemptions for a vault
- Supports async redemption patterns common in DeFi strategies

**Metadata**

- `registered()` - Returns adapter registration status
- `name()` - Human readable adapter identification
- `version()` - Adapter version for compatibility tracking

## Vault Module Interfaces

### IVaultBatch

Interface for vault batch processing functionality within the modular vault system. Handles batch lifecycle, request management, and settlement coordination.

**Batch Operations**

- `getBatchId()` - Returns current active batch identifier
- `createBatchReceiver()` - Deploys deterministic batch receiver for asset distribution
- `closeBatch()` - Marks current batch as closed to new requests
- `settleBatch()` - Processes batch settlement with yield distribution

### IVaultClaim

Interface for processing user claims from settled batches. Manages conversion of requests to actual token distributions.

**Claim Processing**

- `claimStake()` - Claims stkTokens from settled stake requests
- `claimUnstake()` - Claims underlying assets from settled unstake requests
- `batchClaimStake()` - Processes multiple stake claims efficiently
- `batchClaimUnstake()` - Processes multiple unstake claims efficiently

### IVaultFees

Interface for vault fee collection and distribution. Handles both management and performance fees with precise calculations.

**Fee Management**

- `collectManagementFees()` - Collects continuous management fees
- `collectPerformanceFees()` - Collects fees on positive yields only
- `setFeeCollector()` - Updates fee collection destination
- `getFeeAccrued()` - Returns current accrued fee amounts

## Utility Interfaces

### IExtsload

External storage loading interface enabling efficient batch reading of storage slots. Supports advanced inspection and debugging capabilities.

**Storage Operations**

- `extsload()` - Loads single storage slot value
- `extsloadMultiple()` - Batch loads multiple storage slot values
- Enables efficient off-chain state reading and analysis

**Use Cases**

- Protocol state inspection for monitoring
- Batch state queries for gas efficiency
- Debug and analysis tooling support
- Off-chain computation with on-chain verification

---

**Note**: This document covers the primary interfaces for the KAM protocol. Additional view functions, administrative functions, and implementation-specific methods may exist in the actual contracts but are not exhaustively listed here. Refer to the source code interfaces in `/src/interfaces/` for complete function signatures and documentation.
