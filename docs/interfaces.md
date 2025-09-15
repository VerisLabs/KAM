# KAM Protocol Interfaces

This document describes the interfaces that make up the KAM protocol. The protocol implements a dual-track institutional/retail system with batch processing, two-phase settlements, and virtual balance accounting.

## Core Protocol Interfaces

### IkMinter

The institutional gateway for minting and burning kTokens. Implements a push-pull model where institutions can deposit assets to mint kTokens 1:1, and request burns that are fulfilled through batch settlements.

**Core Operations**

- `mint(address asset, address to, uint256 amount)` - Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
- `requestBurn(address asset, address to, uint256 amount)` - Initiates burn process by escrowing kTokens and creating batch burn request
- `burn(bytes32 requestId)` - Executes burn for a request in a settled batch, burning kTokens and transferring assets
- `cancelRequest(bytes32 requestId)` - Cancels a burn request before batch settlement

**Request Management**

- Generates unique request IDs using hash function with multiple entropy sources
- Maintains per-asset batch tracking with `currentBatchIds[asset]` and `assetBatchCounters[asset]`
- Supports request status tracking (PENDING, REDEEMED, CANCELLED)
- Integrates with batch settlement system for asset distribution via BatchReceiver contracts
- Manages batch lifecycle: create, close, settle, and BatchReceiver deployment

**Additional Functions**

- `createNewBatch(address asset_)` - Creates new batch for asset and returns batch ID
- `closeBatch(bytes32 _batchId, bool _create)` - Closes batch to prevent new requests, optionally creates new batch
- `settleBatch(bytes32 _batchId)` - Marks batch as settled after processing
- `createBatchReceiver(bytes32 _batchId)` - Deploys BatchReceiver contract for asset distribution
- `getCurrentBatchId(address asset_)` - Returns current active batch ID for an asset
- `getCurrentBatchNumber(address asset_)` - Returns current batch number counter for an asset
- `hasActiveBatch(address asset_)` - Checks if asset has an active batch
- `getBatchInfo(bytes32 batchId_)` - Returns complete BatchInfo struct with asset, receiver, and status
- `getBatchReceiver(bytes32 batchId_)` - Returns BatchReceiver address for a batch
- `isPaused()` - Checks if contract is currently paused
- `getBurnRequest(bytes32 requestId)` - Returns complete BurnRequest struct with status and details
- `getUserRequests(address user)` - Returns array of request IDs belonging to a user
- `getRequestCounter()` - Returns current counter used for generating unique request IDs
- `getTotalLockedAssets(address asset)` - Returns total amount of assets locked through mint operations
- `rescueReceiverAssets(address batchReceiver, address asset, address to, uint256 amount)` - Recovers stuck assets from BatchReceiver contracts

### IkAssetRouter

Central coordinator for all asset movements and settlements in the KAM protocol. Manages virtual balance accounting, settlement proposals with cooldown periods, and coordinates asset flows between institutional (kMinter) and retail (kStakingVault) operations. Automatically calculates yield distribution parameters when relayers provide only totalAssets values.

**Virtual Balance System**

- `kAssetPush(address asset, uint256 amount, bytes32 batchId)` - Records incoming asset flows from caller to virtual balance
- `kAssetRequestPull(address asset, uint256 amount, bytes32 batchId)` - Stages outgoing asset requests from caller's virtual balance
- `kSharesRequestPush(address vault, uint256 amount, bytes32 batchId)` - Records incoming share flows for unstaking
- `kSharesRequestPull(address vault, uint256 amount, bytes32 batchId)` - Records outgoing share flows for staking

**Settlement Operations**

- `proposeSettleBatch(address asset, address vault, bytes32 batchId, uint256 totalAssets)` - Creates timelock settlement proposal with automatic yield calculations
- `executeSettleBatch(bytes32 proposalId)` - Executes approved settlement after cooldown using proposal ID
- `cancelProposal(bytes32 proposalId)` - Cancels settlement proposals during cooldown period

**Asset Transfer**

- `kAssetTransfer(address sourceVault, address targetVault, address asset, uint256 amount, bytes32 batchId)` - Direct asset transfers between entities with virtual balance updates
- Implements explicit approval pattern for secure adapter interactions
- Coordinates with batch receivers for redemption distribution

**View Functions**

- `getPendingProposals(address vault_)` - Returns array of pending settlement proposal IDs for a vault
- `getDNVaultByAsset(address asset)` - Gets the DN vault address responsible for yield generation for a specific asset
- `getBatchIdBalances(address vault, bytes32 batchId)` - Returns deposited and requested amounts for batch coordination
- `getRequestedShares(address vault, bytes32 batchId)` - Returns total shares requested for redemption in kStakingVault batch
- `isPaused()` - Checks if kAssetRouter contract is currently paused
- `getSettlementProposal(bytes32 proposalId)` - Retrieves complete VaultSettlementProposal struct with all details
- `canExecuteProposal(bytes32 proposalId)` - Checks execution readiness and returns boolean result with descriptive reason
- `getSettlementCooldown()` - Gets current cooldown period in seconds before proposals can be executed
- `getYieldTolerance()` - Gets current yield tolerance threshold in basis points for proposal validation
- `virtualBalance(address vault, address asset)` - Aggregates virtual asset balance across all vault adapters

### IkRegistry

Central registry managing protocol contracts, supported assets, vault registration, and adapter coordination. Acts as the source of truth for all protocol component relationships.

**Contract Management**

- `setContractById(bytes32 id, address contractAddress)` - Registers core protocol contracts
- `getContractById(bytes32 id)` - Retrieves singleton contract addresses by identifier
- Maintains protocol-wide contract mappings with uniqueness validation

**Asset Management**

- `registerAsset(string name, string symbol, address asset, bytes32 id, uint256 maxMintPerBatch, uint256 maxRedeemPerBatch)` - Deploys new kToken and establishes asset support with batch limits
- `assetToKToken(address asset)` - Maps underlying assets to their kToken representations
- `getAllAssets()` - Returns all protocol-supported assets
- `isAsset(address asset)` - Checks if asset is supported by the protocol
- `setAssetBatchLimits(address asset, uint256 maxMintPerBatch_, uint256 maxRedeemPerBatch_)` - Sets maximum amounts per batch
- `getMaxMintPerBatch(address asset)` - Returns maximum mint amount per batch for an asset
- `getMaxRedeemPerBatch(address asset)` - Returns maximum redeem amount per batch for an asset

**Vault Registry**

- `registerVault(address vault, VaultType type_, address asset)` - Registers new vault with type classification for single asset
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

ERC20 token representing wrapped underlying assets in the KAM protocol. Implements role-restricted minting and burning with emergency pause capabilities and comprehensive role management.

**Token Operations**

- `mint(address to, uint256 amount)` - Creates new tokens (restricted to MINTER_ROLE)
- `burn(address from, uint256 amount)` - Destroys tokens from specified address (restricted to MINTER_ROLE)
- `burnFrom(address from, uint256 amount)` - Burns tokens from another address using allowance mechanism

**Standard ERC20**

- Implements full ERC20 interface for transfers and approvals
- Standard allowance mechanism for third-party integrations
- Event emission for all token operations

**Admin Functions**

- `setPaused(bool _isPaused)` - Emergency pause mechanism (EMERGENCY_ADMIN_ROLE only)
- `isPaused()` - Returns current pause state

**Role Management**

- `grantAdminRole(address admin)` - Grants administrative privileges (owner only)
- `revokeAdminRole(address admin)` - Revokes administrative privileges (owner only)
- `grantEmergencyRole(address emergency)` - Grants emergency admin role (ADMIN_ROLE only)
- `revokeEmergencyRole(address emergency)` - Revokes emergency admin role (ADMIN_ROLE only)
- `grantMinterRole(address minter)` - Grants minting privileges (ADMIN_ROLE only)
- `revokeMinterRole(address minter)` - Revokes minting privileges (ADMIN_ROLE only)

**Metadata**

- `name()`, `symbol()`, `decimals()` - Standard ERC20 metadata with underlying asset parity
- Extends IVersioned for contract version tracking

## External Integration Interfaces

### IVaultAdapter

Interface for vault adapter contracts that manage external strategy integrations with permission-based execution. Used by DN vaults to interact with external DeFi protocols while maintaining strict access control.

**Core Operations**

- `execute(address target, bytes calldata data, uint256 value)` - Executes arbitrary calls to external contracts with relayer authorization
- `setTotalAssets(uint256 totalAssets_)` - Updates the last recorded total assets for accounting
- `totalAssets()` - Returns current total assets under management in external strategies

**Emergency Functions**

- `setPaused(bool paused_)` - Emergency pause mechanism for risk management
- `rescueAssets(address asset_, address to_, uint256 amount_)` - Recovers accidentally sent tokens (non-protocol assets only)

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