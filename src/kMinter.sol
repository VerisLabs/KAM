// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { LibBitmap } from "solady/utils/LibBitmap.sol";
import { LibClone } from "solady/utils/LibClone.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkBatch } from "src/interfaces/IkBatch.sol";

import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";
import { IkToken } from "src/interfaces/IkToken.sol";
import { DataTypes } from "src/types/DataTypes.sol";
import { kMinterTypes } from "src/types/kMinterTypes.sol";

/// @title kMinter
/// @notice Institutional minting and redemption manager for kTokens
/// @dev Manages deposits/redemptions through kStakingVault with batch settlement
contract kMinter is Initializable, UUPSUpgradeable, OwnableRoles, ReentrancyGuardTransient, Multicallable, Extsload {
    using SafeTransferLib for address;
    using LibBitmap for LibBitmap.Bitmap;
    using LibClone for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant INSTITUTION_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kMinter.storage.kMinter
    struct kMinterStorage {
        bool isPaused;
        uint256 requestCounter;
        address kBatch;
        address kAssetRouter;
        address[] kTokens;
        mapping(address => bool) registeredKTokens;
        mapping(address => address) assetToKToken;
        mapping(bytes32 => kMinterTypes.RedeemRequest) redeemRequests;
        mapping(address => bytes32[]) userRequests;
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

    event Minted(address indexed to, uint256 amount, uint256 batchId);
    event RedeemRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        uint256 batchId
    );
    event Redeemed(bytes32 indexed requestId);
    event Cancelled(bytes32 indexed requestId);
    event KTokenRegistered(address indexed asset, address indexed kToken);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error AssetAlreadyRegistered();
    error KTokenAlreadyRegistered();
    error AssetNotRegistered();
    error KTokenNotRegistered();
    error kBatchNotSet();
    error kAssetRouterNotSet();
    error BatchNotSettled();
    error InsufficientBalance();
    error TransferFailed();
    error RequestNotFound();
    error RequestNotEligible();
    error RequestAlreadyProcessed();

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
        if (params.kBatch == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(params.owner);
        _grantRoles(params.admin, ADMIN_ROLE);
        _grantRoles(params.emergencyAdmin, EMERGENCY_ADMIN_ROLE);

        // Initialize storage
        kMinterStorage storage $ = _getkMinterStorage();
        $.kBatch = params.kBatch;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
    /// @dev Validates request parameters, transfers assets, deposits to vault, and mints tokens
    /// @param request Structured data containing deposit amount, beneficiary address, and unique nonce
    function mint(kMinterTypes.Request calldata request)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(INSTITUTION_ROLE)
    {
        kMinterStorage storage $ = _getkMinterStorage();
        if ($.kBatch == address(0)) revert kBatchNotSet();
        if ($.kAssetRouter == address(0)) revert kAssetRouterNotSet();

        address kToken = _assetToKToken(request.asset);
        if (!_isRegisteredAsset(request.asset)) revert AssetNotRegistered();
        if (!_isRegisteredKToken(kToken)) revert KTokenNotRegistered();
        if (request.amount == 0) revert ZeroAmount();
        if (request.to == address(0)) revert ZeroAddress();

        uint256 batchId = IkBatch($.kBatch).batchToUse();
        IkBatch($.kBatch).updateBatchInfo(batchId, request.asset, int256(request.amount));

        // Transfer underlying asset from sender to this contract
        request.asset.safeTransferFrom(msg.sender, address(this), request.amount);

        // Approve kAssetRouter to pull the assets
        request.asset.safeApprove($.kAssetRouter, request.amount);

        // Push assets to kAssetRouter
        IkAssetRouter($.kAssetRouter).kAssetPush(address(this), request.asset, request.amount, batchId);

        // Mint kTokens 1:1 with deposited amount (no batch ID in push model)
        IkToken(kToken).mint(request.to, request.amount);

        emit Minted(request.to, request.amount, batchId); // No batch ID in push model
    }

    /// @notice Initiates redemption process by burning kTokens and creating batch redemption request
    /// @dev Burns tokens immediately, generates unique request ID, and adds to batch for settlement
    /// @param request Structured data containing redemption amount, user address, recipient, and nonce
    /// @return requestId Unique identifier for tracking this redemption request
    function requestRedeem(kMinterTypes.Request calldata request)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(INSTITUTION_ROLE)
        returns (bytes32 requestId)
    {
        kMinterStorage storage $ = _getkMinterStorage();
        if ($.kBatch == address(0)) revert kBatchNotSet();
        if ($.kAssetRouter == address(0)) revert kAssetRouterNotSet();

        address kToken = _assetToKToken(request.asset);
        if (!_isRegisteredAsset(request.asset)) revert AssetNotRegistered();
        if (!_isRegisteredKToken(kToken)) revert KTokenNotRegistered();
        if (kToken.balanceOf(msg.sender) < request.amount) revert InsufficientBalance();
        if (request.amount == 0) revert ZeroAmount();
        if (request.to == address(0)) revert ZeroAddress();

        uint256 batchId = IkBatch($.kBatch).batchToUse();
        IkBatch($.kBatch).updateBatchInfo(batchId, request.asset, -int256(request.amount));

        // Generate request ID
        requestId = _createRedeemRequestId(request.to, request.amount, block.timestamp);

        // Create redemption request
        $.redeemRequests[requestId] = kMinterTypes.RedeemRequest({
            id: requestId,
            user: request.to,
            asset: request.asset,
            amount: request.amount.toUint96(),
            recipient: request.to, // Same as user for this simple case
            requestTimestamp: block.timestamp.toUint64(),
            status: kMinterTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[request.to].push(requestId);

        // Direct integration with kBatch - request redemption
        IkAssetRouter($.kAssetRouter).kAssetRequestPull(address(this), request.asset, request.amount, batchId);

        kToken.safeTransferFrom(request.to, address(this), request.amount);

        emit RedeemRequestCreated(requestId, request.to, kToken, request.amount, request.to, batchId);

        return requestId;
    }

    /// @notice Executes redemption for a request in a settled batch
    /// @param requestId Request ID to execute
    function redeem(bytes32 requestId) external payable nonReentrant whenNotPaused {
        kMinterStorage storage $ = _getkMinterStorage();
        kMinterTypes.RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request
        if (redeemRequest.id == bytes32(0)) revert RequestNotFound();
        if (redeemRequest.status != kMinterTypes.RequestStatus.PENDING) revert RequestNotEligible();
        if (redeemRequest.status == kMinterTypes.RequestStatus.REDEEMED) revert RequestAlreadyProcessed();
        if (redeemRequest.status == kMinterTypes.RequestStatus.CANCELLED) revert RequestNotEligible();

        if (!IkBatch($.kBatch).isBatchSettled(redeemRequest.batchId)) revert BatchNotSettled();
        address batchReceiver = IkBatch($.kBatch).getBatchReceiver(redeemRequest.batchId);
        if (batchReceiver == address(0)) revert ZeroAddress();

        // Update state
        redeemRequest.status = kMinterTypes.RequestStatus.REDEEMED;

        // Withdraw from BatchReceiver to recipient (1:1 with kTokens burned)
        IkBatchReceiver(batchReceiver).receiveAssets(
            redeemRequest.recipient, redeemRequest.asset, redeemRequest.amount, redeemRequest.batchId
        );

        emit Redeemed(requestId);
    }

    /// @notice Cancels a redemption request before batch settlement
    /// @param requestId Request ID to cancel
    function cancelRequest(bytes32 requestId) external payable nonReentrant whenNotPaused onlyRoles(INSTITUTION_ROLE) {
        kMinterStorage storage $ = _getkMinterStorage();
        kMinterTypes.RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request
        if (redeemRequest.id == bytes32(0)) revert RequestNotFound();
        if (redeemRequest.status != kMinterTypes.RequestStatus.PENDING) revert RequestNotEligible();
        if (redeemRequest.status == kMinterTypes.RequestStatus.REDEEMED) revert RequestAlreadyProcessed();
        if (redeemRequest.status == kMinterTypes.RequestStatus.CANCELLED) revert RequestNotEligible();

        if (!IkBatch($.kBatch).isBatchSettled(redeemRequest.batchId)) revert BatchNotSettled();
        address kToken = _assetToKToken(redeemRequest.asset);

        // Update state
        redeemRequest.status = kMinterTypes.RequestStatus.CANCELLED;

        // Validate user has sufficient kToken balance
        if (kToken.balanceOf(address(this)) < redeemRequest.amount) revert InsufficientBalance();

        kToken.safeTransferFrom(address(this), redeemRequest.user, redeemRequest.amount);

        emit Cancelled(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function registerKToken(address asset, address kToken) external onlyRoles(ADMIN_ROLE) {
        if (asset == address(0)) revert ZeroAddress();
        if (kToken == address(0)) revert ZeroAddress();

        kMinterStorage storage $ = _getkMinterStorage();
        if ($.assetToKToken[asset] != address(0)) revert AssetAlreadyRegistered();
        if ($.registeredKTokens[kToken]) revert KTokenAlreadyRegistered();

        $.registeredKTokens[kToken] = true;
        $.kTokens.push(kToken);
        $.assetToKToken[asset] = kToken;

        emit KTokenRegistered(asset, kToken);
    }

    /// @notice Set contract pause state
    /// @param paused New pause state
    function setPaused(bool paused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _getkMinterStorage().isPaused = paused;
    }

    /// @notice Set kAssetRouter address. We deploy this 1st then kAssetRouter.
    /// @param kAssetRouter New kAssetRouter address
    function setKAssetRouter(address kAssetRouter) external onlyRoles(ADMIN_ROLE) {
        if (kAssetRouter == address(0)) revert ZeroAddress();
        _getkMinterStorage().kAssetRouter = kAssetRouter;
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an asset is registered
    /// @param asset Asset address
    /// @return True if asset is registered
    function _isRegisteredAsset(address asset) internal view returns (bool) {
        kMinterStorage storage $ = _getkMinterStorage();
        return IkAssetRouter($.kAssetRouter).isRegisteredAsset(asset);
    }

    /// @notice Checks if a kToken is registered
    /// @param kToken kToken address
    /// @return True if kToken is registered
    function _isRegisteredKToken(address kToken) internal view returns (bool) {
        return _getkMinterStorage().registeredKTokens[kToken];
    }

    /// @notice Converts an asset to its corresponding kToken
    /// @param asset Asset address
    /// @return kToken kToken address
    function _assetToKToken(address asset) internal view returns (address) {
        return _getkMinterStorage().assetToKToken[asset];
    }

    /// @notice Generates a request ID
    /// @param user User address
    /// @param amount Amount
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createRedeemRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32) {
        kMinterStorage storage $ = _getkMinterStorage();
        $.requestCounter++;
        return keccak256(abi.encode(address(this), user, amount, timestamp, $.requestCounter));
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the kToken for an asset
    /// @param asset Asset address
    /// @return kToken kToken address
    function kTokenForAsset(address asset) external view returns (address) {
        return _assetToKToken(asset);
    }

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool) {
        return _getkMinterStorage().isPaused;
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
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts ETH transfers
    receive() external payable { }

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
