# KAM Protocol Interfaces

This document describes the interfaces that make up the KAM protocol. The protocol implements a dual-track institutional/retail system with batch processing, two-phase settlements, and virtual balance accounting.

## Core Protocol Interfaces

### IkMinter

The institutional gateway for minting and redeeming kTokens. Implements a push-pull model where institutions can deposit assets to mint kTokens 1:1, and request redemptions that are fulfilled through batch settlements.

**Core Operations**

- `mint(address asset, address to, uint256 amount)` - Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
- `requestRedeem(address kToken, address to, uint256 amount)` - Initiates redemption process by escrowing kTokens and creating batch redemption request
- `redeem(bytes32 requestId)` - Executes redemption for a request in a settled batch, burning kTokens and transferring assets
- `cancelRequest(bytes32 requestId)` - Cancels a redemption request before batch settlement

**Request Management**

- Generates unique request IDs for tracking redemptions
- Maintains user request mappings for efficient lookups
- Supports request status tracking (PENDING, REDEEMED, CANCELLED)
- Integrates with batch settlement system for asset distribution

### IkAssetRouter

Central hub for asset flow coordination between vaults and external strategies. Manages virtual balance accounting, settlement proposals with timelock, and adapter integrations.

**Virtual Balance System**

- `kAssetPush(address from, address vault, address asset, uint256 amount, bytes32 batchId)` - Records incoming asset flows to vault's virtual balance
- `kAssetRequestPull(address from, address vault, address asset, uint256 amount, bytes32 batchId)` - Stages outgoing asset requests from vault's virtual balance
- `kSharesRequestPush(address vault, uint256 amount, bytes32 batchId)` - Records incoming share flows for unstaking
- `kSharesRequestPull(address vault, uint256 amount, bytes32 batchId)` - Records outgoing share flows for staking

**Settlement Operations**

- `proposeSettleBatch(address vault, address asset, bytes32 batchId, uint256 totalAssets, uint256 netted, uint256 yield, bool profit)` - Creates timelock settlement proposal
- `executeSettleBatch(address vault, bytes32 batchId)` - Executes approved settlement after cooldown
- `cancelProposal(address vault, bytes32 batchId)` - Cancels settlement proposals during cooldown period

**Asset Transfer**

- `kAssetTransfer(address sourceVault, address targetVault, address asset, uint256 amount, bytes32 batchId)` - Direct asset transfers between entities with virtual balance updates
- Implements explicit approval pattern for secure adapter interactions
- Coordinates with batch receivers for redemption distribution

### IkRegistry

Central registry managing protocol contracts, supported assets, vault registration, and adapter coordination. Acts as the source of truth for all protocol component relationships.

**Contract Management**

- `setContractById(bytes32 id, address contractAddress)` - Registers core protocol contracts
- `getContractById(bytes32 id)` - Retrieves singleton contract addresses by identifier
- Maintains protocol-wide contract mappings with uniqueness validation

**Asset Management**

- `registerAsset(address asset, address kToken)` - Establishes support for new assets and their corresponding kTokens
- `assetToKToken(address asset)` - Maps underlying assets to their kToken representations
- `kTokenToAsset(address kToken)` - Reverse mapping from kToken to underlying asset
- `getAssets()` - Returns all protocol-supported assets

**Vault Registry**

- `registerVault(address vault, VaultType vaultType, address[] memory assets)` - Registers new vaults with type classification
- `getVaultsByAsset(address asset)` - Returns all vaults managing a specific asset
- `getVaultByAssetAndType(address asset, VaultType vaultType)` - Retrieves vault by asset and type combination
- `getVaultAssets(address vault)` - Returns assets managed by a vault

**Adapter Coordination**

- `registerAdapter(address vault, address adapter)` - Associates adapters with specific vaults
- `getAdapters(address vault)` - Returns adapters for a given vault
- `isAdapterRegistered(address vault, address adapter)` - Validates adapter registration status

**Role Management**

- `isAdmin(address user)` - Checks admin role
- `isEmergencyAdmin(address user)` - Checks emergency admin role
- `isRelayer(address user)` - Checks relayer role
- `isGuardian(address user)` - Checks guardian role
- `isInstitution(address user)` - Checks institutional user status

## Vault Interfaces

### IkStakingVault

Comprehensive interface combining retail staking operations with ERC20 share tokens and vault state reading. Implemented through a MultiFacetProxy pattern that routes calls to different modules while maintaining unified interface access.

**Interface Composition**

- Extends `IVault` - Core staking operations (requestStake, requestUnstake)
- Extends `IVaultReader` - State reading and calculations (routed to ReaderModule via MultiFacetProxy)
- Adds standard ERC20 functions for stkToken management

**MultiFacetProxy Architecture**

- Main kStakingVault contract handles core staking operations and ERC20 functionality
- ReaderModule handles all view functions for vault state and calculations
- Proxy pattern enables modular upgrades while maintaining a single contract interface

**ERC20 Operations**

- `name()`, `symbol()`, `decimals()` - Token metadata
- `totalSupply()`, `balanceOf(address)` - Supply and balance queries
- `transfer()`, `approve()`, `transferFrom()` - Standard ERC20 transfers
- `allowance()` - Approval queries

### IVault

Core interface for vault staking operations. Combines IVaultBatch, IVaultClaim, and IVaultFees interfaces.

**Staking Operations**

- `requestStake(address to, uint256 kTokensAmount)` - Request to stake kTokens for stkTokens
- `requestUnstake(address to, uint256 stkTokenAmount)` - Request to unstake stkTokens for kTokens plus yield

### IVaultBatch

Interface for batch lifecycle management enabling gas-efficient settlement of multiple user operations.

**Batch Operations**

- `createNewBatch()` - Creates new batch for processing requests
- `closeBatch(bytes32 batchId, bool create)` - Closes batch to prevent new requests
- `settleBatch(bytes32 batchId)` - Marks batch as settled after yield distribution
- `createBatchReceiver(bytes32 batchId)` - Deploys minimal proxy for asset distribution

### IVaultClaim

Interface for claiming settled staking rewards and unstaking assets after batch processing.

**Claim Processing**

- `claimStakedShares(bytes32 batchId, bytes32 requestId)` - Claims stkTokens from settled stake requests
- `claimUnstakedAssets(bytes32 batchId, bytes32 requestId)` - Claims kTokens from settled unstake requests

### IVaultFees

Interface for vault fee management including performance and management fees.

**Fee Management**

- `setManagementFee(uint16 fee)` - Sets management fee in basis points
- `setPerformanceFee(uint16 fee)` - Sets performance fee in basis points
- `setHardHurdleRate(bool isHard)` - Configures hurdle rate mechanism
- `notifyManagementFeesCharged(uint64 timestamp)` - Updates management fee timestamp
- `notifyPerformanceFeesCharged(uint64 timestamp)` - Updates performance fee timestamp

### IVaultReader

Read-only interface for querying vault state, calculations, and metrics without modifying contract state.

**Configuration Queries**

- `registry()` - Returns protocol registry address
- `asset()` - Returns vault's share token (stkToken) address
- `underlyingAsset()` - Returns underlying asset address

**Financial Metrics**

- `sharePrice()` - Current share price in underlying asset terms
- `totalAssets()` - Total assets under management
- `totalNetAssets()` - Net assets after fee deductions
- `computeLastBatchFees()` - Calculates accumulated fees (management, performance, total)

**Batch Information**

- `getBatchId()` - Current active batch identifier
- `getSafeBatchId()` - Batch ID with safety validation
- `getBatchIdInfo()` - Comprehensive batch information
- `getBatchReceiver(bytes32 batchId)` - Batch receiver address
- `isBatchClosed()` - Check if current batch is closed
- `isBatchSettled()` - Check if current batch is settled

**Fee Information**

- `managementFee()` - Current management fee rate
- `performanceFee()` - Current performance fee rate
- `hurdleRate()` - Hurdle rate threshold
- `sharePriceWatermark()` - High watermark for performance fees
- `lastFeesChargedManagement()` - Last management fee timestamp
- `lastFeesChargedPerformance()` - Last performance fee timestamp

### IkBatchReceiver

Minimal proxy contract that holds and distributes settled assets for batch redemptions. Deployed per batch to isolate asset distribution and enable efficient settlement.

**Initialization**

- `initialize(bytes32 batchId, address asset)` - Sets batch parameters after deployment
- One-time initialization prevents reuse across different batches
- Validates asset address and prevents double initialization

**Asset Distribution**

- `pullAssets(address receiver, uint256 amount, bytes32 batchId)` - Transfers assets from contract to specified receiver
- Only callable by kMinter with proper batch ID validation
- `rescueAssets(address asset)` - Rescues stuck assets (not protocol assets)

**Access Control**

- Immutable kMinter address set at construction for security
- Batch ID validation prevents cross-batch asset distribution

## Token Interfaces

### IkToken

ERC20 token representing wrapped underlying assets in the KAM protocol. Implements role-restricted minting with standard transfer capabilities.

**Token Operations**

- `mint(address to, uint256 amount)` - Creates new tokens (restricted to MINTER_ROLE)
- `burn(uint256 amount)` - Destroys tokens from caller
- `burnFrom(address from, uint256 amount)` - Burns tokens from another address with allowance

**Standard ERC20**

- Implements full ERC20 interface for transfers and approvals
- Standard allowance mechanism for third-party integrations
- Event emission for all token operations

**Metadata**

- `name()`, `symbol()`, `decimals()` - Standard ERC20 metadata
- Supports ERC-2612 permit functionality for gasless approvals

## External Integration Interfaces

### IAdapter

Interface for protocol adapters that manage external strategy integrations. All adapters must implement this interface for kAssetRouter integration.

**Core Operations**

- `deposit(address asset, uint256 amount, address onBehalfOf)` - Deposits assets to external strategy
- `redeem(address asset, uint256 amount, address onBehalfOf)` - Redeems assets from external strategy
- `processRedemption(uint256 requestId)` - Processes pending redemptions
- `setTotalAssets(address vault, address asset, uint256 totalAssets)` - Updates total assets tracking

**Asset Tracking**

- `totalAssets(address vault, address asset)` - Returns current total assets in strategy
- `getLastTotalAssets(address vault, address asset)` - Returns last recorded total assets
- `convertToAssets(address vault, uint256 shares)` - Converts strategy shares to underlying

**Redemption Management**

- `getPendingRedemption(uint256 requestId)` - Returns redemption request details
- `getPendingRedemptions(address vault)` - Returns all pending redemptions for vault

**Metadata**

- `registered()` - Returns adapter registration status
- `name()` - Human readable adapter identification
- `version()` - Adapter version for compatibility tracking

## Utility Interfaces

### IExtsload

External storage loading interface enabling efficient batch reading of storage slots. Supports advanced inspection and debugging capabilities.

**Storage Operations**

- `extsload(bytes32 slot)` - Loads single storage slot value
- `extsload(bytes32 startSlot, uint256 nSlots)` - Loads consecutive storage slots
- `extsload(bytes32[] calldata slots)` - Loads multiple arbitrary storage slots

**Use Cases**

- Protocol state inspection for monitoring
- Batch state queries for gas efficiency
- Debug and analysis tooling support
- Off-chain computation with on-chain verification

---

**Note**: This document covers the primary interfaces for the KAM protocol. Additional implementation-specific methods may exist in the actual contracts but are not exhaustively listed here. Refer to the source code interfaces in `/src/interfaces/` for complete function signatures and documentation.