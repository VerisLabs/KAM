# KAM Protocol

KAM is an institutional asset management protocol that implements a dual-track architecture for both institutional and retail access. The protocol creates kTokens (kUSD, kBTC) backed 1:1 by real assets (USDC, WBTC), providing institutions with direct minting and redemption capabilities while offering retail users yield opportunities through external strategy deployment. The system features batch processing with virtual balance accounting, two-phase settlement with timelock proposals, and modular vault architecture through diamond pattern implementation.

For more information, refer to the [architecture documentation](./docs/architecture.md).

## Usage

KAM comes with a comprehensive set of tests written in Solidity, which can be executed using Foundry.

To install Foundry:

```sh
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```sh
foundryup
```

To clone the repo:

```sh
git clone https://github.com/kam-protocol/kam.git && cd kam
```

### Installing Dependencies

The project uses Soldeer for dependency management. To install all dependencies:

```sh
forge soldeer install
```

This will install all dependencies specified in `soldeer.toml` and `soldeer.lock`.

## Testing

### in `default` mode

To run the tests in a `default` mode:

```sh
forge test
```

### in `coverage` mode

```sh
forge coverage
```

### Using solx compiler (optional)

For faster compilation with the LLVM-based Solidity compiler, you can install and use solx:

Install solx:
```sh
curl -L https://raw.githubusercontent.com/matter-labs/solx/main/install-solx | bash
```

Use with forge:
```sh
forge build --use $(which solx)
forge test --use $(which solx)
```

## Smart Contracts Documentation

Generate and view the Foundry documentation:

```sh
forge doc --serve --port 4000
```

This will open the documentation at http://localhost:4000

## Protocol Documentation

- [Architecture](./docs/architecture.md) - Complete protocol architecture and operational flows
- [Interfaces](./docs/interfaces.md) - Interface documentation for all protocol contracts
- [Audit Scope](./docs/audits/audit-scope.md) - Comprehensive audit scope and security considerations

## For Integrators

### Institutional Operations

Institutions can mint kTokens 1:1 with underlying assets and request redemptions through batch settlement:

- `kMinter.mint()` - Creates new kTokens by accepting underlying asset deposits
- `kMinter.requestRedeem()` - Initiates redemption process through batch settlement
- `kMinter.redeem()` - Executes redemption for settled batch requests
- `kMinter.cancelRequest()` - Cancels redemption requests before settlement

### Retail Operations

Retail users can stake kTokens to earn yield from external strategies:

- `kStakingVault.requestStake()` - Request to stake kTokens for yield-bearing stkTokens
- `kStakingVault.requestUnstake()` - Request to unstake stkTokens back to kTokens
- Claims processed through vault's ClaimModule after batch settlement

### Virtual Balance System

The protocol uses virtual balance accounting to optimize gas efficiency:

- `kAssetRouter` maintains virtual balances between vaults and strategies
- Physical transfers minimized to settlement operations only
- All inter-vault transfers are virtual until settlement execution

### Batch Processing

Requests are grouped into time-based batches for gas-efficient settlement:

- Each vault manages independent batch cycles
- Batch receivers deployed per batch for isolated asset distribution
- Settlement coordinated through timelock proposals with correction mechanisms

## Role Hierarchy

| Role                 | Permissions                | Contracts                 |
| -------------------- | -------------------------- | ------------------------- |
| OWNER                | Ultimate control, upgrades | All                       |
| ADMIN_ROLE           | Operational management     | All                       |
| EMERGENCY_ADMIN_ROLE | Emergency pause            | All                       |
| MINTER_ROLE          | Mint/burn tokens           | kToken                    |
| INSTITUTION_ROLE     | Mint/redeem kTokens        | kMinter                   |
| RELAYER_ROLE         | Settle batches             | kAssetRouter, BatchModule |
| VENDOR_ROLE          | Adds Institutions          | kRegistry                 |

## Safety

This software is experimental and is provided "as is" and "as available".

No warranties are provided and no liability will be accepted for any loss incurred through the use of this codebase.

Always include thorough tests when using KAM to ensure it interacts correctly with your code.

## Known Limitations

- Settlement proposals require timelock delays, potentially causing settlement delays if parameters need correction
- Virtual balances must remain synchronized with actual adapter holdings
- Redemption completion depends on successful batch settlement and adapter cooperation
- Adapter integrations require careful validation of different DeFi protocol settlement patterns

## Contributing

The code is currently in a closed development phase. This is a proprietary protocol with restricted access.

## License

(c) 2025 KAM Protocol Ltd.

All rights reserved. This project uses a proprietary license.
