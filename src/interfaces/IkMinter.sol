// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IkMinter
/// @notice Interface for kMinter
interface IkMinter {
    /*//////////////////////////////////////////////////////////////
                              TYPES
    //////////////////////////////////////////////////////////////*/

    enum RequestStatus {
        PENDING, // Request submitted but not yet processed (tokens escrowed, not burned)
        REDEEMED, // Request successfully completed and claimed
        CANCELLED // Request cancelled before processing (tokens returned to user)

    }

    struct RedeemRequest {
        address user;
        uint256 amount;
        address asset;
        uint64 requestTimestamp;
        RequestStatus status;
        bytes32 batchId;
        address recipient;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event ContractInitialized(address indexed registry);
    event Minted(address indexed to, uint256 amount, bytes32 batchId);
    event RedeemRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        bytes32 batchId
    );
    event Redeemed(bytes32 indexed requestId);
    event Cancelled(bytes32 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientBalance();
    error RequestNotFound();
    error RequestNotEligible();
    error RequestAlreadyProcessed();
    error BatchClosed();
    error BatchSettled();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address asset, address to, uint256 amount) external payable;
    function requestRedeem(address asset, address to, uint256 amount) external payable returns (bytes32 requestId);
    function redeem(bytes32 requestId) external payable;
    function cancelRequest(bytes32 requestId) external payable;
    function rescueReceiverAssets(address batchReceiver, address asset, address to, uint256 amount) external;

    function isPaused() external view returns (bool);
    function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);
    function getUserRequests(address user) external view returns (bytes32[] memory);
    function getRequestCounter() external view returns (uint256);
}
