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

    /// @notice Mints kTokens by depositing underlying assets at a 1:1 ratio
    /// @param asset The underlying asset to deposit
    /// @param to The recipient of the minted kTokens
    /// @param amount The amount to mint
    function mint(address asset, address to, uint256 amount) external payable;

    /// @notice Initiates a redemption request for underlying assets
    /// @param asset The underlying asset to redeem
    /// @param to The recipient address for the redeemed assets
    /// @param amount The amount of kTokens to redeem
    /// @return requestId Unique identifier for tracking this request
    function requestRedeem(address asset, address to, uint256 amount) external payable returns (bytes32 requestId);

    /// @notice Executes a redemption request after batch settlement
    /// @param requestId The unique identifier of the request to execute
    function redeem(bytes32 requestId) external payable;

    /// @notice Cancels a pending redemption request before batch closure
    /// @param requestId The unique identifier of the request to cancel
    function cancelRequest(bytes32 requestId) external payable;

    /// @notice Admin function to rescue stuck assets from batch receivers
    /// @param batchReceiver The batch receiver contract address
    /// @param asset The asset to rescue
    /// @param to The destination for rescued assets
    /// @param amount The amount to rescue
    function rescueReceiverAssets(address batchReceiver, address asset, address to, uint256 amount) external;

    /// @notice Checks if the contract is currently paused
    /// @return True if paused, false otherwise
    function isPaused() external view returns (bool);

    /// @notice Retrieves details of a specific redemption request
    /// @param requestId The unique identifier of the request
    /// @return The complete RedeemRequest struct
    function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);

    /// @notice Gets all redemption request IDs for a specific user
    /// @param user The user address to query
    /// @return Array of request IDs belonging to the user
    function getUserRequests(address user) external view returns (bytes32[] memory);

    /// @notice Gets the current request counter value
    /// @return The current counter used for generating unique request IDs
    function getRequestCounter() external view returns (uint256);
}
