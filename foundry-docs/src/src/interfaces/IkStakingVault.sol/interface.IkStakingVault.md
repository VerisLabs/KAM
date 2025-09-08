# IkStakingVault
[Git Source](https://github.com/VerisLabs/KAM/blob/3f66acab797e6ddb71d2b17eb97d3be17c371dac/src/interfaces/IkStakingVault.sol)

**Inherits:**
[IVault](/src/interfaces/IVault.sol/interface.IVault.md), [IVaultReader](/src/interfaces/modules/IVaultReader.sol/interface.IVaultReader.md)

Comprehensive interface combining retail staking operations with ERC20 share tokens and vault state reading

*This interface aggregates all kStakingVault functionality by extending IVault (staking/batch/claims/fees) and
IVaultReader (state queries) while adding standard ERC20 operations for stkToken management. The interface provides
a complete view of vault capabilities: (1) Staking Operations: Full request/claim lifecycle for retail users,
(2) Batch Management: Lifecycle control for settlement periods, (3) Share Tokens: Standard ERC20 functionality for
stkTokens that accrue yield, (4) State Reading: Comprehensive vault metrics and calculations, (5) Fee Management:
Performance and management fee configuration. This unified interface enables complete vault interaction through a
single contract, simplifying integration for front-ends and external protocols while maintaining modularity through
interface composition. The combination of vault-specific operations with standard ERC20 compatibility ensures
stkTokens work seamlessly with existing DeFi infrastructure while providing specialized staking functionality.*


## Functions
### owner

Returns the owner of the contract


```solidity
function owner() external view returns (address);
```

### name

Returns the name of the token


```solidity
function name() external view returns (string memory);
```

### symbol

Returns the symbol of the token


```solidity
function symbol() external view returns (string memory);
```

### decimals

Returns the decimals of the token


```solidity
function decimals() external view returns (uint8);
```

### totalSupply

Returns the total supply of the token


```solidity
function totalSupply() external view returns (uint256);
```

### balanceOf

Returns the balance of the specified account


```solidity
function balanceOf(address account) external view returns (uint256);
```

### transfer

Transfers tokens to the specified recipient


```solidity
function transfer(address to, uint256 amount) external returns (bool);
```

### allowance

Returns the remaining allowance that spender has to spend on behalf of owner


```solidity
function allowance(address owner, address spender) external view returns (uint256);
```

### approve

Sets amount as the allowance of spender over the caller's tokens


```solidity
function approve(address spender, uint256 amount) external returns (bool);
```

### transferFrom

Transfers tokens from sender to recipient using the allowance mechanism


```solidity
function transferFrom(address from, address to, uint256 amount) external returns (bool);
```

