# IERC7540
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/IERC7540.sol)

SPDX-License-Identifier: MIT


## Functions
### balanceOf


```solidity
function balanceOf(address) external view returns (uint256);
```

### name


```solidity
function name() external view returns (string memory);
```

### symbol


```solidity
function symbol() external view returns (string memory);
```

### decimals


```solidity
function decimals() external view returns (uint8);
```

### asset


```solidity
function asset() external view returns (address);
```

### totalAssets


```solidity
function totalAssets() external view returns (uint256 assets);
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256 assets);
```

### convertToAssets


```solidity
function convertToAssets(uint256) external view returns (uint256);
```

### convertToShares


```solidity
function convertToShares(uint256) external view returns (uint256);
```

### setOperator


```solidity
function setOperator(address, bool) external;
```

### isOperator


```solidity
function isOperator(address, address) external view returns (bool);
```

### requestDeposit


```solidity
function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);
```

### deposit


```solidity
function deposit(uint256 assets, address to) external returns (uint256 shares);
```

### deposit


```solidity
function deposit(uint256 assets, address to, address controller) external returns (uint256 shares);
```

### requestRedeem


```solidity
function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);
```

### redeem


```solidity
function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets);
```

### withdraw


```solidity
function withdraw(uint256 assets, address receiver, address controller) external returns (uint256 shares);
```

### pendingRedeemRequest


```solidity
function pendingRedeemRequest(address) external view returns (uint256);
```

### claimableRedeemRequest


```solidity
function claimableRedeemRequest(address) external view returns (uint256);
```

### pendingProcessedShares


```solidity
function pendingProcessedShares(address) external view returns (uint256);
```

### pendingDepositRequest


```solidity
function pendingDepositRequest(address) external view returns (uint256);
```

### claimableDepositRequest


```solidity
function claimableDepositRequest(address) external view returns (uint256);
```

### transfer


```solidity
function transfer(address, uint256) external returns (bool);
```

### transferFrom


```solidity
function transferFrom(address, address, uint256) external returns (bool);
```

### lastRedeem


```solidity
function lastRedeem(address) external view returns (uint256);
```

### approve


```solidity
function approve(address, uint256) external returns (bool);
```

### allowance


```solidity
function allowance(address, address) external view returns (uint256);
```

