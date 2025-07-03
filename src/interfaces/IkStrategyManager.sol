// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "src/types/DataTypes.sol";

/// @title IkStrategyManager
/// @notice Interface for kStrategyManager contract
interface IkStrategyManager {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event SettlementExecuted(uint256 indexed batchId, uint256 totalAmount, uint256 allocationsCount);
    event AllocationExecuted(address indexed target, DataTypes.AdapterType adapterType, uint256 amount);
    event AdapterRegistered(address indexed adapter, DataTypes.AdapterType adapterType, uint256 maxAllocation);
    event AdapterUpdated(address indexed adapter, bool enabled, uint256 maxAllocation);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount);
    event SettlementIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidSignature();
    error SignatureExpired();
    error InvalidNonce();
    error AllocationExceeded();
    error AdapterNotEnabled();
    error InvalidAdapter();
    error SettlementTooEarly();
    error TotalAllocationExceeded();
    error InvalidAllocationSum();
    error TooManyAllocations();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function settleAndAllocate(
        uint256 stakingBatchId,
        uint256 unstakingBatchId,
        DataTypes.AllocationOrder calldata order,
        bytes calldata signature
    )
        external;
    function emergencySettle(uint256 stakingBatchId, uint256 unstakingBatchId) external;
    function executeAllocation(DataTypes.AllocationOrder calldata order, bytes calldata signature) external;
    function registerAdapter(
        address adapter,
        DataTypes.AdapterType adapterType,
        uint256 maxAllocation,
        address implementation
    )
        external;
    function updateAdapter(address adapter, bool enabled, uint256 maxAllocation) external;
    function getAdapterConfig(address adapter) external view returns (DataTypes.AdapterConfig memory);
    function getNonce(address account) external view returns (uint256);
    function getRegisteredAdapters() external view returns (address[] memory);
    function setSettlementInterval(uint256 newInterval) external;
    function setPaused(bool paused) external;
    function emergencyWithdraw(address token, address to, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
