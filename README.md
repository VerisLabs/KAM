# kTokens Protocol

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue)](https://docs.soliditylang.org/)

> **Dual-Flow kToken Protocol with Modular Architecture & Automatic Yield Distribution**

kTokens is a next-generation protocol providing 1:1 asset backing for institutions while enabling automatic yield distribution to retail users through a dual accounting model. The protocol features a consolidated modular architecture for contract size optimization, Solady's mathematical libraries with overflow protection and automatic zero-division safety, and enhanced escrow patterns for fund security.

## 🎯 Overview

**Core Value Proposition:**
- **For Institutions:** 1:1 backed kToken minting/redemption (never loses value to yield)
- **For Retail Users:** Automatic yield distribution through kToken staking with multiple risk profiles
- **For Protocol:** Dual accounting model separating institutional 1:1 backing from user yield generation

**Contract Architecture Per Asset Type:**
- **1 kMinter** - Handles actual assets (USDC/WBTC) with 1:1 kToken backing
- **1 kDNStakingVault** - Delta-neutral strategies using kTokens as underlying asset
- **2+ kSStakingVaults** - Higher-risk strategies (Alpha/Beta) using kTokens as underlying asset
- **1 kStrategyManager** - Central orchestrator for all asset flows and settlements
- **1 kSiloContract** - Secure intermediary for custodial strategy returns
- **1 kAsyncTracker** - Monitor for metavault operations and cross-chain delays

## 🏗️ Architecture

### Smart Contracts

```
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│   kToken     │<──►│   kMinter    │───►│  kDNStakingVault │
│ (ERC20/UUPS) │    │ (UUPS)       │    │ (Modular/UUPS)   │
└──────────────┘    └──────────────┘    └──────────────────┘
                                                   │
                            ┌─────────────────────────────────┐
                            │      kStrategyManager           │
                            │   (Central Orchestrator)        │
                            └─────────────────────────────────┘
                                     │           │
                          ┌──────────────┐  ┌──────────────────┐
                          │kSiloContract │  │  kAsyncTracker   │
                          │ (Custodial)  │  │  (Metavaults)    │
                          └──────────────┘  └──────────────────┘
                                     │           │
                          ┌──────────────────┐  ┌──────────────────┐
                          │ kSStakingVault   │  │ kBatchReceiver   │
                          │ (Alpha/Beta)     │  │ (Minimal Proxy)  │
                          └──────────────────┘  └──────────────────┘
```

### Modular kDNStakingVault Architecture

```
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  kDNStakingVault │<──►│  SettlementModule│    │   AdminModule    │
│ (Core + Modules) │    │(Batch Settlement)│    │ (Admin Functions)│
└──────────────────┘    └──────────────────┘    └──────────────────┘
          │                                                 │
          │              ┌──────────────────┐               │
          └─────────────►│  ClaimModule     │<──────────────┘
                         │ (Claim Functions)│
                         └──────────────────┘
                                  │
                         ┌──────────────────┐
                         │   ModuleBase     │
                         │ (Shared Storage) │
                         └──────────────────┘
```

- **kToken:** Upgradeable ERC20 token with 1:1 asset backing, mint/burn controlled by kMinter and vaults
- **kMinter:** Institutional minting/redemption with **bitmap-based batch settlement** and **Extsload** for efficient storage access
  - **Underlying Asset:** Real assets (USDC/WBTC)
  - **Role:** Maintains protocol-level 1:1 backing between kTokens and underlying assets
- **kDNStakingVault:** **Modular dual accounting vault** with **UUPS + MultiFacetProxy** - delta-neutral strategies
  - **Underlying Asset:** kTokens (kUSD/kBTC)
  - **Strategy Destinations:** Metavaults (70%) + Custodial wallets (30%)
  - **AdminModule:** Role management, configuration, and emergency functions
  - **SettlementModule:** O(1) batch settlement with bitmap tracking
  - **ClaimModule:** User claim functions for settled batches
  - **ModuleBase:** Consolidated storage, roles, and shared utilities
- **kSStakingVault:** **Strategy vaults for higher-risk yield strategies** (Alpha/Beta variants)
  - **Underlying Asset:** kTokens (kUSD/kBTC)
  - **Strategy Destinations:** Custodial wallets (80%) + Metavaults (20%)
  - **Asset Sourcing:** Coordinates with kStrategyManager for asset allocation
  - **Risk Profile:** Higher risk, potentially higher yields
- **kStrategyManager:** **Central settlement orchestrator** for all asset flows
  - **Settlement Control:** Validates strategy assets > deployed assets before distribution
  - **Multi-Destination:** Handles custodial and metavault allocations
  - **Backend Integration:** Executes signed orders for optimal asset allocation
- **kSiloContract:** **Secure intermediary** for custodial strategy returns
  - **Custodial Flow:** Custodial addresses can ONLY transfer tokens directly (USDC.transfer(siloAddress, amount))
  - **Access Control:** Only kStrategyManager can redistribute funds using transferToDestination()
  - **Balance Validation:** All transfers validate sufficient balance using asset.balanceOf(address(this))
- **kAsyncTracker:** **Metavault operation monitor** for cross-chain delays
  - **Async Operations:** Tracks metavault request/redeem cycles (~1h delays)
  - **Status Management:** Real-time operation status and completion tracking
- **kBatchReceiver:** Minimal proxy deployed per redemption batch for asset distribution
  - **Funding Source:** Receives assets from kStrategyManager during settlement

### Contract Interactions
- **Institutions** interact with `kMinter` for 1:1 kToken minting/redemption - always get exact asset amounts
- **Retail Users** stake kTokens through `kDNStakingVault` or `kSStakingVault` → get stkTokens → claim yield-bearing vault shares
- **kMinter** maintains 1:1 backing by routing assets to kDNStakingVault's minter pool (fixed ratio)
- **kDNStakingVault** uses **dual accounting**: minter assets (1:1) + user assets (yield-bearing)
- **kSStakingVault** sources actual assets from kDNStakingVault minter pool for higher-risk strategies
- **Modules** share storage via ERC-7201 pattern with **ModuleBase** providing unified access
- **Automatic Yield Distribution**: Minter asset yield automatically flows to user share appreciation
- **Inter-Vault Asset Management**: kSStakingVault calls `allocateAssetsToStrategy()` to get real assets from kDNStakingVault

## ⚡ Technology Stack
- **Framework:** Foundry (forge, anvil, cast) + Soldeer for dependency management
- **Solidity:** ^0.8.30
- **Libraries:** Solady (OwnableRoles, SafeTransferLib, UUPS, LibBitmap, FixedPointMathLib)
- **Architecture:** Consolidated modular design with ModuleBase inheritance
- **Upgradability:** Hybrid UUPS + MultiFacetProxy for dual upgradeability
- **Storage:** ERC-7201 pattern for shared storage across modules
- **Yield Model:** Automatic yield distribution from minter assets to user shares
- **Dual Accounting:** Separate 1:1 minter accounting from yield-bearing user accounting
- **Batch Settlement:** Bitmap-based eligibility and status tracking for ultra-low gas batch settlement
- **Mathematical Safety:** Solady FixedPointMathLib with automatic overflow protection and zero-division safety
- **Escrow Security:** Enhanced escrow pattern preventing fund loss during settlement failures
- **Testing:** Foundry test suite (unit, integration, invariant, fork) with comprehensive edge case coverage
- **Storage Access:** Extsload pattern for efficient frontend data queries

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

### kDNStakingVault Functions (Dual Accounting + Modular)
**Core Functions:**
- `requestMinterDeposit(uint256 assetAmount)` — Minter deposit (1:1 accounting)
- `requestMinterRedeem(uint256 assetAmount, address minter, address batchReceiver)` — Minter redemption (1:1)
- `requestStake(uint256 amount)` — Request kToken staking for stkTokens
- `requestUnstake(uint256 stkTokenAmount)` — Request stkToken unstaking for kTokens + yield

**Settlement Functions (SettlementModule):**
- `settleBatch(uint256 batchId)` — Unified batch settlement with minter operations
- `settleStakingBatch(uint256 batchId, uint256 totalAmount)` — **O(1) staking settlement** (fixed ~13k gas cost)
- `settleUnstakingBatch(uint256 batchId, uint256 totalAmount)` — **O(1) unstaking settlement** (fixed ~13k gas cost)
- `syncYield()` — Sync unaccounted yield from minter assets to user pool

**Claim Functions (ClaimModule):**
- `claimStakedShares(uint256 batchId, uint256 requestIndex)` — Claim yield-bearing shares
- `claimUnstakedAssets(uint256 batchId, uint256 requestIndex)` — Claim assets from unstaking

**Admin Functions (AdminModule):**
- `setPaused(bool isPaused)` — Emergency pause/unpause
- `setDustAmount(uint256 dustAmount)` — Set minimum transaction threshold
- `setSettlementInterval(uint256 interval)` — Set batch settlement interval

### kStrategyManager Functions (O(1) Settlement)
- `settleAndAllocate(stakingBatchId, unstakingBatchId, allocationOrder, signature)` — **O(1) settlement orchestration** with asset allocation
- `validateSettlement(vaultType, totalStrategyAssets, totalDeployedAssets, ...)` — **Vault-type specific settlement validation**
  - **VaultType.KMINTER:** Blocks negative settlements (institutional 1:1 guarantee)
  - **VaultType.KDNSTAKING/KSSTAKING:** Allows negative settlements (user risk bearing)
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

### Settlement Timing Consistency
- **Settlement Interval**: 8 hours across all contracts (kMinter, kDNStakingVault, kSStakingVault)
- **Batch Cutoff Time**: 4 hours for time-based batch creation
- **Coordination**: All settlement intervals aligned for consistent user experience
- **Backend Orchestration**: Centralized settlement timing ensures protocol-wide synchronization

## 💡 Direct Storage Access (Extsload)

The protocol implements Uniswap v4's Extsload pattern for efficient frontend data access:

```javascript
// Read single storage slot
const value = await contract.extsload(slot);

// Read multiple consecutive slots
const values = await contract.extsload(startSlot, count);

// Read arbitrary slots
const values = await contract.extsload([slot1, slot2, slot3]);
```

This enables:
- **Gas-efficient queries**: Direct storage reads without view function overhead
- **Flexible data access**: Frontend can read any storage configuration
- **Reduced contract size**: Removed 15+ view functions from kMinter

## 🧩 Modular Architecture

### ModuleBase Consolidation
The protocol uses a consolidated inheritance pattern where both the main contract and all modules inherit from a single `ModuleBase` contract:

```solidity
// Consolidated base contract
abstract contract ModuleBase is OwnableRoles, ReentrancyGuard {
    // All shared storage, roles, constants, and utilities
    struct kDNStakingVaultStorage { /* ... */ }
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    // ... other roles and helpers
}

// Main contract inherits from ModuleBase
contract kDNStakingVault is ModuleBase, UUPSUpgradeable, ERC20, MultiFacetProxy {
    // Core functions + module delegation
}

// All modules inherit from ModuleBase
contract AdminModule is ModuleBase {
    // Admin functions with access to same storage/roles
}
```

### Adding New Modules
To add a new module to the system:

1. **Create module inheriting from ModuleBase:**
```solidity
contract NewModule is ModuleBase {
    function newFunction() external onlyRoles(ADMIN_ROLE) whenNotPaused {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        // Access shared storage and implement logic
    }
    
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](1);
        moduleSelectors[0] = this.newFunction.selector;
        return moduleSelectors;
    }
}
```

2. **Deploy and register module:**
```solidity
// Deploy new module
NewModule newModule = new NewModule();

// Register functions (requires ADMIN_ROLE)
bytes4[] memory selectors = newModule.selectors();
vault.addFunctions(selectors, address(newModule), false);
```

3. **Module Benefits:**
- **Shared storage:** All modules access same storage via ERC-7201 pattern
- **Role consistency:** All modules use same role system from ModuleBase
- **Gas efficiency:** Direct storage access without proxy overhead
- **Upgradeability:** Modules can be upgraded independently
- **Size limits:** Bypass 24KB contract size limit through modularization

## 🛡️ Security & Risk Model

- **Reentrancy Protection:** Checks-effects-interactions pattern applied across all contracts
- **Dual Accounting Security:** Separate pools ensure minter 1:1 backing never affected by user yield
- **Risk-Segregated Settlement:** Vault-type specific validation ensures proper risk allocation
  - **kMinter:** Strict 1:1 guarantee - negative settlements blocked (institutional protection)
  - **kDN/kS Vaults:** Risk-bearing - negative settlements allowed (users bear strategy losses)
- **Loss Realization:** Automatic loss distribution through negative rebase and kToken burning
- **100% Loss Capability:** Vaults can handle complete strategy failures (vault → 0)
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
- **Modular Tests:** Module integration and storage consistency
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

## 📊 Current Status

- **Architecture:** ✅ Consolidated modular design with ModuleBase inheritance
- **Contract Sizes:** ✅ Optimized to ~20KB main contract + ~15KB modules
- **Storage Efficiency:** ✅ 11 storage slots (down from 13+)
- **Tests:** ✅ 247 passing tests including invariant tests
- **Modules:** ✅ AdminModule, SettlementModule, ClaimModule deployed
- **Dual Accounting:** ✅ 1:1 backing guaranteed for institutions
- **Yield Distribution:** ✅ Automatic yield flow with bounds checking
- **Gas Optimization:** ✅ O(1) settlement with 97-99% gas savings

---

**Built with ❤️ using Foundry, Solady, and Soldeer**