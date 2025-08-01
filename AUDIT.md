# KAM Protocol Audit Documentation

## Table of Contents

- [Audit Scope](#audit-scope)
- [Protocol Overview](#protocol-overview)
- [Architecture](#architecture)
- [Core Mechanics](#core-mechanics)
- [Security Model](#security-model)
- [Contract Details](#contract-details)
- [Roles and Permissions](#roles-and-permissions)
- [Risk Considerations](#risk-considerations)

## Audit Scope

Smart contracts within audit scope:

- **Core**: `kRegistry.sol`, `kBase.sol`, `BaseModule.sol`
- **Tokens**: `kToken.sol`, `kMinter.sol`
- **Vaults**: `kStakingVault.sol`, `BatchModule.sol`, `ClaimModule.sol`
- **Routing**: `kAssetRouter.sol`, `kBatchReceiver.sol`
- **Adapters**: `BaseAdapter.sol`, `MetaVaultAdapter.sol`, `CustodialAdapter.sol`
- **Abstracts**: `Extsload.sol`, `Proxy.sol`
- **Modules**: `MultiFacetProxy.sol`

## Protocol Overview

KAM Protocol enables institutions to mint kTokens backed 1:1 by assets (USDC, WBTC) and earn yield through staking. Institutions mint kTokens via kMinter, while users can stake kTokens in vaults to receive stkTokens that appreciate in value as yield accumulates.

The protocol integrates with both custodial services (CEX) and DeFi protocols (MetaVault) to generate returns through Delta Neutral, Alpha, and Beta strategies.

## Architecture

The protocol uses a modular seven-layer architecture:

1. **Registry**: Central configuration and contract discovery (`kRegistry.sol`)
2. **Tokens**: ERC20 kTokens with controlled minting (`kToken.sol`, `kMinter.sol`)
3. **Vaults**: Staking vaults with batch processing (`kStakingVault.sol`)
4. **Router**: Asset flow management and settlement (`kAssetRouter.sol`)
5. **Adapters**: External integration points (`BaseAdapter.sol`, `MetaVaultAdapter.sol`, `CustodialAdapter.sol`)
6. **Proxy Layer**: Diamond proxy pattern for modular upgrades (`MultiFacetProxy.sol`)
7. **Batch Receivers**: Per-batch asset distribution (`kBatchReceiver.sol`)

### Modular Design

The protocol implements a diamond proxy pattern through `MultiFacetProxy.sol` that enables:
- Function selector mapping to specific implementation contracts
- Modular upgrades without full contract replacement
- Role-based access control for proxy administration
- Delegated execution while maintaining centralized storage

### External Storage Loading

The `Extsload.sol` abstract contract provides external storage loading capabilities used by:
- `kMinter.sol`: For accessing registry data and vault information
- `kStakingVault.sol`: For cross-contract data access during batch processing

## Core Mechanics

### Minting and Redemption

Institutions deposit assets to mint kTokens 1:1 through kMinter. Redemptions follow a request-based model:

1. **Request Creation**: kTokens are burned immediately and redemption request is created
2. **Batch Settlement**: Assets are transferred to kBatchReceiver for the specific batch
3. **Asset Distribution**: Assets are transferred to the user from kBatchReceiver for the requested amount

### Staking Flow

Users stake kTokens in vaults to receive stkTokens. Operations are batched:

1. Users create stake/unstake requests with slippage protection
2. Relayer closes batch and triggers settlement
3. Router calculates net positions and deploys to adapters
4. Users claim after settlement completes

### Yield Distribution

Yield flows to vaults, not individual users. The kAssetRouter:

- Compares current vs previous total assets
- Mints kTokens to vault for profits (increases stkToken price)
- Burns kTokens from vault for losses (decreases stkToken price)

### Virtual Balance System

kAssetRouter maintains virtual balances for all vaults, tracking:

- Assets awaiting deployment per batch
- Pending deposits and withdrawals per batch
- Cross-vault transfer positions through batch settlement

### Batch Processing Architecture

Each batch has three states:
- **Open**: Accepting new requests
- **Closed**: No new requests, ready for settlement
- **Settled**: Assets distributed, claims available

Batch receivers are deployed per batch to isolate asset distribution and enable efficient settlement.

## Security Model

### Batch Processing

All operations process in batches to prevent MEV attacks and enable gas-efficient settlement. Batches have three states: open, closed, and settled.

### Slippage Protection

- Stake requests include `minStkTokens` parameter
- Unstake requests include `minKTokens` parameter
- Claims fail if output would be below minimum

### Emergency Controls

- Pausable contracts with emergency admin role
- Emergency withdrawal functions in adapters
- Dust thresholds prevent griefing attacks

### Role-Based Access Control

- **Owner**: Contract upgrades and critical changes
- **Admin**: Operational configuration and proxy management
- **Emergency Admin**: Pause functionality and emergency operations
- **Relayer**: Batch settlement execution
- **Minter Role**: kToken minting (granted to specific addresses, not contract-restricted)
- **Institution**: Access to mint/redeem functions

## Contract Details

### kRegistry

Singleton registry storing all protocol configuration. Manages asset support, vault registration, and adapter assignments.

### kMinter

Institutional entry point with request-based redemption. Maintains redemption queue and enforces role-based access. Uses Extsload for external storage access.

### kStakingVault

Diamond proxy vault supporting modular functionality through MultiFacetProxy. Tracks stake/unstake requests and coordinates with router for settlement. Implements BaseModule, BatchModule, and ClaimModule.

### kAssetRouter

Settlement engine managing virtual balances and yield distribution. Routes assets to adapters based on net batch positions. Handles cross-vault transfers and batch receiver deployment.

### kBatchReceiver

Minimal proxy contract deployed per batch to hold and distribute settled assets. Isolates asset distribution and enables efficient settlement. Only callable by kMinter.

### Adapters

- **BaseAdapter**: Abstract base providing common functionality and virtual balance tracking
- **CustodialAdapter**: Sends assets to custody addresses, tracks virtual balances
- **MetaVaultAdapter**: Integrates with ERC7540 vaults, manages share-based positions and async redemptions

### Abstract Contracts

- **Extsload**: Provides external storage loading capabilities for cross-contract data access
- **Proxy**: Base proxy functionality for the diamond pattern implementation

## Roles and Permissions

- **Owner**: Contract upgrades and critical changes
- **Admin**: Operational configuration and proxy management
- **Emergency Admin**: Pause functionality and emergency operations
- **Relayer**: Batch settlement execution
- **Minter Role**: kToken minting (granted to specific addresses, not contract-restricted)
- **Institution**: Access to mint/redeem functions

## Risk Considerations

### Operational Risks

- **Custodial Dependency**: Redemptions from custody require off-chain coordination
- **Settlement Delays**: Batch processing introduces time between request and fulfillment
- **Adapter Failures**: External protocol issues could block withdrawals
- **Batch Receiver Deployment**: Each batch requires new kBatchReceiver deployment

### Economic Risks

- **Pricing Accuracy**: stkToken value depends on accurate adapter reporting
- **Yield Volatility**: Negative yield burns kTokens from vaults, reducing stkToken value
- **Liquidity**: Large redemptions may exceed hot wallet reserves

### Technical Risks

- **Diamond Proxy Complexity**: MultiFacetProxy allows granular upgrades but increases attack surface
- **External Storage Access**: Extsload pattern introduces complexity in cross-contract data access
- **Virtual Accounting**: Mismatch between virtual and actual balances could cause issues
- **Cross-Module Dependencies**: Tightly coupled system where one module failure affects others
- **Batch Receiver Isolation**: Per-batch receivers create additional deployment complexity

### Centralization

- Registry controls all protocol parameters
- Relayers determine settlement timing
- Admin roles have significant operational control
- Proxy admin controls function selector mappings