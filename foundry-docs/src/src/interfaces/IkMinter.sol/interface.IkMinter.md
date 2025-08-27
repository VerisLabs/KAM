# IkMinter
[Git Source](https://github.com/VerisLabs/KAM/blob/21fc681bf8c3b068c4bafc99872278de3ba557fb/src/interfaces/IkMinter.sol)

Interface for kMinter


## Functions
### mint


```solidity
function mint(address asset, address to, uint256 amount) external payable;
```

### requestRedeem


```solidity
function requestRedeem(address asset, address to, uint256 amount) external payable returns (bytes32 requestId);
```

### redeem


```solidity
function redeem(bytes32 requestId) external payable;
```

### cancelRequest


```solidity
function cancelRequest(bytes32 requestId) external payable;
```

### rescueReceiverAssets


```solidity
function rescueReceiverAssets(address batchReceiver, address asset, address to, uint256 amount) external;
```

### isPaused


```solidity
function isPaused() external view returns (bool);
```

### getRedeemRequest


```solidity
function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);
```

### getUserRequests


```solidity
function getUserRequests(address user) external view returns (bytes32[] memory);
```

### getRequestCounter


```solidity
function getRequestCounter() external view returns (uint256);
```

## Events
### ContractInitialized

```solidity
event ContractInitialized(address indexed registry);
```

### Minted

```solidity
event Minted(address indexed to, uint256 amount, bytes32 batchId);
```

### RedeemRequestCreated

```solidity
event RedeemRequestCreated(
    bytes32 indexed requestId,
    address indexed user,
    address indexed kToken,
    uint256 amount,
    address recipient,
    bytes32 batchId
);
```

### Redeemed

```solidity
event Redeemed(bytes32 indexed requestId);
```

### Cancelled

```solidity
event Cancelled(bytes32 indexed requestId);
```

## Errors
### InsufficientBalance

```solidity
error InsufficientBalance();
```

### RequestNotFound

```solidity
error RequestNotFound();
```

### RequestNotEligible

```solidity
error RequestNotEligible();
```

### RequestAlreadyProcessed

```solidity
error RequestAlreadyProcessed();
```

### BatchClosed

```solidity
error BatchClosed();
```

### BatchSettled

```solidity
error BatchSettled();
```

## Structs
### RedeemRequest

```solidity
struct RedeemRequest {
    address user;
    uint256 amount;
    address asset;
    uint64 requestTimestamp;
    RequestStatus status;
    bytes32 batchId;
    address recipient;
}
```

## Enums
### RequestStatus

```solidity
enum RequestStatus {
    PENDING,
    REDEEMED,
    CANCELLED
}
```

