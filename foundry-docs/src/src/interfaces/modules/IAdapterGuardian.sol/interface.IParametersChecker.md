# IParametersChecker
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/modules/IAdapterGuardian.sol)


## Functions
### authorizeAdapterCall


```solidity
function authorizeAdapterCall(
    address adapter,
    address target,
    bytes4 selector,
    bytes calldata params
)
    external
    view
    returns (bool);
```

