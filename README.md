# KAM Protocol

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

## Key Features

### 🔄 Dual User Model
- **Institutions**: Mint/redeem kTokens with guaranteed 1:1 asset backing
- **Retail Users**: Stake kTokens for yield-bearing stkTokens that appreciate with strategy performance

### 🎯 Centralized Asset Management
- **kAssetRouter**: Central hub managing all asset flows with virtual balance tracking
- **Yield Strategies**: Deploy assets to external custodial and DeFi strategies for yield generation
- **1:1 Guarantee**: Strict backing maintenance for institutional users while enabling yield for retail

### ⏱ Batch Settlement System
- **Time-Based Batches**: 4-hour cutoff, 8-hour settlement intervals
- **Gas Optimization**: Batch multiple operations for reduced per-user costs
- **MEV Protection**: Request/claim pattern prevents frontrunning

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
│                 │    │                 │    │                 │
│ • Mint kTokens  │    │ • Issue stkTkns │    │ • Manage flows  │
│ • Batch redeem  │    │ • Modular arch  │    │ • Virt balances │
│ • 1:1 guarantee │    │ • Yield receipt │    │ • Yield distrib │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────────┐
                    │     kBatch      │
                    │                 │
                    │ • Time batches  │
                    │ • Deploy rcvrs  │
                    │ • Track status  │
                    └─────────────────┘
```

### Core Contracts

| Contract | Purpose | Key Features |
|----------|---------|-------------|
| **kToken** | ERC20 token with role-based access | UUPS upgradeable, 1:1 backing, emergency pause |
| **kMinter** | Institutional interface | Direct mint/redeem, batch settlement, 1:1 guarantee |
| **kAssetRouter** | Central asset coordinator | Virtual balances, yield distribution, peg protection |
| **kStakingVault** | Retail staking vault | Request/claim pattern, modular architecture, yield receipt |
| **kBatch** | Batch management | Time-based processing, kBatchReceiver deployment |
| **kBatchReceiver** | Redemption distribution | Per-batch asset distribution to users |

## Quick Start

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd KAM

# Install dependencies
soldeer install

# Build contracts
forge build

# Run tests
forge test
```

### Basic Usage

#### For Institutions

```solidity
// Mint kTokens (1:1 with USDC)
kMinterTypes.Request memory mintRequest = kMinterTypes.Request({
    asset: USDC_ADDRESS,
    amount: 1000000, // 1 USDC (6 decimals)
    to: msg.sender
});
kMinter.mint(mintRequest);

// Request redemption
kMinterTypes.Request memory redeemRequest = kMinterTypes.Request({
    asset: USDC_ADDRESS,
    amount: 1000000, // 1 kUSD
    to: msg.sender
});
bytes32 requestId = kMinter.requestRedeem(redeemRequest);

// Claim after batch settlement
kMinter.redeem(requestId);
```

#### For Retail Users

```solidity
// Stake kTokens for yield
uint256 requestId = kStakingVault.requestStake(
    msg.sender,     // recipient
    1000000,        // 1 kUSD to stake
    950000          // minimum 0.95 stkTokens (slippage protection)
);

// Claim stkTokens after settlement
claimModule.claimStakedShares(batchId, requestId);

// Unstake for kTokens + yield
uint256 unstakeId = kStakingVault.requestUnstake(
    msg.sender,     // recipient  
    1000000,        // 1 stkToken
    1000000         // minimum 1 kUSD expected (yield protection)
);

// Claim kTokens + yield after settlement
claimModule.claimUnstakedAssets(batchId, unstakeId);
```

## User Flows

### Institutional Flow

1. **Minting**: Institution deposits USDC → receives kUSD 1:1 → assets available for yield strategies
2. **Redemption Request**: Institution burns kUSD → request added to batch → kBatchReceiver deployed
3. **Settlement**: SETTLER processes batch → assets transferred to kBatchReceiver
4. **Claim**: Institution claims USDC from kBatchReceiver

### Retail Flow

1. **Staking Request**: User deposits kUSD → request added to batch → virtual balance transfer
2. **Settlement**: SETTLER processes batch → stkTokens calculated and available for claim
3. **Yield Accumulation**: stkTokens appreciate as strategies generate yield
4. **Unstaking**: User requests unstaking → share value calculated → kTokens + yield claimable

## Security

### Access Control
- **Owner**: Ultimate admin control, contract upgrades
- **Admin**: Day-to-day operations, role management
- **Emergency Admin**: Emergency pause capabilities
- **Minter**: kToken minting/burning (kMinter, vaults)
- **Settler**: Batch settlement authorization

### Safety Mechanisms
- **Emergency Pause**: All contracts can be paused in emergencies
- **Slippage Protection**: Users specify minimum outputs
- **Request/Claim Pattern**: Prevents frontrunning and MEV
- **1:1 Backing**: Institutional users guaranteed asset backing
- **Role-Based Security**: Granular permissions for all operations

### Audit Status
- ⚠️ **Not yet audited** - Use at your own risk
- 🧪 **Testnet only** - Not recommended for mainnet deployment without audit

## Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run coverage
forge coverage

# Run specific test file
forge test --match-path test/unit/kMinter.t.sol

# Run invariant tests
forge test --match-path test/invariant/
```

## Deployment

### Local Testing

```bash
# Start local node
anvil

# Deploy to local
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

```bash
# Deploy to testnet (example: Sepolia)
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --account myKeystoreName
```

### Multi-Asset Deployment

For each asset pair (USDC/WBTC):

1. Deploy kToken contract (kUSD/kBTC)
2. Deploy kMinter contract per asset
3. Deploy shared kAssetRouter (coordinates all assets)
4. Deploy shared kBatch (handles all batch operations)
5. Deploy kStakingVault (can handle multiple assets)
6. Configure roles and permissions
7. Deploy and register vault modules

## Gas Optimization

The protocol is highly optimized for gas efficiency:

- **Solady Libraries**: Battle-tested, gas-optimized utilities
- **Batch Processing**: Amortize costs across multiple users
- **Virtual Balances**: Minimize actual token transfers
- **Struct Packing**: Optimized storage layouts
- **Transient Storage**: Cheaper reentrancy protection
- **Modular Architecture**: Pay only for functions used

## Technical Specifications

### Batch Timing
- **Batch Cutoff**: 4 hours from batch creation
- **Settlement Interval**: 8 hours from batch creation
- **New Batch Creation**: Automatic when cutoff reached

### Token Standards
- **kTokens**: Full ERC20 compliance with additional role-based functions
- **stkTokens**: Full ERC20 compliance with rebase-like yield appreciation
- **Upgradeable**: UUPS proxy pattern for all main contracts

### Gas Costs (Estimates)
- **Institutional Mint**: ~80,000 gas
- **Institutional Redeem Request**: ~60,000 gas
- **Retail Stake Request**: ~90,000 gas
- **Retail Unstake Request**: ~70,000 gas
- **Batch Settlement**: ~150,000 gas + ~20,000 per request
- **Asset Claims**: ~40,000 gas

## Development Guidelines

### When Working with the Codebase

1. **Role Requirements**: Most functions are role-gated - check access controls
2. **1:1 Backing**: Always maintain invariant for institutional users
3. **Virtual Balances**: Update kAssetRouter virtual balances for vault operations
4. **Batch Integration**: New operations should integrate with batch settlement system
5. **Gas Efficiency**: Use Solady utilities and optimize for gas
6. **Modular Pattern**: Keep vault functions in appropriate modules
7. **Events**: Emit events for all state changes
8. **Testing**: Add unit tests and integration tests for new features

### Security Checklist
- [ ] All functions have appropriate role checks
- [ ] State changes emit events
- [ ] Input validation (zero addresses, amounts)
- [ ] Slippage protection for user operations
- [ ] Reentrancy protection on external calls
- [ ] Integer overflow/underflow protection
- [ ] 1:1 backing invariant maintained

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following the development guidelines
4. Add tests for new functionality
5. Ensure all tests pass (`forge test`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## Current Status

### ✅ Completed Features
- Core architecture with modular design
- Institutional minting/redemption flows
- Retail staking/unstaking flows
- Batch settlement system
- Virtual balance management
- Role-based security model
- Gas-optimized implementation

### 🔄 In Development
- External strategy integration
- Yield optimization
- Advanced monitoring

### 📋 Roadmap
- Cross-chain deployment
- Governance mechanisms
- Third-party integrations
- Mobile interfaces

## License

This project is licensed under the UNLICENSED License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This software is provided as-is without any guarantees or warranty. The authors are not responsible for any damages or losses that may arise from the use of this software. Use at your own risk.

**⚠️ IMPORTANT**: This protocol has not been audited. Do not use with real funds on mainnet without proper security review.

## Support

For questions, issues, or contributions:

- 🐛 **Issues**: [GitHub Issues](../../issues)
- 💬 **Discussions**: [GitHub Discussions](../../discussions)
- 📖 **Documentation**: See [CLAUDE.md](./CLAUDE.md) for detailed technical documentation

## Acknowledgments

Built with:
- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit
- [Solady](https://github.com/Vectorized/solady) - Gas-optimized Solidity utilities
- [OpenZeppelin](https://openzeppelin.com/) - Security patterns and standards