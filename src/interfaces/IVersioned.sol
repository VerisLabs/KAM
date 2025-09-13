// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IVersioned
/// @notice Standard interface for contract versioning in upgradable contracts
/// @dev This interface provides a standardized way to query contract identity and version information
/// for upgradable contracts. It enables consistent version tracking across the protocol, supports
/// upgrade management, and allows for contract discovery and validation. All upgradable contracts
/// in the KAM protocol should implement this interface to maintain consistency and enable proper
/// version control during upgrades.
interface IVersioned {
    /// @notice Returns the human-readable name identifier for this contract type
    /// @dev Used for contract identification and logging purposes. The name should be consistent
    /// across all versions of the same contract type. This enables external systems and other
    /// contracts to identify the contract's purpose and role within the protocol ecosystem.
    /// @return The contract name as a string (e.g., "kMinter", "kAssetRouter", "kRegistry")
    function contractName() external pure returns (string memory);

    /// @notice Returns the version identifier for this contract implementation
    /// @dev Used for upgrade management and compatibility checking within the protocol. The version
    /// string should follow semantic versioning (e.g., "1.0.0") to clearly indicate major, minor,
    /// and patch updates. This enables the protocol governance and monitoring systems to track
    /// deployed versions and ensure compatibility between interacting components.
    /// @return The contract version as a string following semantic versioning (e.g., "1.0.0")
    function contractVersion() external pure returns (string memory);
}
