// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "src/vendor/Ownable.sol";

import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";

import { OptimizedFixedPointMathLib } from "src/libraries/OptimizedFixedPointMathLib.sol";

import { OptimizedEfficientHashLib } from "src/libraries/OptimizedEfficientHashLib.sol";
import { OptimizedLibClone } from "src/libraries/OptimizedLibClone.sol";
import { OptimizedSafeCastLib } from "src/libraries/OptimizedSafeCastLib.sol";

import { Initializable } from "src/vendor/Initializable.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";

import { IVault } from "src/interfaces/IVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

import {
    KSTAKINGVAULT_INSUFFICIENT_BALANCE,
    KSTAKINGVAULT_IS_PAUSED,
    KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE,
    KSTAKINGVAULT_REQUEST_NOT_FOUND,
    KSTAKINGVAULT_UNAUTHORIZED,
    KSTAKINGVAULT_VAULT_CLOSED,
    KSTAKINGVAULT_VAULT_SETTLED,
    KSTAKINGVAULT_WRONG_ROLE,
    KSTAKINGVAULT_ZERO_ADDRESS,
    KSTAKINGVAULT_ZERO_AMOUNT,
    VAULTBATCHES_NOT_CLOSED,
    VAULTBATCHES_VAULT_CLOSED,
    VAULTBATCHES_VAULT_SETTLED,
    VAULTCLAIMS_BATCH_NOT_SETTLED,
    VAULTCLAIMS_INVALID_BATCH_ID,
    VAULTCLAIMS_NOT_BENEFICIARY,
    VAULTCLAIMS_REQUEST_NOT_PENDING,
    VAULTFEES_FEE_EXCEEDS_MAXIMUM,
    VAULTFEES_INVALID_TIMESTAMP
} from "src/errors/Errors.sol";

import { MultiFacetProxy } from "src/base/MultiFacetProxy.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVault } from "src/kStakingVault/base/BaseVault.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is IVault, BaseVault, Initializable, UUPSUpgradeable, Ownable, MultiFacetProxy {
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;
    using SafeTransferLib for address;
    using OptimizedSafeCastLib for uint256;
    using OptimizedSafeCastLib for uint128;
    using OptimizedSafeCastLib for uint64;
    using OptimizedFixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    // VaultBatches Events
    /// @notice Emitted when a new batch is created
    /// @param batchId The batch ID of the new batch
    event BatchCreated(bytes32 indexed batchId);

    /// @notice Emitted when a batch is settled
    /// @param batchId The batch ID of the settled batch
    event BatchSettled(bytes32 indexed batchId);

    /// @notice Emitted when a batch is closed
    /// @param batchId The batch ID of the closed batch
    event BatchClosed(bytes32 indexed batchId);

    /// @notice Emitted when a BatchReceiver is created
    /// @param receiver The address of the created BatchReceiver
    /// @param batchId The batch ID of the BatchReceiver
    event BatchReceiverCreated(address indexed receiver, bytes32 indexed batchId);

    // VaultClaims Events
    /// @notice Emitted when a user claims staking shares
    event StakingSharesClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 shares);

    /// @notice Emitted when a user claims unstaking assets
    event UnstakingAssetsClaimed(bytes32 indexed batchId, bytes32 requestId, address indexed user, uint256 assets);

    /// @notice Emitted when kTokens are unstaked
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);

    // VaultFees Events
    /// @notice Emitted when the management fee is updated
    /// @param oldFee Previous management fee in basis points
    /// @param newFee New management fee in basis points
    event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);

    /// @notice Emitted when the performance fee is updated
    /// @param oldFee Previous performance fee in basis points
    /// @param newFee New performance fee in basis points
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);

    /// @notice Emitted when fees are charged to the vault
    /// @param managementFees Amount of management fees collected
    /// @param performanceFees Amount of performance fees collected
    event FeesAssesed(uint256 managementFees, uint256 performanceFees);

    /// @notice Emitted when the hurdle rate is updated
    /// @param newRate New hurdle rate in basis points
    event HurdleRateUpdated(uint16 newRate);

    /// @notice Emitted when the hard hurdle rate is updated
    /// @param newRate New hard hurdle rate in basis points
    event HardHurdleRateUpdated(bool newRate);

    /// @notice Emitted when management fees are charged
    /// @param timestamp Timestamp of the fee charge
    event ManagementFeesCharged(uint256 timestamp);

    /// @notice Emitted when performance fees are charged
    /// @param timestamp Timestamp of the fee charge
    event PerformanceFeesCharged(uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kStakingVault contract (stack optimized)
    /// @dev Phase 1: Core initialization without strings to avoid stack too deep
    /// @param registry_ The registry address
    /// @param paused_ If the vault is paused_
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param asset_ Underlying asset address
    function initialize(
        address owner_,
        address registry_,
        bool paused_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address asset_
    )
        external
        initializer
    {
        require(asset_ != address(0), KSTAKINGVAULT_ZERO_ADDRESS);

        // Initialize ownership and roles
        __BaseVault_init(registry_, paused_);
        _initializeOwner(owner_);

        // Initialize storage with optimized packing
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.name = name_;
        $.symbol = symbol_;
        _setDecimals($, decimals_);
        $.underlyingAsset = asset_;
        $.sharePriceWatermark = (10 ** decimals_).toUint128();
        $.kToken = _registry().assetToKToken(asset_);
        $.receiverImplementation = address(new kBatchReceiver(_registry().getContractById(K_MINTER)));

        emit Initialized(registry_, name_, symbol_, decimals_, asset_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param to Address to receive the stkTokens
    /// @param amount Amount of kTokens to stake
    /// @return requestId Request ID for this staking request
    function requestStake(address to, uint256 amount) external payable returns (bytes32 requestId) {
        // Open `nonReentrant`
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        _checkAmountNotZero(amount);

        // Cache frequently used values
        IkToken kToken = IkToken($.kToken);
        require(kToken.balanceOf(msg.sender) >= amount, KSTAKINGVAULT_INSUFFICIENT_BALANCE);

        bytes32 batchId = $.currentBatchId;
        uint128 amount128 = amount.toUint128();

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, amount, block.timestamp);

        // Create staking request
        $.stakeRequests[requestId] = BaseVaultTypes.StakeRequest({
            user: msg.sender,
            kTokenAmount: amount128,
            recipient: to,
            requestTimestamp: block.timestamp.toUint64(),
            status: BaseVaultTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].add(requestId);

        // Deposit ktokens
        $.kToken.safeTransferFrom(msg.sender, address(this), amount);

        // Increase pending stakt
        $.totalPendingStake += amount.toUint128();

        // Notify the router to move underlying assets from DN strategy
        // To the strategy of this vault
        // That movement will happen from the wallet managing the portfolio
        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            _getKMinter(), address(this), $.underlyingAsset, amount, batchId
        );

        emit StakeRequestCreated(bytes32(requestId), msg.sender, $.kToken, amount, to, batchId);

        // Close `nonReentrant`
        _unlockReentrant();

        return requestId;
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId) {
        // Open `nonReentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        _checkAmountNotZero(stkTokenAmount);
        require(balanceOf(msg.sender) >= stkTokenAmount, KSTAKINGVAULT_INSUFFICIENT_BALANCE);

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, stkTokenAmount, block.timestamp);

        // Create unstaking request
        $.unstakeRequests[requestId] = BaseVaultTypes.UnstakeRequest({
            user: msg.sender,
            stkTokenAmount: stkTokenAmount.toUint128(),
            recipient: to,
            requestTimestamp: (block.timestamp).toUint64(),
            status: BaseVaultTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].add(requestId);

        // Transfer stkTokens to contract to keep share price stable
        // It will only be burned when the assets are claimed later
        _transfer(msg.sender, address(this), stkTokenAmount);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPush(address(this), stkTokenAmount, batchId);

        emit UnstakeRequestCreated(requestId, msg.sender, stkTokenAmount, to, batchId);

        // Close `nonReentrant`
        _unlockReentrant();

        return requestId;
    }

    /// @notice Cancels a staking request
    /// @param requestId Request ID to cancel
    function cancelStakeRequest(bytes32 requestId) external payable {
        // Open `nonReentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        BaseVaultTypes.StakeRequest storage request = $.stakeRequests[requestId];

        require($.userRequests[msg.sender].contains(requestId), KSTAKINGVAULT_REQUEST_NOT_FOUND);
        require(msg.sender == request.user, KSTAKINGVAULT_UNAUTHORIZED);
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE);

        request.status = BaseVaultTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        $.totalPendingStake -= request.kTokenAmount;
        require(!$.batches[request.batchId].isClosed, KSTAKINGVAULT_VAULT_CLOSED);
        require(!$.batches[request.batchId].isSettled, KSTAKINGVAULT_VAULT_SETTLED);

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            address(this), _getKMinter(), $.underlyingAsset, request.kTokenAmount, request.batchId
        );

        $.kToken.safeTransfer(request.user, request.kTokenAmount);

        emit StakeRequestCancelled(bytes32(requestId));

        // Close `nonReentrant`
        _unlockReentrant();
    }

    /// @notice Cancels an unstaking request
    /// @param requestId Request ID to cancel
    function cancelUnstakeRequest(bytes32 requestId) external payable {
        // Open `nonReentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        BaseVaultTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];

        require(msg.sender == request.user, KSTAKINGVAULT_UNAUTHORIZED);
        require($.userRequests[msg.sender].contains(requestId), KSTAKINGVAULT_REQUEST_NOT_FOUND);
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE);

        request.status = BaseVaultTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        require(!$.batches[request.batchId].isClosed, KSTAKINGVAULT_VAULT_CLOSED);
        require(!$.batches[request.batchId].isSettled, KSTAKINGVAULT_VAULT_SETTLED);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPull(address(this), request.stkTokenAmount, request.batchId);

        _transfer(address(this), request.user, request.stkTokenAmount);

        emit UnstakeRequestCancelled(requestId);

        // Close `nonReentrant`
        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT BATCHES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function createNewBatch() external returns (bytes32) {
        _checkRelayer(msg.sender);
        return _createNewBatch();
    }

    /// @notice Closes a batch to prevent new requests
    /// @param _batchId The batch ID to close
    /// @param _create Whether to create a new batch after closing
    /// @dev Only callable by RELAYER_ROLE, typically called at cutoff time
    function closeBatch(bytes32 _batchId, bool _create) external {
        _checkRelayer(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(!$.batches[_batchId].isClosed, VAULTBATCHES_VAULT_CLOSED);
        $.batches[_batchId].isClosed = true;

        if (_create) {
            _batchId = _createNewBatch();
        }
        emit BatchClosed(_batchId);
    }

    /// @notice Marks a batch as settled
    /// @param _batchId The batch ID to settle
    /// @dev Only callable by kMinter, indicates assets have been distributed
    function settleBatch(bytes32 _batchId) external {
        _checkRouter(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require($.batches[_batchId].isClosed, VAULTBATCHES_NOT_CLOSED);
        require(!$.batches[_batchId].isSettled, VAULTBATCHES_VAULT_SETTLED);
        $.batches[_batchId].isSettled = true;

        // Snapshot the gross and net share price for this batch
        $.batches[_batchId].sharePrice = _sharePrice().toUint128();
        $.batches[_batchId].netSharePrice = _netSharePrice().toUint128();

        emit BatchSettled(_batchId);
    }

    /// @notice Deploys BatchReceiver for specific batch
    /// @param _batchId Batch ID to deploy receiver for
    /// @dev Only callable by kAssetRouter
    function createBatchReceiver(bytes32 _batchId) external returns (address) {
        _lockReentrant();
        _checkRouter(msg.sender);

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        address receiver = $.batches[_batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        receiver = OptimizedLibClone.clone($.receiverImplementation);

        $.batches[_batchId].batchReceiver = receiver;

        // Initialize the BatchReceiver
        kBatchReceiver(receiver).initialize(_batchId, $.underlyingAsset);

        emit BatchReceiverCreated(receiver, _batchId);

        _unlockReentrant();
        return receiver;
    }

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function _createNewBatch() private returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        unchecked {
            $.currentBatch++;
        }
        bytes32 newBatchId = OptimizedEfficientHashLib.hash(
            uint256(uint160(address(this))),
            $.currentBatch,
            block.chainid,
            block.timestamp,
            uint256(uint160($.underlyingAsset))
        );

        // Update current batch ID and initialize new batch
        $.currentBatchId = newBatchId;
        BaseVaultTypes.BatchInfo storage batch = $.batches[newBatchId];
        batch.batchId = newBatchId;
        batch.batchReceiver = address(0);
        batch.isClosed = false;
        batch.isSettled = false;

        emit BatchCreated(newBatchId);

        return newBatchId;
    }

    /// @notice Checks if the vault is paused
    /// @param $ Storage pointer
    /// @dev Only callable by RELAYER_ROLE
    function _checkPaused(BaseVaultStorage storage $) private view {
        require(!_getPaused($), KSTAKINGVAULT_IS_PAUSED);
    }

    /// @notice Checks if the amount is not zero
    /// @param amount Amount to check
    function _checkAmountNotZero(uint256 amount) private pure {
        require(amount != 0, KSTAKINGVAULT_ZERO_AMOUNT);
    }

    /// @notice Checks if the bps is valid
    /// @param bps BPS to check
    function _checkValidBPS(uint256 bps) private pure {
        require(bps <= 10_000, VAULTFEES_FEE_EXCEEDS_MAXIMUM);
    }

    /// @dev Only callable by RELAYER_ROLE
    function _checkRelayer(address relayer) private view {
        require(_isRelayer(relayer), KSTAKINGVAULT_WRONG_ROLE);
    }

    /// @dev Only callable by kAssetRouter
    function _checkRouter(address router) private view {
        require(_isKAssetRouter(router), KSTAKINGVAULT_WRONG_ROLE);
    }

    /// @dev Only callable by ADMIN_ROLE
    function _checkAdmin(address admin) private view {
        require(_isAdmin(admin), KSTAKINGVAULT_WRONG_ROLE);
    }

    /// @dev Validate timestamp
    /// @param timestamp Timestamp to validate
    /// @param lastTimestamp Last timestamp to validate
    function _validateTimestamp(uint256 timestamp, uint256 lastTimestamp) private view {
        require(timestamp >= lastTimestamp && timestamp <= block.timestamp, VAULTFEES_INVALID_TIMESTAMP);
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT CLAIMS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimStakedShares(bytes32 batchId, bytes32 requestId) external payable {
        // Open `nonRentrant`
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        require($.batches[batchId].isSettled, VAULTCLAIMS_BATCH_NOT_SETTLED);

        BaseVaultTypes.StakeRequest storage request = $.stakeRequests[requestId];
        require(request.batchId == batchId, VAULTCLAIMS_INVALID_BATCH_ID);
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, VAULTCLAIMS_REQUEST_NOT_PENDING);
        require(msg.sender == request.user, VAULTCLAIMS_NOT_BENEFICIARY);

        request.status = BaseVaultTypes.RequestStatus.CLAIMED;

        // Calculate stkToken amount based on settlement-time share price
        uint256 netSharePrice = $.batches[batchId].netSharePrice;
        _checkAmountNotZero(netSharePrice);

        // Divide the deposited assets by the share price of the batch to obtain stkTokens to mint
        uint256 stkTokensToMint = (uint256(request.kTokenAmount)).fullMulDiv(10 ** _getDecimals($), netSharePrice);

        emit StakingSharesClaimed(batchId, requestId, request.user, stkTokensToMint);

        // Reduce total pending stake and remove user stake request
        $.userRequests[msg.sender].remove(requestId);
        $.totalPendingStake -= request.kTokenAmount;

        // Mint stkTokens to user
        _mint(request.user, stkTokensToMint);

        // Close `nonRentrant`
        _unlockReentrant();
    }

    /// @notice Claims kTokens from a settled unstaking batch (simplified implementation)
    /// @param batchId Batch ID to claim from
    /// @param requestId Request ID to claim
    function claimUnstakedAssets(bytes32 batchId, bytes32 requestId) external payable {
        // Open `nonRentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);

        require($.batches[batchId].isSettled, VAULTCLAIMS_BATCH_NOT_SETTLED);

        BaseVaultTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];
        require(request.batchId == batchId, VAULTCLAIMS_INVALID_BATCH_ID);
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, VAULTCLAIMS_REQUEST_NOT_PENDING);
        require(msg.sender == request.user, VAULTCLAIMS_NOT_BENEFICIARY);

        request.status = BaseVaultTypes.RequestStatus.CLAIMED;

        uint256 sharePrice = $.batches[batchId].sharePrice;
        uint256 netSharePrice = $.batches[batchId].netSharePrice;
        _checkAmountNotZero(sharePrice);

        // Calculate total kTokens to return based on settlement-time share price
        // Multply redeemed shares for net and gross share price to obtain gross and net amount of assets
        uint8 decimals = _getDecimals($);
        uint256 totalKTokensNet = (uint256(request.stkTokenAmount)).fullMulDiv(netSharePrice, 10 ** decimals);

        // Calculate fees as the deifference between gross and net amount
        uint256 fees = (uint256(request.stkTokenAmount)).fullMulDiv(sharePrice, 10 ** decimals) - totalKTokensNet;

        // Burn stkTokens from vault (already transferred to vault during request)
        _burn(address(this), request.stkTokenAmount);
        emit UnstakingAssetsClaimed(batchId, requestId, request.user, totalKTokensNet);

        // Transfer fees to treasury
        $.kToken.safeTransfer(_registry().getTreasury(), fees);

        // Transfer kTokens to user
        $.kToken.safeTransfer(request.user, totalKTokensNet);
        emit KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensNet);

        // Close `nonRentrant`
        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT FEES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the hard hurdle rate
    /// @param _isHard Whether the hard hurdle rate is enabled
    /// @dev If true, performance fees will only be charged to the excess return
    function setHardHurdleRate(bool _isHard) external {
        _checkAdmin(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _setIsHardHurdleRate($, _isHard);
        emit HardHurdleRateUpdated(_isHard);
    }

    /// @notice Sets the management fee
    /// @param _managementFee The new management fee
    /// @dev Fee is a basis point (1% = 100)
    function setManagementFee(uint16 _managementFee) external {
        _checkAdmin(msg.sender);
        _checkValidBPS(_managementFee);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint16 oldFee = _getManagementFee($);
        _setManagementFee($, _managementFee);
        emit ManagementFeeUpdated(oldFee, _managementFee);
    }

    /// @notice Sets the performance fee
    /// @param _performanceFee The new performance fee
    /// @dev Fee is a basis point (1% = 100)
    function setPerformanceFee(uint16 _performanceFee) external {
        _checkAdmin(msg.sender);
        _checkValidBPS(_performanceFee);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint16 oldFee = _getPerformanceFee($);
        _setPerformanceFee($, _performanceFee);
        emit PerformanceFeeUpdated(oldFee, _performanceFee);
    }

    /// @notice Notifies the module that management fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyManagementFeesCharged(uint64 _timestamp) external {
        _checkAdmin(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _validateTimestamp(_timestamp, _getLastFeesChargedManagement($));
        _setLastFeesChargedManagement($, _timestamp);
        _updateGlobalWatermark();
        emit ManagementFeesCharged(_timestamp);
    }

    /// @notice Notifies the module that performance fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyPerformanceFeesCharged(uint64 _timestamp) external {
        _checkAdmin(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _validateTimestamp(_timestamp, _getLastFeesChargedPerformance($));
        _setLastFeesChargedPerformance($, _timestamp);
        _updateGlobalWatermark();
        emit PerformanceFeesCharged(_timestamp);
    }

    /// @notice Updates the share price watermark
    /// @dev Updates the high water mark if the current share price exceeds the previous mark
    function _updateGlobalWatermark() private {
        uint256 sp = _netSharePrice();
        if (sp > _getBaseVaultStorage().sharePriceWatermark) {
            _getBaseVaultStorage().sharePriceWatermark = sp.toUint128();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a unique request ID for a staking request
    /// @param user User address
    /// @param amount Amount of underlying assets
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) private returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        unchecked {
            $.currentBatch++;
        }
        return OptimizedEfficientHashLib.hash(
            uint256(uint160(address(this))), uint256(uint160(user)), amount, timestamp, $.currentBatch
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function setPaused(bool paused_) external {
        require(_isEmergencyAdmin(msg.sender), KSTAKINGVAULT_WRONG_ROLE);
        _setPaused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override {
        _checkAdmin(msg.sender);
        require(newImplementation != address(0), KSTAKINGVAULT_ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                        FUNCTIONS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize function modification
    /// @dev This allows modifying functions while keeping modules separate
    function _authorizeModifyFunctions(address sender) internal override {
        _checkOwner();
    }
}
