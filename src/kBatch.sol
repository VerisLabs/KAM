// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import { Extsload } from "src/abstracts/Extsload.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { kBatchTypes } from "src/types/kBatchTypes.sol";

/// @title kBatch
/// @notice Handles the protocol batching logic
contract kBatch is Initializable, UUPSUpgradeable, OwnableRoles, ReentrancyGuardTransient, Multicallable, Extsload {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant KMINTER_ROLE = _ROLE_1;

    address public immutable kMinterUSD;
    address public immutable kMinterBTC;
    address public immutable USDC;
    address public immutable WBTC;

    uint256 public constant SETTLEMENT_INTERVAL = 8 hours;
    uint256 public constant BATCH_CUTOFF_TIME = 4 hours;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kBatch.storage.kBatch
    struct kBatchStorage {
        uint256 currentBatchId;
        address batchReceiverImplementation;
        uint256 requestCounter;
        mapping(uint256 => kBatchTypes.BatchInfo) batches;
    }

    // keccak256(abi.encode(uint256(keccak256("kBatch.storage.kBatch")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant kBATCH_STORAGE_LOCATION =
        0x13c7c99a947cbbabed54ccebce1e23703834d5c9f38341d94ef7ca0fc9ab6c00;

    function _getkBatchStorage() private pure returns (kBatchStorage storage $) {
        assembly {
            $.slot := kBATCH_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetsReceived(address indexed receiver, uint256 indexed amount);
    event BatchCreated(uint256 indexed batchId, uint256 startTime, uint256 cutoffTime, uint256 settlementTime);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error OnlyKMinter();
    error InvalidBatchId();
    error BatchClosed();
    error BatchSettled();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _kMinterUSD,
        address _kMinterBTC,
        address _USDC,
        address _WBTC,
        address admin_
    )
        external
        initializer
    {
        if (_kMinterUSD == address(0) || _kMinterBTC == address(0) || _USDC == address(0) || _WBTC == address(0)) {
            revert ZeroAddress();
        }

        kBatchStorage storage $ = _getkBatchStorage();

        // Deploy BatchReceiver implementation with actual parameters
        $.batchReceiverImplementation = address(
            new kBatchReceiver(
                _kMinterUSD,
                _kMinterBTC,
                0, // batchId placeholder
                _USDC,
                _WBTC
            )
        );

        _initializeOwner(admin_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(_kMinterUSD, KMINTER_ROLE);
        _grantRoles(_kMinterBTC, KMINTER_ROLE);

        _newBatch();
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Forces creation of new time-based batch
    function forceCreateNewBatch() external onlyRoles(ADMIN_ROLE) {
        _newBatch();
    }

    function setBatchReceiverImplementation(address _batchReceiverImplementation) external onlyRoles(ADMIN_ROLE) {
        kBatchStorage storage $ = _getkBatchStorage();
        $.batchReceiverImplementation = _batchReceiverImplementation;
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function batchToUse() external onlyRoles(KMINTER_ROLE) returns (uint256) {
        return _batchToUse();
    }

    function deployBatchReceiver(uint256 _batchId) external onlyRoles(KMINTER_ROLE) {
        _deployBatchReceiver(_batchId);
    }

    function updateBatchInfo(uint256 _batchId, address _asset, int256 _netPosition) external onlyRoles(KMINTER_ROLE) {
        kBatchStorage storage $ = _getkBatchStorage();

        if ($.batches[_batchId].isClosed) revert BatchClosed();
        if ($.batches[_batchId].isSettled) revert BatchSettled();
        if (!$.batches[_batchId].assetsInBatch[_asset]) {
            $.batches[_batchId].assetsInBatch[_asset] = true;
        }
        if ($.batches[_batchId].vaultsInBatch[msg.sender] == address(0)) {
            $.batches[_batchId].vaultsInBatch[msg.sender] = _asset;
        }

        $.batches[_batchId].assetNetPositions[_asset] += _netPosition;
    }

    function settleBatch(uint256 _batchId) external onlyRoles(KMINTER_ROLE) {
        kBatchStorage storage $ = _getkBatchStorage();
        $.batches[_batchId].isSettled = true;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getCurrentBatchId() external view returns (uint256) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.currentBatchId;
    }

    function isBatchSettled(uint256 _batchId) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].isClosed;
    }

    function getBatchInfo(uint256 _batchId)
        external
        view
        returns (
            uint256 batchId,
            uint256 startTime,
            uint256 cutoffTime,
            uint256 settlementTime,
            address batchReceiver,
            bool isClosed,
            bool isSettled
        )
    {
        kBatchStorage storage $ = _getkBatchStorage();
        return (
            $.batches[_batchId].batchId,
            $.batches[_batchId].startTime,
            $.batches[_batchId].cutoffTime,
            $.batches[_batchId].settlementTime,
            $.batches[_batchId].batchReceiver,
            $.batches[_batchId].isClosed,
            $.batches[_batchId].isSettled
        );
    }

    function getBatchReceiver(uint256 _batchId) external view returns (address) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].batchReceiver;
    }

    function getBatchAssets(uint256 _batchId) external view returns (address[] memory) {
        // NOTE: This function would need to be implemented with additional tracking
        // For now, return empty array
        return new address[](0);
    }

    function getBatchVaults(uint256 _batchId) external view returns (address[] memory) {
        // NOTE: This function would need to be implemented with additional tracking
        // For now, return empty array
        return new address[](0);
    }

    function isAssetInBatch(uint256 _batchId, address _asset) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].assetsInBatch[_asset];
    }

    function isVaultInBatch(uint256 _batchId, address _vault) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].vaultsInBatch[_vault] != address(0);
    }

    function getAssetInVaultBatch(uint256 _batchId, address _vault) external view returns (address) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].vaultsInBatch[_vault];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new time-based batch with 4h cutoff
    function _newBatch() internal {
        kBatchStorage storage $ = _getkBatchStorage();
        uint256 newBatchId = ++$.currentBatchId;
        uint256 startTime = block.timestamp;

        kBatchTypes.BatchInfo storage batch = $.batches[newBatchId];
        batch.batchId = newBatchId;
        batch.startTime = startTime.toUint64();
        batch.cutoffTime = (startTime + BATCH_CUTOFF_TIME).toUint64();
        batch.settlementTime = (startTime + SETTLEMENT_INTERVAL).toUint64();
        batch.batchReceiver = address(0);
        batch.isClosed = false;
        batch.isSettled = false;

        emit BatchCreated(newBatchId, startTime, startTime + BATCH_CUTOFF_TIME, startTime + SETTLEMENT_INTERVAL);
    }

    /// @notice Deploys BatchReceiver for specific batch
    function _deployBatchReceiver(uint256 batchId) internal returns (address) {
        kBatchStorage storage $ = _getkBatchStorage();

        address receiver = $.batches[batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        // Deploy new BatchReceiver directly (not using clone due to immutable variables)
        receiver = address(new kBatchReceiver(kMinterUSD, kMinterBTC, batchId, USDC, WBTC));
        $.batches[batchId].batchReceiver = receiver;

        return receiver;
    }

    /// @notice Gets target batch ID based on time cutoff
    function _batchToUse() internal returns (uint256) {
        kBatchStorage storage $ = _getkBatchStorage();
        kBatchTypes.BatchInfo storage currentBatch = $.batches[$.currentBatchId];

        // If past cutoff time, create new batch and use it
        if (block.timestamp > currentBatch.cutoffTime) {
            _newBatch();
            return $.currentBatchId;
        }

        return $.currentBatchId;
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @dev Only callable by ADMIN_ROLE
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kBatch";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
