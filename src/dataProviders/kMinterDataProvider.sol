// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { kMinter } from "src/kMinter.sol";

/// @title kMinterDataProvider
/// @notice Data provider for kMinter contract using direct storage access pattern
/// @dev Provides efficient batch queries and accounting data for frontend and monitoring systems
///
/// ARCHITECTURE:
/// This contract provides read-only access to kMinter state using the extsload pattern,
/// enabling gas-efficient batch queries without modifying the main contract.
/// All storage slot calculations follow the ERC-7201 pattern used by kMinter.
///
/// KEY FEATURES:
/// - Direct storage access via extsload for gas efficiency
/// - Batch queries to minimize RPC calls
/// - Settlement timing calculations
/// - Accounting validation functions
/// - Bitmap status reading for request tracking
contract kMinterDataProvider {
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice kMinter storage location following ERC-7201 pattern
    /// @dev keccak256(abi.encode(uint256(keccak256("kMinter.storage.kMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KMINTER_STORAGE_LOCATION =
        0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00;

    /// @notice Settlement interval matching kMinter constant
    uint256 private constant SETTLEMENT_INTERVAL = 8 hours;

    /*//////////////////////////////////////////////////////////////
                              IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Target kMinter contract
    kMinter public immutable minter;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided
    error ZeroAddress();

    /// @notice Thrown when an invalid batch ID is provided
    error InvalidBatchId();

    /// @notice Thrown when a request ID doesn't exist
    error RequestNotFound();

    /// @notice Thrown when storage slot calculation overflows
    error StorageSlotOverflow();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the data provider for a specific kMinter instance
    /// @param _minter Address of the kMinter contract to read from
    constructor(address _minter) {
        if (_minter == address(0)) revert ZeroAddress();
        minter = kMinter(payable(_minter));
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH DATA QUERIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Get comprehensive batch data and settlement status
    /// @return currentBatchId Current batch ID being populated
    /// @return totalDeposited Total amount deposited across all batches
    /// @return totalRedeemed Total amount redeemed across all batches
    /// @return totalPendingRedemptions Total pending redemption amounts
    function getBatchData()
        external
        view
        returns (uint256 currentBatchId, uint256 totalDeposited, uint256 totalRedeemed, uint256 totalPendingRedemptions)
    {
        // Read from storage slots using extsload
        // Storage layout in kMinterStorage:
        // Slot 0: isPaused (bool)
        // Slot 1: kToken (address)
        // Slot 2: underlyingAsset (address)
        // Slot 3: kDNStaking (address)
        // Slot 4: kStrategyManager (address)
        // Slot 5: batchReceiverImplementation (address)
        // Slot 6: currentBatchId (uint256)
        // Slot 7: requestCounter (uint256)
        // Slots 8-13: mappings (separate storage trees)
        // Slot 14: totalDeposited (uint256)
        // Slot 15: totalRedeemed (uint256)
        // Slot 16: totalPendingRedemptions (uint256)
        // Slot 17: isAuthorizedMinter (bool)

        bytes32[] memory slots = new bytes32[](4);
        slots[0] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 6); // currentBatchId
        slots[1] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 14); // totalDeposited
        slots[2] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 15); // totalRedeemed
        slots[3] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 16); // totalPendingRedemptions

        bytes32[] memory values = minter.extsload(slots);

        currentBatchId = uint256(values[0]);
        totalDeposited = uint256(values[1]);
        totalRedeemed = uint256(values[2]);
        totalPendingRedemptions = uint256(values[3]);
    }

    /// @notice Get detailed batch information for a specific batch
    /// @param batchId Batch ID to query
    /// @return exists Whether the batch exists
    /// @return startTime Batch start time
    /// @return cutoffTime Batch cutoff time
    /// @return batchReceiver Address of the batch receiver contract
    /// @return isClosed Whether the batch is closed
    /// @return totalAmount Total amount in this batch
    function getBatchInfo(uint256 batchId)
        external
        view
        returns (
            bool exists,
            uint256 startTime,
            uint256 cutoffTime,
            address batchReceiver,
            bool isClosed,
            uint256 totalAmount
        )
    {
        // Calculate batch mapping slot: keccak256(batchId . slot)
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(KMINTER_STORAGE_LOCATION) + 7));

        // Read batch data from storage (DataTypes.BatchInfo struct)
        bytes32[] memory slots = new bytes32[](6);
        slots[0] = batchSlot; // startTime
        slots[1] = bytes32(uint256(batchSlot) + 1); // cutoffTime
        slots[2] = bytes32(uint256(batchSlot) + 2); // settlementTime (not returned)
        slots[3] = bytes32(uint256(batchSlot) + 3); // isClosed
        slots[4] = bytes32(uint256(batchSlot) + 4); // totalAmount
        slots[5] = bytes32(uint256(batchSlot) + 5); // batchReceiver

        bytes32[] memory values = minter.extsload(slots);

        startTime = uint256(values[0]);
        cutoffTime = uint256(values[1]);
        // settlementTime = uint256(values[2]); // Not returned
        isClosed = uint256(values[3]) != 0;
        totalAmount = uint256(values[4]);
        batchReceiver = address(uint160(uint256(values[5])));

        exists = startTime > 0 || totalAmount > 0;
    }

    /// @notice Get batch receiver for a specific batch (moved from main contract)
    /// @param batchId Batch ID to query
    /// @return batchReceiver Address of the batch receiver contract
    function getBatchReceiver(uint256 batchId) external view returns (address batchReceiver) {
        // Calculate batch mapping slot: keccak256(batchId . slot)
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(KMINTER_STORAGE_LOCATION) + 7));

        // DataTypes.BatchInfo struct layout:
        // Slot 0: startTime
        // Slot 1: cutoffTime
        // Slot 2: settlementTime
        // Slot 3: isClosed
        // Slot 4: totalAmount
        // Slot 5: batchReceiver
        bytes32 receiverSlot = bytes32(uint256(batchSlot) + 5);
        bytes32 value = minter.extsload(receiverSlot);
        batchReceiver = address(uint160(uint256(value)));
    }

    /*//////////////////////////////////////////////////////////////
                        ACCOUNTING DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get comprehensive accounting data
    /// @return totalDeposited Total deposited across all time
    /// @return totalRedeemed Total redeemed across all time
    /// @return totalPendingRedemptions Total pending redemptions
    /// @return netDeposits Net deposits (deposited - redeemed)
    /// @return isAuthorizedMinter Whether this minter is authorized
    function getAccountingData()
        external
        view
        returns (
            uint256 totalDeposited,
            uint256 totalRedeemed,
            uint256 totalPendingRedemptions,
            uint256 netDeposits,
            bool isAuthorizedMinter
        )
    {
        bytes32[] memory slots = new bytes32[](4);
        slots[0] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 14); // totalDeposited
        slots[1] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 15); // totalRedeemed
        slots[2] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 16); // totalPendingRedemptions
        slots[3] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 17); // isAuthorizedMinter

        bytes32[] memory values = minter.extsload(slots);

        totalDeposited = uint256(values[0]);
        totalRedeemed = uint256(values[1]);
        totalPendingRedemptions = uint256(values[2]);
        isAuthorizedMinter = uint256(values[3]) != 0;

        // Calculate net deposits with underflow protection
        netDeposits = totalDeposited > totalRedeemed ? totalDeposited - totalRedeemed : 0;
    }

    /*//////////////////////////////////////////////////////////////
                        USER REQUEST DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get user's redemption request details
    /// @param requestId Request ID to query
    /// @return exists Whether the request exists
    /// @return user User who made the request
    /// @return recipient Recipient of the redemption
    /// @return amount Amount to be redeemed
    /// @return batchId Batch ID this request belongs to
    /// @return executed Whether request has been executed
    /// @return cancelled Whether request has been cancelled
    function getRedemptionRequest(bytes32 requestId)
        external
        view
        returns (
            bool exists,
            address user,
            address recipient,
            uint256 amount,
            uint256 batchId,
            bool executed,
            bool cancelled
        )
    {
        // Calculate redemption request mapping slot
        bytes32 requestSlot = keccak256(abi.encode(requestId, uint256(KMINTER_STORAGE_LOCATION) + 64));

        // Read redemption request data
        bytes32[] memory slots = new bytes32[](3);
        slots[0] = requestSlot; // user + recipient (packed)
        slots[1] = bytes32(uint256(requestSlot) + 1); // amount
        slots[2] = bytes32(uint256(requestSlot) + 2); // batchId

        bytes32[] memory values = minter.extsload(slots);

        // Extract packed addresses from first slot
        user = address(uint160(uint256(values[0])));
        recipient = address(uint160(uint256(values[0]) >> 160));
        amount = uint256(values[1]);
        batchId = uint256(values[2]);

        exists = user != address(0);

        // Check executed and cancelled status from bitmaps
        (executed, cancelled) = _getRequestBitmapStatus(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH SETTLEMENT STATUS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get batch settlement timing and readiness
    /// @param batchId Batch ID to check
    /// @return canSettle Whether batch can be settled now
    /// @return timeToSettle Time remaining until settlement (0 if ready)
    /// @return batchAge Age of the batch in seconds
    function getBatchSettlementStatus(uint256 batchId)
        external
        view
        returns (bool canSettle, uint256 timeToSettle, uint256 batchAge)
    {
        // Get batch info first
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(KMINTER_STORAGE_LOCATION) + 60));
        bytes32 settledSlot = bytes32(uint256(batchSlot) + 3);

        bytes32 settledValue = minter.extsload(settledSlot);
        bool settled = uint256(settledValue) != 0;

        if (settled) {
            canSettle = false;
            timeToSettle = 0;
            batchAge = 0;
        } else {
            // Calculate actual settlement timing based on batch creation time
            // Read batch creation timestamp from storage
            bytes32 timestampSlot = bytes32(uint256(batchSlot) + 1); // Assuming timestamp is stored at offset +1
            bytes32 timestampValue = minter.extsload(timestampSlot);
            uint256 batchCreationTime = uint256(timestampValue);

            if (batchCreationTime == 0) {
                // Batch not found or invalid
                canSettle = false;
                timeToSettle = 0;
                batchAge = 0;
            } else {
                // Calculate time since batch creation
                batchAge = block.timestamp - batchCreationTime;

                // Use constant from contract level
                if (batchAge >= SETTLEMENT_INTERVAL) {
                    canSettle = true;
                    timeToSettle = 0;
                } else {
                    canSettle = false;
                    timeToSettle = SETTLEMENT_INTERVAL - batchAge;
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validate minter accounting invariants
    /// @return isValid Whether accounting is correct
    /// @return totalDeposited Total deposited amount
    /// @return totalRedeemed Total redeemed amount
    /// @return totalPending Total pending redemptions
    /// @return netBalance Net balance (deposited - redeemed - pending)
    function validateMinterAccounting()
        external
        view
        returns (bool isValid, uint256 totalDeposited, uint256 totalRedeemed, uint256 totalPending, uint256 netBalance)
    {
        (totalDeposited, totalRedeemed, totalPending,,) = this.getAccountingData();

        netBalance =
            totalDeposited >= (totalRedeemed + totalPending) ? totalDeposited - totalRedeemed - totalPending : 0;

        isValid = totalDeposited >= (totalRedeemed + totalPending);
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get contract metadata (moved from main contract)
    /// @return name Contract name
    /// @return version Contract version
    function getContractMetadata() external pure returns (string memory name, string memory version) {
        name = "kMinter";
        version = "1.0.0";
    }

    /// @notice Get core contract addresses
    /// @return kToken kToken contract address
    /// @return underlyingAsset Underlying asset address
    /// @return kDNStaking kDNStaking vault address
    /// @return batchReceiverImpl Batch receiver implementation address
    function getContractAddresses()
        external
        view
        returns (address kToken, address underlyingAsset, address kDNStaking, address batchReceiverImpl)
    {
        bytes32[] memory slots = new bytes32[](4);
        slots[0] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 1); // kToken
        slots[1] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 2); // underlyingAsset
        slots[2] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 3); // kDNStaking
        slots[3] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 4); // batchReceiverImplementation

        bytes32[] memory values = minter.extsload(slots);

        kToken = address(uint160(uint256(values[0])));
        underlyingAsset = address(uint160(uint256(values[1])));
        kDNStaking = address(uint160(uint256(values[2])));
        batchReceiverImpl = address(uint160(uint256(values[3])));
    }

    /*//////////////////////////////////////////////////////////////
                        BITMAP STATUS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a specific request has been executed
    /// @param requestId The request ID to check
    /// @return executed Whether the request has been executed
    function isRequestExecuted(bytes32 requestId) external view returns (bool executed) {
        (executed,) = _getRequestBitmapStatus(requestId);
    }

    /// @notice Checks if a specific request has been cancelled
    /// @param requestId The request ID to check
    /// @return cancelled Whether the request has been cancelled
    function isRequestCancelled(bytes32 requestId) external view returns (bool cancelled) {
        (, cancelled) = _getRequestBitmapStatus(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL BITMAP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reads executed and cancelled status from bitmaps using extsload
    /// @param requestId The request ID to check
    /// @return executed Whether the request has been executed
    /// @return cancelled Whether the request has been cancelled
    function _getRequestBitmapStatus(bytes32 requestId) internal view returns (bool executed, bool cancelled) {
        uint256 requestIndex = uint256(requestId);

        // Calculate bitmap indices and bit positions
        uint256 bitmapIndex = requestIndex >> 8; // Divide by 256
        uint256 bitPosition = requestIndex & 0xff; // Modulo 256

        // Calculate storage slots for bitmap data
        // executedRequests bitmap starts at STORAGE_SLOT_BASE + 9 (after requestToKDNBatch mapping)
        // cancelledRequests bitmap starts at STORAGE_SLOT_BASE + 10 (after executedRequests bitmap)
        bytes32 executedSlot = keccak256(abi.encode(bitmapIndex, uint256(KMINTER_STORAGE_LOCATION) + 9)); // +9 for
            // executedRequests offset
        bytes32 cancelledSlot = keccak256(abi.encode(bitmapIndex, uint256(KMINTER_STORAGE_LOCATION) + 10)); // +10 for
            // cancelledRequests offset

        bytes32[] memory slots = new bytes32[](2);
        slots[0] = executedSlot;
        slots[1] = cancelledSlot;

        bytes32[] memory values = minter.extsload(slots);

        // Extract bits at the specific positions
        uint256 executedBitmap = uint256(values[0]);
        uint256 cancelledBitmap = uint256(values[1]);

        executed = (executedBitmap >> bitPosition) & 1 == 1;
        cancelled = (cancelledBitmap >> bitPosition) & 1 == 1;
    }
}
