// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IModule
/// @notice Modules are special contracts that extend the functionality of other contracts
interface IModule {
    /// @notice Returns the selectors for functions in this module
    /// @return moduleSelectors Array of function selectors
    function selectors() external view returns (bytes4[] memory);
}
