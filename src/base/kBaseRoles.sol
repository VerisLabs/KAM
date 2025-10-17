// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedOwnableRoles } from "solady/auth/OptimizedOwnableRoles.sol";

import {
    KROLESBASE_ALREADY_INITIALIZED,
    KROLESBASE_NOT_INITIALIZED,
    KROLESBASE_WRONG_ROLE,
    KROLESBASE_ZERO_ADDRESS
} from "kam/src/errors/Errors.sol";

/// @title kBaseRoles
/// @notice Foundation contract providing essential shared functionality and registry integration for all KAM protocol
contract kBaseRoles is OptimizedOwnableRoles {
    /* //////////////////////////////////////////////////////////////
                              ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Admin role for authorized operations
    uint256 internal constant ADMIN_ROLE = _ROLE_0;

    /// @notice Emergency admin role for emergency operations
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /// @notice Guardian role as a circuit breaker for settlement proposals
    uint256 internal constant GUARDIAN_ROLE = _ROLE_2;

    /// @notice Relayer role for external vaults
    uint256 internal constant RELAYER_ROLE = _ROLE_3;

    /// @notice Reserved role for special whitelisted addresses
    uint256 internal constant INSTITUTION_ROLE = _ROLE_4;

    /// @notice Vendor role for Vendor vaults
    uint256 internal constant VENDOR_ROLE = _ROLE_5;

    /// @notice Vendor role for Manager vaults
    uint256 internal constant MANAGER_ROLE = _ROLE_6;

    /* //////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the emergency pause state is toggled for protocol-wide risk mitigation
    /// @dev This event signals a critical protocol state change that affects all inheriting contracts.
    /// When paused=true, protocol operations are halted to prevent potential exploits or manage emergencies.
    /// Only emergency admins can trigger this, providing rapid response capability during security incidents.
    /// @param paused_ The new pause state (true = operations halted, false = normal operation)
    event Paused(bool paused_);

    /* //////////////////////////////////////////////////////////////
                        STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kBaseRoles
    /// @dev Storage struct following ERC-7201 namespaced storage pattern to prevent collisions during upgrades.
    /// This pattern ensures that storage layout remains consistent across proxy upgrades and prevents
    /// accidental overwriting when contracts inherit from multiple base contracts. The namespace
    /// "kam.storage.kBaseRoles" uniquely identifies this storage area within the contract's storage space.
    struct kBaseRolesStorage {
        /// @dev Initialization flag preventing multiple initialization calls (reentrancy protection)
        bool initialized;
        /// @dev Emergency pause state affecting all protocol operations in inheriting contracts
        bool paused;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kBaseRoles")) - 1)) & ~bytes32(uint256(0xff))
    // / This specific slot is chosen to avoid any possible collision with standard storage layouts while maintaining
    // / deterministic addressing. The calculation ensures the storage location is unique to this namespace and won't
    // / conflict with other inherited contracts or future upgrades. The 0xff mask ensures proper alignment.
    bytes32 private constant KROLESBASE_STORAGE_LOCATION =
        0x841668355433cc9fb8fc1984bd90b939822ef590acd27927baab4c6b4fb12900;

    /* //////////////////////////////////////////////////////////////
                              STORAGE GETTER
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the kBase storage pointer using ERC-7201 namespaced storage pattern
    /// @return $ Storage pointer to the kBaseStorage struct at the designated storage location
    /// This function uses inline assembly to directly set the storage pointer to our namespaced location,
    /// ensuring efficient access to storage variables while maintaining upgrade safety. The pure modifier
    /// is used because we're only returning a storage pointer, not reading storage values.
    function _getkBaseRolesStorage() internal pure returns (kBaseRolesStorage storage $) {
        assembly {
            $.slot := KROLESBASE_STORAGE_LOCATION
        }
    }

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function __kBaseRoles_init(
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address guardian_,
        address relayer_
    )
        internal
    {
        kBaseRolesStorage storage $ = _getkBaseRolesStorage();

        require(!$.initialized, KROLESBASE_ALREADY_INITIALIZED);

        $.paused = false;
        $.initialized = true;

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(admin_, VENDOR_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(guardian_, GUARDIAN_ROLE);
        _grantRoles(relayer_, RELAYER_ROLE);
        _grantRoles(relayer_, MANAGER_ROLE);
    }

    /* //////////////////////////////////////////////////////////////
                                MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Toggles the emergency pause state affecting all protocol operations in this contract
    /// @dev This function provides critical risk management capability by allowing emergency admins to halt
    /// contract operations during security incidents or market anomalies. The pause mechanism: (1) Affects all
    /// state-changing operations in inheriting contracts that check _isPaused(), (2) Does not affect view/pure
    /// functions ensuring protocol state remains readable, (3) Enables rapid response to potential exploits by
    /// halting operations protocol-wide, (4) Requires emergency admin role ensuring only authorized governance
    /// can trigger pauses. Inheriting contracts should check _isPaused() modifier in critical functions to
    /// respect the pause state. The external visibility with role check prevents unauthorized pause manipulation.
    /// @param paused_ The desired pause state (true = halt operations, false = resume normal operation)
    function setPaused(bool paused_) external {
        _checkEmergencyAdmin(msg.sender);
        kBaseRolesStorage storage $ = _getkBaseRolesStorage();
        require($.initialized, KROLESBASE_NOT_INITIALIZED);
        $.paused = paused_;
        emit Paused(paused_);
    }

    /* //////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal helper to check if a user has a specific role
    /// @dev Wraps the OptimizedOwnableRoles hasAnyRole function for role verification
    /// @param user The address to check for role membership
    /// @param role_ The role constant to check (e.g., ADMIN_ROLE, VENDOR_ROLE)
    /// @return True if the user has the specified role, false otherwise
    function _hasRole(address user, uint256 role_) internal view returns (bool) {
        return hasAnyRole(user, role_);
    }

    /// @notice Check if caller has Admin role
    /// @param user Address to check
    function _checkAdmin(address user) internal view {
        require(_hasRole(user, ADMIN_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if caller has Emergency Admin role
    /// @param user Address to check
    function _checkEmergencyAdmin(address user) internal view {
        require(_hasRole(user, EMERGENCY_ADMIN_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if caller has Guardian role
    /// @param user Address to check
    function _checkGuardian(address user) internal view {
        require(_hasRole(user, GUARDIAN_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if caller has relayer role
    /// @param user Address to check
    function _checkRelayer(address user) internal view {
        require(_hasRole(user, RELAYER_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if caller has Institution role
    /// @param user Address to check
    function _checkInstitution(address user) internal view {
        require(_hasRole(user, INSTITUTION_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if caller has Vendor role
    /// @param user Address to check
    function _checkVendor(address user) internal view {
        require(_hasRole(user, VENDOR_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if caller has Manager role
    /// @param user Address to check
    function _checkManager(address user) internal view {
        require(_hasRole(user, MANAGER_ROLE), KROLESBASE_WRONG_ROLE);
    }

    /// @notice Check if address is not zero
    /// @param addr Address to check
    function _checkAddressNotZero(address addr) internal pure {
        require(addr != address(0), KROLESBASE_ZERO_ADDRESS);
    }
}
