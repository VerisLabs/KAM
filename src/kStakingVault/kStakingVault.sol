// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "solady/auth/Ownable.sol";
import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";

import { MultiFacetProxy } from "src/base/MultiFacetProxy.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { BaseVault } from "src/kStakingVault/base/BaseVault.sol";

import { VaultBatches } from "src/kStakingVault/base/VaultBatches.sol";
import { VaultClaims } from "src/kStakingVault/base/VaultClaims.sol";
import { VaultFees } from "src/kStakingVault/base/VaultFees.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is
    Initializable,
    UUPSUpgradeable,
    Ownable,
    BaseVault,
    MultiFacetProxy,
    VaultFees,
    VaultClaims,
    VaultBatches
{
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;
    using SafeTransferLib for address;
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
        if (asset_ == address(0)) revert ZeroAddress();

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
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (_getPaused($)) revert IsPaused();
        if (amount == 0) revert ZeroAmount();
        if ($.kToken.balanceOf(msg.sender) < amount) {
            revert InsufficientBalance();
        }

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, amount, block.timestamp);

        // Create staking request
        $.stakeRequests[requestId] = BaseVaultTypes.StakeRequest({
            user: msg.sender,
            kTokenAmount: amount.toUint128(),
            recipient: to,
            requestTimestamp: block.timestamp.toUint64(),
            status: BaseVaultTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].add(requestId);

        $.kToken.safeTransferFrom(msg.sender, address(this), amount);

        $.totalPendingStake += amount.toUint128();

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            _getKMinter(), address(this), $.underlyingAsset, amount, batchId
        );

        emit StakeRequestCreated(bytes32(requestId), msg.sender, $.kToken, amount, to, batchId);
        _unlockReentrant();

        return requestId;
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId) {
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (_getPaused($)) revert IsPaused();
        if (stkTokenAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < stkTokenAmount) {
            revert InsufficientBalance();
        }

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, stkTokenAmount, block.timestamp);

        // Create unstaking request
        $.unstakeRequests[requestId] = BaseVaultTypes.UnstakeRequest({
            user: msg.sender,
            stkTokenAmount: stkTokenAmount.toUint128(),
            recipient: to,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: BaseVaultTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].add(requestId);

        _transfer(msg.sender, address(this), stkTokenAmount);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPush(address(this), stkTokenAmount, batchId);

        emit UnstakeRequestCreated(bytes32(requestId), msg.sender, stkTokenAmount, to, batchId);

        _unlockReentrant();

        return requestId;
    }

    /// @notice Cancels a staking request
    /// @param requestId Request ID to cancel
    function cancelStakeRequest(bytes32 requestId) external payable {
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        BaseVaultTypes.StakeRequest storage request = $.stakeRequests[requestId];

        if (!$.userRequests[msg.sender].contains(requestId)) {
            revert RequestNotFound();
        }
        if (msg.sender != request.user) revert Unauthorized();
        if (request.status != BaseVaultTypes.RequestStatus.PENDING) {
            revert RequestNotEligible();
        }

        request.status = BaseVaultTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        $.totalPendingStake -= request.kTokenAmount;
        if ($.batches[request.batchId].isClosed) revert Closed();
        if ($.batches[request.batchId].isSettled) revert Settled();

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            address(this), _getKMinter(), $.underlyingAsset, request.kTokenAmount, request.batchId
        );

        $.kToken.safeTransfer(request.user, request.kTokenAmount);

        emit StakeRequestCancelled(bytes32(requestId));
        _unlockReentrant();
    }

    /// @notice Cancels an unstaking request
    /// @param requestId Request ID to cancel
    function cancelUnstakeRequest(bytes32 requestId) external payable {
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (_getPaused($)) revert IsPaused();
        BaseVaultTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];

        if (msg.sender != request.user) revert Unauthorized();
        if (!$.userRequests[msg.sender].contains(requestId)) {
            revert RequestNotFound();
        }
        if (request.status != BaseVaultTypes.RequestStatus.PENDING) {
            revert RequestNotEligible();
        }

        request.status = BaseVaultTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        if ($.batches[request.batchId].isClosed) revert Closed();
        if ($.batches[request.batchId].isSettled) revert Settled();

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPull(address(this), request.stkTokenAmount, request.batchId);

        _transfer(address(this), request.user, request.stkTokenAmount);

        emit UnstakeRequestCancelled(requestId);
        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a unique request ID for a staking request
    /// @param user User address
    /// @param amount Amount of underlying assets
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) internal returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.currentBatch++;
        return keccak256(abi.encode(address(this), user, amount, timestamp, $.currentBatch));
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function setPaused(bool paused_) external {
        if (!_isEmergencyAdmin(msg.sender)) revert WrongRole();
        _setPaused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the price of stkTokens in underlying asset terms
    /// @dev Uses the last total assets and total supply to calculate the price
    /// @return price Price per stkToken in underlying asset terms
    function sharePrice() external view returns (uint256) {
        return _netSharePrice();
    }

    /// @notice Returns the current total assets
    /// @return Total assets currently deployed in strategies
    function totalAssets() external view returns (uint256) {
        return _totalAssets();
    }

    /// @notice Returns the current total assets after fees
    /// @return Total net assets currently deployed in strategies
    function totalNetAssets() external view returns (uint256) {
        return _totalNetAssets();
    }

    /// @notice Returns the current batch
    /// @return Batch
    function getBatchId() public view returns (bytes32) {
        return _getBaseVaultStorage().currentBatchId;
    }

    /// @notice Returns the safe batch
    /// @return Batch
    function getSafeBatchId() external view returns (bytes32) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        bytes32 batchId = getBatchId();
        if ($.batches[batchId].isClosed) revert Closed();
        if ($.batches[batchId].isSettled) revert Settled();
        return batchId;
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override {
        if (!_isAdmin(msg.sender)) revert WrongRole();
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                        FUNCTIONS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize function modification
    /// @dev This allows modifying functions while keeping modules separate
    function _authorizeModifyFunctions(address sender) internal override {
        //_checkOwner();
    }

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
