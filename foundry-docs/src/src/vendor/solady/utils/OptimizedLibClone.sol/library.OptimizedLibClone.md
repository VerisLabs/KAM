# OptimizedLibClone
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/vendor/solady/utils/OptimizedLibClone.sol)

**Authors:**
Originally by Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibClone.sol), Minimal proxy by 0age (https://github.com/0age), Clones with immutable args by wighawag, zefram.eth, Saw-mon & Natalie
(https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args), Minimal ERC1967 proxy by jtriley-eth (https://github.com/jtriley-eth/minimum-viable-proxy)

Minimal proxy library.

*NOTE: This is a reduced version of the original Solady library.
We have extracted only the necessary cloning functionality to optimize contract size.
Original code by Solady, modified for size optimization.*


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

