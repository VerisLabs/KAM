// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedReentrancyGuardTransient } from "src/abstracts/OptimizedReentrancyGuardTransient.sol";
import { OptimizedOwnableRoles } from "src/libraries/OptimizedOwnableRoles.sol";
import { ERC20 } from "src/vendor/ERC20.sol";
import { Multicallable } from "src/vendor/Multicallable.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";

import {
    KTOKEN_IS_PAUSED, KTOKEN_TRANSFER_FAILED, KTOKEN_ZERO_ADDRESS, KTOKEN_ZERO_AMOUNT
} from "src/errors/Errors.sol";

/// @title kToken
/// @notice ERC20 token with role-based minting and burning capabilities
/// @dev Implements UUPS upgradeable pattern with 1:1 backing by underlying assets
contract kToken is ERC20, OptimizedOwnableRoles, OptimizedReentrancyGuardTransient, Multicallable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when tokens are minted
    /// @param to The address to which the tokens are minted
    /// @param amount The quantity of tokens minted
    event Minted(address indexed to, uint256 amount);

    /// @notice Emitted when tokens are burned
    /// @param from The address from which tokens are burned
    /// @param amount The quantity of tokens burned
    event Burned(address indexed from, uint256 amount);

    /// @notice Emitted when a new token is created
    /// @param token The address of the new token
    /// @param owner The owner of the new token
    /// @param name The name of the new token
    /// @param symbol The symbol of the new token
    /// @param decimals The decimals of the new token
    event TokenCreated(address indexed token, address owner, string name, string symbol, uint8 decimals);

    /// @notice Emitted when the pause state is changed
    /// @param isPaused The new pause state
    event PauseState(bool isPaused);

    /// @notice Emitted when an authorized caller is updated
    /// @param caller The address of the caller
    /// @param authorized Whether the caller is authorized
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);

    /// @notice Emitted when an emergency withdrawal is requested
    /// @param token The address of the token
    /// @param to The address to which the tokens will be sent
    /// @param amount The amount of tokens to withdraw
    /// @param admin The address of the admin
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);

    /// @notice Emitted when assets are rescued
    /// @param asset The address of the asset
    /// @param to The address to which the assets will be sent
    /// @param amount The amount of assets rescued
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);

    /// @notice Emitted when ETH is rescued
    /// @param asset The address of the asset
    /// @param amount The amount of ETH rescued
    event RescuedETH(address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role constants
    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant MINTER_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Pause state
    bool _isPaused;
    /// @notice Name of the token
    string private _name;
    /// @notice Symbol of the token
    string private _symbol;
    /// @notice Decimals of the token
    uint8 private _decimals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the kToken contract
    /// @param owner_ Contract owner address
    /// @param admin_ Admin role recipient
    /// @param emergencyAdmin_ Emergency admin role recipient
    /// @param minter_ Minter role recipient
    /// @param name_ Name of the token
    /// @param symbol_ Symbol of the token
    /// @param decimals_ Decimals of the token
    constructor(
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address minter_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        require(owner_ != address(0), KTOKEN_ZERO_ADDRESS);
        require(admin_ != address(0), KTOKEN_ZERO_ADDRESS);
        require(emergencyAdmin_ != address(0), KTOKEN_ZERO_ADDRESS);
        require(minter_ != address(0), KTOKEN_ZERO_ADDRESS);

        // Initialize ownership and roles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(minter_, MINTER_ROLE);

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        emit TokenCreated(address(this), owner_, name_, symbol_, _decimals);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new tokens and assigns them to the specified address
    /// @dev Calls internal _mint function and emits Minted event, restricted to MINTER_ROLE
    /// @param _to The address that will receive the newly minted tokens
    /// @param _amount The quantity of tokens to create and assign
    function mint(address _to, uint256 _amount) external onlyRoles(MINTER_ROLE) {
        require(!_isPaused, KTOKEN_IS_PAUSED);
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    /// @notice Destroys tokens from the specified address
    /// @dev Calls internal _burn function and emits Burned event, restricted to MINTER_ROLE
    /// @param _from The address from which tokens will be destroyed
    /// @param _amount The quantity of tokens to destroy
    function burn(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE) {
        require(!_isPaused, KTOKEN_IS_PAUSED);
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /// @notice Destroys tokens from specified address using allowance mechanism
    /// @dev Consumes allowance before burning, calls _spendAllowance then _burn, restricted to MINTER_ROLE
    /// @param _from The address from which tokens will be destroyed
    /// @param _amount The quantity of tokens to destroy from the allowance
    function burnFrom(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE) {
        require(!_isPaused, KTOKEN_IS_PAUSED);
        _spendAllowance(_from, msg.sender, _amount);
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the human-readable name of the token
    /// @dev Returns the name stored in contract storage during initialization
    /// @return The token name as a string
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice Retrieves the abbreviated symbol of the token
    /// @dev Returns the symbol stored in contract storage during initialization
    /// @return The token symbol as a string
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice Retrieves the number of decimal places for the token
    /// @dev Returns the decimals value stored in contract storage during initialization
    /// @return The number of decimal places as uint8
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /// @notice Checks whether the contract is currently in paused state
    /// @dev Reads the isPaused flag from contract storage
    /// @return Boolean indicating if contract operations are paused
    function isPaused() external view returns (bool) {
        return _isPaused;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grant admin role
    /// @param admin Address to grant admin role to
    function grantAdminRole(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN_ROLE);
    }

    /// @notice Revoke admin role
    /// @param admin Address to revoke admin role from
    function revokeAdminRole(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN_ROLE);
    }

    /// @notice Grant emergency role
    /// @param emergency Address to grant emergency role to
    function grantEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(emergency, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Revoke emergency role
    /// @param emergency Address to revoke emergency role from
    function revokeEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(emergency, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Assigns minter role privileges to the specified address
    /// @dev Calls internal _grantRoles function to assign MINTER_ROLE
    /// @param minter The address that will receive minter role privileges
    function grantMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(minter, MINTER_ROLE);
    }

    /// @notice Removes minter role privileges from the specified address
    /// @dev Calls internal _removeRoles function to remove MINTER_ROLE
    /// @param minter The address that will lose minter role privileges
    function revokeMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(minter, MINTER_ROLE);
    }

    /// @notice Sets the pause state of the contract
    /// @dev Updates the isPaused flag in storage and emits PauseState event
    /// @param isPaused_ Boolean indicating whether to pause (true) or unpause (false) the contract
    function setPaused(bool isPaused_) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _isPaused = isPaused_;
        emit PauseState(_isPaused);
    }

    /// @notice Emergency withdrawal of tokens sent by mistake
    /// @dev Can only be called by emergency admin when contract is paused
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        require(to != address(0), KTOKEN_ZERO_ADDRESS);
        require(amount != 0, KTOKEN_ZERO_AMOUNT);

        if (token == address(0)) {
            // Withdraw ETH
            (bool success,) = to.call{ value: amount }("");
            require(success, KTOKEN_TRANSFER_FAILED);
            emit RescuedETH(to, amount);
        } else {
            // Withdraw ERC20 token
            token.safeTransfer(to, amount);
            emit RescuedAssets(token, to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal hook that executes before any token transfer
    /// @dev Applies whenNotPaused modifier to prevent transfers during pause, then calls parent implementation
    /// @param from The address tokens are being transferred from
    /// @param to The address tokens are being transferred to
    /// @param amount The quantity of tokens being transferred
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        require(!_isPaused, KTOKEN_IS_PAUSED);
        super._beforeTokenTransfer(from, to, amount);
    }
}
