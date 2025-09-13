# KAM Protocol - Users Flow Diagram

## Overview: User Journey

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│User has     │───▶│Step1: Stake │───▶│Wait for     │───▶│Step2: Claim │
│kTokens      │    │kTokens      │    │Settlement   │    │stkTokens    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                  │
┌─────────────┐    ┌─────────────┐    ┌───────────-──┐            │
│Step4: Claim │◀───│Wait for     │◀───│Step3: Request│◀───────────┘
│kTokens +    │    │Settlement   │    │Unstake       │
│Yield        │    └─────────────┘    └────────────-─┘
└─────────────┘                   
```

## Detailed Flow: Staking kTokens

```
┌─────────────────┐
│User has kTokens │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Request Stake    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Check Balance    │NO  │Insufficient     │
│kToken >= amount ├───▶│Balance Error    │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐
│Generate Request │
│ID (hash-based)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│safeTransferFrom │
│kTokens to Vault │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Create Stake     │
│Request Struct   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Track User       │
│Request & Update │
│Pending Stakes   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Notify Router    │
│kAssetTransfer() │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Waiting for      │
│Batch Settlement │
└─────────────────┘
```

## Detailed Flow: Unstaking Process

```
┌─────────────────┐
│User has         │
│stkTokens        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Request Unstake  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Has Balance?     │NO  │Insufficient     │
│                 ├───▶│Balance          │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐
│stkTokens Held   │
│by Vault         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Create Unstake   │
│Request          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Update Virtual   │
│Balances         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Waiting for      │
│Batch Settlement │
└─────────────────┘
```

## Batch Processing

```
┌─────────────────┐
│Active Batch     │
│(Accepting       │
│stake/unstake    │
│requests)        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Relayer Closes   │
│Batch            │ ── closeBatch() - stops new requests
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Relayer Proposes │
│Settlement       │ ── proposeSettleBatch() with yield calculation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Cooldown Period  │
│(1 hour default) │ ── Guardian review period
└────────┬────────┘
         │
         ├──────────────────────────┐
         ▼                          ▼
┌────────────────---─┐     ┌─────────────────┐     
│After Cooldown      │     │Guardian Can     │     
│Execute Settlement  │     │Cancel Proposal  │     
│executeSettleBatch()│     │cancelProposal() │     
└-───────┬──-──────--┘     └─────────────────┘     
         │
         ▼
┌─────────────────┐
│Settlement       │
│Executed         │ ── Mint/burn kTokens for yield
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Vault settleBatch│
│Called           │ ── Captures share prices
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Share Prices     │
│Locked           │ ── sharePrice and netSharePrice set
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Ready for Claims │
└─────────────────┘
```

## Claiming Staked Shares

```
┌─────────────────┐
│Stake Request    │
│Pending          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Batch Settled?   │NO  │Cannot Claim Yet │
│                 ├───▶│                 │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐
│Calculate        │
│stkTokens Based  │ ── stkTokens = kTokens * (10^decimals) / netSharePrice
│on Net Share     │ 
│Price            │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Mint stkTokens   │
│to User          │ ── ERC20 mint operation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Update State     │
│- Mark CLAIMED   │ ── Status = RequestStatus.CLAIMED
│- Remove from    │ ── $.userRequests[user].remove(requestId)
│  user requests  │ ── $.totalPendingStake -= kTokenAmount
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│User Receives    │
│stkTokens        │
└─────────────────┘
```

## Claiming Unstaked Assets

```
┌─────────────────┐
│Unstake Request  │
│Pending          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Batch Settled?   │NO  │Cannot Claim Yet │
│                 ├───▶│                 │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐
│Calculate kTokens│
│Net Amount       │ ── netKTokens = stkTokens * netSharePrice / (10^decimals)
│                 │ 
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Calculate Fees   │
│                 │ ── grossKTokens = stkTokens * sharePrice / (10^decimals)
│                 │ ── fees = grossKTokens - netKTokens
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Burn stkTokens   │
│from Vault       │ ── Burns from address(this) - already transferred
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Transfer Fees to │
│Treasury         │ ── $.kToken.safeTransfer(getTreasury(), fees)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Transfer Net     │
│kTokens to User  │ ── $.kToken.safeTransfer(user, netKTokens)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│User Receives    │
│kTokens + Yield  │
└─────────────────┘
```

## Contract Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                       Retail Staking Architecture                  │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  User Layer:                                                       │
│  ┌─────────────┐                                                   │
│  │Retail User  │                                                   │
│  └──────┬──────┘                                                   │
│         │                                                          │
│         ▼                                                          │
│  Vault Layer:                                                      │
│  ┌─────────────┐      ┌──────────────┐                             │
│  │kStakingVault│─────▶│stkTokens     │                             │
│  │             │      │(ERC20 shares)│                             │
│  └──────┬──────┘      └──────────────┘                             │
│         │                                                          │
│  Core Infrastructure:                                              │
│         ├─────────▶ ┌─────────────┐                                │
│         │           │kToken       │ ── Underlying asset            │
│         │           └─────────────┘                                │
│         │                                                          │
│         ├─────────▶ ┌─────────────┐                                │
│         │           │kAssetRouter │ ── Central coordinator         │
│         │           └──────┬──────┘    & Virtual balances          │
│         │                  │                                       │
│         │                  ▼                                       │
│         ├─────────▶ ┌─────────────┐                                │
│         │           │kMinter      │ ── Institutional flows         │
│         │           └─────────────┘                                │
│         │                                                          │
│         ├─────────▶ ┌─────────────┐                                │
│         │           │kRegistry    │ ── Access control & config     │
│         │           └─────────────┘                                │
│         │                                                          │
│  Fee & Settlement:                                                 │
│         ├─────────▶ ┌─────────────┐                                │
│         │           │Treasury     │ ── Fee collection              │
│         │           └─────────────┘                                │
│         │                                                          │
│         └─────────▶ ┌─────────────┐                                │
│                     │BatchReceiver│ ── Settlement distribution     │
│                     └─────────────┘                                │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Share Price Calculation

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Share Price Calculation                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Components that build Total Assets:                                │
│  ┌─────────────────┐                                                │
│  │kToken Balance   │                                                │
│  │vault.kToken.    │                                                │
│  │balanceOf(this)  │                                                │
│  └────────┬────────┘                                                │
│           │                                                         │
│           │ Subtract pending stakes                                 │
│           ▼                                                         │
│  ┌─────────────────┐                                                │
│  │Total Assets =   │                                                │
│  │Balance -        │                                                │
│  │PendingStakes    │                                                │
│  └────────┬────────┘                                                │
│           │                                                         │
│  Components that reduce to Net Assets:                              │
│  ┌─────────────────┐         ┌─────────────────┐                    │
│  │Management Fees  │         │Performance Fees │                    │
│  │(configurable)   │         │(configurable)   │                    │
│  │Time-based       │         │Above watermark  │                    │
│  └────────┬────────┘         └────────┬────────┘                    │
│           │                           │                             │
│           └───────────┬───────────────┘                             │
│                       ▼                                             │
│              ┌─────────────────┐                                    │
│              │Total Net Assets │                                    │
│              │= totalAssets -  │                                    │
│              │accumulatedFees  │                                    │
│              └────────┬────────┘                                    │
│                       │                                             │
│  ┌─────────────────┐  │                                             │
│  │Total Supply     │  │                                             │
│  │(stkTokens)      │  │                                             │
│  └────────┬────────┘  │                                             │
│           │           │                                             │
│           └─────┬─────┘                                             │
│                 ▼                                                   │
│        ┌─────────────────────────────────┐                          │
│        │Formulas:                        │                          │
│        │                                 │                          │
│        │grossSharePrice =                │                          │
│        │  totalAssets * (10^decimals)    │                          │
│        │  / totalSupply                  │                          │
│        │                                 │                          │
│        │netSharePrice =                  │                          │
│        │  totalNetAssets * (10^decimals) │                          │
│        │  / totalSupply                  │                          │
│        └─────────────────────────────────┘                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Fee Distribution

```
┌────────────────────────────────────────────────────────────────┐
│                        Fee Distribution Flow                   │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│                         ┌─────────────┐                        │
│                         │Gross Yield  │                        │
│                         └──────┬──────┘                        │
│                                │                               │
│               ┌────────────────────────────────┐               │
│               │                                │               │
│               ▼                                ▼               │
│      ┌────────────────┐               ┌────────────────┐       │
│      │Management Fee  │               │Performance Fee │       │
│      │(configurable)  │               │(configurable)  │       │
│      └────────┬───────┘               └────────┬───────┘       │
│               │                                │               │
│               │                                ▼               │
│               │                         ┌─────────────┐        │
│               └────────────────────────▶│Treasury     │        │
│                                         └─────────────┘        │
│                                                │               |
│                                                ▼               |     
│                                         ┌─────────────┐        |
│                                         │Net Yield    │        |
│                                         └──────┬──────┘        |
│                                                │               |
│                                                ▼               |
│                                         ┌─────────────┐        |
│                                         │Users        │        |
│                                         │(Stakers)    │        |
│                                         └─────────────┘        |
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Request States

```
Request Status Flow:

┌─────────────┐
│PENDING      │ ── Initial state when requestStake() or requestUnstake() is called
└──────┬──────┘
       │
       ├────────────────────────────────────┐
       │                                    ▼
       │                            ┌─────────────┐
       │                            │CANCELLED    │ ── Via user cancellation
       │                            └─────────────┘
       │
       ▼
┌─────────────┐
│CLAIMED      │ ── After successful claim operation
└─────────────┘
```

## Key Functions by Contract

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Contract Function Overview                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  kStakingVault Functions:             Batch Functions:              │
│  ┌───────────────────────────┐      ┌───────────────────────────┐   │
│  │• requestStake()           │      │• createNewBatch()         │   │
│  │  Start staking process    │      │  Create new batch ID      │   │
│  │                           │      │                           │   │
│  │• requestUnstake()         │      │• closeBatch()             │   │
│  │  Start unstaking process  │      │  Stop new requests        │   │
│  │                           │      │                           │   │
│  │• claimStakedShares()      │      │• settleBatch()            │   │
│  │  Get stkTokens            │      │  Lock share prices        │   │
│  │                           │      │  (Called by kAssetRouter) │   │
│  │• claimUnstakedAssets()    │      └───────────────────────────┘   │
│  │  Get kTokens + yield      │                                      │
│  │                           │                                      │
│  │• cancelStakeRequest()     │      kAssetRouter Functions:         │
│  │  Cancel pending stake     │      ┌───────────────────────────┐   │
│  │                           │      │• proposeSettleBatch()     │   │
│  │• cancelUnstakeRequest()   │      │  Start settlement process │   │
│  │  Cancel pending unstake   │      │                           │   │
│  └───────────────────────────┘      │• executeSettleBatch()     │   │
│                                     │  Execute after cooldown   │   │
│  Price Functions:                   │                           │   │
│  ┌───────────────────────────┐      │• cancelProposal()         │   │
│  │• _sharePrice()            │      │  Guardian cancellation    │   │
│  │  Gross price calculation  │      │                           │   │
│  │                           │      │• kAssetTransfer()         │   │
│  │• _netSharePrice()         │      │  Virtual balance updates  │   │
│  │  Net after fees           │      └───────────────────────────┘   │
│  │                           │                                      │
│  │• _totalAssets()           │      Fee Functions:                  │
│  │  Balance - pending stakes │      ┌───────────────────────────┐   │
│  │                           │      │• setManagementFee()       │   │
│  │• _totalNetAssets()        │      │• setPerformanceFee()      │   │
│  │  Assets - fees            │      │• setHardHurdleRate()      │   │
│  └───────────────────────────┘      └───────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Timeline: Happy Path Staking

```
Staking Timeline:

Day 0:              Day 1:              Day 2:              Day 2:              Day N:
┌───────────-──┐     ┌─────────────-┐    ┌-─────────────┐    ┌-─────────────┐    ┌-─────────────┐
│Stake kTokens │───-▶│Batch Closes  │───▶│Settlement    │───▶│Claim         │───▶│Earn Yield    │
│via           │     │(relayer)     │    │Executed      │    │stkTokens     │    │(ongoing)     │
│requestStake()│     │              │    │              │    │              │    │              │
└────────────-─┘     └─────────────-┘    └─────────────-┘    └─────────────-┘    └─────────────-┘
```

## Timeline: Happy Path Unstaking

```
Unstaking Timeline:

Day 0:              Day 1:              Day 2:              Day 2:
┌───────────-──┐    ┌───-──────────┐    ┌─-────────────┐    ┌──-───────────┐
│Request       │───▶│Batch Closes  │───▶│Settlement    │───▶│Claim kTokens │
│Unstake via   │    │(relayer)     │    │Executed      │    │+ Yield       │
│requestUnstake│    │              │    │              │    │              │
└───────────-──┘    └───────-──────┘    └─────────────-┘    └──────-───────┘
```

## Token Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    Token Flow Diagram                                           │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  STAKING FLOW:                                                                                  │
│  ┌─────────────────┐    safeTransferFrom      ┌─────────────────┐                               │
│  │User kTokens     │─────────────────────────▶│kStakingVault    │                               │
│  │                 │                          │                 │                               │
│  └─────────────────┘                          └─────────┬───────┘                               │
│                                                         │                                       │
│                    Virtual transfer via kAssetRouter    │                                       │
│                                                         ▼                                       │
│                                               ┌─────────────────┐                               │
│                                               │From kMinter     │                               │
│                                               │to Vault         │                               │
│                                               └─────────┬───────┘                               │
│                                                         │                                       │
│                      After Settlement                   ▼                                       │
│                                               ┌─────────────────┐                               │
│                                               │Mint stkTokens   │                               │
│                                               │based on share   │                               │
│                                               │price to User    │                               │
│                                               └─────────────────┘                               │
│                                                                                                 │
│  UNSTAKING FLOW:                                                                                │
│  ┌─────────────────┐    Track shares          ┌─────────────────┐                               │
│  │User requests    │─────────────────--───--─▶│   kAssetRouter  │                               │
│  │unstaking        │                          │                 │                               │
│  └─────────────────┘                          └─────────────────┘                               │
│                                                         │                                       │
│                        Settlement yield                 ▼                                       │
│                        ┌─────────────────┐    ┌─────────────────┐                               │
│                        │Mint/burn kTokens│───▶│Vault balance    │                               │
│                        │to vault         │    │updated          │                               │
│                        └─────────────────┘    └─────────-───────┘                               │
│                                                                                                 |
|                                                                                                 │
│  ┌─────────────────┐     Burn stkTokens       ┌─────────────────┐                               │
│  │User claims      │───────────────────----──▶│stkTokens        │                               │
│  │                 │                          │Destroyed        │                               │
│  └─────────────────┘                          └─────────────────┘                               │
│           │                                                                                     │
│           │                Transfer net amount                                                  │
│           ▼                                                                                     │
│  ┌─────────────────┐    ┌─────────────────────────────────┐    ┌─────────────────┐              │
│  │User receives    │◀───│                                 │───▶│Treasury         │              │
│  │kTokens + yield  │    │         Fees deducted           │    │(Fees)           │              │
│  └─────────────────┘    └─────────────────────────────────┘    └─────────────────┘              │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Yield Accumulation

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                Yield Accumulation Flow                                          │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                 │
│  Yield Sources:                                                                                 │
│  ┌─────────────────┐                                                                            │
│  │Adapters         │                                                                            │
│  │                 │                                                                            │
│  │• MetaVault      │                                                                            │
│  │• CEFFU          │                                                                            │
│  │                 │                                                                            │
│  └─────────┬───────┘                                                                            │
│            │                                                                                    │
│            │                                                                                    │
│            |                                                                                    │
│            │                                                                                    │
│            ▼                                                                                    │
│  ┌─────────────────┐                                                                            │
│  │Yield Pool       │                                                                            │
│  │(Aggregated      │                                                                            │
│  │Returns)         │                                                                            │
│  └─────────┬───────┘                                                                            │
│            │                                                                                    │
│            ▼                                                                                    │
│  ┌─────────────────┐                                                                            │
│  │Increases Share  │                                                                            │
│  │Price            │                                                                            │
│  │                 │ ── sharePrice = totalAssets * 1e18 / totalSupply                           │
│  └─────────┬───────┘                                                                            │
│            │                                                                                    │
│            ▼                                                                                    │
│  ┌─────────────────┐                                                                            │
│  │Benefits All     │                                                                            │
│  │stkToken Holders │                                                                            │
│  │                 │ ── All stakers earn proportional yield                                     │
│  └─────────────────┘                                                                            │
│                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```