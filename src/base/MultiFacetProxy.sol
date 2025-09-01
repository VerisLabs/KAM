// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Proxy } from "src/abstracts/Proxy.sol";

/// @title MultiFacetProxy
/// @notice A proxy contract that can route function calls to different implementation contracts
/// @dev Inherits from Base and OpenZeppelin's Proxy contract
abstract contract MultiFacetProxy is Proxy {
    // keccak256(abi.encode(uint256(keccak256("kam.storage.MultiFacetProxy")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant MULTIFACET_PROXY_STORAGE_LOCATION =
        0xfeaf205b5229ea10e902c7b89e4768733c756362b2becb0bfd65a97f71b02d00;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    struct MultiFacetProxyStorage {
        /// @notice Mapping of chain method selectors to implementation contracts
        mapping(bytes4 => address) selectorToImplementation;
    }

    /// @notice Returns the MultiFacetProxy storage struct using ERC-7201 pattern
    /// @return $ Storage reference for MultiFacetProxy state variables
    function _getMultiFacetProxyStorage() internal pure returns (MultiFacetProxyStorage storage $) {
        assembly {
            $.slot := MULTIFACET_PROXY_STORAGE_LOCATION
        }
    }

    /// @notice Adds a function selector mapping to an implementation address
    /// @param selector The function selector to add
    /// @param implementation The implementation contract address
    /// @param forceOverride If true, allows overwriting existing mappings
    /// @dev Only callable by admin role
    function addFunction(bytes4 selector, address implementation, bool forceOverride) public {
        _authorizeModifyFunctions(msg.sender);
        MultiFacetProxyStorage storage $ = _getMultiFacetProxyStorage();
        if (!forceOverride) {
            if ($.selectorToImplementation[selector] != address(0)) revert();
        }
        $.selectorToImplementation[selector] = implementation;
    }

    /// @notice Adds multiple function selector mappings to an implementation
    /// @param selectors Array of function selectors to add
    /// @param implementation The implementation contract address
    /// @param forceOverride If true, allows overwriting existing mappings
    /// @dev Only callable by admin role
    function addFunctions(bytes4[] calldata selectors, address implementation, bool forceOverride) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            addFunction(selectors[i], implementation, forceOverride);
        }
    }

    /// @notice Removes a function selector mapping
    /// @param selector The function selector to remove
    /// @dev Only callable by admin role
    function removeFunction(bytes4 selector) public {
        _authorizeModifyFunctions(msg.sender);
        MultiFacetProxyStorage storage $ = _getMultiFacetProxyStorage();
        delete $.selectorToImplementation[selector];
    }

    /// @notice Removes multiple function selector mappings
    /// @param selectors Array of function selectors to remove
    function removeFunctions(bytes4[] calldata selectors) external {
        for (uint256 i = 0; i < selectors.length; i++) {
            removeFunction(selectors[i]);
        }
    }

    /// @dev Authorize the sender to modify functions
    function _authorizeModifyFunctions(address sender) internal virtual;

    /// @notice Returns the implementation address for a function selector
    /// @dev Required override from OpenZeppelin Proxy contract
    /// @return The implementation contract address
    function _implementation() internal view override returns (address) {
        bytes4 selector = msg.sig;
        MultiFacetProxyStorage storage $ = _getMultiFacetProxyStorage();
        address implementation = $.selectorToImplementation[selector];
        if (implementation == address(0)) revert();
        return implementation;
    }
}
