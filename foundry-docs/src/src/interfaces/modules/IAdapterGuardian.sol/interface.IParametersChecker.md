# IParametersChecker
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/interfaces/modules/IAdapterGuardian.sol)


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

