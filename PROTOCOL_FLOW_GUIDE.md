# KAM kTokens Protocol Flow Guide

## Table of Contents

- [Protocol Architecture Overview](#protocol-architecture-overview)
- [Core Asset Flows](#core-asset-flows)
- [Detailed Flow Examples](#detailed-flow-examples)
- [Settlement Coordination](#settlement-coordination)
- [Yield Distribution Model](#yield-distribution-model)
- [Error Scenarios and Recovery](#error-scenarios-and-recovery)

## Protocol Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            KAM kTokens Protocol                                 │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │   kMinter   │    │  kDNStakingVault │    │  kSStakingVault │                │
│  │             │    │                 │    │                 │                │
│  │ USDC/WBTC   │───▶│    kTokens      │───▶│    kTokens      │                │
│  │     │       │    │       │         │    │       │         │                │
│  │     ▼       │    │       ▼         │    │       ▼         │                │
│  │  kTokens    │    │  stkTokens(DN)  │    │ stkTokens(Alpha)│                │
│  │  (1:1)      │    │  (Yield-bearing)│    │ (Strategy-based)│                │
│  └─────────────┘    └─────────────────┘    └─────────────────┘                │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────┐                │
│  │kStrategyMgr │    │  kSiloContract  │    │  kBatchReceiver │                │
│  │             │    │                 │    │                 │                │
│  │ Settlement  │    │ Custodial       │    │ Redemption      │                │
│  │ Orchestrator│    │ Intermediary    │    │ Distribution    │                │
│  └─────────────┘    └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Core Asset Flows

### 1. Institutional Minting Flow

```
Institution → kMinter → kDNStakingVault → Strategies
     │           │           │               │
     │           │           │               ▼
     │           │           │        ┌─────────────┐
     │           │           │        │ 70% Meta    │
     │           │           │        │ 30% Custodial│
     │           │           │        └─────────────┘
     │           │           │
     │           │           ▼
     │           │    ┌─────────────────┐
     │           │    │ Dual Accounting │
     │           │    │ • Minter: 1:1   │
     │           │    │ • Users: Yield  │
     │           │    └─────────────────┘
     │           │
     │           ▼
     │    ┌─────────────┐
     │    │   kTokens   │
     │    │   Minted    │
     │    │    1:1      │
     │    └─────────────┘
     │
     ▼
┌─────────────┐
│    USDC     │
│  Deposited  │
└─────────────┘
```

### 2. Retail Staking Flow (Delta Neutral)

```
User kTokens → kDNStakingVault → stkTokens (DN)
     │              │                 │
     │              │                 ▼
     │              │         ┌─────────────┐
     │              │         │ Yield-bearing│
     │              │         │ ERC20 Tokens │
     │              │         └─────────────┘
     │              │
     │              ▼
     │      ┌─────────────────┐
     │      │  Asset Transfer │
     │      │  Minter → User  │
     │      │     Pool        │
     │      └─────────────────┘
     │
     ▼
┌─────────────┐
│   kTokens   │
│ Transferred │
└─────────────┘
```

### 3. Strategy Vault Flow (Higher Risk)

```
User kTokens → kSStakingVault → Asset Request → kDNStakingVault
     │              │                              │
     │              │                              ▼
     │              │                    ┌─────────────────┐
     │              │                    │ Actual Assets   │
     │              │                    │ (USDC/WBTC)     │
     │              │                    │ From Minter Pool│
     │              │                    └─────────────────┘
     │              │                              │
     │              │                              ▼
     │              │                    ┌─────────────────┐
     │              │                    │ 80% Custodial   │
     │              │                    │ 20% MetaVault   │
     │              │                    └─────────────────┘
     │              │
     │              ▼
     │      ┌─────────────────┐
     │      │  stkTokens      │
     │      │  (Alpha/Beta)   │
     │      │  Strategy-based │
     │      └─────────────────┘
     │
     ▼
┌─────────────┐
│   kTokens   │
│ Transferred │
└─────────────┘
```

## Detailed Flow Examples

### Example 1: Complete Institutional Minting and Redemption

**Initial State:**
- Institution has 1000 USDC
- Protocol has 0 kUSD tokens in circulation

**Step 1: Institutional Minting**
```
Institution calls kMinter.mint({amount: 1000, beneficiary: institution})

Flow:
1. kMinter.mint() validates request
2. Transfer 1000 USDC from institution to kMinter
3. kMinter approves kDNStakingVault for 1000 USDC
4. kMinter calls kDNStakingVault.requestMinterDeposit(1000)
5. kDNStakingVault transfers 1000 USDC from kMinter
6. kMinter mints 1000 kUSD to institution immediately
7. kMinter updates totalDeposited += 1000

State After:
- Institution: 1000 kUSD tokens
- kMinter: 0 USDC, totalDeposited = 1000
- kDNStakingVault: 1000 USDC, totalMinterAssets = 1000
- Protocol invariant: kUSD.totalSupply() == 1000 == total underlying assets
```

**Step 2: Asset Allocation (Settlement)**
```
kStrategyManager.settleAndAllocate() called with signed allocation order

Flow:
1. kStrategyManager validates signature and settlement timing
2. kDNStakingVault.allocateAssetsToDestinations([metavault, custodial], [700, 300])
3. Transfer 700 USDC to MetaVault for cross-chain arbitrage
4. Transfer 300 USDC to Custodial wallet for delta-neutral strategies
5. Update allocation tracking: totalAllocated = 1000, totalMinterAssets = 0

State After:
- kDNStakingVault: 0 USDC in vault, 1000 allocated to strategies
- MetaVault: 700 USDC allocated
- Custodial: 300 USDC allocated
- Institution still has 1000 kUSD (1:1 backing maintained)
```

**Step 3: Strategy Returns with Yield**
```
Strategies return more than deployed (profit scenario)

Flow:
1. MetaVault returns 720 USDC (20 profit) - stays in MetaVault for compounding
2. Custodial returns 315 USDC (15 profit) - stays in CEX for compounding
3. Total strategy assets: 1035 USDC (35 profit generated)
4. kStrategyManager validates: withdrawals (1035) > deposits (1000) ✓
5. Protocol mints 35 kUSD tokens to represent the yield
6. Automatic yield distribution: 35 kUSD flows to user pool

State After:
- kDNStakingVault: 1000 kUSD tokens (institutions) + 35 kUSD tokens (user pool)
- Available yield for user staking: 35 kUSD tokens
- Institution's 1:1 backing maintained: 1000 kUSD backed by 1000 USDC
- Total kToken supply: 1035 kUSD = 1035 USDC total backing (1:1 protocol-wide)
```

**Step 4: Institutional Redemption**
```
Institution calls kMinter.requestRedeem({amount: 500, user: institution, recipient: institution})

Flow:
1. kMinter generates unique requestId
2. Deploy kBatchReceiver for this batch
3. Burn 500 kUSD from institution immediately
4. Create redemption request linked to BatchReceiver
5. kMinter calls kDNStakingVault.requestMinterRedeem(500, kMinter, batchReceiver)
6. During settlement, 500 USDC transferred to BatchReceiver
7. Institution calls kMinter.redeem(requestId)
8. BatchReceiver transfers 500 USDC to institution

State After:
- Institution: 500 kUSD tokens, 500 USDC redeemed
- kMinter: totalDeposited = 1000, totalRedeemed = 500
- Protocol invariant: kUSD.totalSupply() == 500 == remaining backing
```

### Example 2: Retail User Staking (Delta Neutral)

**Initial State:**
- User has 100 kUSD tokens
- kDNStakingVault has 1000 kUSD tokens (minter assets) + 35 kUSD tokens (user assets)

**Step 1: User Staking Request**
```
User calls kDNStakingVault.requestStake(100)

Flow:
1. Validate user has 100 kUSD balance
2. Transfer 100 kUSD from user to kDNStakingVault
3. Add to current staking batch
4. Request added to batch with index as requestId

State After:
- User: 0 kUSD tokens
- kDNStakingVault: 100 additional kUSD tokens
- Staking batch: 100 kUSD pending
```

**Step 2: Batch Settlement**
```
kStrategyManager.settleAndAllocate() processes staking batch

Flow:
1. Calculate stkToken price based on current user pool performance
2. Determine stkTokens to issue (e.g., 98 stkTokens for 100 kUSD)
3. Transfer 100 kUSD from minter pool to user pool (dual accounting)
4. Update dual accounting:
   - totalMinterAssets -= 100 kUSD
   - userTotalAssets += 100 kUSD
5. Mint 98 stkTokens to user

State After:
- User: 98 stkTokens (yield-bearing)
- kDNStakingVault: 900 kUSD minter assets, 135 kUSD user assets
- Dual accounting maintained: 900 + 135 = 1035 total kUSD assets
```

**Step 3: Yield Accrual**
```
Additional yield flows to user pool through strategy performance

Flow:
1. Strategies generate additional 20 USDC yield in external venues
2. Protocol mints 20 kUSD tokens to represent the yield
3. Automatic yield distribution:
   - totalMinterAssets: 900 kUSD (unchanged)
   - userTotalAssets: 155 kUSD (135 + 20 yield)
4. stkToken price increases automatically

State After:
- User's 98 stkTokens now worth ~102 kUSD equivalent
- Yield automatically distributed without manual intervention
- Total kToken supply: 1055 kUSD = 1055 USDC total backing (1:1 protocol-wide)
```

### Example 3: Strategy Vault Interaction

**Initial State:**
- User has 200 kUSD tokens
- kSStakingVault-Alpha deployed and configured
- kDNStakingVault has minter assets available

**Step 1: Strategy Vault Staking**
```
User calls kSStakingVault.requestStake(200)

Flow:
1. Transfer 200 kUSD from user to kSStakingVault
2. Add to kSStakingVault staking batch
3. Request stored with user address and amount

State After:
- User: 0 kUSD tokens
- kSStakingVault: 200 kUSD tokens
- Staking batch: 200 kUSD pending
```

**Step 2: Asset Sourcing and Allocation**
```
kStrategyManager.settleAndAllocate() processes kSStakingVault batch

Flow:
1. kSStakingVault requests 200 USDC from kDNStakingVault minter pool
2. kDNStakingVault.allocateAssetsToDestinations() called
3. Transfer 200 USDC from kDNStakingVault to kSStakingVault
4. kSStakingVault allocates to Alpha strategy destinations:
   - 160 USDC to Alpha Custodial (80%)
   - 40 USDC to Alpha MetaVault (20%)
5. Issue strategy-specific stkTokens to user

State After:
- User: 200 stkTokens-Alpha
- kDNStakingVault: totalMinterAssets reduced by 200 kUSD
- Alpha strategies: 200 USDC deployed in external venues
```

**Step 3: Strategy Performance (Profit Scenario)**
```
Alpha strategies generate 15% profit

Flow:
1. Alpha Custodial generates 175 USDC value (160 + 15 profit) - stays in CEX
2. Alpha MetaVault generates 43 USDC value (40 + 3 profit) - stays in MetaVault
3. Total strategy value: 218 USDC (18 profit)
4. Protocol mints 18 kUSD tokens to represent the profit
5. kStrategyManager validates and distributes yield
6. Profit reflected through strategic kToken minting

State After:
- 18 additional kUSD tokens minted to reflect profit
- User's stkTokens-Alpha now worth ~218 kUSD equivalent
- Protocol maintains 1:1 backing: total kToken supply = total USDC backing
```

## Settlement Coordination

### Multi-Phase Settlement Process

```
Phase 1: Institutional Settlement
┌─────────────────────────────────────────────────────────────────┐
│  kMinter.settleBatch()                                          │
│  • Process institutional redemptions                           │
│  • Deploy and fund BatchReceivers                             │
│  • Maintain 1:1 backing guarantee                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
Phase 2: Vault Settlements
┌─────────────────────────────────────────────────────────────────┐
│  kStrategyManager.settleAndAllocate()                          │
│  • kDNStakingVault.settleStakingBatch()                       │
│  • kDNStakingVault.settleUnstakingBatch()                     │
│  • kSStakingVault.settleStakingBatch()                        │
│  • kSStakingVault.settleUnstakingBatch()                      │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
Phase 3: Strategy Deployment
┌─────────────────────────────────────────────────────────────────┐
│  _executeAllocation(order)                                      │
│  • Validate signed allocation order                           │
│  • Execute multi-destination deployment                       │
│  • Update allocation tracking                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Settlement Timing Coordination

```
Time-based Settlement (8-hour cycles)

Hour 0: Batch Creation
├─ kMinter: New redemption batch created
├─ kDNStakingVault: New staking/unstaking batches
└─ kSStakingVault: New staking/unstaking batches

Hour 4: Batch Cutoff
├─ kMinter: Redemption batch closed to new requests
├─ Users can still stake/unstake until settlement
└─ BatchReceivers deployed for closed batches

Hour 8: Settlement Execution
├─ kStrategyManager.settleAndAllocate() called
├─ All batches settled in coordinated sequence
├─ Assets allocated according to signed orders
└─ Users can claim settled positions

Hour 16: Next Settlement Cycle
├─ Process continues with new batches
└─ Continuous operation with 8-hour intervals
```

## Yield Distribution Model

### Automatic Yield Distribution

```
┌─────────────────────────────────────────────────────────────────┐
│                    kDNStakingVault                              │
│                                                                 │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │  Minter Pool    │              │   User Pool     │          │
│  │                 │              │                 │          │
│  │ • 1:1 Backing   │              │ • Yield-bearing │          │
│  │ • Fixed Ratio   │   Yield      │ • Appreciating  │          │
│  │ • No Yield      │   ────────▶  │ • Share-based   │          │
│  │                 │   Flow       │                 │          │
│  └─────────────────┘              └─────────────────┘          │
│                                                                 │
│  Formula: userYield = totalAssets - totalMinterAssets -        │
│                       userTotalAssets                          │
└─────────────────────────────────────────────────────────────────┘
```

### Yield Calculation Example

```
Initial State:
- totalMinterAssets: 1000 kUSD
- userTotalAssets: 100 kUSD
- vault.totalAssets(): 1100 kUSD

After Strategy Returns:
- Strategies generate 50 USDC profit in external venues
- Protocol mints 50 kUSD tokens to represent the yield
- vault.totalAssets(): 1150 kUSD
- totalMinterAssets: 1000 kUSD (unchanged)

Automatic Yield Distribution:
- unaccountedYield = 1150 - 1000 - 100 = 50 kUSD
- userTotalAssets automatically becomes 150 kUSD
- stkToken price increases: 150/100 = 1.5x

Result:
- Minter pool: 1000 kUSD (1:1 backing maintained)
- User pool: 150 kUSD (50 kUSD yield distributed)
- Total: 1150 kUSD = 1150 USDC total backing (1:1 protocol-wide)
```

## Error Scenarios and Recovery

### Scenario 1: Settlement Failure

**Problem**: kStrategyManager.settleAndAllocate() fails mid-process

**Detection**:
- Transaction reverts during settlement
- Batches remain unsettled past deadline
- Users cannot claim settled positions

**Recovery**:
1. Emergency settlement functions in individual vaults
2. Admin can call vault-specific settlement functions
3. Manual asset allocation if needed
4. Batch status reset for retry

### Scenario 2: Strategy Loss

**Problem**: Strategy returns less than deployed (e.g., 50 USDC loss)

**Detection**:
- withdrawals <= deposits validation fails
- kStrategyManager.validateSettlement() reverts
- Insufficient assets for user redemptions

**Recovery**:
1. Insurance fund coverage (handled by backend)
2. Strategic kToken burning to maintain backing
3. User pool adjustments to reflect losses
4. Governance decision on loss distribution

### Scenario 3: Dual Accounting Mismatch

**Problem**: totalMinterAssets + userTotalAssets != totalVaultAssets

**Detection**:
- Invariant checks fail during settlement
- Vault accounting becomes inconsistent
- Users cannot stake/unstake properly

**Recovery**:
1. Emergency pause of affected vault
2. Manual accounting reconciliation
3. Asset rebalancing between pools
4. Gradual resumption after validation

### Scenario 4: Batch Receiver Funding Failure

**Problem**: BatchReceiver doesn't receive expected assets

**Detection**:
- Users cannot redeem from BatchReceiver
- Insufficient balance in BatchReceiver
- Settlement validation passes but distribution fails

**Recovery**:
1. kSiloContract holds all custodial returns
2. kStrategyManager can redistribute to BatchReceivers
3. Emergency funding from protocol reserves
4. Manual settlement of affected batches