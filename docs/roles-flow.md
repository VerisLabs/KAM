# KAM Protocol - Roles and Permissions Flow

## Overview: Role-Based Access Control

The KAM Protocol implements a comprehensive role-based access control system using Solady's OptimizedOwnableRoles. Each role has specific permissions and responsibilities within the protocol, enabling secure and efficient operations while maintaining proper access controls.

## Role Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                        Role Hierarchy                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  OWNER (Ultimate Control)                                       │
│  ├── ADMIN_ROLE (Operational Management)                        │
│  │   ├── VENDOR_ROLE (Vendor Management)                        │
│  │   │   └── INSTITUTION_ROLE (Institutional Access)            │
│  │   ├── RELAYER_ROLE (Settlement Operations)                   │
│  │   └── MANAGER_ROLE (Adapter Management)                      │
│  ├── EMERGENCY_ADMIN_ROLE (Emergency Controls)                  │
│  └── GUARDIAN_ROLE (Settlement Oversight)                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Role Definitions and Permissions

**Note**: Not all access control in the protocol is role-based. Some functions use contract-based access control (e.g., only kAssetRouter can call certain VaultAdapter functions).

### OWNER

**Ultimate Protocol Control**

- **Scope**: All contracts
- **Key Permissions**:
  - Contract upgrades and critical changes
  - Role management and delegation
  - Emergency protocol interventions
- **Usage**: Protocol governance and critical decisions

### ADMIN_ROLE

**Operational Management**

- **Scope**: All contracts
- **Key Permissions**:
  - Configuration management
  - Registry updates
  - Vault and adapter registration
  - Treasury management
  - Role delegation (VENDOR, RELAYER, MANAGER)
- **Key Functions**:
  - `kRegistry.setSingletonContract()` - Register core contracts
  - `kRegistry.registerVault()` - Register new vaults
  - `kRegistry.registerAdapter()` - Register external adapters
  - `kRegistry.setTreasury()` - Set treasury address
  - `kRegistry.grantVendorRole()` - Grant vendor privileges
  - `kRegistry.grantRelayerRole()` - Grant relayer privileges
  - `kRegistry.grantManagerRole()` - Grant manager privileges

### EMERGENCY_ADMIN_ROLE

**Emergency Response**

- **Scope**: All contracts
- **Key Permissions**:
  - Protocol-wide pause/unpause
  - Emergency asset recovery
  - Crisis response operations
- **Key Functions**:
  - `kBaseRoles.setPaused()` - Emergency pause protocol
  - `kBase.setPaused()` - Pause individual contracts
  - `kStakingVault.setPaused()` - Pause staking vault
  - `kToken.setPaused()` - Pause token operations
  - `kToken.emergencyWithdraw()` - Emergency asset recovery
  - `kRegistry.rescueAssets()` - Emergency asset recovery

### GUARDIAN_ROLE

**Settlement Oversight**

- **Scope**: kAssetRouter
- **Key Permissions**:
  - Cancel settlement proposals during cooldown
  - Monitor settlement accuracy
  - Circuit breaker for incorrect settlements
- **Key Functions**:
  - `kAssetRouter.cancelProposal()` - Cancel settlement proposals (only function using GUARDIAN_ROLE)

### RELAYER_ROLE

**Settlement Operations**

- **Scope**: kAssetRouter, kMinter, kStakingVault, kRegistry
- **Key Permissions**:
  - Batch lifecycle management
  - Settlement proposal and execution
  - Hurdle rate configuration
  - Automated protocol operations
- **Key Functions**:
  - `kAssetRouter.proposeSettleBatch()` - Propose batch settlements
  - `kMinter.closeBatch()` - Close minting batches
  - `kMinter.settleBatch()` - Mark batches as settled
  - `kStakingVault.createNewBatch()` - Create new staking batches
  - `kStakingVault.closeBatch()` - Close staking batches
  - `kRegistry.setHurdleRate()` - Set performance thresholds

### INSTITUTION_ROLE

**Institutional Access**

- **Scope**: kMinter
- **Key Permissions**:
  - Mint kTokens 1:1 with underlying assets
  - Request redemptions
  - Cancel redemption requests
  - Execute redemptions after settlement
- **Key Functions**:
  - `kMinter.mint()` - Mint kTokens
  - `kMinter.requestBurn()` - Request redemption
  - `kMinter.burn()` - Execute redemption
  - `kMinter.cancelRequest()` - Cancel redemption request

### VENDOR_ROLE

**Vendor Management**

- **Scope**: kRegistry
- **Key Permissions**:
  - Grant institution roles
  - KYC/KYB Controller
  - Manage vendor-specific operations
- **Key Functions**:
  - `kRegistry.grantInstitutionRole()` - Grant institutional access

### MANAGER_ROLE

**Adapter Management**

- **Scope**: VaultAdapter
- **Key Permissions**:
  - Execute arbitrary calls to external protocols
  - Manage adapter operations
  - Coordinate with external protocols
- **Key Functions**:
  - `VaultAdapter.execute()` - Execute arbitrary calls to external protocols (only function using MANAGER_ROLE)

## Role Usage Flow Diagrams

### Institutional Operations Flow
```
┌────────────────────────────────────────────────────────────────---─┐
│                    Institutional Operations                        │
├────────────────────────────────────────────────────────────---─────┤
│                                                                    │
│  INSTITUTION_ROLE Required:                                        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │Mint kTokens     │    │Request          │    │Execute          │ │
│  │1:1 with assets  │    │Redemption       │    │Redemption       │ │
│  │                 │    │                 │    │                 │ │
│  │kMinter.mint()   │    │kMinter.         │    │kMinter.burn()   │ │
│  │                 │    │requestBurn()    │    │                 │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│           │                       │                       │        │
│           ▼                       ▼                       ▼        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │kAssetRouter.    │    │kAssetRouter.    │    │BatchReceiver.   │ │
│  │kAssetPush()     │    │kAssetRequest    │    │pullAssets()     │ │
│  │(track deposit)  │    │Pull()           │    │(transfer assets)│ │
│  │                 │    │(track request)  │    │                 │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│                                                                    │
└──────────────────────────────────────────────---───────────────────┘
```

### Settlement Operations Flow
```
┌────────────────────────────────────────────────────────────────---─┐
│                    Settlement Operations                           │
├───────────────────────────────────────────────────────────---──────┤
│                                                                    │
│  RELAYER_ROLE Required:                                            │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │Close Batch      │    │Propose          │    │Execute          │ │
│  │(stop requests)  │    │Settlement       │    │Settlement       │ │
│  │                 │    │                 │    │                 │ │
│  │closeBatch()     │    │proposeSettle    │    │executeSettle    │ │
│  │                 │    │Batch()          │    │Batch()          │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│           │                       │                       │        │
│           ▼                       ▼                       ▼        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │Batch State:     │    │Cooldown Period  │    │Settlement       │ │
│  │CLOSED           │    │(1 hour default) │    │Executed         │ │
│  │                 │    │                 │    │                 │ │
│  │No new requests  │    │Guardian can     │    │Assets           │ │
│  │accepted         │    │cancel proposal  │    │distributed      │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│                                                                    │
│  GUARDIAN_ROLE (Optional):                                         │
│  ┌─────────────────┐                                               │
│  │Cancel Proposal  │                                               │
│  │(during cooldown)│                                               │
│  │                 │                                               │
│  │cancelProposal() │                                               │
│  └─────────────────┘                                               │
│                                                                    │
└─────────────────────────────────────────────────────────────────---┘
```

### Role Management Flow
```
┌─────────────────────────────────────────────────────────────────┐
│                    Role Management Flow                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ADMIN_ROLE → VENDOR_ROLE → INSTITUTION_ROLE                    │
│       │              │              │                           │
│       ▼              ▼              ▼                           │
│  ┌─────────┐    ┌────────--─┐  ┌─────────┐                      │
│  │Grant    │    │Grant      │  │Access   │                      │
│  │Vendor   │    │Institution│  │kMinter  │                      │
│  │Role     │    │Role       │  │Functions│                      │
│  └─────────┘    └─────────--┘  └─────────┘                      │
│       │              │              │                           │
│       ▼              ▼              ▼                           │
│  ┌────────--─┐  ┌─────────--┐  ┌─────────┐                      │
│  │Vendor     │  │Institution│  │Mint/    │                      │
│  │Can Grant  │  │Can Use    │  │Redeem   │                      │
│  │Institution│  │kMinter    │  │kTokens  │                      │
│  │Roles      │  │Functions  │  │         │                      │
│  └─────────--┘  └─────────--┘  └─────────┘                      │
│                                                                 │
│  ADMIN_ROLE → RELAYER_ROLE                                      │
│       │              │                                          │
│       ▼              ▼                                          │
│  ┌─────────┐    ┌─────────-┐                                    │
│  │Grant    │    │Settlement│                                    │
│  │Relayer  │    │Operations│                                    │
│  │Role     │    │          │                                    │
│  └─────────┘    └─────────-┘                                    │
│                                                                 │
│  ADMIN_ROLE → MANAGER_ROLE                                      │
│       │              │                                          │
│       ▼              ▼                                          │
│  ┌─────────┐    ┌─────────-┐                                    │
│  │Grant    │    │Adapter   │                                    │
│  │Manager  │    │Management│                                    │
│  │Role     │    │          │                                    │
│  └─────────┘    └─────────-┘                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Contract-Specific Role Usage

### kMinter Contract
```
┌─────────────────────────────────────────────────────────────────┐
│                        kMinter Roles                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INSTITUTION_ROLE Functions:                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• mint() - Mint kTokens 1:1 with assets                      ││
│  │• requestBurn() - Request redemption                         ││
│  │• burn() - Execute redemption after settlement               ││
│  │• cancelRequest() - Cancel pending redemption                ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  RELAYER_ROLE Functions:                                        │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• closeBatch() - Close batch to new requests                 ││
│  │• settleBatch() - Mark batch as settled                      ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### kAssetRouter Contract
```
┌─────────────────────────────────────────────────────────────────┐
│                      kAssetRouter Roles                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  RELAYER_ROLE Functions:                                        │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• proposeSettleBatch() - Propose settlement                  ││
│  │• executeSettleBatch() - Execute settlement                  ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  GUARDIAN_ROLE Functions:                                       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• cancelProposal() - Cancel settlement proposal              ││
│  │  (only function using GUARDIAN_ROLE)                        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### kStakingVault Contract
```
┌─────────────────────────────────────────────────────────────────┐
│                     kStakingVault Roles                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  RELAYER_ROLE Functions:                                        │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• createNewBatch() - Create new staking batch                ││
│  │• closeBatch() - Close batch to new requests                 ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  Public Functions (No Role Required):                           │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• requestStake() - Request to stake kTokens                  ││
│  │• requestUnstake() - Request to unstake stkTokens            ││
│  │• claimStakedShares() - Claim staked shares                  ││
│  │• claimUnstakedAssets() - Claim unstaked assets              ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### VaultAdapter Contract
```
┌─────────────────────────────────────────────────────────────────┐
│                      VaultAdapter Access Control                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MANAGER_ROLE Functions:                                        │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• execute() - Execute arbitrary calls to external protocols  ││
│  │  (only function using MANAGER_ROLE)                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  kAssetRouter-Only Functions (No Role Required):                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• setTotalAssets() - Set total assets for accounting         ││
│  │• pull() - Transfer assets to kAssetRouter                   ││
│  │  (only kAssetRouter can call these functions)               ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### kRegistry Contract
```
┌─────────────────────────────────────────────────────────────────-┐
│                        kRegistry Roles                           │
├─────────────────────────────────────────────────────────────────-┤
│                                                                  │
│  ADMIN_ROLE Functions:                                           │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │• setSingletonContract() - Register core contracts           │ │
│  │• registerVault() - Register new vaults                      │ │
│  │• registerAdapter() - Register external adapters             │ │
│  │• setTreasury() - Set treasury address                       │ │
│  │• grantVendorRole() - Grant vendor privileges                │ │
│  │• grantRelayerRole() - Grant relayer privileges              │ │
│  │• grantManagerRole() - Grant manager privileges              │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  VENDOR_ROLE Functions:                                          │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │• grantInstitutionRole() - Grant institutional access        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  RELAYER_ROLE Functions:                                         │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │• setHurdleRate() - Set performance thresholds               │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  EMERGENCY_ADMIN_ROLE Functions:                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │• rescueAssets() - Emergency asset recovery                  │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
└────────────────────────────────────────────────────────────────-─┘
```

### kBase Contract
```
┌─────────────────────────────────────────────────────────────────┐
│                        kBase Roles                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EMERGENCY_ADMIN_ROLE Functions:                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• setPaused() - Pause individual contracts                   ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### kToken Contract
```
┌─────────────────────────────────────────────────────────────────┐
│                        kToken Roles                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EMERGENCY_ADMIN_ROLE Functions:                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• setPaused() - Pause token operations                       ││
│  │• emergencyWithdraw() - Emergency asset recovery             ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### kStakingVault Contract (Additional)
```
┌─────────────────────────────────────────────────────────────────┐
│                    kStakingVault Roles                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  EMERGENCY_ADMIN_ROLE Functions:                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │• setPaused() - Pause staking vault                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Role Assignment Process

### Initial Setup
```
┌─────────────────────────────────────────────────────────────────┐
│                    Initial Role Assignment                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Constructor Initialization:                                    │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │__kBaseRoles_init():                                         ││
│  │• owner_ → OWNER                                             ││
│  │• admin_ → ADMIN_ROLE + VENDOR_ROLE                          ││
│  │• emergencyAdmin_ → EMERGENCY_ADMIN_ROLE                     ││
│  │• guardian_ → GUARDIAN_ROLE                                  ││
│  │• relayer_ → RELAYER_ROLE + MANAGER_ROLE                     ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Role Delegation Flow
```
┌────────────────────────────────────────────────────────────────---─┐
│                    Role Delegation Flow                            │
├─────────────────────────────────────────────────────────────---────┤
│                                                                    │
│  ADMIN_ROLE can grant:                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │VENDOR_ROLE      │    │RELAYER_ROLE     │    │MANAGER_ROLE     │ │
│  │                 │    │                 │    │                 │ │
│  │grantVendorRole()│    │grantRelayerRole │    │grantManagerRole │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│           │                       │                       │        │
│           ▼                       ▼                       ▼        │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │VENDOR_ROLE can  │    │RELAYER_ROLE can │    │MANAGER_ROLE can │ │
│  │grant:           │    │execute:         │    │execute:         │ │
│  │                 │    │                 │    │                 │ │
│  │INSTITUTION_ROLE │    │Settlement Ops   │    │Adapter Ops      │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│                                                                    │
└─────────────────────────────────────────────────────────────────---┘
```

## Security Considerations

### Role Isolation

- Each role has minimal required permissions
- No single role has complete protocol control
- Emergency controls are separate from operational roles

### Multi-Signature Requirements

- Critical operations may require multiple role confirmations
- Settlement proposals have cooldown periods for review
- Guardian role provides circuit breaker functionality

### Emergency Response

- EMERGENCY_ADMIN_ROLE can pause entire protocol
- Asset recovery mechanisms for crisis situations
- Role revocation capabilities for compromised accounts

## Role Validation Patterns

### Standard Role Checks

```solidity
// Pattern used across all contracts
function _checkRole(address user, uint256 role) internal view {
    require(_hasRole(user, role), ERROR_WRONG_ROLE);
}

// Specific role checks
function _checkInstitution(address user) internal view {
    require(_hasRole(user, INSTITUTION_ROLE), KMINTER_WRONG_ROLE);
}

function _checkRelayer(address user) internal view {
    require(_hasRole(user, RELAYER_ROLE), KSTAKINGVAULT_WRONG_ROLE);
}
```

### Registry Integration

```solidity
// Role checks through registry
function _isInstitution(address user) internal view returns (bool) {
    return _registry().isInstitution(user);
}

function _isRelayer(address user) internal view returns (bool) {
    return _registry().isRelayer(user);
}
```

## Timeline: Role-Based Operations

### Institutional Flow Timeline

```
Day 0:              Day 1:              Day 2:              Day 3:
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│Institution  │     │RELAYER      │     │RELAYER      │     │Institution  │
│Mints kTokens│     │Closes Batch │     │Executes     │     │Claims Assets│
│(INSTITUTION │     │(RELAYER_ROLE│     │Settlement   │     │(INSTITUTION │
│_ROLE)       │     │)            │     │(RELAYER_ROLE│     │_ROLE)       │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

### Settlement Oversight Timeline

```
Day 1:              Day 1+1hr:         Day 1+1hr:         Day 1+1hr:
┌─────────────┐     ┌────────────-─┐    ┌─────────────┐    ┌─────────────┐
│RELAYER      │     │GUARDIAN      │    │Anyone       │    │Settlement   │
│Proposes     │     │Can Cancel    │    │Can Execute  │    │Complete     │
│Settlement   │     │(GUARDIAN_ROLE│    │(No Role)    │    │             │
│(RELAYER_ROLE│     │)             │    │             │    │             │
└─────────────┘     └─────────────-┘    └─────────────┘    └─────────────┘
```