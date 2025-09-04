# SafeTransferLib
[Git Source](https://github.com/VerisLabs/KAM/blob/bbd875989135c7d3f313fa3fcc61e94d6afb4346/src/vendor/SafeTransferLib.sol)

**Authors:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeTransferLib.sol), Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol), Permit2 operations from (https://github.com/Uniswap/permit2/blob/main/src/libraries/Permit2Lib.sol)

Safe ETH and ERC20 transfer library that gracefully handles missing return values.

*Note:
- For ETH transfers, please use `forceSafeTransferETH` for DoS protection.*


## State Variables
### GAS_STIPEND_NO_STORAGE_WRITES
*Suggested gas stipend for contract receiving ETH that disallows any storage writes.*


```solidity
uint256 internal constant GAS_STIPEND_NO_STORAGE_WRITES = 2300;
```


### GAS_STIPEND_NO_GRIEF
*Suggested gas stipend for contract receiving ETH to perform a few
storage reads and writes, but low enough to prevent griefing.*


```solidity
uint256 internal constant GAS_STIPEND_NO_GRIEF = 100_000;
```


### DAI_DOMAIN_SEPARATOR
*The unique EIP-712 domain separator for the DAI token contract.*


```solidity
bytes32 internal constant DAI_DOMAIN_SEPARATOR = 0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;
```


### WETH9
*The address for the WETH9 contract on Ethereum mainnet.*


```solidity
address internal constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
```


### PERMIT2
*The canonical Permit2 address.
[Github](https://github.com/Uniswap/permit2)
[Etherscan](https://etherscan.io/address/0x000000000022D473030F116dDEE9F6B43aC78BA3)*


```solidity
address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
```


## Functions
### safeTransferETH

*Sends `amount` (in wei) ETH to `to`.*


```solidity
function safeTransferETH(address to, uint256 amount) internal;
```

### safeTransferAllETH

*Sends all the ETH in the current contract to `to`.*


```solidity
function safeTransferAllETH(address to) internal;
```

### forceSafeTransferETH

*Force sends `amount` (in wei) ETH to `to`, with a `gasStipend`.*


```solidity
function forceSafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal;
```

### forceSafeTransferAllETH

*Force sends all the ETH in the current contract to `to`, with a `gasStipend`.*


```solidity
function forceSafeTransferAllETH(address to, uint256 gasStipend) internal;
```

### forceSafeTransferETH

*Force sends `amount` (in wei) ETH to `to`, with `GAS_STIPEND_NO_GRIEF`.*


```solidity
function forceSafeTransferETH(address to, uint256 amount) internal;
```

### forceSafeTransferAllETH

*Force sends all the ETH in the current contract to `to`, with `GAS_STIPEND_NO_GRIEF`.*


```solidity
function forceSafeTransferAllETH(address to) internal;
```

### trySafeTransferETH

*Sends `amount` (in wei) ETH to `to`, with a `gasStipend`.*


```solidity
function trySafeTransferETH(address to, uint256 amount, uint256 gasStipend) internal returns (bool success);
```

### trySafeTransferAllETH

*Sends all the ETH in the current contract to `to`, with a `gasStipend`.*


```solidity
function trySafeTransferAllETH(address to, uint256 gasStipend) internal returns (bool success);
```

### safeTransferFrom

*Sends `amount` of ERC20 `token` from `from` to `to`.
Reverts upon failure.
The `from` account must have at least `amount` approved for
the current contract to manage.*


```solidity
function safeTransferFrom(address token, address from, address to, uint256 amount) internal;
```

### trySafeTransferFrom

*Sends `amount` of ERC20 `token` from `from` to `to`.
The `from` account must have at least `amount` approved for the current contract to manage.*


```solidity
function trySafeTransferFrom(address token, address from, address to, uint256 amount) internal returns (bool success);
```

### safeTransferAllFrom

*Sends all of ERC20 `token` from `from` to `to`.
Reverts upon failure.
The `from` account must have their entire balance approved for the current contract to manage.*


```solidity
function safeTransferAllFrom(address token, address from, address to) internal returns (uint256 amount);
```

### safeTransfer

*Sends `amount` of ERC20 `token` from the current contract to `to`.
Reverts upon failure.*


```solidity
function safeTransfer(address token, address to, uint256 amount) internal;
```

### safeTransferAll

*Sends all of ERC20 `token` from the current contract to `to`.
Reverts upon failure.*


```solidity
function safeTransferAll(address token, address to) internal returns (uint256 amount);
```

### safeApprove

*Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
Reverts upon failure.*


```solidity
function safeApprove(address token, address to, uint256 amount) internal;
```

### safeApproveWithRetry

*Sets `amount` of ERC20 `token` for `to` to manage on behalf of the current contract.
If the initial attempt to approve fails, attempts to reset the approved amount to zero,
then retries the approval again (some tokens, e.g. USDT, requires this).
Reverts upon failure.*


```solidity
function safeApproveWithRetry(address token, address to, uint256 amount) internal;
```

### balanceOf

*Returns the amount of ERC20 `token` owned by `account`.
Returns zero if the `token` does not exist.*


```solidity
function balanceOf(address token, address account) internal view returns (uint256 amount);
```

### checkBalanceOf

*Performs a `token.balanceOf(account)` check.
`implemented` denotes whether the `token` does not implement `balanceOf`.
`amount` is zero if the `token` does not implement `balanceOf`.*


```solidity
function checkBalanceOf(address token, address account) internal view returns (bool implemented, uint256 amount);
```

### totalSupply

*Returns the total supply of the `token`.
Reverts if the token does not exist or does not implement `totalSupply()`.*


```solidity
function totalSupply(address token) internal view returns (uint256 result);
```

### safeTransferFrom2

*Sends `amount` of ERC20 `token` from `from` to `to`.
If the initial attempt fails, try to use Permit2 to transfer the token.
Reverts upon failure.
The `from` account must have at least `amount` approved for the current contract to manage.*


```solidity
function safeTransferFrom2(address token, address from, address to, uint256 amount) internal;
```

### permit2TransferFrom

*Sends `amount` of ERC20 `token` from `from` to `to` via Permit2.
Reverts upon failure.*


```solidity
function permit2TransferFrom(address token, address from, address to, uint256 amount) internal;
```

### permit2

*Permit a user to spend a given amount of
another user's tokens via native EIP-2612 permit if possible, falling
back to Permit2 if native permit fails or is not implemented on the token.*


```solidity
function permit2(
    address token,
    address owner,
    address spender,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
)
    internal;
```

### simplePermit2

*Simple permit on the Permit2 contract.*


```solidity
function simplePermit2(
    address token,
    address owner,
    address spender,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
)
    internal;
```

### permit2Approve

*Approves `spender` to spend `amount` of `token` for `address(this)`.*


```solidity
function permit2Approve(address token, address spender, uint160 amount, uint48 expiration) internal;
```

### permit2Lockdown

*Revokes an approval for `token` and `spender` for `address(this)`.*


```solidity
function permit2Lockdown(address token, address spender) internal;
```

## Errors
### ETHTransferFailed
*The ETH transfer has failed.*


```solidity
error ETHTransferFailed();
```

### TransferFromFailed
*The ERC20 `transferFrom` has failed.*


```solidity
error TransferFromFailed();
```

### TransferFailed
*The ERC20 `transfer` has failed.*


```solidity
error TransferFailed();
```

### ApproveFailed
*The ERC20 `approve` has failed.*


```solidity
error ApproveFailed();
```

### TotalSupplyQueryFailed
*The ERC20 `totalSupply` query has failed.*


```solidity
error TotalSupplyQueryFailed();
```

### Permit2Failed
*The Permit2 operation has failed.*


```solidity
error Permit2Failed();
```

### Permit2AmountOverflow
*The Permit2 amount must be less than `2**160 - 1`.*


```solidity
error Permit2AmountOverflow();
```

### Permit2ApproveFailed
*The Permit2 approve operation has failed.*


```solidity
error Permit2ApproveFailed();
```

### Permit2LockdownFailed
*The Permit2 lockdown operation has failed.*


```solidity
error Permit2LockdownFailed();
```

