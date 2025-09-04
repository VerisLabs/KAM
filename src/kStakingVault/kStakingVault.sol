// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "src/vendor/Ownable.sol";

import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";
import { OptimizedSafeCastLib } from "src/libraries/OptimizedSafeCastLib.sol";
import { Initializable } from "src/vendor/Initializable.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
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
    KSTAKINGVAULT_ZERO_AMOUNT
} from "src/errors/Errors.sol";

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
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;
    using SafeTransferLib for address;
    using OptimizedSafeCastLib for uint256;
    using OptimizedSafeCastLib for uint128;

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
        require(!_getPaused($), KSTAKINGVAULT_IS_PAUSED);
        require(amount != 0, KSTAKINGVAULT_ZERO_AMOUNT);

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
        require(!_getPaused($), KSTAKINGVAULT_IS_PAUSED);
        require(stkTokenAmount != 0, KSTAKINGVAULT_ZERO_AMOUNT);
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
        require(!_getPaused($), KSTAKINGVAULT_IS_PAUSED);
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
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a unique request ID for a staking request
    /// @param user User address
    /// @param amount Amount of underlying assets
    /// @param timestamp Timestamp
    /// @return Request ID
    function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) private returns (bytes32) {
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
        require(_isEmergencyAdmin(msg.sender), KSTAKINGVAULT_WRONG_ROLE);
        _setPaused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override {
        require(_isAdmin(msg.sender), KSTAKINGVAULT_WRONG_ROLE);
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
