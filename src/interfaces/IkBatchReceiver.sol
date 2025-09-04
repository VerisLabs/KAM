// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for kBatchReceiver
interface IkBatchReceiver {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchReceiverInitialized(address indexed kMinter, bytes32 indexed batchId, address asset);
    event PulledAssets(address indexed receiver, address indexed asset, uint256 amount);
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
    event RescuedETH(address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    function kMinter() external view returns (address);
    function asset() external view returns (address);
    function batchId() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external;
    function rescueAssets(address asset_) external payable;
}
