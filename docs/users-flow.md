# KAM Protocol - Users Flow Diagram

## Overview: User Journey

```mermaid
graph LR
    U[User] --> S1[Step1: Stake kTokens]
    S1 --> W1[Wait for Settlement]
    W1 --> C1[Step2: Claim stkTokens]
    C1 --> H[Hold stkTokens and Earn Yield]
    H --> U1[Step3: Request Unstake]
    U1 --> W2[Wait for Settlement]
    W2 --> C2[Step4: Claim kTokens plus Yield]
```

## Detailed Flow: Staking kTokens

```mermaid
flowchart TD
    Start([User has kTokens]) --> Request[Request Stake]
    Request --> Check{Batch Open?}
    Check -->|No| Reject[Cannot Stake]
    Check -->|Yes| Transfer[Transfer kTokens to Vault]
    Transfer --> Store[Create Stake Request]
    Store --> Track[Update Pending Stakes]
    Track --> End([Waiting for Batch Settlement])
```

## Detailed Flow: Unstaking Process

```mermaid
flowchart TD
    Start([User has stkTokens]) --> Request[Request Unstake]
    Request --> Check{Has Balance?}
    Check -->|No| Reject[Insufficient Balance]
    Check -->|Yes| Hold[stkTokens Held by Vault]
    Hold --> Store[Create Unstake Request]
    Store --> Track[Update Virtual Balances]
    Track --> End([Waiting for Batch Settlement])
```

## Batch Processing

```mermaid
flowchart TD
    Active[Active Batch] --> Close[Relayer Closes Batch]
    Close --> Settle[Settlement Executed]
    Settle --> Capture[Capture Share Prices]
    Capture --> Create[Create BatchReceiver]
    Create --> Ready[Ready for Claims]
```

## Claiming Staked Shares

```mermaid
flowchart TD
    Start([Stake Request Pending]) --> Check{Batch Settled?}
    Check -->|No| Wait[Cannot Claim Yet]
    Check -->|Yes| Calculate[Calculate stkTokens Based on Net Share Price]
    Calculate --> Mint[Mint stkTokens to User]
    Mint --> Update[Update Pending Stakes]
    Update --> End([User Receives stkTokens])
```

## Claiming Unstaked Assets

```mermaid
flowchart TD
    Start([Unstake Request Pending]) --> Check{Batch Settled?}
    Check -->|No| Wait[Cannot Claim Yet]
    Check -->|Yes| Calculate[Calculate kTokens Gross and Net Amounts]
    Calculate --> Fees[Deduct Fees to Treasury]
    Fees --> Burn[Burn stkTokens]
    Burn --> Transfer[Transfer Net kTokens]
    Transfer --> End([User Receives kTokens plus Yield])
```

## Contract Architecture

```mermaid
graph TD
    subgraph User Layer
        USER[Retail User]
    end
    
    subgraph Vault Layer
        KSV[kStakingVault]
        STK[stkTokens]
    end
    
    subgraph Infrastructure
        KT[kToken]
        KAR[kAssetRouter]
        BR[BatchReceiver]
    end
    
    subgraph Fee Layer
        TREAS[Treasury]
    end
    
    USER --> KSV
    KSV --> STK
    KSV --> KT
    KSV --> KAR
    KSV --> BR
    KSV --> TREAS
```

## Share Price Calculation

```mermaid
flowchart TD
    TA[Total Assets] --> SP{Calculate Share Price}
    TS[Total Supply] --> SP
    SP --> Formula[sharePrice equals totalAssets times 1e18 divided by totalSupply]
    
    subgraph Components
        VB[Virtual Balance]
        AA[Adapter Assets]
        MF[Management Fees]
        PF[Performance Fees]
    end
    
    VB --> TA
    AA --> TA
    MF -->|Reduces| TA
    PF -->|Reduces| TA
```

## Fee Distribution

```mermaid
flowchart LR
    GY[Gross Yield] --> MF[Management Fee 2pct]
    GY --> PF[Performance Fee 10pct]
    MF --> T[Treasury]
    PF --> T
    GY --> NY[Net Yield]
    NY --> U[Users]
```

## Request States

```mermaid
flowchart LR
    PENDING --> CLAIMED
    PENDING --> CANCELLED
```

## Key Functions by Contract

```mermaid
graph TD
    subgraph kStakingVault Functions
        F1[requestStake - Start staking]
        F2[requestUnstake - Start unstaking]
        F3[claimStakedShares - Get stkTokens]
        F4[claimUnstakedAssets - Get kTokens]
    end
    
    subgraph Batch Functions
        F5[closeBatch - Stop new requests]
        F6[settleBatch - Lock share prices]
        F7[createBatchReceiver - Deploy distributor]
    end
    
    subgraph Price Functions
        F8[sharePrice - Current price]
        F9[netSharePrice - Price after fees]
        F10[totalAssets - AUM calculation]
    end
```

## Timeline: Happy Path Staking

```mermaid
graph LR
    T0[Day_0: Stake kTokens] --> T1[Day_1: Batch Closes]
    T1 --> T2[Day_2: Settlement]
    T2 --> T3[Day_2: Claim stkTokens]
    T3 --> T4[Day_N: Earn Yield]
```

## Timeline: Happy Path Unstaking

```mermaid
graph LR
    T0[Day_0: Request Unstake] --> T1[Day_1: Batch Closes]
    T1 --> T2[Day_2: Settlement]
    T2 --> T3[Day_2: Claim kTokens]
```

## Token Flow

```mermaid
flowchart LR
    subgraph Staking
        K1[User kTokens] -->|Transfer| K2[Vault]
        K2 -->|After Settlement| K3[stkTokens to User]
    end
    
    subgraph Unstaking
        S1[User stkTokens] -->|Hold| S2[Vault]
        S2 -->|Burn| S3[Destroyed]
        S4[Vault kTokens] -->|Transfer| S5[User kTokens plus Yield]
        S4 -->|Fees| S6[Treasury]
    end
```

## Yield Accumulation

```mermaid
flowchart TD
    subgraph Yield Sources
        Y1[Lending Protocols]
        Y2[Liquidity Pools]
        Y3[Staking Rewards]
    end
    
    Y1 --> YP[Yield Pool]
    Y2 --> YP
    Y3 --> YP
    
    YP --> SP[Increases Share Price]
    SP --> BH[Benefits All Holders]
```