# BaseVaultTypes
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/kStakingVault/types/BaseVaultTypes.sol)

Library containing all data structures used in the ModuleBase

*Defines standardized data types for cross-contract communication and storage*


## Structs
### StakeRequest
Stake request structure


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
Unstake request structure


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
Batch information structure


```solidity
struct BatchInfo {
    address batchReceiver;
    bool isClosed;
    bool isSettled;
    bytes32 batchId;
    uint128 sharePrice;
    uint128 netSharePrice;
}
```

## Enums
### RequestStatus
Request status


```solidity
enum RequestStatus {
    PENDING,
    CLAIMED,
    CANCELLED
}
```

