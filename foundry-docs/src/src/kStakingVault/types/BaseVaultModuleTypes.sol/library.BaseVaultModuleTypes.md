# BaseVaultModuleTypes
[Git Source](https://github.com/VerisLabs/KAM/blob/066df01f2df627ed53b6b3edc701dad6646b8be7/src/kStakingVault/types/BaseVaultModuleTypes.sol)

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

