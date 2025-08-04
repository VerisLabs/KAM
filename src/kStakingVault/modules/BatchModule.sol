// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

/// @title ClaimModule
/// @notice Handles claim operations for settled batches
/// @dev Contains claim functions for staking and unstaking operations
contract BatchModule is BaseModule {
    using SafeCastLib for uint256;
    using SafeCastLib for uint64;
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event BatchCreated(uint256 indexed batchId);
    event BatchReceiverDeployed(uint256 indexed batchId, address indexed receiver);
    event BatchSettled(uint256 indexed batchId);
    event BatchClosed(uint256 indexed batchId);
    event BatchReceiverSet(address indexed batchReceiver, uint256 indexed batchId);
    event BatchReceiverCreated(address indexed receiver, uint256 indexed batchId);

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function createNewBatch() external onlyRelayer returns (uint256) {
        return _newBatch();
    }

    // @notice Closes a batch to prevent new requests
    /// @param _batchId The batch ID to close
    /// @dev Only callable by RELAYER_ROLE, typically called at cutoff time
    function closeBatch(uint256 _batchId, bool _create) external onlyRelayer {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if ($.batches[_batchId].isClosed) revert Closed();
        $.batches[_batchId].isClosed = true;

        if (_create) {
            _batchId = _newBatch();
        }
        emit BatchClosed(_batchId);
    }

    /// @notice Marks a batch as settled
    /// @param _batchId The batch ID to settle
    /// @dev Only callable by kMinter, indicates assets have been distributed
    function settleBatch(uint256 _batchId) external onlyKAssetRouter {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if ($.batches[_batchId].isSettled) revert Settled();
        $.batches[_batchId].isSettled = true;

        emit BatchSettled(_batchId);
    }

    /// @notice Deploys BatchReceiver for specific batch
    /// @param _batchId Batch ID to deploy receiver for
    /// @dev Only callable by kAssetRouter
    function createBatchReceiver(uint256 _batchId) external onlyKAssetRouter returns (address) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        address receiver = $.batches[_batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        receiver = address(new kBatchReceiver(_registry().getContractById(K_MINTER), _batchId, $.underlyingAsset));

        $.batches[_batchId].batchReceiver = receiver;

        emit BatchReceiverCreated(receiver, _batchId);

        return receiver;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _newBatch() internal returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        $.batchCounter = (uint256($.batchCounter) + 1).toUint64();
        $.currentBatchId = uint256(keccak256(abi.encode(address(this), block.timestamp, $.batchCounter)));
        uint256 newBatchId = $.currentBatchId;

        BaseModuleTypes.BatchInfo storage batch = $.batches[newBatchId];
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
