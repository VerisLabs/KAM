// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IVersioned } from "kam/src/interfaces/IVersioned.sol";

interface IVaultAdapter is IVersioned {
    /* //////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the kMinter contract is initialized
    /// @param registry The address of the registry contract used for protocol configuration
    event ContractInitialized(address indexed registry);

    /// @notice Emitted when the emergency pause state is toggled for protocol-wide risk mitigation
    /// @dev This event signals a critical protocol state change that affects all inheriting contracts.
    /// When paused=true, protocol operations are halted to prevent potential exploits or manage emergencies.
    /// Only emergency admins can trigger this, providing rapid response capability during security incidents.
    /// @param paused_ The new pause state (true = operations halted, false = normal operation)
    event Paused(bool paused_);

    /// @notice Emitted when ERC20 tokens are rescued from the contract to prevent permanent loss
    /// @dev This rescue mechanism is restricted to non-protocol assets only - registered assets (USDC, WBTC, etc.)
    /// cannot be rescued to protect user funds and maintain protocol integrity. Typically used to recover
    /// accidentally sent tokens or airdrops. Only admin role can execute rescues as a security measure.
    /// @param asset_ The ERC20 token address being rescued (must not be a registered protocol asset)
    /// @param to_ The recipient address receiving the rescued tokens (cannot be zero address)
    /// @param amount_ The quantity of tokens rescued (must not exceed contract balance)
    event RescuedAssets(address indexed asset_, address indexed to_, uint256 amount_);

    /// @notice Emitted when native ETH is rescued from the contract to recover stuck funds
    /// @dev ETH rescue is separate from ERC20 rescue due to different transfer mechanisms. This prevents
    /// ETH from being permanently locked if sent to the contract accidentally. Uses low-level call for
    /// ETH transfer with proper success checking. Only admin role authorized for security.
    /// @param to_ The recipient address receiving the rescued ETH (cannot be zero address)
    /// @param amount_ The quantity of ETH rescued in wei (must not exceed contract balance)
    event RescuedETH(address indexed to_, uint256 amount_);

    /// @notice Emitted when the relayer executes an arbitrary call on behalf of the protocol
    /// @dev This event provides transparency into all external interactions initiated by the relayer.
    /// It logs the caller, target contract, function data, value sent, and the resulting returndata.
    /// This is critical for auditing and monitoring protocol actions executed via the relayer role.
    /// @param caller The relayer address that initiated the call
    /// @param target The target contract address that was called
    /// @param data The calldata sent to the target contract
    /// @param value The amount of assets sent with the call
    /// @param result The returndata returned from the call
    event Executed(address indexed caller, address indexed target, bytes data, uint256 value, bytes result);

    /// @notice Emmited when the relayer executes a transfer of assets on behalf of the protocol
    /// @dev This event provides transparency into all asset transfers initiated by the relayer.
    /// It logs the caller, asset, recipient, and amount transferred. This is critical for auditing
    /// and monitoring protocol asset movements executed via the relayer role.
    /// @param asset The asset address that was transferred (address(0) for native ETH)
    /// @param to The recipient address that received the assets
    /// @param amount The quantity of assets transferred
    event TransferExecuted(address indexed asset, address indexed to, uint256 amount);

    /* //////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
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
    function setPaused(bool paused_) external;

    /// @notice Rescues accidentally sent assets (ETH or ERC20 tokens) preventing permanent loss of funds
    /// @dev This function implements a critical safety mechanism for recovering tokens or ETH that become stuck
    /// in the contract through user error or airdrops. The rescue process: (1) Validates admin authorization to
    /// prevent unauthorized fund extraction, (2) Ensures recipient address is valid to prevent burning funds,
    /// (3) For ETH rescue (asset_=address(0)): validates balance sufficiency and uses low-level call for transfer,
    /// (4) For ERC20 rescue: critically checks the token is NOT a registered protocol asset (USDC, WBTC, etc.) to
    /// protect user deposits and protocol integrity, then validates balance and uses SafeTransferLib for secure
    /// transfer. The distinction between ETH and ERC20 handling accounts for their different transfer mechanisms.
    /// Protocol assets are explicitly blocked from rescue to prevent admin abuse and maintain user trust.
    /// @param asset_ The asset to rescue (use address(0) for native ETH, otherwise ERC20 token address)
    /// @param to_ The recipient address that will receive the rescued assets (cannot be zero address)
    /// @param amount_ The quantity to rescue (must not exceed available balance)
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable;

    /// @notice Allows the relayer to execute arbitrary calls on behalf of the protocol
    /// @dev This function enables the relayer role to perform flexible interactions with external contracts
    /// as part of protocol operations. Key aspects of this function include: (1) Authorization restricted to relayer
    /// role to prevent misuse, (2) Pause state check to ensure operations are halted during emergencies, (3) Validates
    /// target addresses are non-zero to prevent calls to the zero address, (4) Uses low-level calls to enable arbitrary
    /// function execution
    /// @param targets Array of target contracts to make calls to
    /// @param data Array of calldata to send to each target contract
    /// @param values Array of asset amounts to send with each call
    /// @return result The combined return data from all calls
    function execute(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
        external
        payable
        returns (bytes[] memory result);

    /// @notice Sets the last recorded total assets for vault accounting and performance tracking
    /// @dev This function allows the admin to update the lastTotalAssets variable, which is
    /// used for various accounting and performance metrics within the vault adapter. Key aspects
    /// of this function include: (1) Authorization restricted to admin role to prevent misuse,
    /// (2) Directly updates the lastTotalAssets variable in storage.
    /// @param totalAssets_ The new total assets value to set.
    function setTotalAssets(uint256 totalAssets_) external;

    /// @notice Retrieves the last recorded total assets for vault accounting and performance tracking
    /// @dev This function returns the lastTotalAssets variable, which is used for various accounting
    /// and performance metrics within the vault adapter. This provides a snapshot of the total assets
    /// managed by the vault at the last recorded time.
    /// @return The last recorded total assets value.
    function totalAssets() external view returns (uint256);

    /// @notice This function provides a way for the router to withdraw assets from the adapter
    /// @param asset_ The asset to pull (use address(0) for native ETH, otherwise ERC20 token address)
    /// @param amount_ The quantity to pull
    function pull(address asset_, uint256 amount_) external;
}
