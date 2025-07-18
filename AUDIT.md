# KAM kTokens Protocol - Audit Guide

## Table of Contents

- [Audit Scope](#audit-scope)
- [Protocol Goals](#protocol-goals)
- [How KAM Generates Yield](#how-kam-generates-yield)
- [Risk Segregation Model](#risk-segregation-model)
- [Contract Analysis](#contract-analysis)
- [Critical Security Areas](#critical-security-areas)
- [Audit Focus](#audit-focus)

## Audit Scope

Smart contract files are located in `/src/`

**Core Contracts:**
- `kToken.sol` - ERC20 token with role-based minting/burning
- `kMinter.sol` - Institutional minting with 1:1 backing guarantee
- `kDNStakingVault.sol` - Delta-neutral strategy vault with dual accounting
- `kSStakingVault.sol` - Higher-risk strategy vault  
- `kStrategyManager.sol` - Central settlement orchestrator with vault-type specific validation
- `kSiloContract.sol` - Custodial withdrawal intermediary
- `kBatchReceiver.sol` - Minimal proxy for batch redemptions

**Supporting Contracts:**
- `modules/` - Modular architecture components
- `dataProviders/` - Direct storage access for efficient queries
- `interfaces/` - Contract interfaces

## Protocol Goals

The goal of KAM is to provide **1:1 guaranteed backing for institutional users** while offering **yield-bearing opportunities to retail users** through risk-segregated vault strategies.

Unlike protocols where all users bear the same risk, KAM segregates risk by user type:
- **Institutions**: Get 1:1 kToken backing guarantee, never lose money
- **Retail Users**: Bear strategy risk in exchange for yield opportunities

## How KAM Generates Yield

Users mint kTokens with USDC/WBTC through institutional flow. The underlying assets are deployed to two types of strategies:

**Delta-Neutral Strategies (kDNStakingVault):**
- 70% allocation to custodial wallets for CEX funding and arbitrage
- 30% allocation to cross-chain MetaVaults
- Target yield: 8-12% APY with lower risk

**Higher-Risk Strategies (kSStakingVault):**
- 80% allocation to custodial wallets for directional trading
- 20% allocation to MetaVaults for leverage strategies  
- Target yield: 15-25% APY with higher risk

**Yield Distribution:**
- Strategy profits flow to retail users through automatic yield distribution
- Institutional 1:1 backing maintained through insurance coverage
- Losses are borne by retail users, not institutions

## Risk Segregation Model

KAM implements a **dual accounting system** that separates institutional and retail flows:

**Example Flow:**
1. Institution deposits 100,000 USDC → Gets 100,000 kUSD (1:1 backing)
2. Retail user stakes 50,000 kUSD → Gets yield-bearing stkTokens
3. Strategies generate 10% yield → Retail user's stkTokens appreciate
4. Institution redeems 100,000 kUSD → Gets exactly 100,000 USDC back

**If strategies lose 20%:**
- Institution still gets 100,000 USDC back (insurance covers loss)
- Retail user's stkTokens lose 20% value (bears the strategy risk)
- Protocol maintains 1:1 backing guarantee for institutions

## Contract Analysis

### kToken.sol

**Purpose**: ERC20 token with role-based minting/burning capabilities

**Key Functions**:
- `mint(address to, uint256 amount)` - Only MINTER_ROLE can create tokens
- `burn(address from, uint256 amount)` - Only MINTER_ROLE can destroy tokens
- `burnFrom(address from, uint256 amount)` - Burns using allowance

**Security Focus**:
- Verify only authorized minters can mint/burn
- Check role management is properly restricted
- Validate emergency pause functionality

### kMinter.sol

**Purpose**: Handles institutional minting/redemption with 1:1 backing guarantee

**Key Functions**:
- `mint(MintRequest request)` - Institutional minting with 1:1 backing
- `requestRedeem(RedeemRequest request)` - Batch redemption requests
- `redeem(bytes32 requestId)` - Execute redemption after settlement

**Critical Design**:
- Burns kTokens immediately on redemption request
- Deploys BatchReceiver proxies for each batch
- Routes deposits to kDNStakingVault for yield generation

**Security Focus**:
- **CRITICAL**: Verify 1:1 backing invariant: `kToken.totalSupply() == totalDeposited - totalRedeemed`
- Check batch settlement atomicity
- Validate request ID uniqueness and replay protection

### kDNStakingVault.sol

**Purpose**: Delta-neutral strategy vault with dual accounting system

**Key Functions**:
- `requestMinterDeposit(uint256 amount)` - Institutional deposits (1:1 accounting)
- `requestStake(uint256 amount)` - Retail staking for yield-bearing stkTokens
- `requestUnstake(uint256 amount)` - Retail unstaking

**Dual Accounting Model**:
- **Minter Flow**: 1:1 asset accounting, no yield (institutional guarantee)
- **User Flow**: Yield-bearing shares that appreciate with strategy performance
- **Loss Handling**: Negative rebase reduces user assets, burns kTokens

**Security Focus**:
- **CRITICAL**: Verify dual accounting: `totalMinterAssets + userTotalAssets == totalVaultAssets`
- **CRITICAL**: Ensure minter 1:1 backing never affected by user losses
- **CRITICAL**: Validate negative rebase burns correct amount of kTokens
- Check yield distribution flows only to user pool

### kSStakingVault.sol

**Purpose**: Higher-risk strategy vault for directional trading strategies

**Key Functions**:
- `requestStake(uint256 amount)` - Stake kTokens for strategy exposure
- `requestUnstake(uint256 amount)` - Unstake with strategy performance

**Asset Flow**:
- Sources actual assets (USDC/WBTC) from kDNStakingVault minter pool
- Deploys to higher-risk strategies (funding, shorts, longs)
- Can experience significant losses (up to 100%)

**Security Focus**:
- **CRITICAL**: Verify proper asset sourcing from kDNStakingVault
- **CRITICAL**: Validate negative rebase handling for complete loss scenarios
- Check inter-vault coordination security

### kStrategyManager.sol

**Purpose**: Central settlement orchestrator with vault-type specific risk validation

**Key Functions**:
- `validateSettlement(VaultType vaultType, ...)` - **CRITICAL: Risk-based validation**
- `settleAndAllocate(...)` - Orchestrates multi-phase settlement
- `executeSettlement(uint256 operationId)` - Executes validated settlements

**Vault-Type Validation**:
- **KMINTER**: Strict validation - `totalStrategyAssets > totalDeployedAssets` (forces insurance)
- **KDNSTAKING/KSSTAKING**: Risk-bearing - negative settlements allowed

**Security Focus**:
- **CRITICAL**: Verify kMinter NEVER accepts negative settlements
- **CRITICAL**: Ensure kDN/kS vaults properly handle losses
- Check EIP-712 signature validation for allocation orders
- Validate settlement timing and coordination

### kSiloContract.sol

**Purpose**: Unified intermediary for all external strategy returns (custodial and MetaVault)

**Key Functions**:
- `transferToDestination(...)` - Transfers to kBatchReceivers
- Receives assets from both custodial and MetaVault sources

**Unified Design**:
- **Custodial**: Direct token transfers: `USDC.transfer(siloAddress, amount)`
- **MetaVault**: Redemption transfers: `IMetaVault.redeem(shares, siloAddress, controller)`
- kStrategyManager orchestrates redistribution from single source

**Security Focus**:
- Verify only kStrategyManager can redistribute funds
- Check balance validation prevents over-transfers
- Validate unified asset flow from all external sources

### kBatchReceiver.sol

**Purpose**: Minimal proxy contracts for batch redemptions

**Key Functions**:
- `initialize(...)` - Initialize proxy for specific batch
- `withdrawForRedemption(...)` - Distribute assets to users

**Security Focus**:
- Verify proper proxy initialization
- Check asset distribution logic

## Critical Security Areas

### 1. Insurance Model Enforcement

The protocol's key innovation is **vault-type specific settlement validation**:

```solidity
if (vaultType == VaultType.KMINTER) {
    // Institutional protection - forces insurance intervention
    if (totalStrategyAssets <= totalDeployedAssets) {
        revert InsufficientStrategyAssets();
    }
}
// kDN/kS vaults allow negative settlements (users bear risk)
```

**Critical Points**:
- kMinter settlements MUST be blocked if strategies lose money
- Insurance system must add coverage before settlement proceeds
- Retail vaults can process negative settlements (users bear losses)

### 2. Dual Accounting System

**Core Invariant**: `vault.totalMinterAssets + vault.userTotalAssets == vault.totalVaultAssets`

**Loss Scenarios**:
- **Positive**: Mint kTokens, increase user assets
- **Negative**: Burn kTokens, reduce user assets, preserve minter 1:1 backing

### 3. 1:1 Backing Guarantee

**Protocol Invariant**: `kToken.totalSupply() == totalUnderlyingAssets`

**Components**:
- Institutional deposits maintain 1:1 backing
- Strategy yields represented through strategic kToken minting
- Insurance covers institutional losses

## Audit Focus

### HIGH PRIORITY

1. **Settlement Validation Logic**: Verify kMinter blocks negative settlements while kDN/kS allow them
2. **1:1 Backing Maintenance**: Ensure institutional guarantee never breaks
3. **Dual Accounting**: Verify minter and user accounting separation
4. **Loss Handling**: Test negative rebase scenarios including 100% loss
5. **kToken Burning**: Validate correct burning during losses

### MEDIUM PRIORITY

1. **Inter-vault Asset Flows**: Check proper authorization and tracking
2. **Batch Settlement**: Verify atomicity and timing
3. **Yield Distribution**: Ensure accurate flow to user pool
4. **Role-based Access**: Validate proper role restrictions

### TESTING SCENARIOS

1. **100% Strategy Loss**: Verify user assets go to 0, minter assets preserved
2. **Insurance Intervention**: Test blocked settlement → insurance → successful retry
3. **Negative Rebase**: Verify correct kToken burning and user asset reduction
4. **Cross-vault Coordination**: Test proper asset allocation and return flows

## Key Metrics

- **Gas Efficiency**: Settlement operations should be gas-optimized
- **Settlement Timing**: 8-hour intervals with 4-hour cutoffs
- **Yield Bounds**: MAX_YIELD_PER_SYNC limits (500 tokens)
- **Contract Sizes**: All under 24KB limit with modular architecture

The KAM protocol is designed to be mathematically sound with proper risk segregation. The key innovation is **vault-type specific settlement validation** that ensures institutions never lose money while allowing retail users to bear strategy risk in exchange for yield opportunities.