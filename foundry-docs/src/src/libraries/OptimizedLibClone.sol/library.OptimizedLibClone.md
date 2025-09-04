# OptimizedLibClone
[Git Source](https://github.com/VerisLabs/KAM/blob/9902b1ea80f671449ee88e1d19504fe796d0d9a5/src/libraries/OptimizedLibClone.sol)

**Authors:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/OptimizedLibClone.sol), Minimal proxy by 0age (https://github.com/0age), Clones with immutable args by wighawag, zefram.eth, Saw-mon & Natalie
(https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args), Minimal ERC1967 proxy by jtriley-eth (https://github.com/jtriley-eth/minimum-viable-proxy)

Minimal proxy library.

*Minimal proxy:
Although the sw0nt pattern saves 5 gas over the ERC1167 pattern during runtime,
it is not supported out-of-the-box on Etherscan. Hence, we choose to use the 0age pattern,
which saves 4 gas over the ERC1167 pattern during runtime, and has the smallest bytecode.
- Automatically verified on Etherscan.*

*Minimal proxy (PUSH0 variant):
This is a new minimal proxy that uses the PUSH0 opcode introduced during Shanghai.
It is optimized first for minimal runtime gas, then for minimal bytecode.
The PUSH0 clone functions are intentionally postfixed with a jarring "_PUSH0" as
many EVM chains may not support the PUSH0 opcode in the early months after Shanghai.
Please use with caution.
- Automatically verified on Etherscan.*

*Clones with immutable args (CWIA):
The implementation of CWIA here does NOT append the immutable args into the calldata
passed into delegatecall. It is simply an ERC1167 minimal proxy with the immutable arguments
appended to the back of the runtime bytecode.
- Uses the identity precompile (0x4) to copy args during deployment.*

*Minimal ERC1967 proxy:
A minimal ERC1967 proxy, intended to be upgraded with UUPS.
This is NOT the same as ERC1967Factory's transparent proxy, which includes admin logic.
- Automatically verified on Etherscan.*

*Minimal ERC1967 proxy with immutable args:
- Uses the identity precompile (0x4) to copy args during deployment.
- Automatically verified on Etherscan.*

*ERC1967I proxy:
A variant of the minimal ERC1967 proxy, with a special code path that activates
if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
`implementation` address. The returned implementation is guaranteed to be valid if the
keccak256 of the proxy's code is equal to `ERC1967I_CODE_HASH`.*

*ERC1967I proxy with immutable args:
A variant of the minimal ERC1967 proxy, with a special code path that activates
if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
- Uses the identity precompile (0x4) to copy args during deployment.*

*Minimal ERC1967 beacon proxy:
A minimal beacon proxy, intended to be upgraded with an upgradable beacon.
- Automatically verified on Etherscan.*

*Minimal ERC1967 beacon proxy with immutable args:
- Uses the identity precompile (0x4) to copy args during deployment.
- Automatically verified on Etherscan.*

*ERC1967I beacon proxy:
A variant of the minimal ERC1967 beacon proxy, with a special code path that activates
if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
`implementation` address. The returned implementation is guaranteed to be valid if the
keccak256 of the proxy's code is equal to `ERC1967I_CODE_HASH`.*

*ERC1967I proxy with immutable args:
A variant of the minimal ERC1967 beacon proxy, with a special code path that activates
if `calldatasize() == 1`. This code path skips the delegatecall and directly returns the
- Uses the identity precompile (0x4) to copy args during deployment.*


## Functions
### clone

*Deploys a clone of `implementation`.*


```solidity
function clone(address implementation) internal returns (address instance);
```

### clone

*Deploys a clone of `implementation`.
Deposits `value` ETH during deployment.*


```solidity
function clone(uint256 value, address implementation) internal returns (address instance);
```

## Errors
### DeploymentFailed
*Unable to deploy the clone.*


```solidity
error DeploymentFailed();
```

