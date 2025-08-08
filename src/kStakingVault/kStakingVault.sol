// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";

import { MultiFacetProxy } from "src/base/MultiFacetProxy.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";

import { FeesModule } from "src/kStakingVault/modules/FeesModule.sol";
import { BaseModule } from "src/kStakingVault/modules/base/BaseModule.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is Initializable, UUPSUpgradeable, BaseModule, MultiFacetProxy {
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;
    using SafeCastLib for uint128;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kStakingVault contract (stack optimized)
    /// @dev Phase 1: Core initialization without strings to avoid stack too deep
    /// @param asset_ Underlying asset address
    /// @param owner_ Owner address
    /// @param admin_ Admin address
    /// @param emergencyAdmin_ Emergency admin address
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param dustAmount_ Minimum amount threshold
    /// @param paused_ Initial pause state
    function initialize(
        address registry_,
        address owner_,
        address admin_,
        bool paused_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint128 dustAmount_,
        address emergencyAdmin_,
        address asset_,
        address feeCollector_
    )
        external
        initializer
    {
        if (asset_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        __BaseModule_init(registry_, owner_, admin_, feeCollector_, paused_);
        __MultiFacetProxy__init(ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);

        // Initialize storage with optimized packing
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        $.name = name_;
        $.symbol = symbol_;
        $.decimals = decimals_;
        $.underlyingAsset = asset_;
        $.dustAmount = dustAmount_.toUint96();
        $.kToken = _registry().assetToKToken(asset_);
        $.receiverImplementation = address(new kBatchReceiver(_registry().getContractById(K_MINTER)));

        emit Initialized(registry_, owner_, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param to Address to receive the stkTokens
    /// @param kTokensAmount Amount of kTokens to stake
    /// @return requestId Request ID for this staking request
    function requestStake(
        address to,
        uint256 kTokensAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 requestId)
    {
        _chargeGlobalFees();
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (kTokensAmount == 0) revert ZeroAmount();
        if ($.kToken.balanceOf(msg.sender) < kTokensAmount) revert InsufficientBalance();
        if (kTokensAmount < $.dustAmount) revert AmountBelowDustThreshold();

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, kTokensAmount, block.timestamp);

        // Create staking request
        $.stakeRequests[requestId] = BaseModuleTypes.StakeRequest({
            user: msg.sender,
            kTokenAmount: kTokensAmount.toUint128(),
            recipient: to,
            requestTimestamp: block.timestamp.toUint64(),
            status: BaseModuleTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].add(requestId);

        $.kToken.safeTransferFrom(msg.sender, address(this), kTokensAmount);

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            _getKMinter(), address(this), $.underlyingAsset, kTokensAmount, batchId
        );

        emit StakeRequestCreated(bytes32(requestId), msg.sender, $.kToken, kTokensAmount, to, batchId);

        return requestId;
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(
        address to,
        uint256 stkTokenAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (bytes32 requestId)
    {
        _chargeGlobalFees();
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (stkTokenAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < stkTokenAmount) revert InsufficientBalance();
        if (stkTokenAmount < $.dustAmount) revert AmountBelowDustThreshold();

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, stkTokenAmount, block.timestamp);

        // Create unstaking request
        $.unstakeRequests[requestId] = BaseModuleTypes.UnstakeRequest({
            user: msg.sender,
            stkTokenAmount: stkTokenAmount.toUint128(),
            recipient: to,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: BaseModuleTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].add(requestId);

        _transfer(msg.sender, address(this), stkTokenAmount);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPush(address(this), stkTokenAmount, batchId);

        emit UnstakeRequestCreated(bytes32(requestId), msg.sender, stkTokenAmount, to, batchId);

        return requestId;
    }

    /// @notice Cancels a staking request
    /// @param requestId Request ID to cancel
    function cancelStakeRequest(bytes32 requestId) external {
        _chargeGlobalFees();
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        BaseModuleTypes.StakeRequest storage request = $.stakeRequests[requestId];

        if (!$.userRequests[msg.sender].contains(requestId)) revert RequestNotFound();
        if (msg.sender != request.user) revert Unauthorized();
        if (request.status != BaseModuleTypes.RequestStatus.PENDING) revert RequestNotEligible();

        request.status = BaseModuleTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        address vault = _getDNVaultByAsset($.underlyingAsset);
        if ($.batches[request.batchId].isClosed) revert Closed();
        if ($.batches[request.batchId].isSettled) revert Settled();

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            address(this), _getKMinter(), $.underlyingAsset, request.kTokenAmount, request.batchId
        );

        $.kToken.safeTransfer(request.user, request.kTokenAmount);

        emit StakeRequestCancelled(bytes32(requestId));
    }

    /// @notice Cancels an unstaking request
    /// @param requestId Request ID to cancel
    function cancelUnstakeRequest(bytes32 requestId) external payable nonReentrant whenNotPaused {
        _chargeGlobalFees();
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        BaseModuleTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];

        if (msg.sender != request.user) revert Unauthorized();
        if (!$.userRequests[msg.sender].contains(requestId)) revert RequestNotFound();
        if (request.status != BaseModuleTypes.RequestStatus.PENDING) revert RequestNotEligible();

        request.status = BaseModuleTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        address vault = _getDNVaultByAsset($.underlyingAsset);
        if ($.batches[request.batchId].isClosed) revert Closed();
        if ($.batches[request.batchId].isSettled) revert Settled();

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPull(address(this), request.stkTokenAmount, request.batchId);

        _transfer(address(this), request.user, request.stkTokenAmount);

        emit UnstakeRequestCancelled(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Charges management and performance fees
    /// @return totalFees Total fees charged
    /// @dev Delegatecall to the contract itself, which will forward the call to the FeesModule
    function _chargeGlobalFees() internal returns (uint256) {
        return FeesModule(address(this)).chargeGlobalFees();
    }

    /// @notice Creates a unique request ID for a staking request
    /// @param user User address
    /// @param amount Amount of underlying assets
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        $.currentBatch++;
        return keccak256(abi.encode(address(this), user, amount, timestamp, $.currentBatch));
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function setPaused(bool paused_) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _setPaused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates stkToken price with safety checks
    /// @dev Standard price calculation used across settlement modules
    /// @return price Price per stkToken in underlying asset terms
    function calculateStkTokenPrice() external view returns (uint256) {
        return _calculateStkTokenPrice();
    }

    /// @notice Calculates the price of stkTokens in underlying asset terms
    /// @dev Uses the last total assets and total supply to calculate the price
    /// @return price Price per stkToken in underlying asset terms
    function sharePrice() external view returns (uint256) {
        return _sharePrice();
    }

    /// @notice Returns the current total assets from adapter (real-time)
    /// @return Total assets currently deployed in strategies
    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    /// @notice Returns the current batch
    /// @return Batch
    function getBatchId() public view returns (bytes32) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint256 currentBatch = $.currentBatch;
        return
            keccak256(abi.encodePacked(address(this), currentBatch, block.chainid, block.timestamp, $.underlyingAsset));
    }

    /// @notice Returns the safe batch
    /// @return Batch
    function getSafeBatchId() external view returns (bytes32) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        bytes32 batchId = getBatchId();
        if ($.batches[batchId].isClosed) revert Closed();
        if ($.batches[batchId].isSettled) revert Settled();
        return batchId;
    }

    /// @notice Returns whether the current batch is closed
    /// @return Whether the current batch is closed
    function isBatchClosed() external view returns (bool) {
        return _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isClosed;
    }

    /// @notice Returns whether the current batch is settled
    /// @return Whether the current batch is settled
    function isBatchSettled() external view returns (bool) {
        return _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isSettled;
    }

    /// @notice Returns the current batch ID, whether it is closed, and whether it is settled
    /// @return batchId Current batch ID
    /// @return batchReceiver Current batch receiver
    /// @return isClosed Whether the current batch is closed
    /// @return isSettled Whether the current batch is settled
    function getBatchIdInfo()
        external
        view
        returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled)
    {
        return (
            _getBaseModuleStorage().currentBatchId,
            _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].batchReceiver,
            _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isClosed,
            _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isSettled
        );
    }

    /// @notice Returns the batch receiver for the current batch
    /// @return Batch receiver
    function getBatchIdReceiver(bytes32 batchId) external view returns (address) {
        return _getBaseModuleStorage().batches[batchId].batchReceiver;
    }

    function getSafeBatchReceiver(bytes32 batchId) external view returns (address) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if ($.batches[batchId].isSettled) revert Settled();
        return $.batches[batchId].batchReceiver;
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
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
        return "kStakingVault";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
