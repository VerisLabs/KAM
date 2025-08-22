# KAM Protocol Audit

The KAM protocol is an institutional asset management system that implements a dual-track architecture for both institutional and retail access. The protocol features batch processing with virtual balance accounting, a two-phase settlement with timelock proposals, and a modular vault architecture implemented through a diamond pattern.

The core system enables institutions to mint kTokens 1:1 with underlying assets, stake them in yield-generating vaults, and redeem through batch settlement mechanisms. The protocol implements explicit security patterns, including role-based access control, CREATE2 deterministic deployment, and comprehensive validation layers.

## Audit Scope

The scope of audit involves the complete KAM protocol implementation in `src/`:

```
├── src
│   ├── adapters/
│   │   ├── BaseAdapter.sol
│   │   └── CustodialAdapter.sol
│   ├── base/
│   │   └── kBase.sol
│   ├── interfaces/
│   │   ├── IAdapter.sol
│   │   ├── IkAssetRouter.sol
│   │   ├── IkBatchReceiver.sol
│   │   ├── IkMinter.sol
│   │   ├── IkRegistry.sol
│   │   ├── IkStakingVault.sol
│   │   └── IkToken.sol
│   ├── kAssetRouter.sol
│   ├── kBatchReceiver.sol
│   ├── kMinter.sol
│   ├── kRegistry.sol
│   ├── kStakingVault/
│   │   ├── base/
│   │   │   └── BaseVaultModule.sol
│   │   ├── kStakingVault.sol
│   │   ├── modules/
│   │   │   ├── BatchModule.sol
│   │   │   ├── ClaimModule.sol
│   │   │   └── FeesModule.sol
│   │   └── types/
│   │       └── BaseVaultModuleTypes.sol
│   └── kToken.sol
```

Out of scope: `Extsload.sol`, `MultiFacetProxy.sol`, `Proxy.sol`, and external dependencies.

## Core Protocol Components

**kMinter** - Institutional gateway implementing push-pull minting model. Accepts underlying asset deposits to mint kTokens 1:1, manages redemption requests through batch settlement, and coordinates with kAssetRouter for asset flow.

**kAssetRouter** - Central coordination hub managing virtual balance accounting between vaults and external strategies. Implements two-phase settlement with timelock proposals, handles adapter integrations with explicit approval patterns, and coordinates batch processing flows.

**kRegistry** - Protocol registry managing singleton contracts, asset support, vault registration, and adapter coordination. Maintains bidirectional asset-kToken mappings and enforces protocol-wide access control.

**kStakingVault** - ERC20 vault with dual accounting implementing automatic yield distribution. Features modular architecture through diamond pattern, batch request processing, and CREATE2 deterministic deployment of batch receivers.

**kBatchReceiver** - Minimal proxy contracts deployed per batch for isolated asset distribution. Implements one-time initialization and secure asset distribution with batch ID validation.

**kToken** - ERC20 token representing wrapped underlying assets with institutional-only minting restrictions.

## Notable Protocol Features

**Virtual Balance Accounting** - Assets are tracked through virtual balances rather than direct token holdings, enabling efficient batch processing and settlement coordination without constant token transfers.

**Two-Phase Settlement** - Settlement proposals implement timelock mechanisms with merkle proof verification, allowing for correction of incorrect parameters through cancellation and update functions.

**Batch Processing Architecture** - Requests are grouped into batches for gas-efficient settlement, with deterministic batch receiver deployment and isolated asset distribution.

**Explicit Approval Pattern** - Adapters receive temporary approvals only during settlement execution, immediately revoked afterward for security.

**Role-Based Access Control** - Comprehensive role system including Owner, Admin, Emergency Admin, Institution, Factory, Relayer, and Guardian roles with specific permissions.

**Modular Vault System** - Vaults implement diamond pattern with separate modules for batch processing, claim management, and fee collection.

## Known Caveats

**Settlement Proposal Timelock** - Proposals require timelock delays before execution, potentially causing delays in asset settlement if parameters need correction. The protocol addresses this through proposal cancellation and update mechanisms.

**Virtual Balance Synchronization** - Virtual balances must remain synchronized with actual adapter holdings. Discrepancies could arise from direct adapter interactions or external protocol changes affecting adapter behavior.

**Batch Settlement Dependencies** - Redemption completion depends on successful batch settlement and adapter cooperation. Failed adapter operations could block entire batch processing.

**CREATE2 Salt Mining** - Batch receiver deployment relies on CREATE2 with specific salt requirements. Registry parameter changes between salt discovery and deployment could invalidate prepared salts.

**Adapter Integration Complexity** - Each adapter integration requires careful validation of redemption patterns, asset tracking accuracy, and emergency handling procedures. Different DeFi protocols may have varying settlement timeframes and failure modes.
