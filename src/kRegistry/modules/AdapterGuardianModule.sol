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

    /// @notice Emitted when a selector is allowed or disallowed for an adapter
    event SelectorAllowed(address indexed adapter, address indexed target, bytes4 indexed selector, bool allowed);

    /// @notice Emitted when a parameter checker is set for an adapter selector
    event ParametersCheckerSet(
        address indexed adapter,
        address indexed target,
        bytes4 indexed selector,
        address parametersChecker
    );

    /// @notice Emitted when an adapter is registered
    event AdapterRegistered(address indexed adapter);

    /// @notice Emitted when an adapter is removed
    event AdapterRemoved(address indexed adapter);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Core storage structure for kRegistry using ERC-7201 namespaced storage pattern
    /// @dev This structure maintains all protocol configuration state including contracts, assets, vaults, and
    /// permissions.
    /// Uses the diamond storage pattern to prevent storage collisions in upgradeable contracts.
    /// @custom:storage-location erc7201:kam.storage.kRegistry
    struct kRegistryStorage {
        /// @dev Set of all protocol-supported underlying assets (e.g., USDC, WBTC)
        /// Used to validate assets before operations and maintain a whitelist
        OptimizedAddressEnumerableSetLib.AddressSet supportedAssets;
        /// @dev Set of all registered vault contracts across all types
        /// Enables iteration and validation of vault registrations
        OptimizedAddressEnumerableSetLib.AddressSet allVaults;
        /// @dev Protocol treasury address for fee collection and reserves
        /// Receives protocol fees and serves as emergency fund holder
        address treasury;
        /// @dev Maps assets to their maximum mint amount per batch
        mapping(address => uint256) maxMintPerBatch;
        /// @dev Maps assets to their maximum redeem amount per batch
        mapping(address => uint256) maxRedeemPerBatch;
        /// @dev Maps singleton contract identifiers to their deployed addresses
        mapping(bytes32 => address) singletonContracts;
        /// @dev Maps vault addresses to their type classification (DN, ALPHA, BETA, etc.)
        /// Used for routing and strategy selection based on vault type
        mapping(address => uint8 vaultType) vaultType;
        /// @dev Nested mapping: asset => vaultType => vault address for routing logic
        /// Enables efficient lookup of the primary vault for an asset-type combination
        mapping(address => mapping(uint8 vaultType => address)) assetToVault;
        /// @dev Maps vault addresses to sets of assets they manage
        /// Supports multi-asset vaults (e.g., kMinter managing multiple assets)
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAsset;
        /// @dev Reverse lookup: maps assets to all vaults that support them
        /// Enables finding all vaults that can handle a specific asset
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultsByAsset;
        /// @dev Maps asset identifiers (e.g., USDC, WBTC) to their contract addresses
        /// Provides named access to commonly used asset addresses
        mapping(bytes32 => address) singletonAssets;
        /// @dev Maps underlying asset addresses to their corresponding kToken addresses
        /// Critical for minting/redemption operations and asset tracking
        mapping(address => address) assetToKToken;
        /// @dev Maps vaults to their registered external protocol adapters
        /// Enables yield strategies through DeFi protocol integrations
        mapping(address => OptimizedAddressEnumerableSetLib.AddressSet) vaultAdapters;
        /// @dev Tracks whether an adapter address is registered in the protocol
        /// Used for validation and security checks on adapter operations
        mapping(address => bool) registeredAdapters;
        /// @dev Maps assets to their hurdle rates in basis points (100 = 1%)
        /// Defines minimum performance thresholds for yield distribution
        mapping(address => uint16) assetHurdleRate;
        /// @dev Maps adapter address to target contract to allowed selectors
        /// Used by AdapterGuardianModule for permission checking
        mapping(address => mapping(address => mapping(bytes4 => bool))) adapterAllowedSelectors;
        /// @dev Maps adapter address to target contract to selector to parameter checker
        /// Enables fine-grained parameter validation for adapter calls
        mapping(address => mapping(address => mapping(bytes4 => address))) adapterParametersChecker;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KREGISTRY_STORAGE_LOCATION =
        0x164f5345d77b48816cdb20100c950b74361454722dab40c51ecf007b721fa800;

    /// @notice Retrieves the kRegistry storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The kRegistryStorage struct reference for state modifications
    function _getkRegistryStorage() private pure returns (kRegistryStorage storage $) {
        assembly {
            $.slot := KREGISTRY_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

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

        kRegistryStorage storage $ = _getkRegistryStorage();
        
        // Check if adapter is registered in the vault system
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

        kRegistryStorage storage $ = _getkRegistryStorage();
        
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
        kRegistryStorage storage $ = _getkRegistryStorage();

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
        kRegistryStorage storage $ = _getkRegistryStorage();
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
        kRegistryStorage storage $ = _getkRegistryStorage();
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
        kRegistryStorage storage $ = _getkRegistryStorage();
        return $.adapterParametersChecker[adapter][target][selector];
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() public pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](6);
        moduleSelectors[0] = this.setAdapterAllowedSelector.selector;
        moduleSelectors[1] = this.setAdapterParametersChecker.selector;
        moduleSelectors[2] = this.canAdapterCall.selector;
        moduleSelectors[3] = this.isAdapterRegistered.selector;
        moduleSelectors[4] = this.isAdapterSelectorAllowed.selector;
        moduleSelectors[5] = this.getAdapterParametersChecker.selector;
        return moduleSelectors;
    }
}