# BaseVaultModuleTypes
[Git Source](https://github.com/VerisLabs/KAM/blob/2cfac335d9060b60757c350b6581b2ed1a8a6b82/src/kStakingVault/types/BaseVaultModuleTypes.sol)

Library containing all data structures used in the ModuleBase

*Defines standardized data types for cross-contract communication and storage*


## Structs
### StakeRequest

```solidity
struct StakeRequest {
    address user;
    uint128 kTokenAmount;
    address recipient;
    bytes32 batchId;
    uint64 requestTimestamp;
    RequestStatus status;
}
```

### UnstakeRequest

```solidity
struct UnstakeRequest {
    address user;
    uint128 stkTokenAmount;
    address recipient;
    bytes32 batchId;
    uint64 requestTimestamp;
    RequestStatus status;
}
```

### BatchInfo

```solidity
struct BatchInfo {
    bytes32 batchId;
    address batchReceiver;
    bool isClosed;
    bool isSettled;
}
```

## Enums
### RequestStatus

```solidity
enum RequestStatus {
    PENDING,
    CLAIMED,
    CANCELLED
}
```

