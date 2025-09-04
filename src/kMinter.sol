// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { EfficientHashLib } from "solady/utils/EfficientHashLib.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { kBase } from "src/base/kBase.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";

import { IkMinter } from "src/interfaces/IkMinter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kMinter
/// @notice Institutional minting and redemption manager for kTokens
/// @dev Manages deposits/redemptions through kStakingVault with batch settlement
contract kMinter is IkMinter, Initializable, UUPSUpgradeable, kBase, Extsload {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint64;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kMinter
    struct kMinterStorage {
        mapping(address => uint256) totalLockedAssets;
        uint64 requestCounter;
        mapping(bytes32 => RedeemRequest) redeemRequests;
        mapping(address => OptimizedBytes32EnumerableSetLib.Bytes32Set) userRequests;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KMINTER_STORAGE_LOCATION =
        0xd0574379115d2b8497bfd9020aa9e0becaffc59e5509520aa5fe8c763e40d000;

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
        if (registry_ == address(0)) revert ZeroAddress();
        __kBase_init(registry_);
        emit ContractInitialized(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
    /// @dev Validates request parameters, transfers assets, deposits to vault, and mints tokens
    /// @param asset_ Address of the asset to mint
    /// @param to_ Address of the recipient
    /// @param amount_ Amount of the asset to mint
    function mint(address asset_, address to_, uint256 amount_) external payable nonReentrant {
        if (_isPaused()) revert IsPaused();
        if (!_isInstitution(msg.sender)) revert WrongRole();
        if (!_isAsset(asset_)) revert WrongAsset();

        if (amount_ == 0) revert ZeroAmount();
        if (to_ == address(0)) revert ZeroAddress();

        address kToken = _getKTokenForAsset(asset_);
        address dnVault = _getDNVaultByAsset(asset_);
        bytes32 batchId = _getBatchId(dnVault);

        address router = _getKAssetRouter();

        // Transfer underlying asset from sender to this contract
        asset_.safeTransferFrom(msg.sender, router, amount_);

        // Push assets to kAssetRouter
        IkAssetRouter(router).kAssetPush(asset_, amount_, batchId);
        _getkMinterStorage().totalLockedAssets[asset_] += amount_;

        // Mint kTokens 1:1 with deposited amount (no batch ID in push model)
        IkToken(kToken).mint(to_, amount_);

        emit Minted(to_, amount_, batchId);
    }

    /// @notice Initiates redemption process by burning kTokens and creating batch redemption request
    /// @dev Burns tokens immediately, generates unique request ID, and adds to batch for settlement
    /// @param asset_ Address of the asset to redeem
    /// @param to_ Address of the recipient
    /// @param amount_ Amount of the asset to redeem
    /// @return requestId Unique identifier for tracking this redemption request
    function requestRedeem(
        address asset_,
        address to_,
        uint256 amount_
    )
        external
        payable
        nonReentrant
        returns (bytes32 requestId)
    {
        if (_isPaused()) revert IsPaused();
        if (!_isInstitution(msg.sender)) revert WrongRole();
        if (!_isAsset(asset_)) revert WrongAsset();

        if (amount_ == 0) revert ZeroAmount();
        if (to_ == address(0)) revert ZeroAddress();

        address kToken = _getKTokenForAsset(asset_);
        if (kToken.balanceOf(msg.sender) < amount_) revert InsufficientBalance();

        // Generate request ID
        requestId = _createRedeemRequestId(to_, amount_, block.timestamp);

        address vault = _getDNVaultByAsset(asset_);
        bytes32 batchId = _getBatchId(vault);

        kMinterStorage storage $ = _getkMinterStorage();

        // Create redemption request
        $.redeemRequests[requestId] = RedeemRequest({
            user: msg.sender,
            amount: amount_,
            asset: asset_,
            requestTimestamp: block.timestamp.toUint64(),
            status: RequestStatus.PENDING,
            batchId: batchId,
            recipient: to_
        });

        // Add to user requests tracking
        $.userRequests[to_].add(requestId);

        // Transfer kTokens from user to this contract until batch is settled
        kToken.safeTransferFrom(msg.sender, address(this), amount_);

        IkAssetRouter(_getKAssetRouter()).kAssetRequestPull(asset_, vault, amount_, batchId);

        emit RedeemRequestCreated(requestId, to_, kToken, amount_, to_, batchId);

        return requestId;
    }

    /// @notice Executes redemption for a request in a settled batch
    /// @param requestId Request ID to execute
    function redeem(bytes32 requestId) external payable nonReentrant {
        if (_isPaused()) revert IsPaused();
        if (!_isInstitution(msg.sender)) revert WrongRole();

        kMinterStorage storage $ = _getkMinterStorage();
        RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request
        if (!$.userRequests[redeemRequest.user].contains(requestId)) revert RequestNotFound();
        if (redeemRequest.status != RequestStatus.PENDING) revert RequestNotEligible();
        if (redeemRequest.status == RequestStatus.REDEEMED) revert RequestAlreadyProcessed();
        if (redeemRequest.status == RequestStatus.CANCELLED) revert RequestNotEligible();

        // Update state
        redeemRequest.status = RequestStatus.REDEEMED;

        // Delete request
        $.userRequests[redeemRequest.user].remove(requestId);
        $.totalLockedAssets[redeemRequest.asset] -= redeemRequest.amount;

        address vault = _getDNVaultByAsset(redeemRequest.asset);
        address batchReceiver = _getBatchReceiver(vault, redeemRequest.batchId);
        if (batchReceiver == address(0)) revert ZeroAddress();

        // Burn kTokens
        address kToken = _getKTokenForAsset(redeemRequest.asset);
        IkToken(kToken).burn(address(this), redeemRequest.amount);

        // If batch is not settled, this will fail
        IkBatchReceiver(batchReceiver).pullAssets(redeemRequest.recipient, redeemRequest.amount, redeemRequest.batchId);

        emit Redeemed(requestId);
    }

    /// @notice Cancels a redemption request before batch settlement
    /// @param requestId Request ID to cancel
    function cancelRequest(bytes32 requestId) external payable nonReentrant {
        if (_isPaused()) revert IsPaused();
        if (!_isInstitution(msg.sender)) revert WrongRole();

        kMinterStorage storage $ = _getkMinterStorage();
        RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request
        if (!$.userRequests[redeemRequest.user].contains(requestId)) revert RequestNotFound();
        if (redeemRequest.status != RequestStatus.PENDING) revert RequestNotEligible();
        // Update state
        redeemRequest.status = RequestStatus.CANCELLED;
        // Remove request from user's requests
        $.userRequests[redeemRequest.user].remove(requestId);

        address vault = _getDNVaultByAsset(redeemRequest.asset);
        if (IkStakingVault(vault).isBatchClosed()) revert BatchClosed();
        if (IkStakingVault(vault).isBatchSettled()) revert BatchSettled();

        address kToken = _getKTokenForAsset(redeemRequest.asset);

        // Transfer kTokens from this contract to user
        kToken.safeTransfer(redeemRequest.user, redeemRequest.amount);

        emit Cancelled(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates a request ID
    /// @param user User address
    /// @param amount Amount
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createRedeemRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32) {
        kMinterStorage storage $ = _getkMinterStorage();
        $.requestCounter = (uint256($.requestCounter) + 1).toUint64();
        return EfficientHashLib.hash(
            uint256(uint160(address(this))), uint256(uint160(user)), amount, timestamp, $.requestCounter
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Rescue assets from batch receiver
    /// @param batchReceiver Batch receiver address
    /// @param asset_ Asset address
    /// @param to_ Destination address
    /// @param amount_ Amount
    function rescueReceiverAssets(address batchReceiver, address asset_, address to_, uint256 amount_) external {
        if (batchReceiver == address(0) || asset_ == address(0) || to_ == address(0)) revert ZeroAddress();
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
        if (!_isAdmin(msg.sender)) revert WrongRole();
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
}
