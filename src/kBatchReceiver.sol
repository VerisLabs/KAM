// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";

/// @title kBatchReceiver
/// @notice Minimal proxy contract that holds and distributes settled assets for batch redemptions
/// @dev Deployed per batch to isolate asset distribution and enable efficient settlement
contract kBatchReceiver is IkBatchReceiver {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable kMinter;
    address public immutable asset;
    uint256 public immutable batchId;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the batch receiver with immutable parameters
    /// @param _kMinter Address of the kMinter contract (only authorized caller)
    /// @param _batchId The batch ID this receiver serves
    /// @param _asset Address of the asset contract
    /// @dev Sets immutable variables and emits initialization event
    constructor(address _kMinter, uint256 _batchId, address _asset) {
        if (_kMinter == address(0)) revert ZeroAddress();
        kMinter = _kMinter;
        batchId = _batchId;
        asset = _asset;

        emit BatchReceiverInitialized(kMinter, batchId, asset);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers assets from kMinter to the specified receiver
    /// @param receiver Address to receive the assets
    /// @param amount Amount of assets to transfer
    /// @param _batchId Batch ID for validation (must match this receiver's batch)
    /// @dev Only callable by kMinter, transfers assets from caller to receiver
    function pullAssets(address receiver, uint256 amount, uint256 _batchId) external {
        if (msg.sender != kMinter) revert OnlyKMinter();
        if (_batchId != batchId) revert InvalidBatchId();
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        asset.safeTransfer(receiver, amount);
        emit PulledAssets(receiver, asset, amount);
    }
}
