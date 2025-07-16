# KAM kTokens Protocol Audit Guide

## Table of Contents

- [Protocol Overview](#protocol-overview)
- [Architecture Summary](#architecture-summary)
- [Contract Analysis](#contract-analysis)
- [Key Security Considerations](#key-security-considerations)
- [Critical Invariants](#critical-invariants)
- [Attack Vectors](#attack-vectors)
- [Recommended Audit Approach](#recommended-audit-approach)

## Protocol Overview

The KAM kTokens Protocol is a sophisticated dual accounting system that separates institutional and retail user flows while maintaining 1:1 kToken backing. The protocol implements a multi-vault architecture where different vault types handle different risk profiles and yield strategies.

### Core Value Proposition

1. **Institutional Focus**: Provides 1:1 guaranteed backing for institutional users through kMinter
2. **Retail Yield**: Offers yield-bearing opportunities through dual-vault staking system
3. **Risk Segregation**: Separates delta-neutral strategies (kDNStakingVault) from higher-risk strategies (kSStakingVault)
4. **Automated Yield Distribution**: Implements Ethena-style yield flow from minter assets to user shares

### Key Design Principles

- **1:1 Backing Guarantee**: Total kToken supply equals total underlying assets across all contracts
- **Dual Accounting**: Separate accounting for institutional (1:1) and retail (yield-bearing) flows
- **Batch Settlement**: Async processing with time-based coordination across all components
- **Modular Architecture**: Upgradeable contracts with separated concerns

## Architecture Summary

### Per Asset Type (USDC, WBTC)

For each supported asset (USDC, WBTC), the protocol deploys:

- **1 kMinter** - Handles actual assets with 1:1 kToken backing
- **1 kDNStakingVault** - Delta-neutral strategies using kTokens as underlying
- **2 kSStakingVaults** - Higher-risk strategies (Alpha/Beta) using kTokens as underlying

### Supporting Infrastructure

- **kStrategyManager** - Central settlement orchestrator
- **kSiloContract** - Custodial withdrawal intermediary
- **kBatchReceiver** - Minimal proxy contracts for batch redemptions

### Asset Flow Architecture

```
USDC/WBTC → kMinter → kDNStakingVault → kSStakingVault → Strategies
     ↓                      ↓                ↓
  kTokens            stkTokens (DN)   stkTokens (Alpha/Beta)
```

## Contract Analysis

### 1. kToken.sol - ERC20 Token with Role-Based Control

**Purpose**: Core ERC20 token with role-based minting/burning capabilities

**Key Functions**:
- `mint(address to, uint256 amount)` - Creates new tokens (MINTER_ROLE only)
- `burn(address from, uint256 amount)` - Destroys tokens (MINTER_ROLE only)
- `burnFrom(address from, uint256 amount)` - Burns using allowance (MINTER_ROLE only)

**Security Features**:
- UUPS upgradeable pattern with admin-only authorization
- Role-based access control (ADMIN, EMERGENCY_ADMIN, MINTER)
- Pausable functionality for emergency stops
- Emergency withdrawal function when paused

**Audit Focus**:
- Verify only authorized minters can mint/burn
- Check upgrade authorization is properly restricted
- Validate emergency functions are properly gated
- Ensure proper role management and ownership

### 2. kMinter.sol - Institutional Minting and Redemption Manager

**Purpose**: Maintains 1:1 backing between kTokens and underlying assets for institutional users

**Key Functions**:
- `mint(MintRequest request)` - Institutional minting with 1:1 backing
- `requestRedeem(RedeemRequest request)` - Batch redemption requests
- `redeem(bytes32 requestId)` - Execute individual redemption after settlement
- `cancelRequest(bytes32 requestId)` - Cancel pending redemption requests

**Critical Design**:
- Deploys minimal proxy BatchReceivers for each redemption batch
- Routes all deposits to kDNStakingVault for yield generation
- Burns kTokens immediately on redemption request
- Time-based batching system (4h cutoff, 8h settlement)

**Security Features**:
- Bitmap tracking for executed/cancelled requests
- Request validation and duplicate prevention
- Role-based access control for all operations
- Emergency withdrawal when paused

**Audit Focus**:
- Verify 1:1 backing is maintained (critical invariant)
- Check batch settlement logic for atomicity
- Validate request ID generation and uniqueness
- Ensure proper integration with kDNStakingVault
- Review BatchReceiver deployment and initialization

### 3. kDNStakingVault.sol - Delta-Neutral Strategy Vault

**Purpose**: Implements dual accounting model with separate 1:1 minter flow and yield-bearing user flow

**Key Functions**:
- `requestMinterDeposit(uint256 amount)` - Minter deposits (1:1 accounting)
- `requestMinterRedeem(uint256 amount, address minter, address batchReceiver)` - Minter redemptions
- `requestStake(uint256 amount)` - User staking for yield-bearing stkTokens
- `requestUnstake(uint256 amount)` - User unstaking to kTokens + yield
- `allocateAssetsToDestinations(address[] destinations, uint256[] amounts)` - Asset allocation

**Dual Accounting Model**:
- **Minter Flow**: 1:1 asset accounting, no yield appreciation
- **User Flow**: Yield-bearing shares that appreciate with vault performance
- **Yield Distribution**: Unaccounted vault yield automatically flows to user shares

**Strategy Allocation**:
- X% to Metavaults (cross-chain arbitrage)
- Y% to Custodial wallets (delta-neutral strategies)

**Security Features**:
- Modular architecture using MultiFacetProxy
- Role-based access control with multiple roles
- Batch settlement with time-based coordination
- Emergency functions and pausability

**Audit Focus**:
- Verify dual accounting correctness (critical)
- Check yield distribution mechanism
- Validate asset allocation and return flows
- Ensure proper batch settlement coordination
- Review inter-vault communication security

### 4. kSStakingVault.sol - Strategy Staking Vault

**Purpose**: Strategy-based staking vault for higher-risk yield strategies

**Key Functions**:
- `requestStake(uint256 amount)` - Stake kTokens for strategy-specific yield
- `requestUnstake(uint256 amount)` - Unstake with strategy performance reflection
- `allocateAssetsToDestinations(address[] destinations, uint256[] amounts)` - Strategy allocation

**Asset Sourcing**:
- Withdraws actual assets (USDC/WBTC) from kDNStakingVault minter pool
- Coordinates with kDNStakingVault for asset allocation through kStrategyManager

**Strategy Allocation**:
- Y% to Custodial wallets (funding, shorts, longs)
- X% to Metavaults (cross-chain operations)

**Risk Profile**:
- Higher-risk strategies with potential for loss
- Strategy profits/losses reflected through kToken minting/burning
- Multiple instances per asset type (Alpha, Beta strategies)

**Audit Focus**:
- Verify proper asset sourcing from kDNStakingVault
- Check strategy allocation and return mechanisms
- Validate inter-vault coordination security
- Review risk management and loss handling

### 5. kStrategyManager.sol - Central Settlement Orchestrator

**Purpose**: Coordinates all asset flows and settlement across the protocol

**Key Functions**:
- `settleAndAllocate(SettlementParams params, AllocationOrder order, bytes signature)` - Unified settlement
- `validateSettlement(...)` - Validates settlement ensuring withdrawals > deposits
- `executeSettlement(uint256 operationId)` - Executes validated settlement
- `executeAllocation(AllocationOrder order, bytes signature)` - Processes asset allocation

**Settlement Orchestration**:
1. **Phase 1**: Institutional Settlement (kMinter batches)
2. **Phase 2**: Vault Settlements (kDNStaking and kSStaking)
3. **Phase 3**: Strategy Deployment (allocation orders)

**Security Features**:
- EIP-712 signature validation for allocation orders
- Withdrawal > deposit validation (key security requirement)
- Signed allocation orders with replay protection
- Settlement operation tracking and validation

**Audit Focus**:
- Verify settlement coordination is atomic
- Check signature validation for allocation orders
- Validate withdrawal > deposit requirement
- Review settlement timing and coordination
- Ensure proper asset flow validation

### 6. kSiloContract.sol - Custodial Withdrawal Intermediary

**Purpose**: Secure intermediary for all custodial strategy returns

**Key Functions**:
- `receiveFromCustodial(bytes32 operationId, address sourceStrategy, uint256 amount, string operationType)` - Receive custodial returns
- `transferToDestination(address destination, uint256 amount, bytes32 operationId, string distributionType)` - Transfer to kBatchReceivers
- `batchTransferToDestinations(...)` - Batch transfers to multiple destinations

**Security Model**:
- Only kStrategyManager can redistribute funds
- Complete operation tracking with unique IDs
- Custodial address validation and role management
- Audit trail for all asset movements

**Audit Focus**:
- Verify only kStrategyManager can withdraw
- Check operation tracking and validation
- Validate custodial address authorization
- Review batch transfer security

### 7. kBatchReceiver.sol - Minimal Proxy for Redemptions

**Purpose**: Receives assets from kStrategyManager and distributes to users

**Key Functions**:
- `initialize(address kMinter, address asset, uint256 batchId)` - Initialize proxy
- `receiveAssets(uint256 amount)` - Receive assets from kStrategyManager
- `withdrawForRedemption(address recipient, uint256 amount)` - Distribute to users

**Design Pattern**:
- Minimal proxy pattern for gas efficiency
- Deployed per redemption batch by kMinter
- Receives assets during settlement for user claims

**Audit Focus**:
- Verify proper initialization and authorization
- Check asset reception and distribution logic
- Validate minimal proxy implementation security
- Review integration with kMinter and kStrategyManager

## Key Security Considerations

### 1. Dual Accounting Integrity

The protocol's core innovation is the dual accounting system in kDNStakingVault:

**Critical Invariant**: 
```solidity
vault.totalMinterAssets() + vault.userTotalAssets() == vault.getTotalVaultAssets()
```

**Risk**: If dual accounting breaks, either minters lose 1:1 backing or users lose yield.

**Validation**:
- Verify all asset transfers update both accounting systems correctly
- Check yield distribution only flows to user pool
- Ensure minter 1:1 guarantee is never violated

### 2. 1:1 Backing Guarantee

**Protocol-Level Invariant**:
```solidity
kToken.totalSupply() == totalUnderlyingAssets across all contracts
```

**Backing Mechanism**:
- Institutional deposits: Direct 1:1 kToken minting with USDC deposits
- Strategy yields: Strategic kToken minting to represent external profits
- Total backing: All kTokens backed by actual assets (deposits + compounding yields)

**Components**:
- kMinter.totalDeposited - kMinter.totalRedeemed (institutional backing)
- Strategy yields represented through additional kToken minting
- kDNStakingVault.totalMinterAssets + kDNStakingVault.userTotalAssets
- kSStakingVault.totalAssets

**Risk**: If backing breaks, institutional users cannot redeem 1:1.

### 3. Batch Settlement Atomicity

**Critical Requirement**: All settlement operations must be atomic across phases.

**Validation Points**:
- Institutional settlements complete before user settlements
- Asset allocation only occurs after successful settlements
- Withdrawals > deposits validation in kStrategyManager
- Proper coordination between all vault types

### 4. Yield Distribution Security

**Yield Model**: Strategic kToken minting to represent external yield, with automatic distribution to user shares.

**Mechanism**:
1. Strategies generate profit in external venues (CEX, MetaVault)
2. Protocol mints new kTokens to represent the yield
3. Newly minted kTokens flow to user pool automatically
4. Institutional 1:1 backing maintained through strategic minting

**Formula**: 
```solidity
userYield = vault.totalAssets() - vault.totalMinterAssets() - vault.userTotalAssets()
```

**Risks**:
- Yield manipulation through incorrect kToken minting
- Incorrect yield calculation affecting user returns
- Yield bounds not respected (MAX_YIELD_PER_SYNC)
- 1:1 backing violation if minting doesn't match actual strategy value

### 5. Inter-Vault Asset Management

**Asset Flow**: kSStakingVault sources assets from kDNStakingVault minter pool.

**Validation**:
- Proper authorization for asset transfers
- Correct updating of allocation tracking
- Asset return flows properly validated
- No double-spending of allocated assets

## Critical Invariants

### 1. Total Supply Invariant
```solidity
kToken.totalSupply() == totalUnderlyingAssets (across all protocol contracts)
// This includes: minter deposits + strategy yields represented through kToken minting
```

### 2. Dual Accounting Invariant
```solidity
vault.totalMinterAssets() + vault.userTotalAssets() == vault.getTotalVaultAssets()
```

### 3. Minter 1:1 Guarantee
```solidity
vault.getMinterAssetBalance(minter) == minter.deposits[minter] - minter.redeems[minter]
```

### 4. Batch Integrity
```solidity
batch.reservedAmount == sum(requests[batchId].amounts)
```

### 5. Allocation Tracking
```solidity
vault.totalMinterAssets() + vault.totalAllocatedToStrategies() == vault.getTotalMinterAssetsIncludingStrategies()
```

## Attack Vectors

### 1. Dual Accounting Manipulation

**Attack**: Manipulate dual accounting to drain either minter or user funds.

**Mitigation**: 
- Comprehensive invariant checking
- Atomic settlement operations
- Role-based access controls

### 2. Yield Manipulation

**Attack**: Manipulate kToken minting to represent false yields or steal user funds.

**Mitigation**:
- Yield bounds enforcement (MAX_YIELD_PER_SYNC)
- Strategic kToken minting with validation
- Settlement timing controls
- Signature validation for allocation orders

### 3. Batch Settlement Disruption

**Attack**: Disrupt batch settlement to break atomicity.

**Mitigation**:
- Settlement validation in kStrategyManager
- Withdrawal > deposit requirements
- Emergency settlement functions

### 4. Inter-Vault Asset Drainage

**Attack**: Drain assets during inter-vault transfers.

**Mitigation**:
- Allocation limits and tracking
- Role-based transfer authorization
- Asset return validation

### 5. Signature Replay Attacks

**Attack**: Replay signed allocation orders.

**Mitigation**:
- EIP-712 signature validation
- Nonce-based replay protection
- Deadline enforcement

### Key Metrics to Monitor
- Gas usage optimization
- Contract size limits
- Settlement timing performance
- Yield distribution accuracy
- Asset allocation efficiency