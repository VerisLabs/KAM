// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kBaseRoles } from "kam/src/base/kBaseRoles.sol";
import {
    GUARDIANMODULE_INVALID_ADAPTER,
    GUARDIANMODULE_NOT_ALLOWED,
    GUARDIANMODULE_SELECTOR_ALREADY_SET,
    GUARDIANMODULE_SELECTOR_NOT_FOUND,
    GUARDIANMODULE_UNAUTHORIZED
} from "kam/src/errors/Errors.sol";

import { IAdapterGuardian, IParametersChecker } from "kam/src/interfaces/modules/IAdapterGuardian.sol";
import { IModule } from "kam/src/interfaces/modules/IModule.sol";
import { OptimizedAddressEnumerableSetLib } from "solady/utils/EnumerableSetLib/OptimizedAddressEnumerableSetLib.sol";
import { OptimizedBytes32EnumerableSetLib } from "solady/utils/EnumerableSetLib/OptimizedBytes32EnumerableSetLib.sol";

/// @title AdapterGuardianModule
/// @notice Module for managing adapter permissions and parameter checking in kRegistry
/// @dev Inherits from kBaseRoles for role-based access control
contract AdapterGuardianModule is IAdapterGuardian, IModule, kBaseRoles {
    using OptimizedAddressEnumerableSetLib for OptimizedAddressEnumerableSetLib.AddressSet;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;

    /* //////////////////////////////////////////////////////////////
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
        /// @dev Tracks all allowed targets for each adapter
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) adapterTargets;
        /// @dev Maps the type of each target
        mapping(address => uint8 targetType) targetType;
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

    /* //////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAdapterGuardian
    function setAdapterAllowedSelector(
        address adapter,
        address target,
        uint8 targetType_,
        bytes4 selector,
        bool isAllowed
    )
        external
    {
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
        $.targetType[target] = targetType_;

        // Update tracking sets
        if (isAllowed) {
            // Add target to adapter's target set
            $.adapterTargets[adapter].add(target);
        } else {
            $.adapterTargets[adapter].remove(target);
            // Also remove any parameter checker
            delete $.adapterParametersChecker[adapter][target][selector];
        }

        emit SelectorAllowed(adapter, target, selector, isAllowed);
    }

    /// @inheritdoc IAdapterGuardian
    function setAdapterParametersChecker(address adapter, address target, bytes4 selector, address parametersChecker)
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

    /* //////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAdapterGuardian
    function authorizeAdapterCall(address target, bytes4 selector, bytes calldata params) external {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();

        address adapter = msg.sender;
        require($.adapterAllowedSelectors[adapter][target][selector], GUARDIANMODULE_NOT_ALLOWED);

        address checker = $.adapterParametersChecker[adapter][target][selector];
        if (checker == address(0)) return;

        IParametersChecker(checker).authorizeAdapterCall(adapter, target, selector, params);
    }

    /// @inheritdoc IAdapterGuardian
    function isAdapterSelectorAllowed(address adapter, address target, bytes4 selector) external view returns (bool) {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.adapterAllowedSelectors[adapter][target][selector];
    }

    /// @inheritdoc IAdapterGuardian
    function getAdapterParametersChecker(address adapter, address target, bytes4 selector)
        external
        view
        returns (address)
    {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.adapterParametersChecker[adapter][target][selector];
    }

    /// @notice Gets all allowed targets for a specific adapter
    /// @param adapter The adapter address to query targets for
    /// @return targets An array of allowed target addresses for the adapter
    function getAdapterTargets(address adapter) external view returns (address[] memory targets) {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.adapterTargets[adapter].values();
    }

    /// @inheritdoc IAdapterGuardian
    function getTargetType(address target) external view returns (uint8) {
        AdapterGuardianModuleStorage storage $ = _getAdapterGuardianModuleStorage();
        return $.targetType[target];
    }

    /* //////////////////////////////////////////////////////////////
                        MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](7);
        moduleSelectors[0] = this.setAdapterAllowedSelector.selector;
        moduleSelectors[1] = this.setAdapterParametersChecker.selector;
        moduleSelectors[2] = this.authorizeAdapterCall.selector;
        moduleSelectors[3] = this.isAdapterSelectorAllowed.selector;
        moduleSelectors[4] = this.getAdapterParametersChecker.selector;
        moduleSelectors[5] = this.getAdapterTargets.selector;
        moduleSelectors[6] = this.getTargetType.selector;
        return moduleSelectors;
    }
}
