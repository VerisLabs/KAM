// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kRolesBase } from "src/base/kRolesBase.sol";
import {
    GUARDIANMODULE_INVALID_ADAPTER,
    GUARDIANMODULE_NOT_ALLOWED,
    GUARDIANMODULE_SELECTOR_ALREADY_SET,
    GUARDIANMODULE_SELECTOR_NOT_FOUND,
    GUARDIANMODULE_UNAUTHORIZED,
    GUARDIANMODULE_ZERO_ADDRESS
} from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

import { IAdapterGuardian, IParametersChecker } from "src/interfaces/modules/IAdapterGuardian.sol";
import { OptimizedAddressEnumerableSetLib } from
    "src/vendor/solady/utils/EnumerableSetLib/OptimizedAddressEnumerableSetLib.sol";

/// @title AdapterGuardianModule
/// @notice Module for managing adapter permissions and parameter checking in kRegistry
/// @dev Inherits from kRolesBase for role-based access control
contract AdapterGuardianModule is IAdapterGuardian, kRolesBase {
    using OptimizedAddressEnumerableSetLib for OptimizedAddressEnumerableSetLib.AddressSet;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Storage structure for AdapterGuardianModule using ERC-7201 namespaced storage pattern
    /// @dev This structure maintains adapter permissions and parameter checkers
    /// @custom:storage-location erc7201:kam.storage.AdapterGuardianModule
    struct AdapterGuardianModuleStorage {
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

    /// @notice Set whether a selector is allowed for an adapter on a target contract
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param isAllowed Whether the selector is allowed
    /// @dev Only callable by ADMIN_ROLE
    function setAdapterAllowedSelector(address adapter, address target, bytes4 selector, bool isAllowed) external {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(adapter);
        _checkAddressNotZero(target);

        require(selector != bytes4(0), GUARDIANMODULE_INVALID_ADAPTER);

        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();

        // Check if trying to set to the same value
        bool currentlyAllowed = $.adapterAllowedSelectors[adapter][target][selector];
        if (currentlyAllowed && isAllowed) {
            revert(GUARDIANMODULE_SELECTOR_ALREADY_SET);
        }

        $.adapterAllowedSelectors[adapter][target][selector] = isAllowed;

        // If disallowing, also remove any parameter checker
        if (!isAllowed) {
            delete $.adapterParametersChecker[adapter][target][selector];
        }

        emit SelectorAllowed(adapter, target, selector, isAllowed);
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

        // Selector must be allowed before setting a parameter checker
        require($.adapterAllowedSelectors[adapter][target][selector], GUARDIANMODULE_SELECTOR_NOT_FOUND);

        $.adapterParametersChecker[adapter][target][selector] = parametersChecker;
        emit ParametersCheckerSet(adapter, target, selector, parametersChecker);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if an adapter is authorized to call a specific function on a target
    /// @param target The target contract address
    /// @param selector The function selector
    /// @param params The function parameters
    function authorizeAdapterCall(address target, bytes4 selector, bytes calldata params) external view {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();

        address adapter = msg.sender;
        require($.adapterAllowedSelectors[adapter][target][selector], GUARDIANMODULE_NOT_ALLOWED);

        address checker = $.adapterParametersChecker[adapter][target][selector];
        if (checker == address(0)) return;

        require(
            IParametersChecker(checker).authorizeAdapterCall(adapter, target, selector, params),
            GUARDIANMODULE_UNAUTHORIZED
        );
    }

    /// @notice Check if a selector is allowed for an adapter
    /// @param adapter The adapter address
    /// @param target The target contract address
    /// @param selector The function selector
    /// @return Whether the selector is allowed
    function isAdapterSelectorAllowed(address adapter, address target, bytes4 selector) external view returns (bool) {
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
    /// @return moduleSelectors Array of function selectors
    function selectors() public pure returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](5);
        moduleSelectors[0] = this.setAdapterAllowedSelector.selector;
        moduleSelectors[1] = this.setAdapterParametersChecker.selector;
        moduleSelectors[2] = this.authorizeAdapterCall.selector;
        moduleSelectors[3] = this.isAdapterSelectorAllowed.selector;
        moduleSelectors[4] = this.getAdapterParametersChecker.selector;
    }
}
