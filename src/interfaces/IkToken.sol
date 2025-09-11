// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IVersioned } from "src/interfaces/IVersioned.sol";

/// @title IkToken
/// @notice Interface for kToken with role-based minting and burning capabilities
/// @dev Defines the standard interface for kToken implementations with ERC20 compatibility
interface IkToken is IVersioned {
    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new tokens and assigns them to the specified address
    /// @dev Only callable by addresses with MINTER_ROLE, emits Minted event
    /// @param to The address that will receive the newly minted tokens
    /// @param amount The quantity of tokens to create and assign
    function mint(address to, uint256 amount) external;

    /// @notice Destroys tokens from the specified address
    /// @dev Only callable by addresses with MINTER_ROLE, emits Burned event
    /// @param from The address from which tokens will be destroyed
    /// @param amount The quantity of tokens to destroy
    function burn(address from, uint256 amount) external;

    /// @notice Destroys tokens from an address using allowance mechanism
    /// @dev Reduces allowance and burns tokens, only callable by addresses with MINTER_ROLE
    /// @param from The address from which tokens will be destroyed
    /// @param amount The quantity of tokens to destroy
    function burnFrom(address from, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name of the token
    /// @return The name of the token as a string
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token
    /// @return The symbol of the token as a string
    function symbol() external view returns (string memory);

    /// @notice Returns the number of decimal places for the token
    /// @return The number of decimal places as uint8
    function decimals() external view returns (uint8);

    /// @notice Returns the total amount of tokens in existence
    /// @return The total supply of tokens
    function totalSupply() external view returns (uint256);

    /// @notice Returns the token balance of a specific account
    /// @param account The address to query the balance for
    /// @return The token balance of the specified account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers tokens from the caller to another address
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return success True if the transfer succeeded, false otherwise
    function transfer(address to, uint256 amount) external returns (bool success);

    /// @notice Returns the amount of tokens that spender is allowed to spend on behalf of owner
    /// @param owner The address that owns the tokens
    /// @param spender The address that is approved to spend the tokens
    /// @return The amount of tokens the spender is allowed to spend
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets approval for another address to spend tokens on behalf of the caller
    /// @param spender The address that is approved to spend the tokens
    /// @param amount The amount of tokens the spender is approved to spend
    /// @return success True if the approval succeeded, false otherwise
    function approve(address spender, uint256 amount) external returns (bool success);

    /// @notice Transfers tokens from one address to another using allowance mechanism
    /// @param from The address to transfer tokens from
    /// @param to The address to transfer tokens to
    /// @param amount The amount of tokens to transfer
    /// @return success True if the transfer succeeded, false otherwise
    function transferFrom(address from, address to, uint256 amount) external returns (bool success);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current pause state of the contract
    /// @return True if the contract is paused, false otherwise
    function isPaused() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @dev Only callable by addresses with EMERGENCY_ADMIN_ROLE
    /// @param _isPaused True to pause the contract, false to unpause
    function setPaused(bool _isPaused) external;

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants administrative privileges to an address
    /// @dev Only callable by the contract owner
    /// @param admin The address to grant admin role to
    function grantAdminRole(address admin) external;

    /// @notice Revokes administrative privileges from an address
    /// @dev Only callable by the contract owner
    /// @param admin The address to revoke admin role from
    function revokeAdminRole(address admin) external;

    /// @notice Grants emergency administrative privileges to an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param emergency The address to grant emergency admin role to
    function grantEmergencyRole(address emergency) external;

    /// @notice Revokes emergency administrative privileges from an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param emergency The address to revoke emergency admin role from
    function revokeEmergencyRole(address emergency) external;

    /// @notice Grants minting privileges to an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param minter The address to grant minter role to
    function grantMinterRole(address minter) external;

    /// @notice Revokes minting privileges from an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param minter The address to revoke minter role from
    function revokeMinterRole(address minter) external;

    // contractName() and contractVersion() functions are inherited from IVersioned
}
