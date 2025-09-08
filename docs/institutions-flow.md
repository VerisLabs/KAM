# KAM Protocol - Institutions Flow Diagram

## Overview: Institution Journey

```mermaid
graph LR
    I[Institution] --> M1[Step1: Mint kTokens]
    M1 --> H[Hold kTokens]
    H --> R1[Step2: Request Redemption]
    R1 --> W[Wait for Settlement]
    W --> E[Step3: Execute Redemption]
    E --> A[Receive Assets + Yield]
```

## Detailed Flow: Minting kTokens

```mermaid
flowchart TD
    Start([Institution has Assets]) --> Check{Has INSTITUTION_ROLE?}
    Check -->|No| Deny[Transaction Reverts]
    Check -->|Yes| Transfer[Transfer Assets to Router]
    Transfer --> Mint[Mint kTokens 1:1]
    Mint --> Track[Update Virtual Balances]
    Track --> End([Institution has kTokens])
```

## Detailed Flow: Redemption Request

```mermaid
flowchart TD
    Start([Institution has kTokens]) --> Request[Request Redemption]
    Request --> Escrow[kTokens Held in Escrow]
    Escrow --> GenID[Generate Request ID]
    GenID --> Store[Store Request as PENDING]
    Store --> Update[Update Virtual Balances]
    Update --> End([Waiting for Batch Settlement])
```

## Batch Settlement Process

```mermaid
flowchart TD
    Open[Batch Open] --> Close[Relayer Closes Batch]
    Close --> Propose[Propose Settlement]
    Propose --> Cool[Cooldown Period<br/>1-24 hours]
    Cool --> Execute[Execute Settlement]
    Execute --> Deploy[Deploy BatchReceiver]
    Deploy --> Ready[Ready for Claims]
```

## Redemption Execution

```mermaid
flowchart TD
    Start([Request Pending]) --> Check{Batch Settled?}
    Check -->|No| Wait[Cannot Redeem Yet]
    Check -->|Yes| Pull[Pull Assets from BatchReceiver]
    Pull --> Burn[Burn Escrowed kTokens]
    Burn --> Receive[Institution Receives Assets]
    Receive --> End([Redemption Complete])
```

## Contract Architecture

```mermaid
graph TD
    subgraph User Layer
        INST[Institution]
    end
    
    subgraph Access Layer
        KM[kMinter]
    end
    
    subgraph Token Layer
        KT[kToken]
    end
    
    subgraph Routing Layer
        KAR[kAssetRouter]
    end
    
    subgraph Vault Layer
        DNV[DN Vault]
        BR[BatchReceiver]
    end
    
    INST --> KM
    KM --> KT
    KM --> KAR
    KAR --> DNV
    DNV --> BR
    BR --> INST
```

## State Machine: Request Lifecycle

```mermaid
flowchart LR
    PENDING --> CANCELLED
    PENDING --> SETTLED
    SETTLED --> REDEEMED
```

## Key Functions by Contract

```mermaid
graph TD
    subgraph kMinter Functions
        F1[mint - Create kTokens]
        F2[requestRedeem - Start redemption]
        F3[redeem - Execute redemption]
        F4[cancelRequest - Cancel pending]
    end
    
    subgraph kAssetRouter Functions
        F5[kAssetPush - Track deposits]
        F6[kAssetRequestPull - Track withdrawals]
        F7[proposeSettleBatch - Start settlement]
        F8[executeSettleBatch - Finalize settlement]
    end
    
    subgraph DN Vault Functions
        F9[closeBatch - Stop new requests]
        F10[settleBatch - Lock in prices]
        F11[createBatchReceiver - Deploy distributor]
    end
```

## Timeline: Happy Path

```mermaid
graph LR
    T0[Day_0: Mint kTokens] --> T1[Day_N: Request Redemption]
    T1 --> T2[Day_N+1: Batch Closes]
    T2 --> T3[Day_N+2: Settlement Proposed]
    T3 --> T4[Day_N+3: Settlement Executed]
    T4 --> T5[Day_N+3: Redeem Assets]
```

## Asset Flow

```mermaid
flowchart LR
    subgraph Minting
        A1[Institution Assets] -->|Transfer| A2[Router]
        A2 -->|Virtual Balance| A3[DN Vault Batch]
        A1 -->|Mint 1to1| A4[kTokens to Institution]
    end
    
    subgraph Redeeming
        B1[kTokens] -->|Escrow| B2[kMinter]
        B3[BatchReceiver] -->|Transfer| B4[Assets to Institution]
        B2 -->|Burn| B5[kTokens Destroyed]
    end
```

## Virtual Balance Tracking

```mermaid
flowchart TD
    subgraph Virtual Balances
        D[Deposited]
        R[Requested]
        S[Settled]
    end
    
    Mint -->|Increase| D
    Request -->|Increase| R
    Settlement -->|Move from D,R to| S
    Claim -->|Decrease| S
```
