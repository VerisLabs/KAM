// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { LibClone } from "solady/utils/LibClone.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title BatchModule
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract BatchModule is BaseVaultModule {
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

    // @notice Closes a batch to prevent new requests
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
    function createBatchReceiver(bytes32 _batchId) external returns (address) {
        if (!_isKAssetRouter(msg.sender)) revert WrongRole();
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        address receiver = $.batches[_batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        receiver = LibClone.clone($.receiverImplementation);
        kBatchReceiver(receiver).initialize(_batchId, $.underlyingAsset);

        $.batches[_batchId].batchReceiver = receiver;

        emit BatchReceiverCreated(receiver, _batchId);

        return receiver;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createNewBatch() internal returns (bytes32) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        $.currentBatch++;
        bytes32 newBatchId = keccak256(
            abi.encodePacked(address(this), $.currentBatch, block.chainid, block.timestamp, $.underlyingAsset)
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

    /// @notice Returns the selectors for functions in this module
    /// @return selectors Array of function selectors
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory moduleSelectors = new bytes4[](4);
        moduleSelectors[0] = this.createNewBatch.selector;
        moduleSelectors[1] = this.closeBatch.selector;
        moduleSelectors[2] = this.settleBatch.selector;
        moduleSelectors[3] = this.createBatchReceiver.selector;
        return moduleSelectors;
    }
}
