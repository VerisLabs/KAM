# KAM Protocol Technical Manual

An institutional-grade tokenization protocol that creates kTokens (kUSD, kBTC) backed 1:1 by real assets (USDC, WBTC), providing institutional access with guaranteed backing and retail yield opportunities through external strategy deployment.

[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.30-blue)](https://docs.soliditylang.org/)
[![License](https://img.shields.io/badge/License-UNLICENSED-red.svg)]()

## Overview

The KAM Protocol bridges traditional finance and DeFi by offering:

- 🏦 **Institutional Access**: Direct minting/redemption with guaranteed 1:1 backing
- 💰 **Retail Yield**: Stake kTokens to earn yield from external strategies
- ⚡ **Efficient Settlement**: Time-based batch processing for optimal gas usage
- 🔒 **Security First**: Comprehensive role-based access control and emergency safeguards
- 📈 **Multi-Asset**: Support for multiple underlying assets (USDC/WBTC)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Institutions  │    │  Retail Users   │    │   Settlers      │
│                 │    │                 │    │                 │
│ mint/redeem     │    │ stake/unstake   │    │ settle batches  │
│ kTokens 1:1     │    │ for stkTokens   │    │ distribute yield│
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          ▼                      ▼                      ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    kMinter      │    │ kStakingVault   │    │   kAssetRouter  │
│                 │    │   (Per Asset)   │    │                 │
│ • Mint kTokens  │    │ • Issue stkTkns │    │ • Manage flows  │
│ • Batch redeem  │    │ • Per-vault btch│    │ • Virt balances │
│ • 1:1 guarantee │    │ • Modular arch  │    │ • Yield distrib │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                         ┌───────┴───────┐
                         │   kRegistry   │
                         │               │
                         │ • Addresses   │
                         │ • Mappings    │
                         │ • Permissions │
                         └───────────────┘
```

### Per-Vault Batch Architecture

Each kStakingVault manages its own batch lifecycle:
- Batch creation, closing, and settlement handled by vault's BatchModule
- kBatchReceiver contracts deployed per batch for redemption distribution
- No centralized batch coordinator - each vault is independent

## Project Structure

### Core Contracts

#### `src/kToken.sol`
ERC20 token implementation representing 1:1 backed assets (kUSD, kBTC).
- **Pattern**: UUPS upgradeable with role-based access control
- **Key Features**: Mintable/burnable by authorized roles, emergency pause capability
- **Roles Required**: MINTER_ROLE for mint/burn operations
- **Storage**: Uses ERC-7201 pattern for upgrade safety

#### `src/kMinter.sol`
Institutional interface for minting kTokens and managing redemptions.
- **Pattern**: UUPS upgradeable with batch request system
- **Key State Variables**:
  - `requestCounter`: Incremental counter for unique request IDs
  - `redeemRequests`: Mapping of redemption requests by ID
  - `userRequests`: User address to request IDs mapping
- **Roles Required**: INSTITUTION_ROLE for all operations
- **Integration**: Pushes assets to kAssetRouter, receives from kBatchReceiver

#### `src/kAssetRouter.sol`
Central coordinator managing virtual balances and asset flows between all vaults.
- **Pattern**: Hub-and-spoke architecture with virtual accounting
- **Key State Variables**:
  - `vaultBalances`: Virtual balance tracking per vault per asset
  - `vaultBatchBalances`: Pending deposits/redemptions per batch
  - `vaultRequestedShares`: Share redemption requests per batch
- **Roles Required**: RELAYER_ROLE for settlement operations
- **Integration**: Central point for all asset movements

#### `src/kRegistry.sol`
Central registry storing contract addresses and system configuration.
- **Pattern**: Singleton registry with role-based updates
- **Key Mappings**:
  - Contract identifier → address (e.g., "K_MINTER" → 0x...)
  - Asset → kToken (e.g., USDC → kUSD)
  - Asset → vaults array
  - Asset → primary vault designation
- **Roles Required**: ADMIN_ROLE for registry updates

#### `src/kBatchReceiver.sol`
Minimal proxy contracts deployed per batch for redemption distribution.
- **Pattern**: Immutable contract with single-purpose design
- **Constructor Parameters**: kMinter address, batch ID, asset addresses
- **Key Function**: `pullAssets()` - transfers assets to redeemers
- **Security**: Only callable by authorized kMinter

### Staking Vault System

#### `src/kStakingVault/kStakingVault.sol`
Main vault contract implementing ERC20 stkTokens with modular proxy pattern.
- **Pattern**: MultiFacetProxy routing to function modules
- **Inheritance**: ERC20 + BaseModule + MultiFacetProxy
- **Key Features**:
  - Issues stkTokens that appreciate with yield
  - Request/claim pattern for all operations
  - Per-vault batch management
- **Module Integration**: Delegates calls to specialized modules

#### Vault Modules (`src/kStakingVault/modules/`)

##### `BaseModule.sol`
Shared base contract providing common functionality for all modules.
- **Storage**: Defines BaseModuleStorage struct (ERC-7201 pattern)
- **Common Features**:
  - Registry access helpers
  - Math utilities for share calculations
  - Role modifiers (onlyKAssetRouter, onlyRelayer)
  - Pause functionality

##### `BatchModule.sol`
Manages the batch lifecycle for the vault.
- **Key Functions**:
  - `createNewBatch()`: Initiates new batch cycle
  - `closeBatch()`: Prevents new requests
  - `settleBatch()`: Marks batch as settled
  - `deployBatchReceiver()`: Creates receiver contract
- **Roles Required**: RELAYER_ROLE for batch operations

##### `ClaimModule.sol`
Handles user claims after batch settlement.
- **Key Functions**:
  - `claimStakedShares()`: Claims stkTokens from staking
  - `claimUnstakedAssets()`: Claims kTokens from unstaking
- **Features**: Slippage protection, request validation
- **Integration**: Reads settled batch data, transfers tokens

##### `MultiFacetProxy.sol`
Diamond-like proxy routing calls to appropriate modules.
- **Pattern**: Stores function selector → module address mapping
- **Key Functions**:
  - `registerModule()`: Maps selectors to module addresses
  - `unregisterModule()`: Removes module mappings
- **Fallback**: Routes unknown functions to registered modules

### Type Definitions

#### `src/types/kMinterTypes.sol`
```solidity
struct RedeemRequest {
    bytes32 id;
    address user;
    uint96 amount;
    address asset;
    uint64 requestTimestamp;
    uint8 status;
    uint24 batchId;
    address recipient;
}

enum RequestStatus {
    PENDING,
    REDEEMED,
    CANCELLED
}
```

#### `src/types/kAssetRouterTypes.sol`
```solidity
struct Balances {
    uint128 deposited;
    uint128 requested;
}
```

#### `src/kStakingVault/types/BaseModuleTypes.sol`
```solidity
struct StakeRequest {
    uint256 id;
    address user;
    uint96 kTokenAmount;
    address recipient;
    uint64 requestTimestamp;
    uint8 status;
    uint96 minStkTokens;
    uint32 batchId;
}

struct UnstakeRequest {
    uint256 id;
    address user;
    uint96 stkTokenAmount;
    address recipient;
    uint64 requestTimestamp;
    uint8 status;
    uint96 minKTokens;
    uint32 batchId;
}

struct BatchInfo {
    uint32 batchId;
    address batchReceiver;
    bool isClosed;
    bool isSettled;
}
```

### Base Contracts

#### `src/base/kBase.sol`
Base contract providing common functionality across protocol contracts.
- **Features**:
  - Registry integration
  - Role management (owner, admin, emergency admin)
  - Pause functionality
  - Reentrancy protection
- **Storage**: BaseStorage struct with registry, paused state

### Abstract Contracts

#### `src/abstracts/Extsload.sol`
Implementation allowing external contracts to read storage slots.
- **Use Case**: Off-chain integrations needing storage access
- **Security**: Read-only operations

#### `src/abstracts/Proxy.sol`
Basic proxy implementation for delegation.
- **Pattern**: Transparent proxy with delegatecall

### Interfaces

All interfaces in `src/interfaces/` define the external functions for each contract, enabling type-safe interactions between components.

## Technical Architecture

### Storage Architecture

All upgradeable contracts use the ERC-7201 storage pattern:

```solidity
// Example from kMinter
bytes32 private constant KMINTER_STORAGE_LOCATION = 
    0xd0574379115d2b8497bfd9020aa9e0becaffc59e5509520aa5fe8c763e40d000;

function _getkMinterStorage() private pure returns (kMinterStorage storage $) {
    assembly {
        $.slot := KMINTER_STORAGE_LOCATION
    }
}
```

### Virtual Balance System

The kAssetRouter maintains virtual balances to optimize gas:
- Physical transfers minimized to settlement operations
- All inter-vault transfers are virtual until settlement
- Atomic balance updates prevent race conditions

### Modular Vault Pattern

kStakingVault uses a sophisticated module system:
1. Main contract inherits MultiFacetProxy
2. Function selectors mapped to module addresses
3. Fallback function delegates to appropriate module
4. Modules share storage via BaseModule inheritance

### Batch Processing Flow

1. **Request Phase**: Users submit stake/unstake requests
2. **Cutoff**: Batch closed after predetermined time (4 hours)
3. **Settlement**: Relayer settles batch with current totalAssets
4. **Claim Phase**: Users claim their tokens

### Role Hierarchy

| Role | Permissions | Contracts |
|------|------------|-----------|
| OWNER | Ultimate control, upgrades | All |
| ADMIN_ROLE | Operational management | All |
| EMERGENCY_ADMIN_ROLE | Emergency pause | All |
| MINTER_ROLE | Mint/burn tokens | kToken |
| INSTITUTION_ROLE | Mint/redeem kTokens | kMinter |
| RELAYER_ROLE | Settle batches | kAssetRouter, BatchModule |
| SETTLER_ROLE | Legacy role (deprecated) | - |

## Integration Guide

### Deployment Order

1. Deploy kRegistry
2. Deploy kAssetRouter with registry address
3. Deploy kToken contracts (kUSD, kBTC)
4. Deploy kMinter
5. Deploy vault modules (Base, Batch, Claim)
6. Deploy kStakingVault per asset
7. Register modules with vaults
8. Configure registry mappings
9. Set up role permissions

### Initial Configuration

```solidity
// 1. Register core contracts
registry.setContract("K_ASSET_ROUTER", kAssetRouterAddress);
registry.setContract("K_MINTER", kMinterAddress);

// 2. Set asset mappings
registry.setKTokenForAsset(USDC, kUSD);
registry.addVault(USDC, kStakingVaultUSDC);

// 3. Configure roles
kToken.grantRole(MINTER_ROLE, kMinterAddress);
kToken.grantRole(MINTER_ROLE, kStakingVaultAddress);

// 4. Register vault modules
vault.registerModule(batchModuleAddress);
vault.registerModule(claimModuleAddress);
```

## Usage Reference

### Institutional Operations

```solidity
// Mint kTokens
kMinter.mint(
    address asset,     // USDC address
    address to,        // Recipient
    uint256 amount    // Amount to mint (1:1)
);

// Request redemption
bytes32 requestId = kMinter.requestRedeem(
    address asset,     // USDC address
    address to,        // Recipient
    uint256 amount    // kTokens to redeem
);

// Claim after settlement
kMinter.redeem(requestId);

// Cancel before settlement
kMinter.cancelRequest(requestId);
```

### Retail Operations

```solidity
// Stake kTokens
uint256 requestId = kStakingVault.requestStake(
    address to,           // Recipient of stkTokens
    uint96 kTokensAmount, // Amount to stake
    uint96 minStkTokens   // Slippage protection
);

// Claim stkTokens after settlement
claimModule.claimStakedShares(batchId, requestId);

// Unstake stkTokens
uint256 unstakeId = kStakingVault.requestUnstake(
    address to,              // Recipient of kTokens
    uint96 stkTokenAmount,   // Amount to unstake
    uint96 minKTokens        // Slippage protection
);

// Claim kTokens after settlement
claimModule.claimUnstakedAssets(batchId, unstakeId);
```

### Relayer Operations

```solidity
// Create new batch
uint256 batchId = batchModule.createNewBatch();

// Close batch at cutoff time
batchModule.closeBatch(batchId, _create); // if create a new batch on close.

// Settle batch with total assets
kAssetRouter.settleBatch(
  address vault,
  uint256 batchId,
  uint256 totalAssets,
  uint256 yield,
  uint256 netted,
  bool profit
);
```

## Security Considerations

### Access Control
- All sensitive operations are role-gated
- Multi-signature recommended for admin roles
- Emergency pause available on all contracts

### Invariants
- kToken supply always equals total backing assets
- Virtual balances match physical assets at settlement
- Batch operations are atomic

### Slippage Protection
- Users specify minimum output amounts
- Claims validate against settlement values
- No MEV exposure due to request/claim pattern

## Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/unit/kMinter.t.sol

# Run coverage
forge coverage
```

## License

This project is licensed under the UNLICENSED License.


**⚠️ IMPORTANT**: This protocol has not been audited. Do not use with real funds on mainnet without proper security review.