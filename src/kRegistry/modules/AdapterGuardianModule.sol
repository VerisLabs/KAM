// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kRolesBase } from "src/base/kRolesBase.sol";
import { OptimizedAddressEnumerableSetLib } from "src/libraries/OptimizedAddressEnumerableSetLib.sol";

import {
    KREGISTRY_INVALID_ADAPTER,
    KREGISTRY_SELECTOR_ALREADY_SET,
    KREGISTRY_SELECTOR_NOT_FOUND,
    KREGISTRY_ZERO_ADDRESS
} from "src/errors/Errors.sol";

interface IParametersChecker {
    function canAdapterCall(address adapter, address target, bytes4 selector, bytes calldata params) external view returns (bool);
}

/// @title AdapterGuardianModule
/// @notice Module for managing adapter permissions and parameter checking in kRegistry
/// @dev Inherits from kRolesBase for role-based access control
contract AdapterGuardianModule is kRolesBase {
    using OptimizedAddressEnumerableSetLib for OptimizedAddressEnumerableSetLib.AddressSet;

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
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Storage structure for AdapterGuardianModule using ERC-7201 namespaced storage pattern
    /// @dev This structure maintains adapter permissions and parameter checkers
    /// @custom:storage-location erc7201:kam.storage.AdapterGuardianModule
    struct AdapterGuardianModuleStorage {
        /// @dev Tracks whether an adapter address is registered in the protocol
        /// Used for validation and security checks on adapter operations
        mapping(address => bool) registeredAdapters;
        /// @dev Maps adapter address to target contract to allowed selectors
        /// Controls which functions an adapter can call on target contracts
        mapping(address => mapping(address => mapping(bytes4 => bool))) adapterAllowedSelectors;
        /// @dev Maps adapter address to target contract to selector to parameter checker
        /// Enables fine-grained parameter validation for adapter calls
        mapping(address => mapping(address => mapping(bytes4 => address))) adapterParametersChecker;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.AdapterGuardianModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ADAPTERGUARDIANMODULE_STORAGE_LOCATION =
        0x82abb426e3b44c537e85e43273337421a20a3ea37d7e65190cbdd1a7dbb77100;

    /// @notice Retrieves the AdapterGuardianModule storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The AdapterGuardianModuleStorage struct reference for state modifications
    function _getAdapterGuardianModuleStorage() private pure returns (AdapterGuardianModuleStorage storage $) {
        assembly {
            $.slot := ADAPTERGUARDIANMODULE_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Register or unregister an adapter
    /// @param adapter The adapter address
    /// @param registered Whether the adapter should be registered
    /// @dev Only callable by ADMIN_ROLE
    function setAdapterRegistered(address adapter, bool registered) external {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(adapter);

        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        $.registeredAdapters[adapter] = registered;
        
        emit AdapterRegistered(adapter, registered);
    }

    /// @notice Set whether a selector is allowed for an adapter on a target contract
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param allowed Whether the selector is allowed
    /// @dev Only callable by ADMIN_ROLE
    function setAdapterAllowedSelector(
        address adapter,
        address target,
        bytes4 selector,
        bool allowed
    )
        external
    {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(adapter);
        _checkAddressNotZero(target);
        require(selector != bytes4(0), KREGISTRY_INVALID_ADAPTER);

        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        
        // Check if adapter is registered
        require($.registeredAdapters[adapter], KREGISTRY_INVALID_ADAPTER);

        // Check if trying to set to the same value
        bool currentlyAllowed = $.adapterAllowedSelectors[adapter][target][selector];
        if (currentlyAllowed && allowed) {
            revert(KREGISTRY_SELECTOR_ALREADY_SET);
        }

        $.adapterAllowedSelectors[adapter][target][selector] = allowed;
        
        // If disallowing, also remove any parameter checker
        if (!allowed) {
            delete $.adapterParametersChecker[adapter][target][selector];
        }
        
        emit SelectorAllowed(adapter, target, selector, allowed);
    }

    /// @notice Set a parameter checker for an adapter selector
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param parametersChecker The parameter checker contract address (0x0 to remove)
    /// @dev Only callable by ADMIN_ROLE
    function setAdapterParametersChecker(
        address adapter,
        address target,
        bytes4 selector,
        address parametersChecker
    )
        external
    {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(adapter);
        _checkAddressNotZero(target);

        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        
        // Check if adapter is registered
        require($.registeredAdapters[adapter], KREGISTRY_INVALID_ADAPTER);
        
        // Selector must be allowed before setting a parameter checker
        require($.adapterAllowedSelectors[adapter][target][selector], KREGISTRY_SELECTOR_NOT_FOUND);

        $.adapterParametersChecker[adapter][target][selector] = parametersChecker;
        emit ParametersCheckerSet(adapter, target, selector, parametersChecker);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if an adapter can call a specific function on a target
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param params The function parameters
    /// @return Whether the call is allowed
    function canAdapterCall(
        address adapter,
        address target,
        bytes4 selector,
        bytes calldata params
    )
        external
        view
        returns (bool)
    {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();

        if (!$.registeredAdapters[adapter]) return false;
        if (!$.adapterAllowedSelectors[adapter][target][selector]) return false;

        address checker = $.adapterParametersChecker[adapter][target][selector];
        if (checker == address(0)) return true;

        try IParametersChecker(checker).canAdapterCall(adapter, target, selector, params) returns (bool isAllowed) {
            return isAllowed;
        } catch {
            return false;
        }
    }

    /// @notice Check if an adapter is registered
    /// @param adapter The adapter address to check
    /// @return Whether the adapter is registered
    function isAdapterRegistered(address adapter) external view returns (bool) {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.registeredAdapters[adapter];
    }

    /// @notice Check if a selector is allowed for an adapter
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return Whether the selector is allowed
    function isAdapterSelectorAllowed(
        address adapter,
        address target,
        bytes4 selector
    )
        external
        view
        returns (bool)
    {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.adapterAllowedSelectors[adapter][target][selector];
    }

    /// @notice Get the parameter checker for an adapter selector
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return The parameter checker address (address(0) if none)
    function getAdapterParametersChecker(
        address adapter,
        address target,
        bytes4 selector
    )
        external
        view
        returns (address)
    {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.adapterParametersChecker[adapter][target][selector];
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() public pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](7);
        moduleSelectors[0] = this.setAdapterRegistered.selector;
        moduleSelectors[1] = this.setAdapterAllowedSelector.selector;
        moduleSelectors[2] = this.setAdapterParametersChecker.selector;
        moduleSelectors[3] = this.canAdapterCall.selector;
        moduleSelectors[4] = this.isAdapterRegistered.selector;
        moduleSelectors[5] = this.isAdapterSelectorAllowed.selector;
        moduleSelectors[6] = this.getAdapterParametersChecker.selector;
        return moduleSelectors;
    }
}