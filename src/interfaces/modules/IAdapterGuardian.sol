// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IParametersChecker {
    function authorizeAdapterCall(address adapter, address target, bytes4 selector, bytes calldata params) external view returns (bool);
}

/// @title IAdapterGuardian
interface IAdapterGuardian {

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when an adapter is registered or unregistered
    event AdapterRegistered(address indexed adapter, bool registered);

    /// @notice Emitted when a selector is allowed or disallowed for an adapter
    event SelectorAllowed(address indexed adapter, address indexed target, bytes4 indexed selector, bool allowed);

    /// @notice Emitted when a parameter checker is set for an adapter selector
    event ParametersCheckerSet(
        address indexed adapter,
        address indexed target,
        bytes4 indexed selector,
        address parametersChecker
    );

    /*//////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Set whether a selector is allowed for an adapter on a target contract
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param isAllowed Whether the selector is allowed
    /// @dev Only callable by ADMIN_ROLE
    function setAdapterAllowedSelector(address adapter,address target,bytes4 selector,bool isAllowed) external;

    /// @notice Set a parameter checker for an adapter selector
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param parametersChecker The parameter checker contract address (0x0 to remove)
    /// @dev Only callable by ADMIN_ROLE
    function setAdapterParametersChecker(address adapter, address target, bytes4 selector, address parametersChecker ) external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if an adapter is authorized to call a specific function on a target
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param params The function parameters
    function authorizeAdapterCall(address target,bytes4 selector,bytes calldata params) external view;

    /// @notice Check if a selector is allowed for an adapter
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return Whether the selector is allowed
    function isAdapterSelectorAllowed(address adapter,address target,bytes4 selector) external view returns (bool);

    /// @notice Get the parameter checker for an adapter selector
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return The parameter checker address (address(0) if none)
    function getAdapterParametersChecker(address adapter,address target,bytes4 selector) external view returns (address);
}