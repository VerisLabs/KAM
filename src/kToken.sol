// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedOwnableRoles } from "src/vendor/solady/auth/OptimizedOwnableRoles.sol";
import { ERC20 } from "src/vendor/solady/tokens/ERC20.sol";
import { Multicallable } from "src/vendor/solady/utils/Multicallable.sol";
import { OptimizedReentrancyGuardTransient } from "src/vendor/solady/utils/OptimizedReentrancyGuardTransient.sol";
import { SafeTransferLib } from "src/vendor/solady/utils/SafeTransferLib.sol";

import {
    KTOKEN_IS_PAUSED, KTOKEN_TRANSFER_FAILED, KTOKEN_ZERO_ADDRESS, KTOKEN_ZERO_AMOUNT
} from "src/errors/Errors.sol";

/// @title kToken
/// @notice ERC20 representation of underlying assets with guaranteed 1:1 backing in the KAM protocol
/// @dev This contract serves as the tokenized wrapper for protocol-supported underlying assets (USDC, WBTC, etc.).
/// Each kToken maintains a strict 1:1 relationship with its underlying asset through controlled minting and burning.
/// Key characteristics: (1) Authorized minters (kMinter for institutional deposits, kAssetRouter for yield
/// distribution)
/// can create/destroy tokens, (2) kMinter mints tokens 1:1 when assets are deposited and burns during redemptions,
/// (3) kAssetRouter mints tokens to distribute positive yield to vaults and burns tokens for negative yield/losses,
/// (4) Implements three-tier role system: ADMIN_ROLE for management, EMERGENCY_ADMIN_ROLE for emergency operations,
/// MINTER_ROLE for token creation/destruction, (5) Features emergency pause mechanism to halt all transfers during
/// protocol emergencies, (6) Supports emergency asset recovery for accidentally sent tokens. The contract ensures
/// protocol integrity by maintaining that kToken supply accurately reflects the underlying asset backing plus any
/// distributed yield, while enabling efficient yield distribution without physical asset transfers.
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

    /// @notice Emergency pause state flag for halting all token operations during crises
    /// @dev When true, prevents all transfers, minting, and burning through _beforeTokenTransfer hook
    bool _isPaused;
    /// @notice Human-readable name of the kToken (e.g., "KAM USDC")
    /// @dev Stored privately to override ERC20 default implementation with custom naming
    string private _name;
    /// @notice Trading symbol of the kToken (e.g., "kUSDC")
    /// @dev Stored privately to provide consistent protocol naming convention
    string private _symbol;
    /// @notice Number of decimal places for the kToken, matching the underlying asset
    /// @dev Critical for maintaining 1:1 exchange rates with underlying assets
    uint8 private _decimals;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys and initializes a new kToken with specified parameters and role assignments
    /// @dev This constructor is called by kRegistry during asset registration to create the kToken wrapper.
    /// The process establishes: (1) ownership hierarchy with owner at the top, (2) role assignments for protocol
    /// operations, (3) token metadata matching the underlying asset. The decimals parameter is particularly
    /// important as it must match the underlying asset to maintain accurate 1:1 exchange rates.
    /// @param owner_ The contract owner (typically kRegistry or protocol governance)
    /// @param admin_ Address to receive ADMIN_ROLE for managing minters and emergency admins
    /// @param emergencyAdmin_ Address to receive EMERGENCY_ADMIN_ROLE for pause/emergency operations
    /// @param minter_ Address to receive initial MINTER_ROLE (typically kMinter contract)
    /// @param name_ Human-readable token name (e.g., \"KAM USDC\")
    /// @param symbol_ Token symbol for trading (e.g., \"kUSDC\")
    /// @param decimals_ Decimal places matching the underlying asset for accurate conversions
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

    /// @notice Creates new kTokens and assigns them to the specified address
    /// @dev This function serves two critical purposes in the KAM protocol: (1) kMinter calls this when institutional
    /// users deposit underlying assets, minting kTokens 1:1 to maintain backing ratio, (2) kAssetRouter calls this
    /// to distribute positive yield to vaults, increasing the kToken supply to reflect earned returns. The function
    /// is restricted to MINTER_ROLE holders (kMinter, kAssetRouter) and requires the contract to not be paused.
    /// All minting operations emit a Minted event for transparency and tracking.
    /// @param _to The address that will receive the newly minted kTokens
    /// @param _amount The quantity of kTokens to create (matches asset amount for deposits, yield amount for
    /// distributions)
    function mint(address _to, uint256 _amount) external onlyRoles(MINTER_ROLE) {
        _checkPaused();
        _mint(_to, _amount);
        emit Minted(_to, _amount);
    }

    /// @notice Destroys kTokens from the specified address
    /// @dev This function handles token destruction for two main scenarios: (1) kMinter burns escrowed kTokens during
    /// successful redemptions, reducing total supply to match the underlying assets being withdrawn, (2) kAssetRouter
    /// burns kTokens from vaults when negative yield/losses occur, ensuring the kToken supply accurately reflects the
    /// reduced underlying asset value. The burn operation is permanent and irreversible, requiring careful validation.
    /// Only MINTER_ROLE holders can execute burns, and the contract must not be paused.
    /// @param _from The address from which kTokens will be permanently destroyed
    /// @param _amount The quantity of kTokens to burn (matches redeemed assets or loss amounts)
    function burn(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE) {
        _checkPaused();
        _burn(_from, _amount);
        emit Burned(_from, _amount);
    }

    /// @notice Destroys kTokens from a specified address using the ERC20 allowance mechanism
    /// @dev This function enables more complex burning scenarios where the token holder has pre-approved the burn
    /// operation. The process involves: (1) checking and consuming the allowance between token owner and the minter,
    /// (2) burning the specified amount from the owner's balance. This is useful for automated systems or contracts
    /// that need to burn tokens on behalf of users, such as complex redemption flows or third-party integrations.
    /// The allowance model provides additional security by requiring explicit approval before token destruction.
    /// @param _from The address from which kTokens will be burned (must have approved the burn amount)
    /// @param _amount The quantity of kTokens to burn using the allowance mechanism
    function burnFrom(address _from, uint256 _amount) external onlyRoles(MINTER_ROLE) {
        _checkPaused();
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

    /// @notice Grants administrative privileges to a new address
    /// @dev Only the contract owner can grant admin roles, establishing the highest level of access control.
    /// Admins can manage emergency admins and minter roles but cannot bypass owner-only functions.
    /// @param admin The address to receive administrative privileges
    function grantAdminRole(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN_ROLE);
    }

    /// @notice Removes administrative privileges from an address
    /// @dev Only the contract owner can revoke admin roles, maintaining strict access control hierarchy.
    /// Revoking admin status prevents the address from managing emergency admins and minter roles.
    /// @param admin The address to lose administrative privileges
    function revokeAdminRole(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN_ROLE);
    }

    /// @notice Grants emergency administrative privileges for protocol safety operations
    /// @dev Emergency admins can pause/unpause the contract and execute emergency withdrawals during crises.
    /// This role is critical for protocol security and should only be granted to trusted addresses with
    /// operational procedures in place. Only existing admins can grant emergency roles.
    /// @param emergency The address to receive emergency administrative privileges
    function grantEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(emergency, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Removes emergency administrative privileges from an address
    /// @dev Removes the ability to pause contracts and execute emergency operations. This should be done
    /// carefully as it reduces the protocol's ability to respond to emergencies.
    /// @param emergency The address to lose emergency administrative privileges
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

    /// @notice Activates or deactivates the emergency pause mechanism
    /// @dev When paused, all token transfers, minting, and burning operations are halted to protect the protocol
    /// during security incidents or system maintenance. Only emergency admins can trigger pause/unpause to ensure
    /// rapid response capability. The pause state affects all token operations through the _beforeTokenTransfer hook.
    /// @param isPaused_ True to pause all operations, false to resume normal operations
    function setPaused(bool isPaused_) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _isPaused = isPaused_;
        emit PauseState(_isPaused);
    }

    /// @notice Emergency recovery function for accidentally sent assets
    /// @dev This function provides a safety mechanism to recover tokens or ETH accidentally sent to the kToken
    /// contract.
    /// It's designed for emergency situations where users mistakenly transfer assets to the wrong address.
    /// The function can handle both ERC20 tokens and native ETH. Only emergency admins can execute withdrawals
    /// to prevent unauthorized asset extraction. This should not be used for regular operations.
    /// @param token The token contract address to withdraw (use address(0) for native ETH)
    /// @param to The destination address to receive the recovered assets
    /// @param amount The quantity of tokens or ETH to recover
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

    /// @notice Internal function to validate that the contract is not in emergency pause state
    /// @dev Called before all token operations (transfers, mints, burns) to enforce emergency stops.
    /// Reverts with KTOKEN_IS_PAUSED if the contract is paused, effectively halting all token activity.
    function _checkPaused() private view {
        require(!_isPaused, KTOKEN_IS_PAUSED);
    }

    /// @notice Internal hook that executes before any token transfer, mint, or burn operation
    /// @dev This critical function enforces the pause mechanism across all token operations by checking the pause
    /// state before allowing any balance changes. It intercepts transfers, mints (from=0), and burns (to=0) to
    /// ensure protocol-wide emergency stops work correctly. The hook pattern allows centralized control over
    /// all token movements while maintaining ERC20 compatibility.
    /// @param from The source address (address(0) for minting operations)
    /// @param to The destination address (address(0) for burning operations)
    /// @param amount The quantity of tokens being transferred/minted/burned
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        _checkPaused();
        super._beforeTokenTransfer(from, to, amount);
    }
}
