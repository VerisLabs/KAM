// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IkMinter
/// @notice Interface for institutional minting and redemption operations in the KAM protocol
/// @dev This interface defines the core functionality for qualified institutions to mint kTokens
/// by depositing underlying assets and redeem them through a batch settlement system. The interface
/// supports a two-phase redemption process to accommodate batch processing and yield distribution.
interface IkMinter {
    /*//////////////////////////////////////////////////////////////
                              TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Represents the lifecycle status of a redemption request
    /// @dev Used to track the progression of redemption requests through the batch system
    enum RequestStatus {
        /// @dev Request has been created and tokens are held in escrow, awaiting batch settlement
        PENDING,
        /// @dev Request has been successfully executed and underlying assets have been distributed
        REDEEMED,
        /// @dev Request was cancelled before batch closure and escrowed tokens were returned
        CANCELLED
    }

    /// @notice Contains all information related to a redemption request
    /// @dev Stored on-chain to track redemption lifecycle and enable proper asset distribution
    struct RedeemRequest {
        /// @dev The address that initiated the redemption request
        address user;
        /// @dev The amount of kTokens to be redeemed for underlying assets
        uint256 amount;
        /// @dev The underlying asset address being redeemed
        address asset;
        /// @dev Timestamp when the request was created, used for tracking and auditing
        uint64 requestTimestamp;
        /// @dev Current status in the redemption lifecycle (PENDING, REDEEMED, or CANCELLED)
        RequestStatus status;
        /// @dev The batch identifier this request belongs to for settlement processing
        bytes32 batchId;
        /// @dev The address that will receive the underlying assets upon redemption
        address recipient;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the kMinter contract is initialized
    /// @param registry The address of the registry contract used for protocol configuration
    event ContractInitialized(address indexed registry);

    /// @notice Emitted when kTokens are successfully minted for an institution
    /// @param to The recipient address that received the minted kTokens
    /// @param amount The amount of kTokens minted (matches deposited asset amount)
    /// @param batchId The batch identifier where the deposited assets were allocated
    event Minted(address indexed to, uint256 amount, bytes32 batchId);

    /// @notice Emitted when a new redemption request is created and enters the batch queue
    /// @param requestId The unique identifier assigned to this redemption request
    /// @param user The address that initiated the redemption request
    /// @param kToken The kToken contract address being redeemed
    /// @param amount The amount of kTokens being redeemed
    /// @param recipient The address that will receive the underlying assets
    /// @param batchId The batch identifier this request is associated with
    event RedeemRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        bytes32 batchId
    );

    /// @notice Emitted when a redemption request is successfully executed after batch settlement
    /// @param requestId The unique identifier of the executed redemption request
    event Redeemed(bytes32 indexed requestId);

    /// @notice Emitted when a pending redemption request is cancelled before batch closure
    /// @param requestId The unique identifier of the cancelled redemption request
    event Cancelled(bytes32 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes institutional minting of kTokens through immediate 1:1 issuance against deposited assets
    /// @dev This function enables qualified institutions to mint kTokens by depositing underlying assets. The process
    /// involves: (1) transferring assets from the caller to kAssetRouter, (2) pushing assets into the current batch
    /// of the designated DN vault for yield generation, and (3) immediately minting an equivalent amount of kTokens
    /// to the recipient. Unlike retail operations, institutional mints bypass share-based accounting and provide
    /// immediate token issuance without waiting for batch settlement. The deposited assets are tracked separately
    /// to maintain the 1:1 backing ratio and will participate in vault yield strategies through the batch system.
    /// @param asset The underlying asset address to deposit (must be registered in the protocol)
    /// @param to The recipient address that will receive the newly minted kTokens
    /// @param amount The amount of underlying asset to deposit and kTokens to mint (1:1 ratio)
    function mint(address asset, address to, uint256 amount) external payable;

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
    /// @param asset The underlying asset address to redeem (must match the kToken's underlying asset)
    /// @param to The recipient address that will receive the underlying assets after batch settlement
    /// @param amount The amount of kTokens to redeem (will receive equivalent underlying assets)
    /// @return requestId A unique bytes32 identifier for tracking and executing this redemption request
    function requestRedeem(address asset, address to, uint256 amount) external payable returns (bytes32 requestId);

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
    function redeem(bytes32 requestId) external payable;

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
    function cancelRequest(bytes32 requestId) external payable;

    /// @notice Emergency admin function to recover stuck assets from a batch receiver contract
    /// @dev This function provides a recovery mechanism for assets that may become stuck in kBatchReceiver contracts
    /// due to failed redemptions or system errors. The process involves two steps: (1) calling rescueAssets on the
    /// kBatchReceiver to transfer assets back to this contract, and (2) using the inherited rescueAssets function
    /// from kBase to forward them to the specified destination. This two-step process ensures proper access control
    /// and maintains the security model where only authorized contracts can interact with batch receivers. This
    /// function should only be used in emergency situations and requires admin privileges to prevent abuse.
    /// @param batchReceiver The address of the kBatchReceiver contract holding the stuck assets
    /// @param asset The address of the asset token to rescue (must not be a protocol asset)
    /// @param to The destination address to receive the rescued assets
    /// @param amount The amount of assets to rescue
    function rescueReceiverAssets(address batchReceiver, address asset, address to, uint256 amount) external;

    /// @notice Checks if the contract is currently paused
    /// @dev Returns the paused state from the base storage for operational control
    /// @return True if paused, false otherwise
    function isPaused() external view returns (bool);

    /// @notice Retrieves details of a specific redemption request
    /// @dev Returns the complete RedeemRequest struct containing all request information
    /// @param requestId The unique identifier of the request
    /// @return The complete RedeemRequest struct with status, amounts, and batch information
    function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);

    /// @notice Gets all redemption request IDs for a specific user
    /// @dev Returns request IDs from the user's enumerable set for efficient tracking
    /// @param user The user address to query
    /// @return Array of request IDs belonging to the user
    function getUserRequests(address user) external view returns (bytes32[] memory);

    /// @notice Gets the current request counter value
    /// @dev Returns the monotonically increasing counter used for generating unique request IDs
    /// @return The current counter used for generating unique request IDs
    function getRequestCounter() external view returns (uint256);

    /// @notice Gets the total locked assets for a specific asset
    /// @dev Returns the cumulative amount of assets deposited through mint operations for accounting
    /// @param asset The asset address to query
    /// @return The total amount of assets locked in the protocol
    function getTotalLockedAssets(address asset) external view returns (uint256);
}
