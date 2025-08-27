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
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable kMinter;
    address public asset;
    bytes32 public batchId;
    bool public isInitialised;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the kMinter address immutably
    /// @param _kMinter Address of the kMinter contract (only authorized caller)
    /// @dev Sets kMinter as immutable variable
    constructor(address _kMinter) {
        if (_kMinter == address(0)) revert ZeroAddress();
        kMinter = _kMinter;
    }

    /// @notice Initializes the batch receiver with batch parameters
    /// @param _batchId The batch ID this receiver serves
    /// @param _asset Address of the asset contract
    /// @dev Sets batch ID and asset, then emits initialization event
    function initialize(bytes32 _batchId, address _asset) external {
        if (isInitialised) revert IsInitialised();
        if (_asset == address(0)) revert ZeroAddress();

        batchId = _batchId;
        asset = _asset;
        isInitialised = true;

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
    function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external {
        if (msg.sender != kMinter) revert OnlyKMinter();
        if (_batchId != batchId) revert InvalidBatchId();
        if (amount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();

        asset.safeTransfer(receiver, amount);
        emit PulledAssets(receiver, asset, amount);
    }

    /// @notice Transfers assets from kMinter to the specified receiver
    /// @param asset_ Asset address
    /// @dev Only callable by kMinter, transfers assets to kMinter
    function rescueAssets(address asset_) external {
        address sender = msg.sender;
        if (sender != kMinter) revert OnlyKMinter();
        if (asset_ == asset) revert AssetCantBeRescue();
        
        uint256 balance = asset_.balanceOf(address(this));
        asset_.safeTransfer(sender, balance);
        emit RescuedAssets(asset_, sender, balance);
    }
}
