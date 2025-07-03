# kTokens Protocol

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue)](https://docs.soliditylang.org/)

> **Dual-Flow kToken Protocol with O(1) Settlement & Automatic Yield Distribution**

kTokens is a next-generation protocol providing 1:1 asset backing for institutions while enabling automatic yield distribution to retail users through a dual accounting model. The protocol leverages innovative O(1) settlement optimization, modular strategy management, and Solady's gas-optimized libraries for maximum efficiency

## 🎯 Overview

**Core Value Proposition:**
- **For Institutions:** 1:1 backed kToken minting/redemption (never loses value to yield)
- **For Retail Users:** Automatic yield distribution through kToken staking
- **For Protocol:** Dual accounting model separating institutional 1:1 backing from user yield generation

## 🏗️ Architecture

### Smart Contracts

```
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│   kToken     │<──►│   kMinter    │───►│  kDNStakingVault │
│ (ERC20/UUPS) │    │ (UUPS)       │    │ (Dual Accounting)│
└──────────────┘    └──────────────┘    └──────────────────┘
                                                   │
                                        ┌──────────────────┐
                                        │ kStrategyManager │
                                        │ (O(1) Settlement)│
                                        └──────────────────┘
                                                   │
                                        ┌──────────────────┐
                                        │ kBatchReceiver   │
                                        │ (Minimal Proxy)  │
                                        └──────────────────┘
```

- **kToken:** Upgradeable ERC20 token with 1:1 asset backing, mint/burn controlled by kMinter
- **kMinter:** Institutional minting/redemption with **bitmap-based batch settlement**, integrates with kDNStakingVault for 1:1 backing  
- **kDNStakingVault:** **Dual accounting ERC4626 vault** - separate 1:1 accounting for minters, yield-bearing for users
- **kStrategyManager:** **O(1) settlement orchestration** - modular strategy allocation with EIP712 signatures (97-99% gas savings)
- **kBatchReceiver:** Minimal proxy deployed per redemption batch for asset distribution

### Contract Interactions
- **Institutions** interact with `kMinter` for 1:1 kToken minting/redemption - always get exact asset amounts
- **Retail Users** stake kTokens through `kMinter` → get stkTokens → claim yield-bearing vault shares
- **kMinter** maintains 1:1 backing by routing assets to kDNStakingVault's minter pool (fixed ratio)
- **kDNStakingVault** uses **dual accounting**: minter assets (1:1) + user assets (yield-bearing)
- **Automatic Yield Distribution**: Minter asset yield automatically flows to user share appreciation

## ⚡ Technology Stack
- **Framework:** Foundry (forge, anvil, cast) + Soldeer for dependency management
- **Solidity:** ^0.8.30
- **Libraries:** Solady (OwnableRoles, SafeTransferLib, UUPS, LibBitmap, FixedPointMathLib)
- **Yield Model:** Automatic yield distribution from minter assets to user shares
- **Dual Accounting:** Separate 1:1 minter accounting from yield-bearing user accounting
- **Batch Settlement:** Bitmap-based eligibility and status tracking for ultra-low gas batch settlement
- **Testing:** Foundry test suite (unit, integration, invariant, fork)

## 🚀 Quick Start

### Prerequisites
- [Foundry](https://getfoundry.sh/) installed
- [Soldeer](https://github.com/VerisLabs/soldeer) for dependency management
- Git
- Node.js (for additional tooling)

### Installation

```bash
# Clone the repository
git clone https://github.com/VerisLabs/KAM
cd KAM

# Install dependencies
soldeer install

# Copy environment file
cp .env.example .env
```

### Build

```bash
# Compile contracts
forge build

# Run tests
forge test

# Run tests with gas reports
forge test --gas-report
```

### Deploy

```bash
# Deploy to local anvil
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Deploy to testnet
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify

# Deploy to mainnet (requires additional verification)
forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## 🔑 Secure Private Key Management (Recommended)

**Do NOT add your private key to .env or commit it to version control.**

Instead, use Foundry's keystore system to securely manage your deployer key.

### 1. Create a New Wallet Keystore

```bash
cast wallet import myKeystoreName --interactive
```
- Enter your wallet's private key when prompted.
- Provide a password to encrypt the keystore file.

⚠️ **Recommendation:**
Do not use a private key associated with real funds. Create a new wallet for deployment and testing.

### 2. Deploy the Smart Contract

Use the keystore you created to sign transactions with forge script:

```bash
forge script script/base/01_Deploy.s.sol \
  --rpc-url $RPC_BASE \
  --broadcast \
  --verify \
  --account myKeystoreName \
  --sender <accountAddress>
```
- `--account myKeystoreName`: Use the keystore you created.
- `--sender <accountAddress>`: The address corresponding to your keystore.

## 📋 Contract Interfaces

### kMinter Functions
- `mint(MintRequest calldata request)` — Institutional minting (1:1 with assets, role-gated)
- `requestRedeem(RedeemRequest calldata request)` — Redemption request (burns kToken, creates batch request)
- `enableKTokenStaking(address user, uint256 amount)` — Enable kToken staking for yield (transfers to vault)
- `settleBatch(uint256 batchId)` — **O(1) batch settlement** with bitmap eligibility (fixed ~13k gas cost)
- `redeem(bytes32 requestId)` — Redeem from BatchReceiver (1:1 assets for burned kTokens)
- `cancelRequest(bytes32 requestId)` — Cancel pending redemption (refunds kToken)

### kToken Functions
- `mint(address to, uint256 amount)` — Mint tokens (minter only, 1:1 backed)
- `burn(address from, uint256 amount)` — Burn tokens (minter only)
- `burnFrom(address from, uint256 amount)` — Burn with allowance (minter only)
- `setPaused(bool isPaused)` — Emergency pause

### kDNStakingVault Functions (Dual Accounting)
- `requestMinterDeposit(uint256 assetAmount, address minter)` — Minter deposit (1:1 accounting)
- `requestMinterRedeem(uint256 assetAmount, address minter, address batchReceiver)` — Minter redemption (1:1)
- `enableKTokenStaking(address user, uint256 kTokenAmount, address minter)` — User staking (transfers to yield pool)
- `settleBatch(uint256 batchId)` — Unified batch settlement with minter operations
- `settleStakingBatch(uint256 batchId, uint256 totalAmount)` — **O(1) staking settlement** (fixed ~13k gas cost)
- `settleUnstakingBatch(uint256 batchId, uint256 totalAmount)` — **O(1) unstaking settlement** (fixed ~13k gas cost)
- `claimStakingShares(uint256 batchId, uint256 requestIndex)` — Claim yield-bearing shares
- `syncYield()` — Sync unaccounted yield from minter assets to user pool
- `getUserSharePrice()` — Current user share price including yield
- `getUnaccountedYield()` — View unaccounted yield from minter asset strategies

### kStrategyManager Functions (O(1) Settlement)
- `settleAndAllocate(stakingBatchId, unstakingBatchId, allocationOrder, signature)` — **O(1) settlement orchestration** with asset allocation
- `emergencySettle(uint256 stakingBatchId, uint256 unstakingBatchId)` — Emergency settlement without allocation
- `registerAdapter(address, AdapterType, maxAllocation, implementation)` — Register new strategy adapter
- `executeAllocation(AllocationOrder, signature)` — Execute allocation with EIP712 signature validation

## 🌊 Automatic Yield Distribution

- **Automatic Yield Flow:** Yield from minter deposited assets automatically increases user share value
- **Dual Accounting Pools:** Minter assets (1:1 fixed) + User assets (yield-bearing)
- **Real-Time Sync:** `totalAssets()` includes unaccounted yield for immediate share price updates
- **Manual Sync:** `syncYield()` transfers unaccounted yield from minter to user pool
- **Continuous Accrual:** Yield accrues continuously without manual intervention

## ⚡ O(1) Settlement Optimization

- **Revolutionary Gas Efficiency:** Fixed ~13k gas settlement cost regardless of batch size (97-99% savings vs O(n))
- **Modular Strategy Management:** kStrategyManager orchestrates settlement with multi-adapter allocation
- **EIP712 Signature Validation:** Secure backend coordination for allocation orders
- **User-Paid Claims:** Optional claiming shifts gas costs to users (only when needed)
- **Unlimited Scalability:** No gas limit constraints for batch processing
- **Bitmap-Based Tracking:** Ultra-efficient status and eligibility management

## 🛡️ Security & Dual Accounting Model

- **Reentrancy Protection:** Checks-effects-interactions pattern applied across all contracts
- **Dual Accounting Security:** Separate pools ensure minter 1:1 backing never affected by user yield
- **1:1 Guarantee:** Institutions always get exact asset amounts (minter pool fixed ratio)
- **Automatic Yield Flow:** Unaccounted yield from minter assets automatically flows to user shares
- **Role-Based Access:** All critical functions protected by Solady's OwnableRoles
- **Bitmap Efficiency:** Request tracking and batch eligibility use gas-optimized bitmaps
- **Batch Settlement:** Unified batches with netting for optimal gas efficiency
- **Interface Alignment:** Type-safe contract interactions with verified signatures
- **Event Logging:** All dual accounting operations emit events for auditability
- **Emergency Controls:** Pause, emergency withdrawals, and manual yield distribution

## 🧪 Testing

Our test suite covers:
- **Unit Tests:** Individual contract functionality and dual accounting
- **Integration Tests:** Cross-contract interactions and yield flow
- **Fork Tests:** Mainnet state testing with real yield scenarios
- **Invariant Tests:** Dual accounting invariants and 1:1 backing guarantees
- **Yield Tests:** Automatic yield distribution validation

```bash
# Run all tests
forge test

# Run with coverage
forge coverage

# Run specific test file
forge test --match-path test/unit/kMinter.t.sol
```

## 📚 Resources

- **Documentation:** (coming soon)
- **Whitepaper:** (coming soon)
- **Audit Reports:** (coming soon)
- **Discord:** (coming soon)

## ⚖️ License

This project is Unlicensed.

---

**Built with ❤️ using Foundry, Solady, and Soldeer**