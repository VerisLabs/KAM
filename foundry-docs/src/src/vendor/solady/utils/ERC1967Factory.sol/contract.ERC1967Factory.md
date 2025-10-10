# ERC1967Factory
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/vendor/solady/utils/ERC1967Factory.sol)

**Authors:**
Solady (https://github.com/vectorized/solady/blob/main/src/utils/ERC1967Factory.sol), jtriley-eth (https://github.com/jtriley-eth/minimum-viable-proxy)

Factory for deploying and managing ERC1967 proxy contracts.


## State Variables
### _UNAUTHORIZED_ERROR_SELECTOR
*`bytes4(keccak256(bytes("Unauthorized()")))`.*


```solidity
uint256 internal constant _UNAUTHORIZED_ERROR_SELECTOR = 0x82b42900;
```


### _DEPLOYMENT_FAILED_ERROR_SELECTOR
*`bytes4(keccak256(bytes("DeploymentFailed()")))`.*


```solidity
uint256 internal constant _DEPLOYMENT_FAILED_ERROR_SELECTOR = 0x30116425;
```


### _UPGRADE_FAILED_ERROR_SELECTOR
*`bytes4(keccak256(bytes("UpgradeFailed()")))`.*


```solidity
uint256 internal constant _UPGRADE_FAILED_ERROR_SELECTOR = 0x55299b49;
```


### _SALT_DOES_NOT_START_WITH_CALLER_ERROR_SELECTOR
*`bytes4(keccak256(bytes("SaltDoesNotStartWithCaller()")))`.*


```solidity
uint256 internal constant _SALT_DOES_NOT_START_WITH_CALLER_ERROR_SELECTOR = 0x2f634836;
```


### _ADMIN_CHANGED_EVENT_SIGNATURE
*`keccak256(bytes("AdminChanged(address,address)"))`.*


```solidity
uint256 internal constant _ADMIN_CHANGED_EVENT_SIGNATURE =
    0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f;
```


### _UPGRADED_EVENT_SIGNATURE
*`keccak256(bytes("Upgraded(address,address)"))`.*


```solidity
uint256 internal constant _UPGRADED_EVENT_SIGNATURE = 0x5d611f318680d00598bb735d61bacf0c514c6b50e1e5ad30040a4df2b12791c7;
```


### _DEPLOYED_EVENT_SIGNATURE
*`keccak256(bytes("Deployed(address,address,address)"))`.*


```solidity
uint256 internal constant _DEPLOYED_EVENT_SIGNATURE = 0xc95935a66d15e0da5e412aca0ad27ae891d20b2fb91cf3994b6a3bf2b8178082;
```


### _IMPLEMENTATION_SLOT
*The ERC-1967 storage slot for the implementation in the proxy.
`uint256(keccak256("eip1967.proxy.implementation")) - 1`.*


```solidity
uint256 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
```


## Functions
### adminOf

*Returns the admin of the proxy.*


```solidity
function adminOf(address proxy) public view returns (address admin);
```

### changeAdmin

*Sets the admin of the proxy.
The caller of this function must be the admin of the proxy on this factory.*


```solidity
function changeAdmin(address proxy, address admin) public;
```

### upgrade

*Upgrades the proxy to point to `implementation`.
The caller of this function must be the admin of the proxy on this factory.*


```solidity
function upgrade(address proxy, address implementation) public payable;
```

### upgradeAndCall

*Upgrades the proxy to point to `implementation`.
Then, calls the proxy with abi encoded `data`.
The caller of this function must be the admin of the proxy on this factory.*


```solidity
function upgradeAndCall(address proxy, address implementation, bytes calldata data) public payable;
```

### deploy

*Deploys a proxy for `implementation`, with `admin`,
and returns its address.
The value passed into this function will be forwarded to the proxy.*


```solidity
function deploy(address implementation, address admin) public payable returns (address proxy);
```

### deployAndCall

*Deploys a proxy for `implementation`, with `admin`,
and returns its address.
The value passed into this function will be forwarded to the proxy.
Then, calls the proxy with abi encoded `data`.*


```solidity
function deployAndCall(
    address implementation,
    address admin,
    bytes calldata data
)
    public
    payable
    returns (address proxy);
```

### deployDeterministic

*Deploys a proxy for `implementation`, with `admin`, `salt`,
and returns its deterministic address.
The value passed into this function will be forwarded to the proxy.*


```solidity
function deployDeterministic(
    address implementation,
    address admin,
    bytes32 salt
)
    public
    payable
    returns (address proxy);
```

### deployDeterministicAndCall

*Deploys a proxy for `implementation`, with `admin`, `salt`,
and returns its deterministic address.
The value passed into this function will be forwarded to the proxy.
Then, calls the proxy with abi encoded `data`.*


```solidity
function deployDeterministicAndCall(
    address implementation,
    address admin,
    bytes32 salt,
    bytes calldata data
)
    public
    payable
    returns (address proxy);
```

### _deploy

*Deploys the proxy, with optionality to deploy deterministically with a `salt`.*


```solidity
function _deploy(
    address implementation,
    address admin,
    bytes32 salt,
    bool useSalt,
    bytes calldata data
)
    internal
    returns (address proxy);
```

### predictDeterministicAddress

*Returns the address of the proxy deployed with `salt`.*


```solidity
function predictDeterministicAddress(bytes32 salt) public view returns (address predicted);
```

### initCodeHash

*Returns the initialization code hash of the proxy.
Used for mining vanity addresses with create2crunch.*


```solidity
function initCodeHash() public view returns (bytes32 result);
```

### _initCode

*Returns a pointer to the initialization code of a proxy created via this factory.*


```solidity
function _initCode() internal view returns (bytes32 m);
```

### _emptyData

*Helper function to return an empty bytes calldata.*


```solidity
function _emptyData() internal pure returns (bytes calldata data);
```

## Events
### AdminChanged
*The admin of a proxy contract has been changed.*


```solidity
event AdminChanged(address indexed proxy, address indexed admin);
```

### Upgraded
*The implementation for a proxy has been upgraded.*


```solidity
event Upgraded(address indexed proxy, address indexed implementation);
```

### Deployed
*A proxy has been deployed.*


```solidity
event Deployed(address indexed proxy, address indexed implementation, address indexed admin);
```

## Errors
### Unauthorized
*The caller is not authorized to call the function.*


```solidity
error Unauthorized();
```

### DeploymentFailed
*The proxy deployment failed.*


```solidity
error DeploymentFailed();
```

### UpgradeFailed
*The upgrade failed.*


```solidity
error UpgradeFailed();
```

### SaltDoesNotStartWithCaller
*The salt does not start with the caller.*


```solidity
error SaltDoesNotStartWithCaller();
```

