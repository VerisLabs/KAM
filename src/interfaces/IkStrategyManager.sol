// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "src/types/DataTypes.sol";

/// @title IkStrategyManager
/// @notice Interface for kStrategyManager contract that orchestrates settlement and asset allocation
/// @dev Defines the standard interface for strategy management implementations
interface IkStrategyManager {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a multi-phase settlement has been executed successfully
    /// @dev Indicates completion of vault settlements and strategy allocations
    event SettlementExecuted(uint256 indexed batchId, uint256 totalAmount, uint256 allocationsCount);

    /// @notice Emitted when an individual allocation to a strategy adapter has been executed
    /// @dev Indicates successful asset allocation to a specific strategy
    event AllocationExecuted(address indexed target, DataTypes.AdapterType adapterType, uint256 amount);

    /// @notice Emitted when a new strategy adapter has been registered
    /// @dev Indicates a new strategy is available for asset allocation
    event AdapterRegistered(address indexed adapter, DataTypes.AdapterType adapterType, uint256 maxAllocation);

    /// @notice Emitted when an existing adapter configuration has been updated
    /// @dev Indicates changes to adapter settings or status
    event AdapterUpdated(address indexed adapter, bool enabled, uint256 maxAllocation);

    /// @notice Emitted when an emergency withdrawal has been executed
    /// @dev Indicates emergency asset recovery during paused state
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);

    /// @notice Emitted when the settlement interval has been updated
    /// @dev Indicates changes to the timing between settlement operations
    event SettlementIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when attempting operations while the contract is paused
    error Paused();
    /// @notice Thrown when a zero address is provided where a valid address is required
    error ZeroAddress();
    /// @notice Thrown when a zero amount is provided where a positive amount is required
    error ZeroAmount();
    /// @notice Thrown when a cryptographic signature is invalid or corrupted
    error InvalidSignature();
    /// @notice Thrown when a signed order has passed its expiration deadline
    error SignatureExpired();
    /// @notice Thrown when a nonce is invalid or has already been used
    error InvalidNonce();
    /// @notice Thrown when an allocation exceeds the maximum allowed limit
    error AllocationExceeded();
    /// @notice Thrown when attempting to use a disabled or non-existent adapter
    error AdapterNotEnabled();
    /// @notice Thrown when an adapter configuration is invalid
    error InvalidAdapter();
    /// @notice Thrown when attempting settlement before the required interval has passed
    error SettlementTooEarly();
    /// @notice Thrown when the total allocation would exceed global limits
    error TotalAllocationExceeded();
    /// @notice Thrown when individual allocations don't sum to the expected total
    error InvalidAllocationSum();
    /// @notice Thrown when too many allocations are provided in a single order
    error TooManyAllocations();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Orchestrates multi-phase settlement across the entire protocol with strategy allocation
    /// @dev Implements proper settlement ordering: Institutional → User Staking → Strategy Deployment
    /// @param stakingBatchId Identifier for the staking batch to process
    /// @param unstakingBatchId Identifier for the unstaking batch to process, or 0 to skip
    /// @param totalKTokensStaked Total kTokens in staking batch (backend calculated)
    /// @param totalStkTokensUnstaked Total stkTokens in unstaking batch (backend calculated)
    /// @param totalKTokensToReturn Total original kTokens to return to users
    /// @param totalYieldToMinter Total yield to transfer back to minter pool
    /// @param order Structured allocation instructions containing targets and amounts
    /// @param signature Cryptographic signature validating the allocation order
    function settleAndAllocate(
        uint256 stakingBatchId,
        uint256 unstakingBatchId,
        uint256 totalKTokensStaked,
        uint256 totalStkTokensUnstaked,
        uint256 totalKTokensToReturn,
        uint256 totalYieldToMinter,
        DataTypes.AllocationOrder calldata order,
        bytes calldata signature
    )
        external;
    /// @notice Emergency settlement function that bypasses allocation logic
    /// @dev Only processes vault batch settlement without executing any asset allocation
    /// @param stakingBatchId Identifier for the staking batch to process
    /// @param unstakingBatchId Identifier for the unstaking batch to process
    /// @param totalKTokensStaked Total kTokens in staking batch
    /// @param totalStkTokensUnstaked Total stkTokens in unstaking batch
    /// @param totalKTokensToReturn Total original kTokens to return to users
    /// @param totalYieldToMinter Total yield to transfer back to minter pool
    function emergencySettle(
        uint256 stakingBatchId,
        uint256 unstakingBatchId,
        uint256 totalKTokensStaked,
        uint256 totalStkTokensUnstaked,
        uint256 totalKTokensToReturn,
        uint256 totalYieldToMinter
    )
        external;

    /// @notice Processes asset allocation according to signed allocation order
    /// @dev Validates signature and executes distribution across specified strategy adapters
    /// @param order Structured allocation instructions containing targets and amounts
    /// @param signature Cryptographic signature validating the allocation order
    function executeAllocation(DataTypes.AllocationOrder calldata order, bytes calldata signature) external;

    /// @notice Registers a new strategy adapter for asset allocation
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param adapter Address of the adapter contract
    /// @param adapterType Type category of the adapter
    /// @param maxAllocation Maximum allocation percentage (basis points)
    /// @param implementation Address of the adapter implementation contract
    function registerAdapter(
        address adapter,
        DataTypes.AdapterType adapterType,
        uint256 maxAllocation,
        address implementation
    )
        external;

    /// @notice Updates configuration for an existing strategy adapter
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param adapter Address of the adapter to update
    /// @param enabled Whether the adapter should be active
    /// @param maxAllocation Maximum allocation percentage (basis points)
    function updateAdapter(address adapter, bool enabled, uint256 maxAllocation) external;

    /// @notice Returns the configuration details for a specific adapter
    /// @param adapter Address of the adapter to query
    /// @return Configuration structure containing adapter settings
    function getAdapterConfig(address adapter) external view returns (DataTypes.AdapterConfig memory);

    /// @notice Returns the current nonce for a specific account
    /// @dev Used for replay protection in signed allocation orders
    /// @param account Address to query the nonce for
    /// @return The current nonce value for the account
    function getNonce(address account) external view returns (uint256);

    /// @notice Returns all registered adapter addresses
    /// @return Array of adapter addresses registered for allocation
    function getRegisteredAdapters() external view returns (address[] memory);

    /// @notice Sets the minimum interval between settlement operations
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param newInterval New settlement interval in seconds
    function setSettlementInterval(uint256 newInterval) external;

    /// @notice Sets the pause state of the contract
    /// @dev Only callable by addresses with EMERGENCY_ADMIN_ROLE
    /// @param paused True to pause the contract, false to unpause
    function setPaused(bool paused) external;

    /// @notice Emergency withdraws tokens when the contract is paused
    /// @dev Only callable by addresses with EMERGENCY_ADMIN_ROLE when paused
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address for the withdrawal
    /// @param amount Amount of tokens to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name identifier for this contract type
    /// @return The contract name as a string
    function contractName() external pure returns (string memory);

    /// @notice Returns the version identifier for this contract
    /// @return The contract version as a string
    function contractVersion() external pure returns (string memory);
}
