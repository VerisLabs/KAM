// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { kBase } from "src/base/kBase.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkBatch } from "src/interfaces/IkBatch.sol";
import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

import { kMinterTypes } from "src/types/kMinterTypes.sol";

/// @title kMinter
/// @notice Institutional minting and redemption manager for kTokens
/// @dev Manages deposits/redemptions through kStakingVault with batch settlement
contract kMinter is Initializable, UUPSUpgradeable, kBase, Extsload {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint64;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant INSTITUTION_ROLE = _ROLE_3;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kMinter
    struct kMinterStorage {
        uint64 requestCounter;
        mapping(bytes32 => kMinterTypes.RedeemRequest) redeemRequests;
        mapping(address => bytes32[]) userRequests;
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

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures function cannot be called when contract is paused
    modifier whenNotPaused() {
        if (_getBaseStorage().paused) revert ContractPaused();
        _;
    }

    /// @notice Ensures function can only be called by an institution
    modifier onlyInstitution() {
        if (!hasAnyRole(msg.sender, INSTITUTION_ROLE)) revert OnlyInstitution();
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
    /// @param registry_ Address of the registry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    /// @param emergencyAdmin_ Address of the emergency admin
    function initialize(
        address registry_,
        address owner_,
        address admin_,
        address emergencyAdmin_
    )
        external
        initializer
    {
        if (registry_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        __kBase_init(registry_, owner_, admin_, false);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);

        emit Initialized(registry_, owner_, admin_, emergencyAdmin_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
    /// @dev Validates request parameters, transfers assets, deposits to vault, and mints tokens
    /// @param asset_ Address of the asset to mint
    /// @param to_ Address of the recipient
    /// @param amount_ Amount of the asset to mint
    function mint(
        address asset_,
        address to_,
        uint256 amount_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyInstitution
        onlySupportedAsset(asset_)
    {
        if (amount_ == 0) revert ZeroAmount();
        if (to_ == address(0)) revert ZeroAddress();

        address kToken = _getKTokenForAsset(asset_);
        uint256 batchId = IkBatch(_getKBatch()).getCurrentBatchId();

        // Transfer underlying asset from sender to this contract
        asset_.safeTransferFrom(msg.sender, address(this), amount_);

        // Approve kAssetRouter to pull the assets
        asset_.safeApprove(_getKAssetRouter(), amount_);

        // Push assets to kAssetRouter
        IkAssetRouter(_getKAssetRouter()).kAssetPush(address(this), asset_, amount_, batchId);

        // Mint kTokens 1:1 with deposited amount (no batch ID in push model)
        IkToken(kToken).mint(to_, amount_);

        // Push vault to batch
        _pushVaultToBatch(batchId);

        emit Minted(to_, amount_, batchId.toUint32());
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
        whenNotPaused
        onlyInstitution
        onlySupportedAsset(asset_)
        returns (bytes32 requestId)
    {
        address kToken = _getKTokenForAsset(asset_);
        if (kToken.balanceOf(msg.sender) < amount_) revert InsufficientBalance();
        if (amount_ == 0) revert ZeroAmount();
        if (to_ == address(0)) revert ZeroAddress();

        // Should it be a variable? Validated from frontend ?
        uint256 batchId = IkBatch(_getKBatch()).getCurrentBatchId();
        if (IkBatch(_getKBatch()).isBatchClosed(batchId)) revert BatchClosed();
        if (IkBatch(_getKBatch()).isBatchSettled(batchId)) revert BatchSettled();

        // Generate request ID
        requestId = _createRedeemRequestId(to_, amount_, block.timestamp);

        kMinterStorage storage $ = _getkMinterStorage();

        // Create redemption request
        $.redeemRequests[requestId] = kMinterTypes.RedeemRequest({
            id: requestId,
            user: to_,
            amount: amount_.toUint96(),
            asset: asset_,
            requestTimestamp: block.timestamp.toUint64(),
            status: uint8(kMinterTypes.RequestStatus.PENDING),
            batchId: batchId.toUint24(),
            recipient: to_
        });

        // Add to user requests tracking
        $.userRequests[to_].push(requestId);

        IkAssetRouter(_getKAssetRouter()).kAssetRequestPull(address(this), asset_, amount_, batchId);

        kToken.safeTransferFrom(to_, address(this), amount_);

        _pushVaultToBatch(batchId);

        emit RedeemRequestCreated(requestId, to_, kToken, amount_, to_, batchId.toUint24());

        return requestId;
    }

    /// @notice Executes redemption for a request in a settled batch
    /// @param requestId Request ID to execute
    function redeem(bytes32 requestId) external payable nonReentrant whenNotPaused onlyInstitution {
        kMinterStorage storage $ = _getkMinterStorage();
        kMinterTypes.RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request
        if (redeemRequest.id == bytes32(0)) revert RequestNotFound();
        if (redeemRequest.status != uint8(kMinterTypes.RequestStatus.PENDING)) revert RequestNotEligible();
        if (redeemRequest.status == uint8(kMinterTypes.RequestStatus.REDEEMED)) revert RequestAlreadyProcessed();
        if (redeemRequest.status == uint8(kMinterTypes.RequestStatus.CANCELLED)) revert RequestNotEligible();

        // Update state
        redeemRequest.status = uint8(kMinterTypes.RequestStatus.REDEEMED);

        if (!IkBatch(_getKBatch()).isBatchSettled(uint256(redeemRequest.batchId))) revert BatchNotSettled();
        address batchReceiver = IkBatch(_getKBatch()).getBatchReceiver(uint256(redeemRequest.batchId));
        if (batchReceiver == address(0)) revert ZeroAddress();

        // Withdraw from BatchReceiver to recipient (1:1 with kTokens burned)
        IkBatchReceiver(batchReceiver).pullAssets(
            redeemRequest.recipient, redeemRequest.asset, redeemRequest.amount, uint256(redeemRequest.batchId)
        );

        emit Redeemed(requestId);
    }

    /// @notice Cancels a redemption request before batch settlement
    /// @param requestId Request ID to cancel
    function cancelRequest(bytes32 requestId) external payable nonReentrant whenNotPaused onlyInstitution {
        kMinterStorage storage $ = _getkMinterStorage();
        kMinterTypes.RedeemRequest storage redeemRequest = $.redeemRequests[requestId];

        // Validate request
        if (redeemRequest.id == bytes32(0)) revert RequestNotFound();
        if (redeemRequest.status != uint8(kMinterTypes.RequestStatus.PENDING)) revert RequestNotEligible();
        if (redeemRequest.status == uint8(kMinterTypes.RequestStatus.REDEEMED)) revert RequestAlreadyProcessed();
        if (redeemRequest.status == uint8(kMinterTypes.RequestStatus.CANCELLED)) revert RequestNotEligible();

        // Update state
        redeemRequest.status = uint8(kMinterTypes.RequestStatus.CANCELLED);

        if (!IkBatch(_getKBatch()).isBatchSettled(uint256(redeemRequest.batchId))) revert BatchNotSettled();

        address kToken = _getKTokenForAsset(redeemRequest.asset);
        // Validate protocol has sufficient kToken balance
        if (kToken.balanceOf(address(this)) < redeemRequest.amount) revert InsufficientBalance();

        kToken.safeTransferFrom(address(this), redeemRequest.user, redeemRequest.amount);

        emit Cancelled(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set contract pause state
    /// @param paused New pause state
    function setPaused(bool paused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _setPaused(paused);
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
        return keccak256(abi.encode(address(this), user, amount, timestamp, $.requestCounter));
    }

    function _pushVaultToBatch(uint256 batchId) internal {
        if (!IkBatch(_getKBatch()).isVaultInBatch(batchId, address(this))) {
            IkBatch(_getKBatch()).pushVault(batchId);
        }
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
    function getRedeemRequest(bytes32 requestId) external view returns (kMinterTypes.RedeemRequest memory) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.redeemRequests[requestId];
    }

    function getUserRequests(address user) external view returns (bytes32[] memory) {
        kMinterStorage storage $ = _getkMinterStorage();
        return $.userRequests[user];
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
