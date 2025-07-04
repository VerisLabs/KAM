// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.30;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {Multicallable} from "solady/utils/Multicallable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @title kToken
/// @notice ERC20 token with role-based minting and burning capabilities
/// @dev Implements UUPS upgradeable pattern with 1:1 backing by underlying assets
contract kToken is Initializable, UUPSUpgradeable, ERC20, OwnableRoles, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant MINTER_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kToken.storage.kToken
    struct kTokenStorage {
        bool isPaused;
        string _name;
        string _symbol;
        uint8 _decimals;
    }

    // keccak256(abi.encode(uint256(keccak256("kToken.storage.kToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KTOKEN_STORAGE_LOCATION =
        0x2fb0aec331268355746e3684d9eaaf2249f450cf0e491ca0657288d2091eea00;

    /// @notice Returns the storage pointer for the kToken contract
    /// @return $ The storage pointer for the kToken contract
    function _getkTokenStorage() private pure returns (kTokenStorage storage $) {
        assembly {
            $.slot := KTOKEN_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event UpgradeAuthorized(address indexed newImplementation, address indexed sender);
    event TokenInitialized(string name, string symbol, uint8 decimals);
    event PauseState(bool isPaused);
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Prevents function execution when contract is in paused state
    /// @dev Checks isPaused flag in storage and reverts with Paused error if true
    modifier whenNotPaused() {
        if (_getkTokenStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract from being initialized
    /// @dev Calls _disableInitializers from Solady's Initializable to lock implementation
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kToken contract with token metadata and role assignments
    /// @dev Sets up ERC20 metadata, grants roles, and validates all parameters are non-zero addresses
    /// @param name_ The name of the token
    /// @param symbol_ The symbol of the token
    /// @param decimals_ The number of decimals for the token
    /// @param owner_ Address that will own the contract
    /// @param admin_ Address that will have admin privileges
    /// @param emergencyAdmin_ Address that will have emergency admin privileges
    /// @param minter_ Address that will have minting and burning privileges
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address minter_
    ) external initializer {
        if (owner_ == address(0) || admin_ == address(0) || emergencyAdmin_ == address(0)) revert ZeroAddress();
        if (minter_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(minter_, MINTER_ROLE);

        // Initialize storage
        kTokenStorage storage $ = _getkTokenStorage();
        $._name = name_;
        $._symbol = symbol_;
        $._decimals = decimals_;

        emit TokenInitialized(name_, symbol_, decimals_);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new tokens and assigns them to the specified address
    /// @dev Calls internal _mint function and emits Minted event, restricted to MINTER_ROLE
    /// @param _to The address that will receive the newly minted tokens
    /// @param _amount The quantity of tokens to create and assign
    function mint(address _to, uint256 _amount) external nonReentrant whenNotPaused onlyRoles(MINTER_ROLE) {
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    /// @notice Destroys tokens from the specified address
    /// @dev Calls internal _burn function and emits Burned event, restricted to MINTER_ROLE
    /// @param _from The address from which tokens will be destroyed
    /// @param _amount The quantity of tokens to destroy
    function burn(address _from, uint256 _amount) external nonReentrant whenNotPaused onlyRoles(MINTER_ROLE) {
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /// @notice Destroys tokens from specified address using allowance mechanism
    /// @dev Consumes allowance before burning, calls _spendAllowance then _burn, restricted to MINTER_ROLE
    /// @param _from The address from which tokens will be destroyed
    /// @param _amount The quantity of tokens to destroy from the allowance
    function burnFrom(address _from, uint256 _amount) external nonReentrant whenNotPaused onlyRoles(MINTER_ROLE) {
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
        return _getkTokenStorage()._name;
    }

    /// @notice Retrieves the abbreviated symbol of the token
    /// @dev Returns the symbol stored in contract storage during initialization
    /// @return The token symbol as a string
    function symbol() public view virtual override returns (string memory) {
        return _getkTokenStorage()._symbol;
    }

    /// @notice Retrieves the number of decimal places for the token
    /// @dev Returns the decimals value stored in contract storage during initialization
    /// @return The number of decimal places as uint8
    function decimals() public view virtual override returns (uint8) {
        return _getkTokenStorage()._decimals;
    }

    /// @notice Checks whether the contract is currently in paused state
    /// @dev Reads the isPaused flag from contract storage
    /// @return Boolean indicating if contract operations are paused
    function isPaused() external view returns (bool) {
        return _getkTokenStorage().isPaused;
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
    /// @param _isPaused Boolean indicating whether to pause (true) or unpause (false) the contract
    function setPaused(bool _isPaused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _getkTokenStorage().isPaused = _isPaused;
        emit PauseState(_isPaused);
    }

    /// @notice Emergency withdrawal of tokens sent by mistake
    /// @dev Can only be called by emergency admin when contract is paused
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        kTokenStorage storage $ = _getkTokenStorage();
        if (!$.isPaused) revert("Contract not paused");
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (token == address(0)) {
            // Withdraw ETH
            to.safeTransferETH(amount);
        } else {
            // Withdraw ERC20 token
            token.safeTransfer(to, amount);
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
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Internal function that validates upgrade authorization for UUPS pattern
    /// @dev Validates new implementation is not zero address and emits authorization event
    /// @param newImplementation The address of the new contract implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
        emit UpgradeAuthorized(newImplementation, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Provides the human-readable name identifier for this contract
    /// @dev Returns a constant string value for contract identification purposes
    /// @return The contract name as a string literal
    function contractName() external pure returns (string memory) {
        return "kToken";
    }

    /// @notice Provides the version number of this contract implementation
    /// @dev Returns a constant string value for version tracking purposes
    /// @return The contract version as a semantic version string
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
