// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedEfficientHashLib } from "src/libraries/OptimizedEfficientHashLib.sol";

import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";
import { OptimizedSafeCastLib } from "src/libraries/OptimizedSafeCastLib.sol";
import { Initializable } from "src/vendor/Initializable.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { kBase } from "src/base/kBase.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";

import {
    KMINTER_BATCH_CLOSED,
    KMINTER_BATCH_SETTLED,
    KMINTER_INSUFFICIENT_BALANCE,
    KMINTER_IS_PAUSED,
    KMINTER_REQUEST_NOT_ELIGIBLE,
    KMINTER_REQUEST_NOT_FOUND,
    KMINTER_REQUEST_PROCESSED,
    KMINTER_WRONG_ASSET,
    KMINTER_WRONG_ROLE,
    KMINTER_ZERO_ADDRESS,
    KMINTER_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kMinter
/// @notice Institutional gateway for kToken minting and redemption with batch settlement processing
/// @dev This contract serves as the primary interface for qualified institutions to interact with the KAM protocol,
/// enabling them to mint kTokens by depositing underlying assets and redeem them through a sophisticated batch
/// settlement system. Key features include: (1) Immediate 1:1 kToken minting upon asset deposit, bypassing the
/// share-based accounting used for retail users, (2) Two-phase redemption process that handles requests through
/// batch settlements to optimize gas costs and maintain protocol efficiency, (3) Integration with kStakingVault
/// for yield generation on deposited assets, (4) Request tracking and management system with unique IDs for each
/// redemption, (5) Cancellation mechanism for pending requests before batch closure. The contract enforces strict
/// access control, ensuring only verified institutions can access these privileged operations while maintaining
/// the security and integrity of the protocol's asset backing.
contract kMinter is IkMinter, Initializable, UUPSUpgradeable, kBase, Extsload {
    using SafeTransferLib for address;
    using OptimizedSafeCastLib for uint256;
    using OptimizedSafeCastLib for uint64;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Core storage structure for kMinter using ERC-7201 namespaced storage pattern
    /// @dev This structure manages all state for institutional minting and redemption operations.
    /// Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.
    /// @custom:storage-location erc7201:kam.storage.kMinter
    struct kMinterStorage {
        /// @dev Tracks the total amount of each asset deposited through mint operations
        /// Used to maintain accurate accounting of assets backing kTokens
        mapping(address => uint256) totalLockedAssets;
        /// @dev Monotonically increasing counter used for generating unique redemption request IDs
        /// Ensures each request has a globally unique identifier even with identical parameters
        uint64 requestCounter;
        /// @dev Stores all redemption requests indexed by their unique request ID
        /// Contains full request details including user, amount, status, and batch information
        mapping(bytes32 => RedeemRequest) redeemRequests;
        /// @dev Maps user addresses to their set of redemption request IDs for efficient lookup
        /// Enables quick retrieval of all requests associated with a specific user
        mapping(address => OptimizedBytes32EnumerableSetLib.Bytes32Set) userRequests;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KMINTER_STORAGE_LOCATION =
        0xd0574379115d2b8497bfd9020aa9e0becaffc59e5509520aa5fe8c763e40d000;

    /// @notice Retrieves the kMinter storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The kMinterStorage struct reference for state modifications
    function _getkMinterStorage() private pure returns (kMinterStorage storage $) {
        assembly {
            $.slot := KMINTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kMinter contract
    /// @param registry_ Address of the registry contract
    function initialize(address registry_) external initializer {
        require(registry_ != address(0), KMINTER_ZERO_ADDRESS);
        __kBase_init(registry_);
        emit ContractInitialized(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkMinter
    function mint(address asset_, address to_, uint256 amount_) external payable {
        _lockReentrant();
        _checkNotPaused();
        _checkInstitution(msg.sender);
        _checkValidAsset(asset_);

        _checkAmountNotZero(amount_);
        _checkAddressNotZero(to_);

        address kToken = _getKTokenForAsset(asset_);
        address dnVault = _getDNVaultByAsset(asset_);
        bytes32 batchId = _getBatchId(dnVault);

        address router = _getKAssetRouter();

        // Transfer underlying asset from sender directly to router for efficiency
        asset_.safeTransferFrom(msg.sender, router, amount_);

        // Push assets to kAssetRouter which will forward them to the DN vault for yield generation
        IkAssetRouter(router).kAssetPush(asset_, amount_, batchId);
        // Track total assets deposited for this asset type (important for protocol accounting)
        _getkMinterStorage().totalLockedAssets[asset_] += amount_;

        // Mint kTokens 1:1 with deposited amount - immediate issuance for institutional users
        IkToken(kToken).mint(to_, amount_);

        emit Minted(to_, amount_, batchId);
        _unlockReentrant();
    }

    /// @inheritdoc IkMinter
    function requestRedeem(address asset_, address to_, uint256 amount_) external payable returns (bytes32 requestId) {
        _lockReentrant();
        _checkNotPaused();
        _checkInstitution(msg.sender);
        _checkValidAsset(asset_);
        _checkAmountNotZero(amount_);
        _checkAddressNotZero(to_);

        address kToken = _getKTokenForAsset(asset_);
        require(kToken.balanceOf(msg.sender) >= amount_, KMINTER_INSUFFICIENT_BALANCE);

        // Generate unique request ID using recipient, amount, timestamp and counter for uniqueness
        requestId = _createRedeemRequestId(to_, amount_, block.timestamp);

        address vault = _getDNVaultByAsset(asset_);
        bytes32 batchId = _getBatchId(vault);

        kMinterStorage storage $ = _getkMinterStorage();

        // Create and store redemption request with all necessary tracking information
        $.redeemRequests[requestId] = RedeemRequest({
            user: msg.sender,
            amount: amount_,
            asset: asset_,
            requestTimestamp: block.timestamp.toUint64(),
            status: RequestStatus.PENDING,
            batchId: batchId,
            recipient: to_
        });

        // Add request ID to user's set for efficient lookup of all their requests
        $.userRequests[to_].add(requestId);

        // Escrow kTokens in this contract - NOT burned yet to allow cancellation
        kToken.safeTransferFrom(msg.sender, address(this), amount_);

        // Register redemption request with router for batch processing and settlement
        IkAssetRouter(_getKAssetRouter()).kAssetRequestPull(asset_, vault, amount_, batchId);

        emit RedeemRequestCreated(requestId, to_, kToken, amount_, to_, batchId);

        _unlockReentrant();
        return requestId;
    }

    /// @inheritdoc IkMinter
    function redeem(bytes32 requestId) external payable {
        _lockReentrant();
        _checkNotPaused();
        _checkInstitution(msg.sender);

        kMinterStorage storage $ = _getkMinterStorage();
        RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request exists and belongs to the user
        require($.userRequests[redeemRequest.user].contains(requestId), KMINTER_REQUEST_NOT_FOUND);
        // Ensure request is still pending (not already processed)
        require(redeemRequest.status == RequestStatus.PENDING, KMINTER_REQUEST_NOT_ELIGIBLE);
        // Double-check request hasn't been redeemed (redundant but safe)
        require(redeemRequest.status != RequestStatus.REDEEMED, KMINTER_REQUEST_PROCESSED);
        // Ensure request wasn't cancelled
        require(redeemRequest.status != RequestStatus.CANCELLED, KMINTER_REQUEST_NOT_ELIGIBLE);

        // Mark request as redeemed to prevent double-spending
        redeemRequest.status = RequestStatus.REDEEMED;

        // Clean up request tracking and update accounting
        $.userRequests[redeemRequest.user].remove(requestId);
        $.totalLockedAssets[redeemRequest.asset] -= redeemRequest.amount;

        address vault = _getDNVaultByAsset(redeemRequest.asset);
        address batchReceiver = _getBatchReceiver(vault, redeemRequest.batchId);
        require(batchReceiver != address(0), KMINTER_ZERO_ADDRESS);

        // Permanently burn the escrowed kTokens to reduce total supply
        address kToken = _getKTokenForAsset(redeemRequest.asset);
        IkToken(kToken).burn(address(this), redeemRequest.amount);

        // Pull assets from batch receiver - will revert if batch not settled
        IkBatchReceiver(batchReceiver).pullAssets(redeemRequest.recipient, redeemRequest.amount, redeemRequest.batchId);

        _unlockReentrant();
        emit Redeemed(requestId);
    }

    /// @inheritdoc IkMinter
    function cancelRequest(bytes32 requestId) external payable {
        _lockReentrant();
        _checkNotPaused();
        _checkInstitution(msg.sender);

        kMinterStorage storage $ = _getkMinterStorage();
        RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request exists and is eligible for cancellation
        require($.userRequests[redeemRequest.user].contains(requestId), KMINTER_REQUEST_NOT_FOUND);
        require(redeemRequest.status == RequestStatus.PENDING, KMINTER_REQUEST_NOT_ELIGIBLE);

        // Update status and remove from tracking
        redeemRequest.status = RequestStatus.CANCELLED;
        $.userRequests[redeemRequest.user].remove(requestId);

        // Ensure batch is still open - cannot cancel after batch closure or settlement
        address vault = _getDNVaultByAsset(redeemRequest.asset);
        require(!IkStakingVault(vault).isBatchClosed(), KMINTER_BATCH_CLOSED);
        require(!IkStakingVault(vault).isBatchSettled(), KMINTER_BATCH_SETTLED);

        address kToken = _getKTokenForAsset(redeemRequest.asset);

        // Return escrowed kTokens to the original requester
        kToken.safeTransfer(redeemRequest.user, redeemRequest.amount);

        emit Cancelled(requestId);

        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if contract is not paused
    function _checkNotPaused() private view {
        require(!_isPaused(), KMINTER_IS_PAUSED);
    }

    /// @notice Check if caller is an institution
    /// @param user Address to check
    function _checkInstitution(address user) private view {
        require(_isInstitution(user), KMINTER_WRONG_ROLE);
    }

    /// @notice Check if caller is an admin
    /// @param user Address to check
    function _checkAdmin(address user) private view {
        require(_isAdmin(user), KMINTER_WRONG_ROLE);
    }

    /// @notice Check if asset is valid/supported
    /// @param asset Asset address to check
    function _checkValidAsset(address asset) private view {
        require(_isAsset(asset), KMINTER_WRONG_ASSET);
    }

    /// @notice Check if amount is not zero
    /// @param amount Amount to check
    function _checkAmountNotZero(uint256 amount) private pure {
        require(amount != 0, KMINTER_ZERO_AMOUNT);
    }

    /// @notice Check if address is not zero
    /// @param addr Address to check
    function _checkAddressNotZero(address addr) private pure {
        require(addr != address(0), KMINTER_ZERO_ADDRESS);
    }

    /// @notice Generates a request ID
    /// @param user User address
    /// @param amount Amount
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createRedeemRequestId(address user, uint256 amount, uint256 timestamp) private returns (bytes32) {
        kMinterStorage storage $ = _getkMinterStorage();
        $.requestCounter = (uint256($.requestCounter) + 1).toUint64();
        return OptimizedEfficientHashLib.hash(
            uint256(uint160(address(this))), uint256(uint160(user)), amount, timestamp, $.requestCounter
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkMinter
    function rescueReceiverAssets(address batchReceiver, address asset_, address to_, uint256 amount_) external {
        require(batchReceiver != address(0) && asset_ != address(0) && to_ != address(0), KMINTER_ZERO_ADDRESS);
        IkBatchReceiver(batchReceiver).rescueAssets(asset_);
        this.rescueAssets(asset_, to_, amount_);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkMinter
    function isPaused() external view returns (bool) {
        return _getBaseStorage().paused;
    }

    /// @inheritdoc IkMinter
    function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.redeemRequests[requestId];
    }

    /// @inheritdoc IkMinter
    function getUserRequests(address user) external view returns (bytes32[] memory) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.userRequests[user].values();
    }

    /// @inheritdoc IkMinter
    function getRequestCounter() external view returns (uint256) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.requestCounter;
    }

    /// @inheritdoc IkMinter
    function getTotalLockedAssets(address asset) external view returns (uint256) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.totalLockedAssets[asset];
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @dev Only callable by ADMIN_ROLE
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override {
        require(_isAdmin(msg.sender), KMINTER_WRONG_ROLE);
        require(newImplementation != address(0), KMINTER_ZERO_ADDRESS);
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
}
