# KAM Protocol Audit

The KAM protocol is an institutional asset management system that implements a dual-track architecture for both institutional and retail access. The protocol features batch processing with virtual balance accounting, a two-phase settlement with timelock proposals, and a modular vault architecture implemented through a diamond pattern.

The core system enables institutions to mint kTokens 1:1 with underlying assets, stake them in yield-generating vaults, and redeem through batch settlement mechanisms. The protocol implements explicit security patterns, including role-based access control, CREATE2 deterministic deployment, and comprehensive validation layers.

## Audit Scope

The scope of audit involves the complete KAM protocol implementation in `src/`:

```
├── src
│   ├── abstracts/
│   │   ├── Extsload.sol              [NOT IN SCOPE - Storage optimization]
│   │   └── Proxy.sol                 [NOT IN SCOPE - Proxy implementation]
│   ├── adapters/
│   │   ├── BaseAdapter.sol
│   │   └── CustodialAdapter.sol
│   ├── base/
│   │   ├── MultiFacetProxy.sol       [NOT IN SCOPE - Diamond proxy base]
│   │   └── kBase.sol
│   ├── interfaces/
│   │   ├── IAdapter.sol
│   │   ├── IExtsload.sol
│   │   ├── IkAssetRouter.sol
│   │   ├── IkBatchReceiver.sol
│   │   ├── IkMinter.sol
│   │   ├── IkRegistry.sol
│   │   ├── IkStakingVault.sol
│   │   ├── IkToken.sol
│   │   └── modules/
│   │       ├── IVaultBatch.sol
│   │       ├── IVaultClaim.sol
│   │       └── IVaultFees.sol
│   ├── kAssetRouter.sol
│   ├── kBatchReceiver.sol
│   ├── kMinter.sol
│   ├── kRegistry.sol
│   ├── kStakingVault/
│   │   ├── base/
│   │   │   └── BaseVault.sol
│   │   ├── kStakingVault.sol
│   │   ├── modules/
│   │   │   ├── VaultBatches.sol
│   │   │   ├── VaultClaims.sol
│   │   │   └── VaultFees.sol
│   │   └── types/
│   │       └── BaseVaultTypes.sol
│   └── kToken.sol
```

**Out of scope**: External dependencies (Solady, OpenZeppelin), test contracts, and deployment scripts.

## Core Protocol Components

**kMinter** - Institutional gateway implementing push-pull minting model. Accepts underlying asset deposits to mint kTokens 1:1, manages redemption requests through batch settlement, and coordinates with kAssetRouter for asset flow.

**kAssetRouter** - Central coordination hub managing virtual balance accounting between vaults and external strategies. Implements two-phase settlement with timelock proposals, handles adapter integrations with explicit approval patterns, and coordinates batch processing flows.

**kRegistry** - Protocol registry managing singleton contracts, asset support, vault registration, and adapter coordination. Maintains bidirectional asset-kToken mappings and enforces protocol-wide access control.

**kStakingVault** - ERC20 vault with dual accounting implementing automatic yield distribution. Features modular architecture through diamond pattern, batch request processing, and CREATE2 deterministic deployment of batch receivers.

**kBatchReceiver** - Minimal proxy contracts deployed per batch for isolated asset distribution. Implements one-time initialization and secure asset distribution with batch ID validation.

**kToken** - ERC20 token representing wrapped underlying assets with institutional-only minting restrictions.

## Notable Protocol Features

**Virtual Balance Accounting** - Assets are tracked through virtual balances rather than direct token holdings, enabling efficient batch processing and settlement coordination without constant token transfers.

**Two-Phase Settlement** - Settlement proposals implement timelock mechanisms allowing for correction of incorrect parameters through cancellation before execution. Proposals include cooldown periods (1 hour to 1 day) before execution is permitted.

**Batch Processing Architecture** - Requests are grouped into batches for gas-efficient settlement, with deterministic batch receiver deployment and isolated asset distribution.

**Explicit Approval Pattern** - Adapters receive temporary approvals only during settlement execution, immediately revoked afterward for security.

**Role-Based Access Control** - Comprehensive role system implemented through Solady's OwnableRoles including:
- Owner: Protocol ownership and ultimate control
- Admin: Administrative functions and upgrades  
- Emergency Admin: Pause functionality and emergency operations
- Institution: Minting and redemption permissions
- Vendor: Asset management and adapter permissions
- Relayer: Settlement proposal creation
- Guardian: Settlement proposal cancellation

**Modular Vault System** - Vaults implement diamond pattern with separate modules for batch processing, claim management, and fee collection.

## Technical Architecture

**ERC-7201 Storage Patterns** - All contracts implement namespaced storage using ERC-7201 to prevent storage collisions during upgrades. Each contract defines unique storage locations with keccak256-derived slots.

**UUPS Upgradeability** - Core contracts (`kMinter`, `kAssetRouter`, `kRegistry`, `kStakingVault`) implement UUPS (Universal Upgradeable Proxy Standard) through Solady's UUPSUpgradeable, enabling controlled protocol upgrades with admin authorization.

**Solady Dependencies** - Protocol extensively uses Solady library for gas optimization and security:
- `SafeTransferLib` for secure token transfers
- `ReentrancyGuardTransient` for gas-efficient reentrancy protection  
- `FixedPointMathLib` for precision arithmetic
- `EnumerableSetLib` for efficient set operations
- `OwnableRoles` for role-based access control

**Extsload Pattern** - `kMinter` implements Extsload for storage reading optimization, allowing efficient cross-contract storage access without additional SLOAD operations.

**Transient Reentrancy Protection** - All state-changing functions use transient reentrancy guards that leverage Solidity 0.8.30's transient storage (TSTORE/TLOAD) for gas-efficient protection.

## Known Caveats

**Settlement Proposal Timelock** - Proposals require timelock delays before execution, potentially causing delays in asset settlement if parameters need correction. The protocol addresses this through proposal cancellation mechanisms.

**Virtual Balance Synchronization** - Virtual balances must remain synchronized with actual adapter holdings. Discrepancies could arise from direct adapter interactions or external protocol changes affecting adapter behavior.

**Batch Settlement Dependencies** - Redemption completion depends on successful batch settlement and adapter cooperation. Failed adapter operations could block entire batch processing.

**CREATE2 Salt Mining** - Batch receiver deployment relies on CREATE2 with specific salt requirements. Registry parameter changes between salt discovery and deployment could invalidate prepared salts.

**ERC-7201 Storage Collision Risks** - While ERC-7201 prevents most storage collisions, incorrect namespace calculations or implementation errors could lead to storage overwrites during upgrades.

**Diamond Pattern Security** - The modular vault architecture using MultiFacetProxy requires careful validation of function selector conflicts and delegation call security. Malicious or incorrectly implemented modules could compromise the entire vault.

**Transient Storage Dependencies** - The protocol's reliance on Solidity 0.8.30's transient storage for reentrancy protection creates a hard dependency on specific compiler behavior and EVM implementations that support TSTORE/TLOAD.

**UUPS Upgrade Authorization** - Upgrade mechanisms depend on proper access control validation. Compromise of admin keys or authorization bypass could allow malicious upgrades across multiple protocol contracts.

**Adapter Integration Complexity** - Each adapter integration requires careful validation of redemption patterns, asset tracking accuracy, and emergency handling procedures. Different DeFi protocols may have varying settlement timeframes and failure modes.

**Virtual Balance Attack Vectors** - Virtual balance accounting creates potential attack vectors where discrepancies between recorded and actual balances could be exploited to drain funds or prevent legitimate withdrawals.
