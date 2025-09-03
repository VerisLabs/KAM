// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title VaultBatches
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract VaultBatches is BaseVaultModule {
    using SafeCastLib for uint256;
    using SafeCastLib for uint64;
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchCreated(bytes32 indexed batchId);
    event BatchReceiverDeployed(bytes32 indexed batchId, address indexed receiver);
    event BatchSettled(bytes32 indexed batchId);
    event BatchClosed(bytes32 indexed batchId);
    event BatchReceiverSet(address indexed batchReceiver, bytes32 indexed batchId);
    event BatchReceiverCreated(address indexed receiver, bytes32 indexed batchId);

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function createNewBatch() external returns (bytes32) {
        if (!_isRelayer(msg.sender)) revert WrongRole();
        return _createNewBatch();
    }

    /// @notice Closes a batch to prevent new requests
    /// @param _batchId The batch ID to close
    /// @dev Only callable by RELAYER_ROLE, typically called at cutoff time
    function closeBatch(bytes32 _batchId, bool _create) external {
        if (!_isRelayer(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        if ($.batches[_batchId].isClosed) revert Closed();
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
        if (!_isKAssetRouter(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        if (!$.batches[_batchId].isClosed) revert NotClosed();
        if ($.batches[_batchId].isSettled) revert Settled();
        $.batches[_batchId].isSettled = true;

        emit BatchSettled(_batchId);
    }

    /// @notice Deploys BatchReceiver for specific batch
    /// @param _batchId Batch ID to deploy receiver for
    /// @dev Only callable by kAssetRouter
    function createBatchReceiver(bytes32 _batchId) external nonReentrant returns (address) {
        if (!_isKAssetRouter(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        address receiver = $.batches[_batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        receiver = LibClone.clone($.receiverImplementation);
        $.batches[_batchId].batchReceiver = receiver;
        kBatchReceiver(receiver).initialize(_batchId, $.underlyingAsset);

        emit BatchReceiverCreated(receiver, _batchId);

        return receiver;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function _createNewBatch() internal returns (bytes32) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        unchecked {
            $.currentBatch++;
        }
        bytes32 newBatchId = EfficientHashLib.hash(
            uint256(uint160(address(this))),
            $.currentBatch,
            block.chainid,
            block.timestamp,
            uint256(uint160($.underlyingAsset))
        );

        $.currentBatchId = newBatchId;
        BaseVaultModuleTypes.BatchInfo storage batch = $.batches[newBatchId];
        batch.batchId = newBatchId;
        batch.batchReceiver = address(0);
        batch.isClosed = false;
        batch.isSettled = false;

        emit BatchCreated(newBatchId);

        return newBatchId;
    }
}
