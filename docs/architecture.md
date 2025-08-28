# KAM Protocol Architecture

## Overview

KAM is an institutional-grade tokenization protocol that creates kTokens (kUSD, kBTC, etc.) backed 1:1 by real-world assets (USDC, WBTC, etc.). The protocol bridges traditional finance and DeFi by serving two distinct user bases through separate but interconnected pathways.

**Institutional Access**: Institutions interact directly with the kMinter contract to mint and redeem kTokens with guaranteed 1:1 backing. This provides instant liquidity for large operations without slippage or MEV concerns. Institutions deposit underlying assets and receive kTokens immediately, or request redemptions that are processed through batch settlement.

**Retail Yield Generation**: Retail users stake their kTokens in kStakingVault contracts to earn yield from external strategy deployments. When users stake kTokens, they receive stkTokens (staking tokens) that accrue yield over time as the protocol deploys capital to external strategies like CEX lending, institutional custody, or other DeFi protocols.

### System Architecture

```
┌─────────────────┐    ┌─────────────────┐      ┌─────────────────┐
│   Institutions  │    │  Retail Users   │      │    Relayers     │
│                 │    │                 │      │                 │
│ • Direct mint   │    │ • Stake kTokens │      │ • Propose       │
│ • 1:1 backing   │    │ • Earn yield    │      │ • Settle        │
│ • Batch redeem  │    │ • Claim rewards │      │ • Coordinate    │
└────────┬────────┘    └────────┬────────┘      └────────┬────────┘
         │                      │                        │
         ▼                      ▼                        ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Contract Layer                           │
├─────────────────┬───────────────--──┬───────────────────────────┤
│    kMinter      │  kStakingVault    │      kAssetRouter         │
│                 │                   │                           │
│ • Mint kTokens  │ • Issue stkTkns   │ • Virtual accounting      │
│ • Queue redeem  │ • Batch requests  │ • Settlement coordination │
│ • Escrow tokens │ • Module system   │ • Adapter management      │
└─────────────────┴─────────────────--┴───────────────────────────┘
                               │
                     ┌─────────┴─────────┐
                     │   Infrastructure  │
                     ├───────────────────┤
                     │    kRegistry      │ → Contract mappings
                     │    kToken         │ → ERC20 implementation
                     │    kBatchReceiver │ → Redemption distribution
                     │    Adapters       │ → External strategies
                     └───────────────────┘
```

### Virtual Balance Accounting

Each kToken instance maintains strict peg enforcement through a sophisticated virtual accounting system managed by the kAssetRouter. This system tracks asset flows without requiring immediate physical settlement, creating several key advantages:

**Capital Efficiency**: Assets can be productively deployed to yield-generating strategies while maintaining instant liquidity for institutional operations. The protocol doesn't need to hold idle reserves.

**Gas Optimization**: Operations are tracked virtually and settled in batches, dramatically reducing transaction costs compared to immediate settlement of every operation.

**Risk Isolation**: Virtual balances allow the protocol to maintain accurate accounting even when external strategies experience delays or temporary issues.

The virtual accounting works by tracking deposits, withdrawals, and transfers across all vaults and maintaining a reconciliation mechanism through periodic settlement.

```
┌──────────────────────────────────────────────────────────────┐
│                    Virtual Balance System                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   kMinter Balance    Vault A Balance    Vault B Balance      │
│   ┌────────────┐     ┌────────────┐     ┌────────────┐       │
│   │ Virtual:   │     │ Virtual:   │     │ Virtual:   │       │
│   │  +1000     │     │  +500      │     │  +300      │       │
│   │  -200      │     │  -100      │     │  -50       │       │
│   │ = 800      │     │ = 400      │     │ = 250      │       │
│   └────────────┘     └────────────┘     └────────────┘       │
│         │                   │                  │             │
│         └───────────────────┴──────────────────┘             │
│                             │                                │
│                    ┌────────▼──────-──┐                      │
│                    │  Net Settlement  │                      │
│                    │                  │                      │
│                    │ Total: +1450     │                      │
│                    │ Deploy to        │                      │
│                    │ Adapters         │                      │
│                    └──────────────────┘                      │
└──────────────────────────────────────────────────────────────┘
```

### Batch Settlement Architecture

The protocol operates on a time-based batch settlement system where operations are aggregated over configurable time periods, then settled atomically with yields retrieved from external strategies.

**Batch Lifecycle**: Each vault maintains independent batches that progress from Active (accepting requests) → Closed (ready for settlement) → Settled (yields distributed). There's no cross-vault dependency, allowing parallel processing.

**Two-Phase Settlement**: Settlement uses a proposal-commit pattern with timelock protection. Relayers propose settlement parameters (total assets, yield, net flows), wait for a cooldown period (default 1 hour), then execute the settlement atomically.

**Yield Distribution**: During settlement, yields from external strategies are calculated and distributed. Positive yields mint new kTokens to vaults, while losses burn kTokens, maintaining the 1:1 backing ratio.

```
┌─────────────────────────────────────────────────────────────┐
│                      Batch Lifecycle                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ACTIVE              CLOSED              SETTLED           │
│   ┌──────┐           ┌──────┐           ┌──────┐            │
│   │      │           │      │           │      │            │
│   │ Open │──4hrs────>│ Lock │──settle──>│ Done │            │
│   │      │           │      │           │      │            │
│   └──────┘           └──────┘           └──────┘            │
│      ▲                   │                  │               │
│      │                   │                  │               │
│   Accepts            No new            Claims               │
│   requests           requests          available            │
│                                                             │
│   • Stake            • Calculate       • Claim stkTokens    │
│   • Unstake          • Net flows       • Claim kTokens      │
│   • Mint             • Propose         • Redeem assets      │
│   • Redeem           • Cooldown        • Yield distributed  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Code Structure

KAM is split into the following main contracts:

### Core Token System

#### kToken

The fundamental ERC20 implementation representing tokenized real-world assets. Each kToken maintains a 1:1 peg with its underlying asset (e.g., kUSD:USDC, kBTC:WBTC).

The kToken contract is the foundational building block of the KAM protocol, implementing a role-restricted ERC20 token with advanced security features. It uses the UUPS upgradeable pattern where the upgrade logic resides in the implementation contract rather than the proxy, reducing proxy size and gas costs while maintaining upgradeability.

The contract implements ERC-7201 "Namespaced Storage Layout" to prevent storage collisions during upgrades. Each storage struct is placed at a deterministic slot to ensure upgrade safety. Role-based access control integrates Solady's OwnableRoles for gas-efficient permission management, with MINTER_ROLE for token operations, ADMIN_ROLE for configuration, and EMERGENCY_ADMIN_ROLE for crisis response.

All core functions respect a global pause state, allowing immediate shutdown if security issues are detected. Due to Solidity's stack depth limitations, initialization is split into two phases: basic setup without strings, then metadata configuration in a separate call.

#### kMinter

The institutional gateway contract serving as the primary interface for institutional actors to mint and redeem kTokens.

The kMinter contract implements a "push-pull" model for institutional operations, where minting is immediate but redemptions are processed through a request queue system. When institutions mint kTokens, the process is synchronous - assets transfer to kAssetRouter, virtual balances update, and kTokens are minted 1:1 immediately, ensuring institutions receive tokens instantly without waiting for settlement.

Redemptions use an asynchronous request-response pattern. Institutions call requestRedeem() which transfers kTokens to the kMinter contract for escrow (not burning immediately). A unique request ID is generated and stored with request details, and the request is added to the current batch for settlement processing. During settlement, assets are retrieved from strategies, and institutions later call redeem() which burns the escrowed kTokens and claims underlying assets from the batch receiver.

The contract utilizes Solady's EnumerableSet for O(1) addition/removal of user requests, allowing efficient iteration over pending requests with automatic cleanup when processed or cancelled. Request states track the lifecycle from PENDING to REDEEMED or CANCELLED.

### Settlement and Routing Infrastructure

#### kAssetRouter

The central settlement engine and virtual balance coordinator that manages all asset flows between protocol components.

The kAssetRouter is the most complex contract in the KAM protocol, serving as both the virtual accounting system and the settlement coordination hub. It implements a sophisticated dual accounting model where virtual balances are tracked separately from physical asset movements.

The router maintains three primary mappings for tracking asset states: vault batch balances for pending deposits/withdrawals per vault per batch, share redemption requests per vault per batch, and settlement proposals with timelock protection. The Balances struct packs two uint128 values in a single storage slot for gas efficiency.

Settlement uses a proposal-commit pattern that provides security through time delays and validation. Relayers submit settlement proposals containing total assets, netted amounts, yield calculations, and profit status. After a mandatory cooldown period where proposals can be reviewed and cancelled if errors are detected, anyone can execute the settlement atomically.

The router handles four distinct types of asset movements: kMinter push operations when institutions mint tokens, kMinter pull requests when institutions request redemptions, vault transfers when retail users stake/unstake, and share management for complex multi-vault operations.

During settlement execution, the system handles kMinter versus regular vault settlement differently. For kMinter settlements, assets are transferred to batch receivers for institutional redemptions, with the vault variable being reassigned to the corresponding DN vault. For regular vault settlements, yield is minted or burned based on profit/loss calculations. Netted assets are then deployed to external strategies via adapters using explicit approval patterns for security.

```
┌───────────────────────────────────────────────────────────────-----──┐
│                     Three-Phase Settlement                           │
├───────────────────────────────────────────────────────────────-------┤
│                                                                      │
│  Phase 1: PROPOSAL           Phase 2: COOLDOWN      Phase 3: EXECUTE |
│  ┌──────────────┐           ┌──────────────┐      ┌──────────────┐   |
│  │   Relayer    │           │   Timelock   │      │   Anyone     │   |
│  │              │           │              │      │              │   |
│  │ • Calculate  │           │ • 1hr wait   │      │ • Clear      │   |
│  │   yields     │──────────>│ • Can cancel │─────>│   balances   │   |
│  │ • Net flows  │           │ • Can update │      │ • Deploy     │   |
│  │ • Submit     │           │              │      │   assets     │   |
│  └──────────────┘           └──────────────┘      └──────────────┘   |
│                                                                      │
└─────────────────────────────────────────────────────────────────-----┘
```

### Vault System

#### kStakingVault

Modular vault implementation deployed per asset type, enabling retail users to stake kTokens for yield-bearing stkTokens.

The kStakingVault implements a sophisticated modular architecture using the "diamond pattern" via MultiFacetProxy. This design allows the vault to compose functionality from multiple specialized modules while maintaining a single contract interface.

**BaseVaultModule**: Provides foundational vault logic including ERC20 token functionality for stkTokens. These tokens represent staked positions and automatically accrue yield. The module uses ERC-7201 namespaced storage for upgrade safety, connects to kRegistry for system-wide configuration, implements role-based permissions, and uses ReentrancyGuardTransient for gas-efficient protection.

**BatchModule**: Handles the complete batch lifecycle for efficient gas usage. It automatically creates new batches when current batches settle, marks batches ready for settlement processing, coordinates with kAssetRouter for atomic settlement, and creates deterministic addresses for redemption distribution.

**FeesModule**: Manages comprehensive fee collection and distribution. Management fees accrue continuously based on time and total assets under management, while performance fees are charged only on positive yields from external strategies. Fee calculation uses precise math to avoid rounding errors, and collection occurs during settlement operations to minimize gas or over an X period of time.

**ClaimModule**: Processes user claims for completed requests. It converts completed stake requests into stkToken balances, processes unstaking requests and distributes underlying tokens plus yield, ensures claims are only processed for settled batches, and batches multiple claims for efficiency.

The MultiFacetProxy pattern enables modular functionality through delegatecall routing, allowing new functionality to be added without contract redeployment, isolating complex logic in specialized modules, maintaining a clean main contract interface, and upgrading individual modules independently.

#### kBatchReceiver

Lightweight, immutable proxy contracts deployed per batch to handle redemption distributions.

The kBatchReceiver serves as a secure escrow mechanism for institutional redemptions, providing a trustless way for institutions to claim their underlying assets after batch settlement. These contracts use CREATE2 for deterministic deployment with predictable addresses, preventing frontrunning attacks.

Once deployed, batch receivers cannot be modified, having no upgrade capability for maximum security. The single-purpose functionality reduces attack surface, and the minimal proxy pattern enables gas-efficient deployment. Asset distribution implements simple but secure asset claiming, with only kMinter able to trigger asset distribution and no administrator override capabilities.

### External Integration Layer

#### BaseAdapter

Abstract foundation for all strategy adapters, providing common functionality and security checks:

- Role-based access control for secure operations
- Reentrancy protection across all external calls
- Virtual balance tracking for protocol coordination
- Emergency pause capability for crisis management

#### CustodialAdapter

Concrete implementation for custodial strategies (CEX, institutional custody).

The CustodialAdapter maps vaults to custodial addresses where assets are actually held, tracks virtual balances while assets are externally deployed, reports total assets back to the protocol accurately, and handles deposit and redemption flows seamlessly. This enables the protocol to integrate with traditional financial infrastructure while maintaining on-chain transparency.

### Registry and Configuration

#### kRegistry

System-wide configuration store maintaining all protocol mappings and permissions.

The registry maintains contract ID to address mappings for all protocol components, asset to kToken associations for supported tokenization pairs, vault registration and type classification for proper routing, adapter registration per vault for strategy management, and role management across the entire protocol ecosystem.

### Supporting Infrastructure

The above contracts depend on base contracts and libraries:

**kBase**: Common functionality inherited by core protocol contracts, providing registry integration helpers, role management utilities, pause functionality, and standardized storage access patterns.

**Extsload**: Allows external contracts to read storage slots efficiently, implementing EIP-2930 access list optimization for off-chain monitoring and verification.

**MultiFacetProxy**: Proxy pattern for modular vault architecture, enabling delegatecall routing to facet implementations, selector-based function dispatch, and admin-controlled facet management.

## Operational Flows

### Institutional Minting Flow

The institutional minting process ensures immediate token issuance while maintaining proper virtual accounting. Institutions must have INSTITUTION_ROLE granted by protocol governance. The process involves transferring underlying assets to kAssetRouter via safeTransferFrom, updating virtual balances for kMinter in the current batch, minting kTokens 1:1 immediately to the institution's specified recipient, and eventually deploying assets to strategies during batch settlement.

```
Institution                kMinter              kAssetRouter            kToken
    │                         │                      │                    │
    ├──approve(USDC)─────────>│                      │                    │
    │                         │                      │                    │
    ├──mint(amount,to)───────>│                      │                    │
    │                         ├──transferFrom(USDC)─>│                    │
    │                         │                      │                    │
    │                         ├──kAssetPush────────->│                    │
    │                         │                      ├──updateVirtual()   │
    │                         │                      │                    │
    │                         ├──mint(kUSD)────────────────-─────────────>│
    │<────────────────────────┤                      │                    │
    │                         │                      │                    │
    │  kTokens received 1:1   │                      │                    │
```

### Institutional Redemption Flow

The redemption process implements a secure request-queue system that protects both the protocol and institutions. The process begins with request creation where institutions call requestRedeem() with their kToken amount. A unique ID is created from user data, amount, and timestamp, and kTokens are transferred to kMinter for holding (not burned immediately). Virtual balances are updated in kAssetRouter to mark assets as requested for withdrawal.

During batch settlement, assets are retrieved from strategies and transferred to kBatchReceiver for distribution. Finally, institutions call redeem() to burn the escrowed kTokens and receive underlying assets from the batch receiver, ensuring atomic exchange of tokens for assets.

```
Institution            kMinter            kAssetRouter         BatchReceiver
    │                     │                    │                    │
    ├──requestRedeem─────>│                    │                    │
    │                     ├──escrow(kTokens)   │                    │
    │                     ├──requestPull──────>│                    │
    │                     │                    ├──queueForBatch()   │
    │<──requestId─────────┤                    │                    │
    │                     │                    │                    │
    │        [Wait for Settlement]             │                    │
    │                     │                    ├──settle()─────────>│
    │                     │                    │                    │
    ├──redeem(requestId)─>│                    │                    │
    │                     ├──burn(kTokens)     │                    │
    │                     ├──pullAssets────────────────────────────>│
    │<────────────────────┤                    │                    │
    │   USDC received     │                    │                    │
```

### Retail Staking Flow

Retail users interact through kStakingVault to earn yield on their kTokens. Users first acquire kTokens via DEX or other means, then call requestStake() with their desired amount. kTokens are moved to the vault via safeTransferFrom, and kAssetRouter transfers virtual balance from kMinter to vault. Requests are queued for the current batch, and after settlement, users can claim stkTokens representing their staked position. These stkTokens automatically accrue yield from external strategies.

```
Retail User          kStakingVault         kAssetRouter           Batch
    │                     │                      │                  │
    ├──requestStake──────>│                      │                  │
    │                     ├──transfer(kTokens)   │                  │
    │                     ├──kAssetTransfer────->│                  │
    │                     │                      ├──updateVirtual() │
    │<──requestId─────────┤                      │                  │
    │                     │                      │                  │
    │         [Batch Closes & Settles]           │                  │
    │                     │                      ├──settlement────->│
    │                     │                      │                  │
    ├──claimShares───────>│                      │                  │
    │                     ├──validateClaim()     │                  │
    │<──stkTokens─────────┤                      │                  │
    │                     │                      │                  │
```

### Settlement Process

Settlement is the critical synchronization point between virtual and actual balances, implemented through a secure three-phase process. During the proposal phase, relayers calculate and submit settlement parameters including total assets with yield, netted amounts for deposits minus withdrawals, yield amounts, and profit/loss determination.

The cooldown phase provides a mandatory waiting period (default 1 hour, configurable up to 1 day) where proposals can be reviewed and cancelled if errors are detected.

In the execution phase, after cooldown expires, anyone can execute the settlement atomically. The system clears batch balances, handles different settlement types (kMinter vs regular vault), deploys netted assets to adapters with explicit approvals, updates adapter total asset tracking, and marks batches as settled in vaults.

## Virtual Balance System

The protocol maintains a dual accounting system that enables capital efficiency while ensuring accurate tracking. Virtual balances track theoretical positions without physical custody, enabling instant operations without waiting for settlement, reducing gas costs by batching transfers, and allowing assets to remain productively deployed.

Physical settlement provides periodic synchronization of virtual and actual balances through net settlement that minimizes token transfers, yield distribution based on time-weighted positions, and adapter reconciliation to ensure accuracy.

The system calculates virtual balances by querying all adapters for a vault and summing their reported total assets. Currently, the implementation assumes single asset per vault and uses the first asset from the vault's asset list, which may be addressed when multi-asset vaults are implemented.

## Security Architecture

### Role-Based Access Control

The protocol implements granular permissions via Solady's OwnableRoles with clearly defined responsibilities:

| Role                 | Scope       | Key Permissions                 |
| -------------------- | ----------- | ------------------------------- |
| OWNER                | Protocol    | Upgrades, critical changes      |
| ADMIN_ROLE           | Operational | Configuration, registry updates |
| EMERGENCY_ADMIN_ROLE | Crisis      | Pause, emergency withdrawals    |
| MINTER_ROLE          | Tokens      | Mint/burn kTokens               |
| INSTITUTION_ROLE     | Access      | Use kMinter functions           |
| VENDOR_ROLE          | Adapters    | Register adapters, manage assets|
| RELAYER_ROLE         | Settlement  | Propose batch settlements       |
| GUARDIAN_ROLE        | Settlement  | Cancel settlement proposals     |

### Settlement Security

The two-phase commit system provides multiple safeguards:

**Timelock Protection**

- Mandatory cooldown period (1hr default, max 1 day)
- Proposal cancellation capability
- Parameter update mechanism
- On-chain validation

### Emergency Controls

The protocol implements a multi-layered emergency response system with global pause across all contracts, per-vault pause for isolated issues, emergency fund withdrawal by admin, proposal cancellation mechanisms, and upgrade capability via UUPS for critical fixes.

## Batch Processing Architecture

### Batch Lifecycle

Each batch progresses through defined states: Active phase accepting deposits and withdrawals with no time limit on duration, Pending Settlement phase where batches are closed to new requests and net positions are calculated, and Settled phase where all operations are complete, yields are distributed, and claims become available.

### Per-Vault Independence

Each vault maintains separate batch tracking with no cross-vault dependencies, parallel settlement capability, independent cycle timing, and vault-specific parameters. This design ensures that issues in one vault don't affect others and allows for optimized processing.

### Batch Receiver Deployment

For each settled batch with redemptions, the system creates deterministic batch receiver addresses using CREATE2 with a salt derived from the vault address and batch ID. This ensures predictable addresses while preventing frontrunning attacks.

## Fee Structure

### Management Fees

Management fees accrue continuously on assets under management, calculated on a per-second basis, collected during settlement operations, and are configurable per vault to accommodate different strategy types.

### Performance Fees

Performance fees are charged only on positive yield generation, calculated as a percentage of profits, distributed to the designated fee collector, with no fees charged on losses to align incentives properly.

### Fee Calculation

The system uses precise mathematical calculations to determine fees based on time passed and total assets, avoiding rounding errors through careful implementation, and ensuring fairness across all participants.

## Adapter Integration Pattern

### Adapter Interface

All adapters must implement the IAdapter interface providing deposit functionality for deploying assets to strategies, redemption capability for retrieving assets, total asset reporting for virtual balance calculation, and asset tracking updates for settlement reconciliation.

### Integration Requirements

Strategy integration requires implementing the IAdapter interface correctly, registering with kRegistry for protocol recognition, mapping to specific vaults for proper routing, handling approvals properly for security, and reporting accurate balances for system integrity.

### Custodial Adapter Flow

The custodial adapter receives deposit calls from kAssetRouter, transfers assets to designated custodial addresses, updates internal balance tracking systems, reports total assets accurately on queries, and handles redemptions when requested by the protocol.

## Advanced Technical Features

### ERC-7201 Namespaced Storage

All contracts implement ERC-7201 "Namespaced Storage Layout" to prevent storage collisions during upgrades. Each storage struct is placed at a deterministic slot calculated as:

```solidity
keccak256(abi.encode(uint256(keccak256("kam.storage.ContractName")) - 1)) & ~bytes32(uint256(0xff))
```

This ensures that:
- Storage layouts are upgrade-safe
- No accidental overwrites between contracts
- Clear separation of concerns for each contract's state

### Transient Reentrancy Protection

The protocol uses Solady's `ReentrancyGuardTransient` which leverages Solidity 0.8.30's transient storage opcodes (TSTORE/TLOAD) for gas-efficient reentrancy protection. This provides:

- Cheaper reentrancy protection than traditional storage-based guards  
- Automatic cleanup after transaction completion
- No permanent storage pollution
- Modern EVM optimization for frequent state checks

### UUPS Upgrade Pattern

Core contracts implement the Universal Upgradeable Proxy Standard (UUPS) where the upgrade logic resides in the implementation contract rather than the proxy. This provides:

- Smaller proxy size and reduced deployment costs
- Implementation-controlled upgrade authorization
- Better gas efficiency for delegatecalls
- Reduced proxy complexity

## Gas Optimizations

The protocol implements multiple optimization strategies for cost efficiency:

**Batch Processing**: Aggregate operations into single settlements with amortized gas costs

**Virtual Balances**: Minimize actual token transfers through net settlement only

**Storage Packing**: Multiple values in single slots (uint128 pairs)

**Proxy Patterns**: Minimal proxies for receivers, UUPS for upgradeability

**CREATE2**: Deterministic deployment without initialization transactions

**Multicall**: Batching multiple operations with reduced overhead

## Upgrade Mechanism

All core contracts use the UUPS pattern with proper authorization controls. Only addresses with ADMIN_ROLE can authorize upgrades, and the new implementation address must be non-zero. Storage preservation is ensured through ERC-7201 namespaced layout with no storage collision risk and append-only modifications.

Some components remain immutable by design: kBatchReceiver contracts have no upgrade capability for security, and deployed proxies maintain fixed implementations for predictability.

## Integration Points

### For Institutions

- Direct kMinter access
- 1:1 guaranteed backing
- No slippage or MEV
- Batch-based efficiency
- Comprehensive request tracking

### For Retail Users

- Standard ERC20 interface
- Auto-compounding yields
- Flexible redemption
- stkToken appreciation

### For Strategies

- IAdapter implementation
- Virtual balance reporting
- Automated distribution
- Multi-strategy support

### For Monitoring

- Extsload for storage access
- Off-chain verification
- Real-time tracking
- Audit trail capability
