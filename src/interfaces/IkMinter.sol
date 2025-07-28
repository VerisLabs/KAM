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
        bytes32 id;
        address user;
        uint96 amount;
        address asset;
        uint64 requestTimestamp;
        uint8 status;
        uint24 batchId;
        address recipient;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address indexed registry, address indexed owner, address admin, address emergencyAdmin);
    event Minted(address indexed to, uint256 amount, uint32 batchId);
    event RedeemRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        uint24 batchId
    );
    event Redeemed(bytes32 indexed requestId);
    event Cancelled(bytes32 indexed requestId);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error BatchNotSettled();
    error InsufficientBalance();
    error RequestNotFound();
    error RequestNotEligible();
    error RequestAlreadyProcessed();
    error OnlyInstitution();
    error BatchClosed();
    error BatchSettled();
    error ContractPaused();
    error InvalidAsset();

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address asset, address to, uint256 amount) external payable;
    function requestRedeem(address asset, address to, uint256 amount) external payable returns (bytes32 requestId);
    function redeem(bytes32 requestId) external payable;
    function cancelRequest(bytes32 requestId) external payable;
    function setPaused(bool paused) external;
    function isPaused() external view returns (bool);

    function getRedeemRequest(bytes32 requestId) external view returns (RedeemRequest memory);
    function getUserRequests(address user) external view returns (bytes32[] memory);
    function getRequestCounter() external view returns (uint256);
}
