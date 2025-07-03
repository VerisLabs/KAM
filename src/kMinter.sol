// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { LibTransient } from "solady/utils/LibTransient.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkDNStaking } from "src/interfaces/IkDNStaking.sol";
import { IkToken } from "src/interfaces/IkToken.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title kMinter
/// @notice Institutional minting and redemption manager for kTokens
/// @dev Manages deposits/redemptions through kDNStakingVault with batch settlement
contract kMinter is Initializable, UUPSUpgradeable, OwnableRoles, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;
    using LibBitmap for LibBitmap.Bitmap;
    using LibClone for address;
    using SafeCastLib for uint256;
    using LibTransient for *;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant INSTITUTION_ROLE = _ROLE_2;
    uint256 public constant SETTLER_ROLE = _ROLE_3;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SETTLEMENT_INTERVAL = 8 hours;
    uint256 public constant BATCH_CUTOFF_TIME = 4 hours;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kMinter.storage.kMinter
    struct kMinterStorage {
        bool isPaused;
        uint256 dustAmount;
        address kToken;
        address underlyingAsset;
        address kDNStaking;
        address batchReceiverImplementation;
        uint256 currentBatchId;
        uint256 requestCounter;
        mapping(uint256 => DataTypes.BatchInfo) batches;
        mapping(bytes32 => uint256) requestToKDNBatch;
        mapping(bytes32 => address) requestToBatchReceiver;
        LibBitmap.Bitmap executedRequests;
        LibBitmap.Bitmap cancelledRequests;
        LibBitmap.Bitmap usedNonces;
        mapping(bytes32 => DataTypes.RedemptionRequest) redemptionRequests;
        mapping(address => bytes32[]) userRequests;
        uint256 totalDeposited;
        uint256 totalRedeemed;
        uint256 totalPendingRedemptions;
        bool isAuthorizedMinter;
    }

    // keccak256(abi.encode(uint256(keccak256("kMinter.storage.kMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KMINTER_STORAGE_LOCATION =
        0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00;

    function _getkMinterStorage() private pure returns (kMinterStorage storage $) {
        assembly {
            $.slot := KMINTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Minted(address indexed beneficiary, uint256 amount, uint256 nonce, uint256 indexed batchId);
    event RedemptionRequested(
        bytes32 indexed requestId, address indexed user, address recipient, uint256 amount, uint256 indexed batchId
    );
    event RedemptionExecuted(bytes32 indexed requestId, address indexed recipient, uint256 amount);
    event RedemptionCancelled(bytes32 indexed requestId, address indexed user, uint256 amount);
    event KDNStakingUpdated(address indexed newStaking);
    event BatchReceiverDeployed(uint256 indexed batchId, address receiver);
    event BatchAssetsReceived(uint256 indexed kdnBatchId, uint256 amount);
    // KTokenStakingEnabled event removed - staking happens directly on kDNStakingVault
    event AuthorizedMinterSet(bool authorized);
    event KDNBatchSettled(uint256 indexed kdnBatchId, uint256 timestamp);
    event PauseState(bool isPaused);
    event BatchCreated(uint256 indexed batchId, uint256 timestamp);
    event DustAmountUpdated(uint256 newDustAmount);
    event BatchCutoffReached(uint256 indexed batchId, uint256 timestamp);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error RequestNotFound();
    error RequestNotEligible();
    error RequestAlreadyProcessed();
    error InsufficientAssets();
    error NonceAlreadyUsed();
    error InsufficientBalance();
    error KDNStakingNotSet();
    error BatchReceiverAlreadyDeployed();
    error InvalidBatchReceiver();
    error NotAuthorizedMinter();
    error AmountTooLarge();
    error BatchNotSettled();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures function cannot be called when contract is paused
    modifier whenNotPaused() {
        if (_getkMinterStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kMinter contract
    /// @param params Initialization parameters
    function initialize(DataTypes.InitParams calldata params) external initializer {
        if (params.kToken == address(0)) revert ZeroAddress();
        if (params.underlyingAsset == address(0)) revert ZeroAddress();
        if (params.owner == address(0)) revert ZeroAddress();
        if (params.admin == address(0)) revert ZeroAddress();
        if (params.emergencyAdmin == address(0)) revert ZeroAddress();
        if (params.institution == address(0)) revert ZeroAddress();
        if (params.settler == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(params.owner);
        _grantRoles(params.admin, ADMIN_ROLE);
        _grantRoles(params.emergencyAdmin, EMERGENCY_ADMIN_ROLE);
        _grantRoles(params.institution, INSTITUTION_ROLE);
        _grantRoles(params.settler, SETTLER_ROLE);

        // Initialize storage
        kMinterStorage storage $ = _getkMinterStorage();
        $.kToken = params.kToken;
        $.underlyingAsset = params.underlyingAsset;
        $.kDNStaking = params.manager;
        // Time-based batches use fixed 8h settlement interval
        $.dustAmount = 1e12;

        // Initialize time-based batch system
        $.currentBatchId = 1;

        // Deploy BatchReceiver implementation
        $.batchReceiverImplementation = address(new kBatchReceiver());

        // Create initial batch with time-based cutoff
        _createNewTimeBatch();

        // Register as authorized minter if kDNStaking is set
        if (params.manager != address(0)) {
            _registerAsAuthorizedMinter();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
    /// @dev Validates request parameters, transfers assets, deposits to vault, and mints tokens
    /// @param request Structured data containing deposit amount, beneficiary address, and unique nonce
    function mint(DataTypes.MintRequest calldata request)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(INSTITUTION_ROLE)
    {
        kMinterStorage storage $ = _getkMinterStorage();
        if ($.kDNStaking == address(0)) revert KDNStakingNotSet();
        if (!$.isAuthorizedMinter) revert NotAuthorizedMinter();

        // Validate request
        if (request.amount == 0) revert ZeroAmount();
        if (request.beneficiary == address(0)) revert ZeroAddress();
        if ($.usedNonces.get(request.nonce)) revert NonceAlreadyUsed();

        // Mark nonce as used
        $.usedNonces.set(request.nonce);

        // Transfer underlying asset from sender to this contract
        $.underlyingAsset.safeTransferFrom(msg.sender, address(this), request.amount);

        // Approve kDNStaking to pull the assets
        $.underlyingAsset.safeApprove($.kDNStaking, request.amount);

        // Update accounting
        $.totalDeposited += request.amount;

        // Deposit to vault with 1:1 accounting for institutions
        uint256 batchId = IkDNStaking($.kDNStaking).requestMinterDeposit(request.amount);

        // Mint kTokens 1:1 with deposited amount
        IkToken($.kToken).mint(request.beneficiary, request.amount);

        emit Minted(request.beneficiary, request.amount, request.nonce, batchId);
    }

    /// @notice Initiates redemption process by burning kTokens and creating batch redemption request
    /// @dev Burns tokens immediately, generates unique request ID, and adds to batch for settlement
    /// @param request Structured data containing redemption amount, user address, recipient, and nonce
    /// @return requestId Unique identifier for tracking this redemption request
    function requestRedeem(DataTypes.RedeemRequest calldata request)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(INSTITUTION_ROLE)
        returns (bytes32 requestId)
    {
        kMinterStorage storage $ = _getkMinterStorage();
        if ($.kDNStaking == address(0)) revert KDNStakingNotSet();
        if (!$.isAuthorizedMinter) revert NotAuthorizedMinter();

        // Validate request
        if (request.amount == 0) revert ZeroAmount();
        if (request.user == address(0) || request.recipient == address(0)) revert ZeroAddress();
        if ($.usedNonces.get(request.nonce)) revert NonceAlreadyUsed();

        // Mark nonce as used
        $.usedNonces.set(request.nonce);

        // Validate user has sufficient kToken balance
        if (IkToken($.kToken).balanceOf(request.user) < request.amount) {
            revert InsufficientBalance();
        }

        // Generate request ID
        requestId = _generateRequestId(request.user, request.amount, block.timestamp);

        // Get target batch based on time cutoff
        uint256 targetBatchId = _getTargetBatchId();

        // Deploy BatchReceiver for this batch if not already deployed
        if ($.batches[targetBatchId].batchReceiver == address(0)) {
            _deployBatchReceiverForBatch(targetBatchId);
        }

        // Create redemption request
        $.redemptionRequests[requestId] = DataTypes.RedemptionRequest({
            id: requestId,
            user: request.user,
            amount: _safeToUint96(request.amount),
            recipient: request.recipient,
            requestTimestamp: _safeToUint64(block.timestamp),
            status: DataTypes.RedemptionStatus.PENDING
        });

        // Add to user requests tracking
        $.userRequests[request.user].push(requestId);

        // Update accounting
        $.totalPendingRedemptions += request.amount;
        $.batches[targetBatchId].totalAmount += request.amount;

        // Store batch receiver mapping BEFORE external calls (we already have this value)
        $.requestToBatchReceiver[requestId] = $.batches[targetBatchId].batchReceiver;

        // Burn kTokens immediately from user
        IkToken($.kToken).burnFrom(request.user, request.amount);

        // Direct integration with kDNStaking - request redemption
        $.requestToKDNBatch[requestId] = IkDNStaking($.kDNStaking).requestMinterRedeem(
            request.amount, address(this), $.batches[targetBatchId].batchReceiver
        );

        emit RedemptionRequested(requestId, request.user, request.recipient, request.amount, targetBatchId);

        return requestId;
    }

    /// @notice Executes redemption for a request in a settled batch
    /// @param requestId Request ID to execute
    function redeem(bytes32 requestId) external payable nonReentrant whenNotPaused {
        kMinterStorage storage $ = _getkMinterStorage();
        DataTypes.RedemptionRequest storage request = $.redemptionRequests[requestId];

        // Validate request
        if (request.id == bytes32(0)) revert RequestNotFound();
        if (request.status == DataTypes.RedemptionStatus.REDEEMED) revert RequestAlreadyProcessed();
        if (request.status == DataTypes.RedemptionStatus.CANCELLED) revert RequestNotEligible();

        // Check if kDN batch is settled (direct integration)
        uint256 kdnBatchId = $.requestToKDNBatch[requestId];
        if (kdnBatchId == 0) {
            revert RequestNotFound();
        }

        // Check if kDN batch is ready (simplified - backend coordinates this)
        // Assets should be available in BatchReceiver after kDN settlement
        if (!IkDNStaking($.kDNStaking).isBatchSettled(kdnBatchId)) {
            revert BatchNotSettled();
        }

        // Check if already executed
        if ($.executedRequests.get(uint256(requestId))) {
            revert RequestAlreadyProcessed();
        }

        // Get batch receiver from stored mapping
        address batchReceiver = $.requestToBatchReceiver[requestId];
        if (batchReceiver == address(0)) {
            revert InvalidBatchReceiver();
        }

        // Update state
        request.status = DataTypes.RedemptionStatus.REDEEMED;
        _markRequestExecuted(requestId);

        // Update accounting BEFORE external call (effects before interactions)
        $.totalPendingRedemptions -= request.amount;
        $.totalRedeemed += request.amount;

        // Emit event BEFORE external call
        emit RedemptionExecuted(requestId, request.recipient, request.amount);

        // External call LAST (interactions)
        // Withdraw from BatchReceiver to recipient (1:1 with kTokens burned)
        kBatchReceiver(batchReceiver).withdrawForRedemption(request.recipient, request.amount);
    }

    /// @notice Cancels a redemption request before batch settlement
    /// @param requestId Request ID to cancel
    function cancelRequest(bytes32 requestId) external payable nonReentrant whenNotPaused onlyRoles(INSTITUTION_ROLE) {
        kMinterStorage storage $ = _getkMinterStorage();
        DataTypes.RedemptionRequest storage request = $.redemptionRequests[requestId];

        // Validate request
        if (request.id == bytes32(0)) revert RequestNotFound();
        if (request.status != DataTypes.RedemptionStatus.PENDING) revert RequestNotEligible();

        // Cannot cancel if kDN batch is already processed
        uint256 kdnBatchId = $.requestToKDNBatch[requestId];
        if (kdnBatchId == 0) {
            revert RequestNotFound();
        }

        // Check if kDN batch is still pending (can only cancel before settlement)
        // This would need to be coordinated with kDNStaking settlement status
        // For now, we allow cancellation if request is still PENDING

        // Update state
        request.status = DataTypes.RedemptionStatus.CANCELLED;
        _markRequestCancelled(requestId);

        // Update accounting
        $.totalPendingRedemptions -= request.amount;

        emit RedemptionCancelled(requestId, request.user, request.amount);

        // Return kTokens to user (1:1)
        IkToken($.kToken).mint(request.user, request.amount);
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Notifies that kDN batch assets have been received
    /// @param kdnBatchId kDN Batch ID that received assets
    /// @param batchReceiver BatchReceiver that received the assets
    /// @param amount Amount of assets received
    function notifyKDNBatchAssetsReceived(
        uint256 kdnBatchId,
        address batchReceiver,
        uint256 amount
    )
        external
        onlyRoles(SETTLER_ROLE)
    {
        // Verify BatchReceiver actually received the assets
        if (batchReceiver == address(0)) {
            revert InvalidBatchReceiver();
        }

        uint256 receiverBalance = kBatchReceiver(batchReceiver).totalReceived();
        if (receiverBalance < amount) {
            revert InsufficientAssets();
        }

        emit BatchAssetsReceived(kdnBatchId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset address
    function asset() external view returns (address) {
        return _getkMinterStorage().underlyingAsset;
    }

    /// @notice Returns the kToken address
    function kToken() external view returns (address) {
        return _getkMinterStorage().kToken;
    }

    /// @notice Returns the kDNStaking address
    function kDNStaking() external view returns (address) {
        return _getkMinterStorage().kDNStaking;
    }

    /// @notice Returns BatchReceiver address for a time-based batch
    /// @param batchId Batch ID to query
    /// @return BatchReceiver address
    function getBatchReceiver(uint256 batchId) external view returns (address) {
        return _getkMinterStorage().batches[batchId].batchReceiver;
    }

    /// @notice Check if this contract is an authorized minter
    function isAuthorizedMinter() external view returns (bool) {
        return _getkMinterStorage().isAuthorizedMinter;
    }

    /// @notice Checks if nonce is used
    /// @param nonce Nonce to check
    /// @return True if used, false otherwise
    function isNonceUsed(uint256 nonce) external view returns (bool) {
        return _getkMinterStorage().usedNonces.get(nonce);
    }

    /// @notice Get batch info - Use kDataProvider for UX functions
    function getBatchInfo(uint256 batchId) external view returns (DataTypes.BatchInfo memory) {
        return _getkMinterStorage().batches[batchId];
    }

    /// @notice Get redemption request - Use kDataProvider for UX functions
    function getRedemptionRequest(bytes32 requestId) external view returns (DataTypes.RedemptionRequest memory) {
        return _getkMinterStorage().redemptionRequests[requestId];
    }

    /// @notice Get user requests - Use kDataProvider for UX functions
    function getUserRequests(address user) external view returns (bytes32[] memory) {
        return _getkMinterStorage().userRequests[user];
    }

    /// @notice Get total pending redemptions - Use kDataProvider for UX functions
    function getTotalPendingRedemptions() external view returns (uint256) {
        return _getkMinterStorage().totalPendingRedemptions;
    }

    /// @notice Get batch total amount - Use kDataProvider for UX functions
    function getBatchTotalAmount(uint256 batchId) external view returns (uint256) {
        return _getkMinterStorage().batches[batchId].totalAmount;
    }

    /// @notice Check if eligible for redeem - Use kDataProvider for UX functions
    function isEligibleForRedeem(bytes32 requestId) external view returns (bool eligible, string memory reason) {
        kMinterStorage storage $ = _getkMinterStorage();
        DataTypes.RedemptionRequest storage request = $.redemptionRequests[requestId];

        if (request.id == bytes32(0)) return (false, "Request not found");
        if (request.status != DataTypes.RedemptionStatus.PENDING) return (false, "Request not pending");
        if ($.executedRequests.get(uint256(requestId))) return (false, "Request already executed");

        return (true, "");
    }

    /// @notice Get request kDN batch ID - Use kDataProvider for UX functions
    function getRequestKDNBatchId(bytes32 requestId) external view returns (uint256) {
        return _getkMinterStorage().requestToKDNBatch[requestId];
    }

    /// @notice Get request batch receiver - Use kDataProvider for UX functions
    function getRequestBatchReceiver(bytes32 requestId) external view returns (address) {
        return _getkMinterStorage().requestToBatchReceiver[requestId];
    }

    /// @notice Get current batch info - Use kDataProvider for UX functions
    function getCurrentBatchInfo()
        external
        view
        returns (uint256 batchId, uint256 startTime, uint256 cutoffTime, uint256 settlementTime, uint256 totalAmount)
    {
        kMinterStorage storage $ = _getkMinterStorage();
        batchId = $.currentBatchId;
        DataTypes.BatchInfo storage batch = $.batches[batchId];
        startTime = batch.startTime;
        cutoffTime = batch.cutoffTime;
        settlementTime = batch.settlementTime;
        totalAmount = batch.totalAmount;
    }

    /// @notice Get total value locked - Use kDataProvider for UX functions
    function getTotalValueLocked() external view returns (uint256) {
        return _getkMinterStorage().totalDeposited - _getkMinterStorage().totalRedeemed;
    }

    /// @notice Get total deposited - Use kDataProvider for UX functions
    function getTotalDeposited() external view returns (uint256) {
        return _getkMinterStorage().totalDeposited;
    }

    /// @notice Get total redeemed - Use kDataProvider for UX functions
    function getTotalRedeemed() external view returns (uint256) {
        return _getkMinterStorage().totalRedeemed;
    }

    /// @notice Get total kToken supply - Use kDataProvider for UX functions
    function getTotalKTokenSupply() external view returns (uint256) {
        return IkToken(_getkMinterStorage().kToken).totalSupply();
    }

    /// @notice Check if current batch past cutoff - Use kDataProvider for UX functions
    function isCurrentBatchPastCutoff() external view returns (bool) {
        kMinterStorage storage $ = _getkMinterStorage();
        return block.timestamp > $.batches[$.currentBatchId].cutoffTime;
    }

    /// @notice Get next settlement time - Use kDataProvider for UX functions
    function getNextSettlementTime() external view returns (uint256) {
        kMinterStorage storage $ = _getkMinterStorage();
        uint256 targetBatch = _getTargetBatchIdView();
        return $.batches[targetBatch].settlementTime;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants admin role to address
    /// @param admin Address to grant role to
    function grantAdminRole(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN_ROLE);
    }

    /// @notice Revokes admin role from address
    /// @param admin Address to revoke role from
    function revokeAdminRole(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN_ROLE);
    }

    /// @notice Updates kDNStaking address
    /// @param newStaking New kDNStaking address
    function setKDNStaking(address newStaking) external onlyRoles(ADMIN_ROLE) {
        if (newStaking == address(0)) revert ZeroAddress();
        kMinterStorage storage $ = _getkMinterStorage();
        $.kDNStaking = newStaking;

        // Register as authorized minter
        _registerAsAuthorizedMinter();

        emit KDNStakingUpdated(newStaking);
    }

    /// @notice Sets the dust amount threshold
    /// @param newDustAmount New dust amount value
    function setDustAmount(uint256 newDustAmount) external onlyRoles(ADMIN_ROLE) {
        _getkMinterStorage().dustAmount = newDustAmount;
        emit DustAmountUpdated(newDustAmount);
    }

    /// @notice Forces creation of new time-based batch
    function forceCreateNewBatch() external onlyRoles(ADMIN_ROLE) {
        _createNewTimeBatch();
    }

    /// @notice Grants emergency role to address
    /// @param emergency Address to grant role to
    function grantEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(emergency, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Revokes emergency role from address
    /// @param emergency Address to revoke role from
    function revokeEmergencyRole(address emergency) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(emergency, EMERGENCY_ADMIN_ROLE);
    }

    /// @notice Grants institution role to address
    /// @param institution Address to grant role to
    function grantInstitutionRole(address institution) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(institution, INSTITUTION_ROLE);
    }

    /// @notice Revokes institution role from address
    /// @param institution Address to revoke role from
    function revokeInstitutionRole(address institution) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(institution, INSTITUTION_ROLE);
    }

    /// @notice Grants settler role to address
    /// @param settler Address to grant role to
    function grantSettlerRole(address settler) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(settler, SETTLER_ROLE);
    }

    /// @notice Revokes settler role from address
    /// @param settler Address to revoke role from
    function revokeSettlerRole(address settler) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(settler, SETTLER_ROLE);
    }

    /// @notice Pauses or unpauses the contract
    /// @param _isPaused True to pause, false to unpause
    function setPaused(bool _isPaused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _getkMinterStorage().isPaused = _isPaused;
        emit PauseState(_isPaused);
    }

    /// @notice Emergency withdraws tokens when paused
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        if (!_getkMinterStorage().isPaused) revert("Not paused");
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (token == address(0)) {
            // Withdraw ETH
            to.safeTransferETH(amount);
        } else {
            // Withdraw ERC20 token
            token.safeTransfer(to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Safely casts uint256 to uint96
    /// @param value Value to cast
    /// @return Casted uint96 value
    function _safeToUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) revert AmountTooLarge();
        return uint96(value);
    }

    /// @notice Safely casts uint256 to uint64
    /// @param value Value to cast
    /// @return Casted uint64 value
    function _safeToUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) revert AmountTooLarge();
        return uint64(value);
    }

    /// @notice Registers this contract as an authorized minter
    function _registerAsAuthorizedMinter() private {
        kMinterStorage storage $ = _getkMinterStorage();

        // Check if we're authorized
        $.isAuthorizedMinter = IkDNStaking($.kDNStaking).isAuthorizedMinter(address(this));

        emit AuthorizedMinterSet($.isAuthorizedMinter);
    }

    /// @notice View version of _getTargetBatchId (doesn't modify state)
    function _getTargetBatchIdView() internal view returns (uint256) {
        kMinterStorage storage $ = _getkMinterStorage();
        DataTypes.BatchInfo storage currentBatch = $.batches[$.currentBatchId];

        // If past cutoff time, requests would go to next batch
        if (block.timestamp > currentBatch.cutoffTime) {
            return $.currentBatchId + 1;
        }

        return $.currentBatchId;
    }

    /// @notice Creates new time-based batch with 4h cutoff
    function _createNewTimeBatch() internal {
        kMinterStorage storage $ = _getkMinterStorage();
        uint256 newBatchId = ++$.currentBatchId;
        uint256 startTime = block.timestamp;

        $.batches[newBatchId] = DataTypes.BatchInfo({
            startTime: startTime,
            cutoffTime: startTime + BATCH_CUTOFF_TIME,
            settlementTime: startTime + SETTLEMENT_INTERVAL,
            isClosed: false,
            totalAmount: 0,
            batchReceiver: address(0)
        });

        emit BatchCreated(newBatchId, startTime);
    }

    /// @notice Gets target batch ID based on time cutoff
    function _getTargetBatchId() internal returns (uint256) {
        kMinterStorage storage $ = _getkMinterStorage();
        DataTypes.BatchInfo storage currentBatch = $.batches[$.currentBatchId];

        // If past cutoff time, create new batch and use it
        if (block.timestamp > currentBatch.cutoffTime) {
            _createNewTimeBatch();
            return $.currentBatchId;
        }

        return $.currentBatchId;
    }

    /// @notice Deploys BatchReceiver for specific batch
    function _deployBatchReceiverForBatch(uint256 batchId) internal {
        kMinterStorage storage $ = _getkMinterStorage();

        if ($.batches[batchId].batchReceiver != address(0)) {
            revert BatchReceiverAlreadyDeployed();
        }

        // Deploy minimal proxy
        bytes32 salt = keccak256(abi.encode(address(this), batchId));
        address receiver = $.batchReceiverImplementation.cloneDeterministic(salt);

        // Initialize the receiver
        kBatchReceiver(receiver).initialize(address(this), $.underlyingAsset, batchId);

        // Store the receiver address
        $.batches[batchId].batchReceiver = receiver;

        emit BatchReceiverDeployed(batchId, receiver);
    }

    /// @notice Generates a request ID
    /// @param user User address
    /// @param amount Amount
    /// @param timestamp Timestamp
    /// @return Request ID
    function _generateRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32) {
        kMinterStorage storage $ = _getkMinterStorage();
        $.requestCounter++;
        return keccak256(abi.encode(address(this), user, amount, timestamp, $.requestCounter));
    }

    /// @notice Marks a request as executed
    /// @param requestId Request ID
    function _markRequestExecuted(bytes32 requestId) internal {
        _getkMinterStorage().executedRequests.set(uint256(requestId));
    }

    /// @notice Marks a request as cancelled
    /// @param requestId Request ID
    function _markRequestCancelled(bytes32 requestId) internal {
        _getkMinterStorage().cancelledRequests.set(uint256(requestId));
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
        return "kMinter";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts ETH transfers
    receive() external payable { }
}
