# KAM Protocol - Institutions Flow Diagram

## Overview: Institution Journey

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│Institution  │───▶│Step1: Mint  │───▶│Hold kTokens │───▶│Step2:Request│
│has Assets   │    │kTokens 1:1  │    │& Earn Yield │    │Redemption   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                 │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐            │
│Receive      │◀───│Step3:Execute│◀───│Wait for     │◀───────────┘
│Assets+Yield │    │Redemption   │    │Settlement   │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Detailed Flow: Minting kTokens

```
┌─────────────────┐
│Institution has  │
│Assets (USDC)    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Has INSTITUTION_ │NO  │Transaction      │
│ROLE?            ├───▶│Reverts          │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐    ┌─────────────────┐
│Active batch     │NO  │Create new batch │
│exists for asset?├───▶│for asset        │
└────────┬────────┘    └────────┬────────┘
         │YES                   │
         ▼                      ▼
┌─────────────────┐    ┌─────────────────┐
│safeTransferFrom │◀───┤Transfer to      │
│to kAssetRouter  │    │kAssetRouter     │
└────────┬────────┘    └─────────────────┘
         │
         ▼
┌─────────────────┐
│kAssetRouter.    │
│kAssetPush()     │ ── Track virtual balance
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Mint kTokens     │
│1:1 immediately  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Institution has  │
│kTokens          │
└─────────────────┘
```

## Detailed Flow: Redemption Request

```
┌─────────────────┐
│Institution has  │
│kTokens          │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Sufficient       │NO  │Transaction      │
│balance?         ├───▶│Reverts          │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐
│Generate unique  │
│request ID       │ ── Uses hash(counter, user, asset, time)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Transfer kTokens │
│to kMinter       │ ── Escrow (not burned yet)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Store as PENDING │
│RedeemRequest    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│kAssetRouter.    │
│kAssetRequestPull│ ── Track withdrawal request
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Create BatchRecv │
│if needed        │ ── _createBatchReceiver()
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Waiting for      │
│Batch Settlement │
└─────────────────┘
```

## Batch Settlement Process

```
┌─────────────────┐
│Batch Active     │
│(Accepting mint/ │
│burn requests)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Relayer Closes   │
│Batch            │ ── closeBatch() - stops new requests
└────────┬────────┘
         │
         ▼
┌─────────────────-┐
│Relayer calls     │
│proposeSettleBatch│ ── Only provides totalAssets parameter
│with totalAssets  │
└────────┬────────-┘
         │
         ▼
┌─────────────────┐
│kAssetRouter     │
│calculates:      │ ── Contract automatically computes:
│• netted amount  │    • netted = deposited - requested
│• yield amount   │    • yield = totalAssets - netted - lastTotal
│• profit/loss    │    • profit = yield > 0
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Cooldown Period  │
│(Default 1 hour) │ ── Guards can cancel during cooldown
└────────┬────────┘
         │
         ▼
┌─────────────────-┐
│Anyone calls      │
│executeSettleBatch│ ── After cooldown expires
└────────┬────────-┘
         │
         ▼
┌─────────────────┐
│Transfer assets  │
│to BatchReceiver │ ── For institutional redemptions
│for redemptions  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Ready for Claims │
└─────────────────┘
```

## Redemption Execution

```
┌─────────────────┐
│Request Pending  │
│(PENDING status) │
└────────┬────────┘
         │
         ▼
┌─────────────────┐    ┌─────────────────┐
│Batch Settled?   │NO  │Cannot Redeem    │
│                 ├───▶│Yet              │
└────────┬────────┘    └─────────────────┘
         │YES
         ▼
┌─────────────────┐
│Validate request │
│status           │ ── Check request exists and is PENDING
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Mark request as  │
│REDEEMED         │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Burn escrowed    │
│kTokens          │ ── IkToken(kToken).burn(address(this), amount)
│permanently      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│BatchReceiver.   │
│pullAssets()     │ ── Transfer assets to recipient
│to recipient     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│Institution      │
│receives         │
│underlying assets│
└─────────────────┘
```

## State Machine: Request Lifecycle

```
Request Status Flow:

┌─────────────┐
│PENDING      │ ── Initial state when requestBurn() is called
└──────┬──────┘
       │
       ├─────────────┐
       │             ▼
       │    ┌─────────────┐
       │    │CANCELLED    │ ── Via cancelRequest() before batch settlement
       │    └─────────────┘
       │
       ▼
┌─────────────┐
│SETTLED      │ ── After batch settlement is executed
└──────┬──────┘
       │
       ▼
┌─────────────┐
│REDEEMED     │ ── After burn() successfully pulls assets
└─────────────┘
```

## Key Functions by Contract

```
┌─────────────────────────────────────────────────────────────────-┐
│                    Contract Function Overview                    │
├─────────────────────────────────────────────────────────────────-┤
│                                                                  │
│  kMinter Functions:              kAssetRouter Functions:         │
│  ┌─────────────────────────┐      ┌─────────────────────────┐    │
│  │• mint()                 │      │• kAssetPush()           │    │
│  │  Create kTokens 1:1     │      │  Track deposits         │    │
│  │                         │      │                         │    │
│  │• requestBurn()          │      │• kAssetRequestPull()    │    │
│  │  Start redemption       │      │  Track withdrawals      │    │
│  │                         │      │                         │    │
│  │• burn()                 │      │• proposeSettleBatch()   │    │
│  │  Execute redemption     │      │  Start settlement       │    │
│  │                         │      │                         │    │
│  │• cancelRequest()        │      │• executeSettleBatch()   │    │
│  │  Cancel pending         │      │  Finalize settlement    │    │
│  └─────────────────────────┘      └─────────────────────────┘    │
│                                                                  │
│  kMinter Batch Functions:                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │• createNewBatch() - Create new batch for asset              │ │
│  │• closeBatch() - Stop accepting new requests                 │ │
│  │• settleBatch() - Mark batch as settled after processing     │ │
│  │• createBatchReceiver() - Deploy distributor per batch       │ │
│  └─────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────-─┘
```

## Timeline: Happy Path

```
Institutional Redemption Timeline:

Day 0:              Day N:              Day N+1:           Day N+2:
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│Mint kTokens │────▶│Request      │────▶│Batch Closes │────▶│Settlement   │
│1:1 immediate│     │Redemption   │     │(relayer)    │     │Proposed     │
│             │     │(any time)   │     │             │     │(relayer)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                    │
Day N+3:                                 Day N+3:                   │
┌─────────────┐     ┌─────────────┐     ┌─────────────┐             │
│Redeem Assets│◀────│Settlement   │◀────│Cooldown     │◀────────────┘
│(institution)│     │Executed     │     │Period (1hr) │
│             │     │(anyone)     │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Asset Flow

```
┌───────────────────────────────────────────────────────────────----─┐
│                        Asset Flow Diagram                          │
├─────────────────────────────────────────────────────────────────---┤
│                                                                    │
│  MINTING FLOW:                                                     │
│  ┌─────────────────┐    safeTransferFrom      ┌─────────────────┐  │
│  │Institution      │─────────────────────────▶│kAssetRouter     │  │
│  │Assets (USDC)    │                          │                 │  │
│  └─────────────────┘                          └─────────┬───────┘  │
│           │                                             │          │
│           │ Mint 1:1 immediate                          │          │
│           ▼                              kAssetPush()   │          │
│  ┌─────────────────┐                     (tracking)     │          │
│  │kTokens to       │                                    ▼          │
│  │Institution      │                          ┌─────────────────┐  │
│  └─────────────────┘                          │Virtual Balance  │  │
│                                               │Update           │  │
│                                               └─────────────────┘  │
│                                                                    │
│  REDEMPTION FLOW:                                                  │
│  ┌─────────────────┐    Escrow                ┌─────────────────┐  │
│  │kTokens          │────────────────────----─▶│Request Created  │  │
│  │                 │   (not burned yet)       │in kMinter       │  │
│  └─────────────────┘                          └─────────┬───────┘  │
│                                                         │          │
│                           Settlement                    ▼          │
│                        ┌─────────────────┐    ┌─────────────────┐  │
│                        │BatchReceiver    │◀───│Settlement       │  │
│                        │gets assets      │    │Executed         │  │
│                        └─────────┬───────┘    └─────────────────┘  │
│                                  │                                 │
│                    pullAssets()  ▼            Burn escrowed        │
│  ┌─────────────────┐   ┌─────────────────┐       kTokens           │
│  │Assets to        │◀──│Institution      │◀────────────-------     |
│  │Institution      │   │calls burn()     │                         │
│  └─────────────────┘   └─────────────────┘                         │
│                                                                    │
└─────────────────────────────────────────────────────────────────---┘
```

## Virtual Balance Tracking

```
┌─────────────────────────────────────────────────────────────────┐
│                    Virtual Balance State Machine                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Virtual Balances Tracked by kAssetRouter:                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │Deposited    │    │Requested    │    │Settled      │          │
│  │Balance      │    │Balance      │    │Balance      │          │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘          │
│         │                  │                  │                 │
│         ▲                  ▲                  ▲                 │
│         │                  │                  │                 │
│  ┌──────┴──────┐    ┌──────┴──────┐    ┌──────┴──────┐          │
│  │kAssetPush() │    │kAssetRequest│    │Settlement   │          │
│  │             │    │Pull()       │    │Execution    │          │
│  │Mint         │    │             │    │             │          │
│  │Operations   │    │Redeem       │    │Batch        │          │
│  └─────────────┘    │Requests     │    │Processing   │          │
│                     └─────────────┘    └─────────────┘          │
│                                               │                 │
│                                               ▼                 │
│                                        ┌─────────────┐          │
│                                        │Claim        │          │
│                                        │Operations   │          │
│                                        │             │          │
│                                        │Decrease     │          │
│                                        │Settled      │          │
│                                        └─────────────┘          │
│                                                                 │
│  Flow Summary:                                                  │
│  Mint → Increase Deposited                                      │
│  Request Redeem → Increase Requested                            │
│  Settlement → Move D,R to Settled                               │
│  Claim → Decrease Settled                                       │
└─────────────────────────────────────────────────────────────────┘
```
