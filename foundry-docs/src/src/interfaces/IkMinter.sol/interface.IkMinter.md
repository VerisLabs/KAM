# IkMinter
[Git Source](https://github.com/VerisLabs/KAM/blob/d9f3bcfb40b15ca7c34b1d780c519322be4b7590/src/interfaces/IkMinter.sol)

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

### setPaused


```solidity
function setPaused(bool paused) external;
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
### Initialized

```solidity
event Initialized(address indexed registry, address indexed owner, address admin, address emergencyAdmin);
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
### ZeroAmount

```solidity
error ZeroAmount();
```

### BatchNotSettled

```solidity
error BatchNotSettled();
```

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

### OnlyInstitution

```solidity
error OnlyInstitution();
```

### BatchClosed

```solidity
error BatchClosed();
```

### BatchSettled

```solidity
error BatchSettled();
```

### ContractPaused

```solidity
error ContractPaused();
```

### InvalidAsset

```solidity
error InvalidAsset();
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

