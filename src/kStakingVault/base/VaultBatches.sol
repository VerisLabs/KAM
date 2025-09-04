// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedLibClone } from "src/libraries/OptimizedLibClone.sol";
import { OptimizedSafeCastLib } from "src/libraries/OptimizedSafeCastLib.sol";

import {
    VAULTBATCHES_NOT_CLOSED,
    VAULTBATCHES_VAULT_CLOSED,
    VAULTBATCHES_VAULT_SETTLED,
    VAULTBATCHES_WRONG_ROLE
} from "src/errors/Errors.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVault } from "src/kStakingVault/base/BaseVault.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

/// @title VaultBatches
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract VaultBatches is BaseVault {
    using OptimizedSafeCastLib for uint256;
    using OptimizedSafeCastLib for uint64;
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new batch is created
    /// @param batchId The batch ID of the new batch
    event BatchCreated(bytes32 indexed batchId);

    /// @notice Emitted when a batch is settled
    /// @param batchId The batch ID of the settled batch
    event BatchSettled(bytes32 indexed batchId);

    /// @notice Emitted when a batch is closed
    /// @param batchId The batch ID of the closed batch
    event BatchClosed(bytes32 indexed batchId);

    /// @notice Emitted when a BatchReceiver is created
    /// @param receiver The address of the created BatchReceiver
    /// @param batchId The batch ID of the BatchReceiver
    event BatchReceiverCreated(address indexed receiver, bytes32 indexed batchId);

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function createNewBatch() external returns (bytes32) {
        require(_isRelayer(msg.sender), VAULTBATCHES_WRONG_ROLE);
        return _createNewBatch();
    }

    /// @notice Closes a batch to prevent new requests
    /// @param _batchId The batch ID to close
    /// @param _create Whether to create a new batch after closing
    /// @dev Only callable by RELAYER_ROLE, typically called at cutoff time
    function closeBatch(bytes32 _batchId, bool _create) external {
        require(_isRelayer(msg.sender), VAULTBATCHES_WRONG_ROLE);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(!$.batches[_batchId].isClosed, VAULTBATCHES_VAULT_CLOSED);
        $.batches[_batchId].isClosed = true;

        if (_create) {
            _batchId = _createNewBatch();
        }
        emit BatchClosed(_batchId);
    }

    /// @notice Marks a batch as settled
    /// @param _batchId The batch ID to settle
    /// @dev Only callable by kMinter, indicates assets have been distributed
    function settleBatch(bytes32 _batchId) external {
        require(_isKAssetRouter(msg.sender), VAULTBATCHES_WRONG_ROLE);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require($.batches[_batchId].isClosed, VAULTBATCHES_NOT_CLOSED);
        require(!$.batches[_batchId].isSettled, VAULTBATCHES_VAULT_SETTLED);
        $.batches[_batchId].isSettled = true;

        // Snapshot the gross and net share price for this batch
        $.batches[_batchId].sharePrice = _sharePrice().toUint128();
        $.batches[_batchId].netSharePrice = _netSharePrice().toUint128();

        emit BatchSettled(_batchId);
    }

    /// @notice Deploys BatchReceiver for specific batch
    /// @param _batchId Batch ID to deploy receiver for
    /// @dev Only callable by kAssetRouter
    function createBatchReceiver(bytes32 _batchId) external returns (address) {
        _lockReentrant();
        require(_isKAssetRouter(msg.sender), VAULTBATCHES_WRONG_ROLE);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        address receiver = $.batches[_batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        receiver = OptimizedLibClone.clone($.receiverImplementation);
        $.batches[_batchId].batchReceiver = receiver;

        // Initialize the BatchReceiver
        kBatchReceiver(receiver).initialize(_batchId, $.underlyingAsset);

        emit BatchReceiverCreated(receiver, _batchId);

        _unlockReentrant();
        return receiver;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function _createNewBatch() internal returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        unchecked {
            $.currentBatch++;
        }
        bytes32 newBatchId = keccak256(
            abi.encode(
                uint256(uint160(address(this))),
                $.currentBatch,
                block.chainid,
                block.timestamp,
                uint256(uint160($.underlyingAsset))
            )
        );

        // Update current batch ID and initialize new batch
        $.currentBatchId = newBatchId;
        BaseVaultTypes.BatchInfo storage batch = $.batches[newBatchId];
        batch.batchId = newBatchId;
        batch.batchReceiver = address(0);
        batch.isClosed = false;
        batch.isSettled = false;

        emit BatchCreated(newBatchId);

        return newBatchId;
    }
}
