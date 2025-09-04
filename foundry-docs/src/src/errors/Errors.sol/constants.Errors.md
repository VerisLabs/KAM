# Constants
[Git Source](https://github.com/VerisLabs/KAM/blob/670f05acf8766190fcaa1d272341611f065917de/src/errors/Errors.sol)

### KASSETROUTER_ALREADY_REGISTERED
*All error codes use contract-specific prefixes for easier debugging:
- A*: kAssetRouter errors
- BA*: BaseAdapter errors
- BV*: BaseVault errors
- B*: kBatchReceiver errors
- C*: Custodial adapter errors
- K*: kBase errors
- M*: kMinter errors
- R*: kRegistry errors
- SV*: kStakingVault errors
- T*: kToken errors
- VB*: VaultBatches errors
- VC*: VaultClaims errors
- VF*: VaultFees errors*


```solidity
string constant KASSETROUTER_ALREADY_REGISTERED = "A1";
```

### KASSETROUTER_BATCH_CLOSED

```solidity
string constant KASSETROUTER_BATCH_CLOSED = "A2";
```

### KASSETROUTER_BATCH_ID_PROPOSED

```solidity
string constant KASSETROUTER_BATCH_ID_PROPOSED = "A3";
```

### KASSETROUTER_BATCH_SETTLED

```solidity
string constant KASSETROUTER_BATCH_SETTLED = "A4";
```

### KASSETROUTER_COOLDOOWN_IS_UP

```solidity
string constant KASSETROUTER_COOLDOOWN_IS_UP = "A5";
```

### KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE

```solidity
string constant KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE = "A6";
```

### KASSETROUTER_INVALID_COOLDOWN

```solidity
string constant KASSETROUTER_INVALID_COOLDOWN = "A7";
```

### KASSETROUTER_INVALID_VAULT

```solidity
string constant KASSETROUTER_INVALID_VAULT = "A8";
```

### KASSETROUTER_IS_PAUSED

```solidity
string constant KASSETROUTER_IS_PAUSED = "A9";
```

### KASSETROUTER_NO_PROPOSAL

```solidity
string constant KASSETROUTER_NO_PROPOSAL = "A10";
```

### KASSETROUTER_ONLY_KMINTER

```solidity
string constant KASSETROUTER_ONLY_KMINTER = "A11";
```

### KASSETROUTER_ONLY_KSTAKING_VAULT

```solidity
string constant KASSETROUTER_ONLY_KSTAKING_VAULT = "A12";
```

### KASSETROUTER_PROPOSAL_EXECUTED

```solidity
string constant KASSETROUTER_PROPOSAL_EXECUTED = "A13";
```

### KASSETROUTER_PROPOSAL_EXISTS

```solidity
string constant KASSETROUTER_PROPOSAL_EXISTS = "A14";
```

### KASSETROUTER_PROPOSAL_NOT_FOUND

```solidity
string constant KASSETROUTER_PROPOSAL_NOT_FOUND = "A15";
```

### KASSETROUTER_WRONG_ROLE

```solidity
string constant KASSETROUTER_WRONG_ROLE = "A16";
```

### KASSETROUTER_ZERO_ADDRESS

```solidity
string constant KASSETROUTER_ZERO_ADDRESS = "A17";
```

### KASSETROUTER_ZERO_AMOUNT

```solidity
string constant KASSETROUTER_ZERO_AMOUNT = "A18";
```

### ADAPTER_ALREADY_INITIALIZED

```solidity
string constant ADAPTER_ALREADY_INITIALIZED = "BA1";
```

### ADAPTER_INVALID_REGISTRY

```solidity
string constant ADAPTER_INVALID_REGISTRY = "BA2";
```

### ADAPTER_TRANSFER_FAILED

```solidity
string constant ADAPTER_TRANSFER_FAILED = "BA3";
```

### ADAPTER_WRONG_ASSET

```solidity
string constant ADAPTER_WRONG_ASSET = "BA4";
```

### ADAPTER_WRONG_ROLE

```solidity
string constant ADAPTER_WRONG_ROLE = "BA5";
```

### ADAPTER_ZERO_ADDRESS

```solidity
string constant ADAPTER_ZERO_ADDRESS = "BA6";
```

### ADAPTER_ZERO_AMOUNT

```solidity
string constant ADAPTER_ZERO_AMOUNT = "BA7";
```

### ADAPTER_INSUFFICIENT_BALANCE

```solidity
string constant ADAPTER_INSUFFICIENT_BALANCE = "BA8";
```

### BASEVAULT_ALREADY_INITIALIZED

```solidity
string constant BASEVAULT_ALREADY_INITIALIZED = "BV1";
```

### BASEVAULT_CONTRACT_NOT_FOUND

```solidity
string constant BASEVAULT_CONTRACT_NOT_FOUND = "BV2";
```

### BASEVAULT_INVALID_REGISTRY

```solidity
string constant BASEVAULT_INVALID_REGISTRY = "BV3";
```

### BASEVAULT_INVALID_VAULT

```solidity
string constant BASEVAULT_INVALID_VAULT = "BV4";
```

### BASEVAULT_NOT_INITIALIZED

```solidity
string constant BASEVAULT_NOT_INITIALIZED = "BV5";
```

### KBATCHRECEIVER_ALREADY_INITIALIZED

```solidity
string constant KBATCHRECEIVER_ALREADY_INITIALIZED = "B1";
```

### KBATCHRECEIVER_INVALID_BATCH_ID

```solidity
string constant KBATCHRECEIVER_INVALID_BATCH_ID = "B2";
```

### KBATCHRECEIVER_ONLY_KMINTER

```solidity
string constant KBATCHRECEIVER_ONLY_KMINTER = "B3";
```

### KBATCHRECEIVER_TRANSFER_FAILED

```solidity
string constant KBATCHRECEIVER_TRANSFER_FAILED = "B4";
```

### KBATCHRECEIVER_WRONG_ASSET

```solidity
string constant KBATCHRECEIVER_WRONG_ASSET = "B5";
```

### KBATCHRECEIVER_ZERO_ADDRESS

```solidity
string constant KBATCHRECEIVER_ZERO_ADDRESS = "B6";
```

### KBATCHRECEIVER_ZERO_AMOUNT

```solidity
string constant KBATCHRECEIVER_ZERO_AMOUNT = "B7";
```

### CUSTODIAL_INVALID_CUSTODIAL_ADDRESS

```solidity
string constant CUSTODIAL_INVALID_CUSTODIAL_ADDRESS = "C1";
```

### CUSTODIAL_TRANSFER_FAILED

```solidity
string constant CUSTODIAL_TRANSFER_FAILED = "C2";
```

### CUSTODIAL_VAULT_DESTINATION_NOT_SET

```solidity
string constant CUSTODIAL_VAULT_DESTINATION_NOT_SET = "C3";
```

### CUSTODIAL_WRONG_ASSET

```solidity
string constant CUSTODIAL_WRONG_ASSET = "C4";
```

### CUSTODIAL_WRONG_ROLE

```solidity
string constant CUSTODIAL_WRONG_ROLE = "C5";
```

### CUSTODIAL_ZERO_ADDRESS

```solidity
string constant CUSTODIAL_ZERO_ADDRESS = "C6";
```

### CUSTODIAL_ZERO_AMOUNT

```solidity
string constant CUSTODIAL_ZERO_AMOUNT = "C7";
```

### KBASE_ALREADY_INITIALIZED

```solidity
string constant KBASE_ALREADY_INITIALIZED = "K1";
```

### KBASE_INVALID_REGISTRY

```solidity
string constant KBASE_INVALID_REGISTRY = "K2";
```

### KBASE_NOT_INITIALIZED

```solidity
string constant KBASE_NOT_INITIALIZED = "K3";
```

### KBASE_WRONG_ROLE

```solidity
string constant KBASE_WRONG_ROLE = "K4";
```

### KBASE_ZERO_ADDRESS

```solidity
string constant KBASE_ZERO_ADDRESS = "K5";
```

### KBASE_ZERO_AMOUNT

```solidity
string constant KBASE_ZERO_AMOUNT = "K6";
```

### KBASE_TRANSFER_FAILED

```solidity
string constant KBASE_TRANSFER_FAILED = "K7";
```

### KBASE_WRONG_ASSET

```solidity
string constant KBASE_WRONG_ASSET = "K8";
```

### KBASE_CONTRACT_NOT_FOUND

```solidity
string constant KBASE_CONTRACT_NOT_FOUND = "K9";
```

### KBASE_ASSET_NOT_SUPPORTED

```solidity
string constant KBASE_ASSET_NOT_SUPPORTED = "K10";
```

### KBASE_INVALID_VAULT

```solidity
string constant KBASE_INVALID_VAULT = "K11";
```

### KMINTER_BATCH_CLOSED

```solidity
string constant KMINTER_BATCH_CLOSED = "M1";
```

### KMINTER_BATCH_SETTLED

```solidity
string constant KMINTER_BATCH_SETTLED = "M2";
```

### KMINTER_INSUFFICIENT_BALANCE

```solidity
string constant KMINTER_INSUFFICIENT_BALANCE = "M3";
```

### KMINTER_IS_PAUSED

```solidity
string constant KMINTER_IS_PAUSED = "M4";
```

### KMINTER_REQUEST_NOT_ELIGIBLE

```solidity
string constant KMINTER_REQUEST_NOT_ELIGIBLE = "M5";
```

### KMINTER_REQUEST_NOT_FOUND

```solidity
string constant KMINTER_REQUEST_NOT_FOUND = "M6";
```

### KMINTER_REQUEST_PROCESSED

```solidity
string constant KMINTER_REQUEST_PROCESSED = "M7";
```

### KMINTER_WRONG_ASSET

```solidity
string constant KMINTER_WRONG_ASSET = "M8";
```

### KMINTER_WRONG_ROLE

```solidity
string constant KMINTER_WRONG_ROLE = "M9";
```

### KMINTER_ZERO_ADDRESS

```solidity
string constant KMINTER_ZERO_ADDRESS = "M10";
```

### KMINTER_ZERO_AMOUNT

```solidity
string constant KMINTER_ZERO_AMOUNT = "M11";
```

### KREGISTRY_ADAPTER_ALREADY_SET

```solidity
string constant KREGISTRY_ADAPTER_ALREADY_SET = "R1";
```

### KREGISTRY_ALREADY_REGISTERED

```solidity
string constant KREGISTRY_ALREADY_REGISTERED = "R2";
```

### KREGISTRY_ASSET_NOT_SUPPORTED

```solidity
string constant KREGISTRY_ASSET_NOT_SUPPORTED = "R3";
```

### KREGISTRY_INVALID_ADAPTER

```solidity
string constant KREGISTRY_INVALID_ADAPTER = "R4";
```

### KREGISTRY_TRANSFER_FAILED

```solidity
string constant KREGISTRY_TRANSFER_FAILED = "R5";
```

### KREGISTRY_WRONG_ASSET

```solidity
string constant KREGISTRY_WRONG_ASSET = "R6";
```

### KREGISTRY_WRONG_ROLE

```solidity
string constant KREGISTRY_WRONG_ROLE = "R7";
```

### KREGISTRY_ZERO_ADDRESS

```solidity
string constant KREGISTRY_ZERO_ADDRESS = "R8";
```

### KREGISTRY_ZERO_AMOUNT

```solidity
string constant KREGISTRY_ZERO_AMOUNT = "R9";
```

### KREGISTRY_FEE_EXCEEDS_MAXIMUM

```solidity
string constant KREGISTRY_FEE_EXCEEDS_MAXIMUM = "R10";
```

### KSTAKINGVAULT_INSUFFICIENT_BALANCE

```solidity
string constant KSTAKINGVAULT_INSUFFICIENT_BALANCE = "SV1";
```

### KSTAKINGVAULT_IS_PAUSED

```solidity
string constant KSTAKINGVAULT_IS_PAUSED = "SV2";
```

### KSTAKINGVAULT_NOT_INITIALIZED

```solidity
string constant KSTAKINGVAULT_NOT_INITIALIZED = "SV3";
```

### KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE

```solidity
string constant KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE = "SV4";
```

### KSTAKINGVAULT_REQUEST_NOT_FOUND

```solidity
string constant KSTAKINGVAULT_REQUEST_NOT_FOUND = "SV5";
```

### KSTAKINGVAULT_UNAUTHORIZED

```solidity
string constant KSTAKINGVAULT_UNAUTHORIZED = "SV6";
```

### KSTAKINGVAULT_VAULT_CLOSED

```solidity
string constant KSTAKINGVAULT_VAULT_CLOSED = "SV7";
```

### KSTAKINGVAULT_VAULT_SETTLED

```solidity
string constant KSTAKINGVAULT_VAULT_SETTLED = "SV8";
```

### KSTAKINGVAULT_WRONG_ROLE

```solidity
string constant KSTAKINGVAULT_WRONG_ROLE = "SV9";
```

### KSTAKINGVAULT_ZERO_ADDRESS

```solidity
string constant KSTAKINGVAULT_ZERO_ADDRESS = "SV10";
```

### KSTAKINGVAULT_ZERO_AMOUNT

```solidity
string constant KSTAKINGVAULT_ZERO_AMOUNT = "SV11";
```

### KTOKEN_IS_PAUSED

```solidity
string constant KTOKEN_IS_PAUSED = "T1";
```

### KTOKEN_TRANSFER_FAILED

```solidity
string constant KTOKEN_TRANSFER_FAILED = "T2";
```

### KTOKEN_ZERO_ADDRESS

```solidity
string constant KTOKEN_ZERO_ADDRESS = "T3";
```

### KTOKEN_ZERO_AMOUNT

```solidity
string constant KTOKEN_ZERO_AMOUNT = "T4";
```

### VAULTBATCHES_NOT_CLOSED

```solidity
string constant VAULTBATCHES_NOT_CLOSED = "VB1";
```

### VAULTBATCHES_VAULT_CLOSED

```solidity
string constant VAULTBATCHES_VAULT_CLOSED = "VB2";
```

### VAULTBATCHES_VAULT_SETTLED

```solidity
string constant VAULTBATCHES_VAULT_SETTLED = "VB3";
```

### VAULTCLAIMS_BATCH_NOT_SETTLED

```solidity
string constant VAULTCLAIMS_BATCH_NOT_SETTLED = "VC1";
```

### VAULTCLAIMS_INVALID_BATCH_ID

```solidity
string constant VAULTCLAIMS_INVALID_BATCH_ID = "VC2";
```

### VAULTCLAIMS_NOT_BENEFICIARY

```solidity
string constant VAULTCLAIMS_NOT_BENEFICIARY = "VC4";
```

### VAULTCLAIMS_REQUEST_NOT_PENDING

```solidity
string constant VAULTCLAIMS_REQUEST_NOT_PENDING = "VC5";
```

### VAULTCLAIMS_ZERO_SHARE_PRICE

```solidity
string constant VAULTCLAIMS_ZERO_SHARE_PRICE = "VC6";
```

### VAULTFEES_FEE_EXCEEDS_MAXIMUM

```solidity
string constant VAULTFEES_FEE_EXCEEDS_MAXIMUM = "VF1";
```

### VAULTFEES_INVALID_TIMESTAMP

```solidity
string constant VAULTFEES_INVALID_TIMESTAMP = "VF2";
```

