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
import { BaseVaultModule } from "src/kStakingVault/base/BaseVaultModule.sol";
import {
    INSUFFICIENT_BALANCE,
    IS_PAUSED,
    REQUEST_NOT_ELIGIBLE,
    REQUEST_NOT_FOUND,
    UNAUTHORIZED,
    VAULT_CLOSED,
    VAULT_SETTLED,
    WRONG_ROLE,
    ZERO_ADDRESS,
    ZERO_AMOUNT
} from "src/kStakingVault/errors/BaseVaultErrors.sol";

import { VaultBatches } from "src/kStakingVault/base/VaultBatches.sol";
import { VaultClaims } from "src/kStakingVault/base/VaultClaims.sol";
import { VaultFees } from "src/kStakingVault/base/VaultFees.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is
    Initializable,
    UUPSUpgradeable,
    Ownable,
    BaseVaultModule,
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
        require(asset_ != address(0), ZERO_ADDRESS);

        // Initialize ownership and roles
        __BaseVaultModule_init(registry_, paused_);
        _initializeOwner(owner_);

        // Initialize storage with optimized packing
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
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
    function requestStake(address to, uint256 amount) external payable nonReentrant returns (bytes32 requestId) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        require(!_getPaused($), IS_PAUSED);
        require(amount != 0, ZERO_AMOUNT);
        require($.kToken.balanceOf(msg.sender) >= amount, INSUFFICIENT_BALANCE);

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, amount, block.timestamp);

        // Create staking request
        $.stakeRequests[requestId] = BaseVaultModuleTypes.StakeRequest({
            user: msg.sender,
            kTokenAmount: amount.toUint128(),
            recipient: to,
            requestTimestamp: block.timestamp.toUint64(),
            status: BaseVaultModuleTypes.RequestStatus.PENDING,
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
        returns (bytes32 requestId)
    {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        require(!_getPaused($), IS_PAUSED);
        require(stkTokenAmount != 0, ZERO_AMOUNT);
        require(balanceOf(msg.sender) >= stkTokenAmount, INSUFFICIENT_BALANCE);

        bytes32 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, stkTokenAmount, block.timestamp);

        // Create unstaking request
        $.unstakeRequests[requestId] = BaseVaultModuleTypes.UnstakeRequest({
            user: msg.sender,
            stkTokenAmount: stkTokenAmount.toUint128(),
            recipient: to,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: BaseVaultModuleTypes.RequestStatus.PENDING,
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
    function cancelStakeRequest(bytes32 requestId) external payable nonReentrant {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        BaseVaultModuleTypes.StakeRequest storage request = $.stakeRequests[requestId];

        require($.userRequests[msg.sender].contains(requestId), REQUEST_NOT_FOUND);
        require(msg.sender == request.user, UNAUTHORIZED);
        require(request.status == BaseVaultModuleTypes.RequestStatus.PENDING, REQUEST_NOT_ELIGIBLE);

        request.status = BaseVaultModuleTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        $.totalPendingStake -= request.kTokenAmount;
        require(!$.batches[request.batchId].isClosed, VAULT_CLOSED);
        require(!$.batches[request.batchId].isSettled, VAULT_SETTLED);

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            address(this), _getKMinter(), $.underlyingAsset, request.kTokenAmount, request.batchId
        );

        $.kToken.safeTransfer(request.user, request.kTokenAmount);

        emit StakeRequestCancelled(bytes32(requestId));
    }

    /// @notice Cancels an unstaking request
    /// @param requestId Request ID to cancel
    function cancelUnstakeRequest(bytes32 requestId) external payable nonReentrant {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        require(!_getPaused($), IS_PAUSED);
        BaseVaultModuleTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];

        require(msg.sender == request.user, UNAUTHORIZED);
        require($.userRequests[msg.sender].contains(requestId), REQUEST_NOT_FOUND);
        require(request.status == BaseVaultModuleTypes.RequestStatus.PENDING, REQUEST_NOT_ELIGIBLE);

        request.status = BaseVaultModuleTypes.RequestStatus.CANCELLED;
        $.userRequests[msg.sender].remove(requestId);

        require(!$.batches[request.batchId].isClosed, VAULT_CLOSED);
        require(!$.batches[request.batchId].isSettled, VAULT_SETTLED);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPull(address(this), request.stkTokenAmount, request.batchId);

        _transfer(address(this), request.user, request.stkTokenAmount);

        emit UnstakeRequestCancelled(requestId);
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
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
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
        require(_isEmergencyAdmin(msg.sender), WRONG_ROLE);
        _setPaused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the price of stkTokens in underlying asset terms
    /// @dev Uses the last total assets and total supply to calculate the price
    /// @return price Price per stkToken in underlying asset terms
    function sharePrice() external view returns (uint256) {
        return _sharePrice();
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
        return _getBaseVaultModuleStorage().currentBatchId;
    }

    /// @notice Returns the safe batch
    /// @return Batch
    function getSafeBatchId() external view returns (bytes32) {
        BaseVaultModuleStorage storage $ = _getBaseVaultModuleStorage();
        bytes32 batchId = getBatchId();
        require(!$.batches[batchId].isClosed, VAULT_CLOSED);
        require(!$.batches[batchId].isSettled, VAULT_SETTLED);
        return batchId;
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override {
        require(_isAdmin(msg.sender), WRONG_ROLE);
        require(newImplementation != address(0), ZERO_ADDRESS);
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
