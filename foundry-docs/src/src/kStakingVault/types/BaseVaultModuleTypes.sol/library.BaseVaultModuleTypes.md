<<<<<<< HEAD
# BaseVaultTypes
[Git Source](https://github.com/VerisLabs/KAM/blob/77168a37e8e40e14b0fd1320a6e90f9203339144/src/kStakingVault/types/BaseVaultTypes.sol)
=======
# BaseVaultTypes
[Git Source](https://github.com/VerisLabs/KAM/blob/786bfc5b94e4c849db94b9fb47f71818d5cce1ab/src/kStakingVault/types/BaseVaultTypes.sol)
>>>>>>> development

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

