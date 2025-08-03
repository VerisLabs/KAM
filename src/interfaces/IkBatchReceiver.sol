// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for kBatchReceiver
interface IkBatchReceiver {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchReceiverInitialized(address indexed kMinter, uint256 indexed batchId, address asset);
    event PulledAssets(address indexed receiver, address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error OnlyKMinter();
    error InvalidBatchId();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    function kMinter() external view returns (address);
    function asset() external view returns (address);
    function batchId() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function pullAssets(address receiver, uint256 amount, uint256 _batchId) external;
}
