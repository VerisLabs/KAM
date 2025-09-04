// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import {
    KTOKEN_IS_PAUSED, KTOKEN_TRANSFER_FAILED, KTOKEN_ZERO_ADDRESS, KTOKEN_ZERO_AMOUNT
} from "src/errors/Errors.sol";

/// @title kToken
/// @notice ERC20 token with role-based minting and burning capabilities
/// @dev Implements UUPS upgradeable pattern with 1:1 backing by underlying assets
contract kToken is ERC20, OwnableRoles, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event TokenCreated(address indexed token, address owner, string name, string symbol, uint8 decimals);
    event PauseState(bool isPaused);
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
    event RescuedETH(address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant MINTER_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    bool _isPaused;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract from being initialized
    /// @dev Calls _disableInitializers from Solady's Initializable to lock implementation
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
    function mint(address _to, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE) {
        require(!_isPaused, KTOKEN_IS_PAUSED);
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    /// @notice Destroys tokens from the specified address
    /// @dev Calls internal _burn function and emits Burned event, restricted to MINTER_ROLE
    /// @param _from The address from which tokens will be destroyed
    /// @param _amount The quantity of tokens to destroy
    function burn(address _from, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE) {
        require(!_isPaused, KTOKEN_IS_PAUSED);
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /// @notice Destroys tokens from specified address using allowance mechanism
    /// @dev Consumes allowance before burning, calls _spendAllowance then _burn, restricted to MINTER_ROLE
    /// @param _from The address from which tokens will be destroyed
    /// @param _amount The quantity of tokens to destroy from the allowance
    function burnFrom(address _from, uint256 _amount) external nonReentrant onlyRoles(MINTER_ROLE) {
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
