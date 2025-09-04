// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";

import {
    KBATCHRECEIVER_ALREADY_INITIALIZED,
    KBATCHRECEIVER_INVALID_BATCH_ID,
    KBATCHRECEIVER_ONLY_KMINTER,
    KBATCHRECEIVER_TRANSFER_FAILED,
    KBATCHRECEIVER_WRONG_ASSET,
    KBATCHRECEIVER_ZERO_ADDRESS,
    KBATCHRECEIVER_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";

/// @title kBatchReceiver
/// @notice Minimal proxy contract that holds and distributes settled assets for batch redemptions
/// @dev Deployed per batch to isolate asset distribution and enable efficient settlement
contract kBatchReceiver is IkBatchReceiver {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the kMinter contract (only authorized caller)
    address public immutable kMinter;
    /// @notice Address of the asset contract
    address public asset;
    /// @notice Batch ID this receiver serves
    bytes32 public batchId;
    /// @notice Whether this receiver has been initialised
    bool public isInitialised;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the kMinter address immutably
    /// @param _kMinter Address of the kMinter contract (only authorized caller)
    /// @dev Sets kMinter as immutable variable
    constructor(address _kMinter) {
        require(_kMinter != address(0), KBATCHRECEIVER_ZERO_ADDRESS);
        kMinter = _kMinter;
    }

    /// @notice Initializes the batch receiver with batch parameters
    /// @param _batchId The batch ID this receiver serves
    /// @param _asset Address of the asset contract
    /// @dev Sets batch ID and asset, then emits initialization event
    function initialize(bytes32 _batchId, address _asset) external {
        require(!isInitialised, KBATCHRECEIVER_ALREADY_INITIALIZED);
        require(_asset != address(0), KBATCHRECEIVER_ZERO_ADDRESS);

        isInitialised = true;
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
    function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external {
        require(msg.sender == kMinter, KBATCHRECEIVER_ONLY_KMINTER);
        require(_batchId == batchId, KBATCHRECEIVER_INVALID_BATCH_ID);
        require(amount != 0, KBATCHRECEIVER_ZERO_AMOUNT);
        require(receiver != address(0), KBATCHRECEIVER_ZERO_ADDRESS);

        asset.safeTransfer(receiver, amount);
        emit PulledAssets(receiver, asset, amount);
    }

    /// @notice Transfers assets from kMinter to the specified receiver
    /// @param asset_ Asset address (use address(0) for ETH)
    /// @dev Only callable by kMinter, transfers assets to kMinter
    function rescueAssets(address asset_) external payable {
        address sender = msg.sender;
        require(sender == kMinter, KBATCHRECEIVER_ONLY_KMINTER);

        if (asset_ == address(0)) {
            // Rescue ETH
            uint256 balance = address(this).balance;
            require(balance != 0, KBATCHRECEIVER_ZERO_AMOUNT);

            (bool success,) = sender.call{ value: balance }("");
            require(success, KBATCHRECEIVER_TRANSFER_FAILED);

            emit RescuedETH(sender, balance);
        } else {
            // Rescue ERC20 tokens
            require(asset_ != asset, KBATCHRECEIVER_WRONG_ASSET);

            uint256 balance = asset_.balanceOf(address(this));
            require(balance != 0, KBATCHRECEIVER_ZERO_AMOUNT);

            asset_.safeTransfer(sender, balance);
            emit RescuedAssets(asset_, sender, balance);
        }
    }
}
