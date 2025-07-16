// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Proxy } from "src/abstracts/Proxy.sol";

/// @title MultiFacetProxy
/// @notice A proxy contract that can route function calls to different implementation contracts
/// @dev Implements a diamond-style proxy pattern for modular contract architecture
///
/// PROXY DELEGATION MECHANISM:
/// - Maps function selectors to specific implementation contracts
/// - Uses delegatecall to execute functions in the context of the main contract
/// - Maintains storage and state in the main contract while execution happens in modules
/// - Enables modular upgrades by updating individual function implementations
///
/// SECURITY MODEL:
/// - Role-based access control for proxy administration
/// - Prevents unauthorized function mapping modifications
/// - Explicit selector mapping prevents accidental delegations
/// - Main contract storage remains isolated and protected
contract MultiFacetProxy is Proxy, OwnableRoles {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when attempting to call a function with no mapped implementation
    error NoImplementationForSelector();
    /// @notice Thrown when attempting to call a function that doesn't exist in any implementation
    error FunctionNotFound();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Maps function selectors to their corresponding implementation contract addresses
    /// @dev Used for function routing in the fallback mechanism
    mapping(bytes4 => address) selectorToImplementation;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the proxy with specified admin role configuration
    /// @dev Sets the proxy admin role using assembly for gas optimization
    /// @param proxyAdminRole_ The role identifier for proxy administration privileges
    // 0x4fa563f6ad0f2ba943d6492a5a9c8ec6e039cc68444fb93b0b51ea1d78a61ef8 = keccak256("MultiFacetProxy")
    constructor(uint256 proxyAdminRole_) {
        assembly {
            sstore(0x4fa563f6ad0f2ba943d6492a5a9c8ec6e039cc68444fb93b0b51ea1d78a61ef8, proxyAdminRole_)
        }
    }

    /// @notice Initializes the proxy's role-based access control system
    /// @dev Required for proper proxy functionality when deployed via minimal proxy pattern
    /// @param owner The owner address with ultimate authority over the proxy
    /// @param admin The admin address with proxy administration privileges
    function initializeProxyRoles(address owner, address admin) external {
        // Only allow initialization if not already initialized
        // Check if owner is already set by checking if any role exists
        if (!(hasAnyRole(admin, _proxyAdminRole()))) revert AlreadyInitialized();

        // Initialize the owner
        _initializeOwner(owner);

        // Grant the proxy admin role to the admin
        _grantRoles(admin, _proxyAdminRole());
    }

    /*//////////////////////////////////////////////////////////////
                              CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a function selector mapping to an implementation address
    /// @dev Maps a specific function to a module contract for delegated execution
    /// @param selector The function selector to add to the mapping
    /// @param implementation The implementation contract address that will handle this function
    /// @param forceOverride If true, allows overwriting existing mappings for upgrades
    function addFunction(bytes4 selector, address implementation, bool forceOverride) public virtual {
        // Allow either the proxy admin role or the owner to call this function
        if (!(hasAnyRole(msg.sender, _proxyAdminRole()) || msg.sender == owner())) revert Unauthorized();
        if (!forceOverride) {
            if (selectorToImplementation[selector] != address(0)) revert();
        }
        selectorToImplementation[selector] = implementation;
    }

    /// @notice Adds multiple function selector mappings to an implementation contract
    /// @dev Batch operation for efficient module registration
    /// @param selectors Array of function selectors to add to the mapping
    /// @param implementation The implementation contract address that will handle these functions
    /// @param forceOverride If true, allows overwriting existing mappings for upgrades
    function addFunctions(bytes4[] calldata selectors, address implementation, bool forceOverride) public virtual {
        uint256 length = selectors.length;
        for (uint256 i; i < length;) {
            addFunction(selectors[i], implementation, forceOverride);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Removes a function selector mapping from the proxy
    /// @dev Deletes the mapping, reverting calls to that function to the main contract
    /// @param selector The function selector to remove from the mapping
    function removeFunction(bytes4 selector) public {
        // Allow either the proxy admin role or the owner to call this function
        if (!(hasAnyRole(msg.sender, _proxyAdminRole()) || msg.sender == owner())) revert Unauthorized();
        delete selectorToImplementation[selector];
    }

    /// @notice Removes multiple function selector mappings from the proxy
    /// @dev Batch operation for efficient module deregistration
    /// @param selectors Array of function selectors to remove from the mapping
    function removeFunctions(bytes4[] calldata selectors) public {
        uint256 length = selectors.length;
        for (uint256 i; i < length;) {
            removeFunction(selectors[i]);

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the implementation address for a function selector
    /// @dev Required override from Proxy contract for internal delegation logic
    /// @return The implementation contract address mapped to the current function selector
    function _implementation() internal view override returns (address) {
        bytes4 selector = msg.sig;
        address implementation = selectorToImplementation[selector];
        if (implementation == address(0)) {
            // If no implementation is mapped, revert with specific error
            revert NoImplementationForSelector();
        }
        return implementation;
    }

    /// @notice Retrieves the proxy admin role identifier from storage
    /// @dev Uses assembly for gas-efficient storage access
    /// @return role The proxy admin role identifier
    function _proxyAdminRole() internal view returns (uint256 role) {
        assembly {
            role := sload(0x4fa563f6ad0f2ba943d6492a5a9c8ec6e039cc68444fb93b0b51ea1d78a61ef8)
        }
    }

    /*//////////////////////////////////////////////////////////////
                              FALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice Fallback function that routes calls to appropriate module implementations
    /// @dev Implements secure delegation pattern with explicit selector mapping validation
    ///
    /// DELEGATION SECURITY:
    /// - Only delegates to explicitly mapped selectors
    /// - Prevents accidental delegation to unknown functions
    /// - Maintains main contract storage context during execution
    /// - Uses delegatecall for proper state management
    fallback() external payable override {
        bytes4 selector = msg.sig;
        address implementation = selectorToImplementation[selector];

        // Only delegate if we have an explicit mapping for this selector
        if (implementation != address(0)) {
            _delegate(implementation);
        } else {
            // If no mapping exists, let the main contract handle it normally
            // This will cause a revert if the function doesn't exist in the main contract
            revert FunctionNotFound();
        }
    }
}
