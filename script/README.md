# KAM Protocol Deployment Guide

Complete guide for deploying the KAM protocol using JSON configs, Makefile automation, and OpenZeppelin Defender security.

## 🚀 Quick Start

1. **Configure network**: Edit `config/mainnet.json`
2. **Deploy protocol**: `make deploy-mainnet`  
3. **Check addresses**: `cat output/mainnet/addresses.json`

## Prerequisites

1. **OpenZeppelin Defender Account** with configured approval process
2. **Foundry** installed and configured (`curl -L https://foundry.paradigm.xyz | bash`)
3. **RPC endpoints** configured in root `.env` file

## 🔒 Security Features

- **No private keys in configs** - All keys managed by Defender vault
- **Multi-signature approvals** - Required for all deployments
- **Bytecode verification** - Automatic verification of deployed contracts
- **Audit trail** - Complete deployment history via Defender
- **Auto address tracking** - JSON-based deployment address management

## 📁 File Structure

```
deployments/
├── config/           # Network configuration (input)
│   ├── mainnet.json  # Production config
│   ├── sepolia.json  # Testnet config
│   └── localhost.json # Local dev config
└── output/           # Deployment addresses (output)  
    ├── mainnet/
    │   └── addresses.json
    ├── sepolia/
    │   └── addresses.json
    └── localhost/
        └── addresses.json
```

## ⚙️ Configuration Format

**Input** (`config/{network}.json`):
```json
{
  "network": "mainnet",
  "chainId": 1,
  "roles": {
    "owner": "0x...",
    "admin": "0x...",
    "emergencyAdmin": "0x...",
    "guardian": "0x...",
    "relayer": "0x...",
    "institution": "0x...",
    "treasury": "0x..."
  },
  "assets": {
    "USDC": "0xA0b86a33E6d8c30c9b61aEB5eF6c5C756fA2A45F1",
    "WBTC": "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"
  },
  "defender": {
    "approvalProcessId": "your-approval-process-id"
  }
}
```

**Output** (`output/{network}/addresses.json`):
```json
{
  "chainId": 1,
  "network": "mainnet", 
  "timestamp": 1700000000,
  "contracts": {
    "kRegistry": "0x...",
    "kMinter": "0x...",
    "kAssetRouter": "0x...",
    "kUSD": "0x...",
    "kBTC": "0x...",
    "dnVault": "0x...",
    "alphaVault": "0x...",
    "betaVault": "0x..."
  }
}
```

## 🔧 Makefile Commands

- `make deploy-mainnet` - Full mainnet deployment
- `make deploy-sepolia` - Full testnet deployment  
- `make deploy-localhost` - Full local deployment
- `make deploy-core` - Deploy core contracts only (01-03)
- `make verify` - Verify deployment files exist

## 🔒 Security Features

- ✅ **No private keys in configs** - Uses DefenderScript security
- ✅ **Auto address tracking** - Addresses saved to JSON automatically
- ✅ **Dependency validation** - Scripts check previous deployments
- ✅ **Network detection** - Auto-detects chain from foundry context
- ✅ **Multi-sig required** - All deployments via Defender approval

## 🔄 Deployment Flow

1. **01-03**: Core contracts (Registry, Minter, AssetRouter)
2. **04**: Register singletons (admin calls via Defender)
3. **05**: Deploy kTokens (admin calls via Defender)
4. **06**: Deploy vault modules
5. **07**: Deploy vaults (DN, Alpha, Beta)
6. **08**: Register modules (admin calls via Defender)
7. **09**: Deploy adapters
8. **10**: Configure protocol (admin calls via Defender)

Scripts automatically read previous deployment addresses and validate dependencies.

## Manual Step-by-Step Deployment

If you prefer manual control over each step:

```bash
# Core contracts (automatically saves addresses to JSON)
forge script script/deployment/01_DeployRegistry.s.sol --rpc-url mainnet
forge script script/deployment/02_DeployMinter.s.sol --rpc-url mainnet
forge script script/deployment/03_DeployAssetRouter.s.sol --rpc-url mainnet

# Registry setup (requires admin calls via Defender UI)
forge script script/deployment/04_RegisterSingletons.s.sol --rpc-url mainnet

# Token deployment (requires admin calls via Defender UI)  
forge script script/deployment/05_DeployTokens.s.sol --rpc-url mainnet

# Vault system (automatically saves addresses to JSON)
forge script script/deployment/06_DeployVaultModules.s.sol --rpc-url mainnet
forge script script/deployment/07_DeployVaults.s.sol --rpc-url mainnet

# Module registration (requires admin calls via Defender UI)
forge script script/deployment/08_RegisterModules.s.sol --rpc-url mainnet

# Adapters and final config (requires admin calls via Defender UI)
forge script script/deployment/09_DeployAdapters.s.sol --rpc-url mainnet
forge script script/deployment/10_ConfigureProtocol.s.sol --rpc-url mainnet
```

## Post-Deployment Configuration

### Set Settlement Cooldown
```solidity
// Via Defender Admin UI:
kAssetRouter(addresses.kAssetRouter).setSettlementCooldown(0); // Testing
// OR
kAssetRouter(addresses.kAssetRouter).setSettlementCooldown(3600); // 1 hour production
```

### Create Initial Batches (Optional)
```solidity
// Via Defender Relayer UI:
bytes4 createBatchSelector = bytes4(keccak256("createNewBatch()"));
addresses.dnVault.call(abi.encodeWithSelector(createBatchSelector));
addresses.alphaVault.call(abi.encodeWithSelector(createBatchSelector));
addresses.betaVault.call(abi.encodeWithSelector(createBatchSelector));
```

## Verification

```bash
# Quick verification
make verify

# Manual verification - check addresses exist
cat output/mainnet/addresses.json | grep -v "0x0000000000000000000000000000000000000000"
```

## Troubleshooting

### Common Issues

1. **Config file not found**
   - Ensure `config/{network}.json` exists
   - Copy from template and update addresses

2. **Dependency errors**
   - Scripts validate previous deployments automatically
   - Run scripts in order (01-10) or use `make deploy-all`

3. **Defender approval process**
   - Check Defender UI for pending approvals
   - Ensure approval process ID is correct in config

4. **Address validation**
   - Config addresses cannot be zero address
   - Scripts validate all required addresses

### Features

- ✅ **Auto dependency checking** - Scripts validate previous deployments
- ✅ **Auto address tracking** - Deployed addresses saved to JSON
- ✅ **Network auto-detection** - Foundry chain ID determines network
- ✅ **Clean error messages** - Clear guidance when dependencies missing
- ✅ **Makefile automation** - Simple commands for complex deployments

## 💡 Usage Tips

- Scripts auto-detect network from foundry RPC settings
- Addresses are automatically written to JSON after each deployment
- Later scripts automatically read earlier deployment addresses
- Admin calls are shown in console - execute via Defender UI for security
- Use `make clean` to reset deployment files for fresh deployment

## Security Notes

- **No private keys in JSON configs** - Only addresses stored
- **DefenderScript security** - All deployments via Defender approval
- **Bytecode verification** - Automatic via Defender integration
- **Multi-sig enforcement** - Admin calls require Defender UI execution
- **Complete audit trail** - JSON deployment records maintained