/// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IProcessRouterModule {
    /// @dev Sets the processId to target and selector
    /// @param processId The processId to set
    /// @param targets The targets to set
    /// @param selectors_ The selectors to set
    function setProcessId(bytes32 processId, address[] memory targets, bytes4[] memory selectors_) external;

    /// @dev Gets the processId to target and selector
    /// @param processId The processId to get
    /// @return targets The targets to get
    /// @return selectors_ The selectors to get
    function getProcess(bytes32 processId) external view returns (address[] memory targets, bytes4[] memory selectors_);

    /// @dev Gets the function selector for a function signature
    /// @param functionSignature The function signature to get the selector for
    /// @return selector The selector for the function signature
    function getfunctionSelector(string memory functionSignature) external view returns (bytes4 selector);
}