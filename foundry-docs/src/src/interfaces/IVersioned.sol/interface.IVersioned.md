# IVersioned
[Git Source](https://github.com/VerisLabs/KAM/blob/e73c6a1672196804f5e06d5429d895045a4c6974/src/interfaces/IVersioned.sol)

Standard interface for contract versioning in upgradable contracts

*This interface provides a standardized way to query contract identity and version information
for upgradable contracts. It enables consistent version tracking across the protocol, supports
upgrade management, and allows for contract discovery and validation. All upgradable contracts
in the KAM protocol should implement this interface to maintain consistency and enable proper
version control during upgrades.*


## Functions
### contractName

Returns the human-readable name identifier for this contract type

*Used for contract identification and logging purposes. The name should be consistent
across all versions of the same contract type. This enables external systems and other
contracts to identify the contract's purpose and role within the protocol ecosystem.*


```solidity
function contractName() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract name as a string (e.g., "kMinter", "kAssetRouter", "kRegistry")|


### contractVersion

Returns the version identifier for this contract implementation

*Used for upgrade management and compatibility checking within the protocol. The version
string should follow semantic versioning (e.g., "1.0.0") to clearly indicate major, minor,
and patch updates. This enables the protocol governance and monitoring systems to track
deployed versions and ensure compatibility between interacting components.*


```solidity
function contractVersion() external pure returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The contract version as a string following semantic versioning (e.g., "1.0.0")|


