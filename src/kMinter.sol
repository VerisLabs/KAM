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

    /// @notice Executes institutional minting of kTokens through immediate 1:1 issuance against deposited assets
    /// @dev This function enables qualified institutions to mint kTokens by depositing underlying assets. The process
    /// involves: (1) transferring assets from the caller to kAssetRouter, (2) pushing assets into the current batch
    /// of the designated DN vault for yield generation, and (3) immediately minting an equivalent amount of kTokens
    /// to the recipient. Unlike retail operations, institutional mints bypass share-based accounting and provide
    /// immediate token issuance without waiting for batch settlement. The deposited assets are tracked separately
    /// to maintain the 1:1 backing ratio and will participate in vault yield strategies through the batch system.
    /// @param asset_ The underlying asset address to deposit (must be registered in the protocol)
    /// @param to_ The recipient address that will receive the newly minted kTokens
    /// @param amount_ The amount of underlying asset to deposit and kTokens to mint (1:1 ratio)
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

    /// @notice Initiates a two-phase institutional redemption by creating a batch request for underlying asset
    /// withdrawal
    /// @dev This function implements the first phase of the redemption process for qualified institutions. The workflow
    /// consists of: (1) transferring kTokens from the caller to this contract for escrow (not burned yet), (2)
    /// generating
    /// a unique request ID for tracking, (3) creating a RedeemRequest struct with PENDING status, (4) registering the
    /// request with kAssetRouter for batch processing. The kTokens remain in escrow until the batch is settled and the
    /// user calls redeem() to complete the process. This two-phase approach is necessary because redemptions are
    /// processed
    /// in batches through the DN vault system, which requires waiting for batch settlement to ensure proper asset
    /// availability and yield distribution. The request can be cancelled before batch closure/settlement.
    /// @param asset_ The underlying asset address to redeem (must match the kToken's underlying asset)
    /// @param to_ The recipient address that will receive the underlying assets after batch settlement
    /// @param amount_ The amount of kTokens to redeem (will receive equivalent underlying assets)
    /// @return requestId A unique bytes32 identifier for tracking and executing this redemption request
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

    /// @notice Completes the second phase of institutional redemption by executing a settled batch request
    /// @dev This function finalizes the redemption process initiated by requestRedeem(). It can only be called after
    /// the batch containing this request has been settled through the kAssetRouter settlement process. The execution
    /// involves: (1) validating the request exists and is in PENDING status, (2) updating the request status to
    /// REDEEMED,
    /// (3) removing the request from tracking, (4) burning the escrowed kTokens permanently, (5) instructing the
    /// kBatchReceiver contract to transfer the underlying assets to the recipient. The kBatchReceiver is a minimal
    /// proxy
    /// deployed per batch that holds the settled assets and ensures isolated distribution. This function will revert if
    /// the batch is not yet settled, ensuring assets are only distributed when available. The separation between
    /// request
    /// and redemption phases allows for efficient batch processing of multiple redemptions while maintaining asset
    /// safety.
    /// @param requestId The unique identifier of the redemption request to execute (obtained from requestRedeem)
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

    /// @notice Cancels a pending redemption request and returns the escrowed kTokens to the user
    /// @dev This function allows institutions to cancel their redemption requests before the batch is closed or
    /// settled.
    /// The cancellation process involves: (1) validating the request exists and is in PENDING status, (2) checking that
    /// the batch is neither closed nor settled (once closed, cancellation is not possible as the batch is being
    /// processed),
    /// (3) updating the request status to CANCELLED, (4) removing the request from tracking, (5) returning the escrowed
    /// kTokens back to the original requester. This mechanism provides flexibility for institutions to manage their
    /// liquidity needs, allowing them to reverse redemption decisions if market conditions change or if they need
    /// immediate
    /// access to their kTokens. The function enforces strict timing constraints - cancellation is only permitted while
    /// the
    /// batch remains open, ensuring batch integrity and preventing manipulation of settled redemptions.
    /// @param requestId The unique identifier of the redemption request to cancel (obtained from requestRedeem)
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

    /// @notice Emergency admin function to recover stuck assets from a batch receiver contract
    /// @dev This function provides a recovery mechanism for assets that may become stuck in kBatchReceiver contracts
    /// due to failed redemptions or system errors. The process involves two steps: (1) calling rescueAssets on the
    /// kBatchReceiver to transfer assets back to this contract, and (2) using the inherited rescueAssets function
    /// from kBase to forward them to the specified destination. This two-step process ensures proper access control
    /// and maintains the security model where only authorized contracts can interact with batch receivers. This
    /// function should only be used in emergency situations and requires admin privileges to prevent abuse.
    /// @param batchReceiver The address of the kBatchReceiver contract holding the stuck assets
    /// @param asset_ The address of the asset token to rescue (must not be a protocol asset)
    /// @param to_ The destination address to receive the rescued assets
    /// @param amount_ The amount of assets to rescue
    function rescueReceiverAssets(address batchReceiver, address asset_, address to_, uint256 amount_) external {
        require(batchReceiver != address(0) && asset_ != address(0) && to_ != address(0), KMINTER_ZERO_ADDRESS);
        IkBatchReceiver(batchReceiver).rescueAssets(asset_);
        this.rescueAssets(asset_, to_, amount_);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool) {
        return _getBaseStorage().paused;
    }

    /// @notice Get a redeem request
    /// @param requestId Request ID
    /// @return Redeem request
    function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.redeemRequests[requestId];
    }

    /// @notice Get all redeem requests for a user
    /// @param user User address
    /// @return Redeem requests
    function getUserRequests(address user) external view returns (bytes32[] memory) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.userRequests[user].values();
    }

    /// @notice Get the request counter
    /// @return Request counter
    function getRequestCounter() external view returns (uint256) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.requestCounter;
    }

    /// @notice Get total locked assets for a specific asset
    /// @param asset Asset address
    /// @return Total locked assets
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
