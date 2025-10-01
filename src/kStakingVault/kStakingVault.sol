// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Ownable } from "solady/auth/Ownable.sol";

import { OptimizedBytes32EnumerableSetLib } from "solady/utils/EnumerableSetLib/OptimizedBytes32EnumerableSetLib.sol";

import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";

import { OptimizedEfficientHashLib } from "solady/utils/OptimizedEfficientHashLib.sol";
import { OptimizedSafeCastLib } from "solady/utils/OptimizedSafeCastLib.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkAssetRouter } from "kam/src/interfaces/IkAssetRouter.sol";

import { IVault, IVaultBatch, IVaultClaim, IVaultFees } from "kam/src/interfaces/IVault.sol";
import { IkToken } from "kam/src/interfaces/IkToken.sol";

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
} from "kam/src/errors/Errors.sol";

import { MultiFacetProxy } from "kam/src/base/MultiFacetProxy.sol";
import { kBatchReceiver } from "kam/src/kBatchReceiver.sol";
import { BaseVault } from "kam/src/kStakingVault/base/BaseVault.sol";
import { BaseVaultTypes } from "kam/src/kStakingVault/types/BaseVaultTypes.sol";

/// @title kStakingVault
/// @notice Retail staking vault enabling kToken holders to earn yield through batch-processed share tokens
/// @dev This contract implements the complete retail staking system for the KAM protocol, providing individual
/// kToken holders access to institutional-grade yield opportunities through a share-based mechanism. The implementation
/// combines several architectural patterns: (1) Dual-token system where kTokens convert to yield-bearing stkTokens,
/// (2) Batch processing for gas-efficient operations and fair pricing across multiple users, (3) Virtual balance
/// coordination with kAssetRouter for cross-vault yield optimization, (4) Two-phase operations (request → claim)
/// ensuring accurate settlement and preventing MEV attacks, (5) Fee management system supporting both management
/// and performance fees with hurdle rate mechanisms. The vault integrates with the broader protocol through
/// kAssetRouter for asset flow coordination and yield distribution. Gas optimizations include packed storage,
/// minimal proxy deployment for batch receivers, and efficient batch settlement processing. The modular architecture
/// enables upgrades while maintaining state integrity through UUPS pattern and ERC-7201 storage.
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

    /// @notice Initializes the kStakingVault with complete protocol integration and share token configuration
    /// @dev This function establishes the vault's integration with the KAM protocol ecosystem. The initialization
    /// process: (1) Validates asset address to prevent deployment with invalid configuration, (2) Initializes
    /// BaseVault foundation with registry and operational state, (3) Sets up ownership and access control through
    /// Ownable pattern, (4) Configures share token metadata and decimals for ERC20 functionality, (5) Establishes
    /// kToken integration through registry lookup for asset-to-token mapping, (6) Sets initial share price watermark
    /// for performance fee calculations, (7) Deploys BatchReceiver implementation for settlement asset distribution.
    /// The initialization creates a complete retail staking solution integrated with the protocol's institutional
    /// flows.
    /// @param owner_ The address that will have administrative control over the vault
    /// @param registry_ The kRegistry contract address for protocol configuration integration
    /// @param paused_ Initial operational state (true = paused, false = active)
    /// @param name_ ERC20 token name for the stkToken (e.g., "Staked kUSDC")
    /// @param symbol_ ERC20 token symbol for the stkToken (e.g., "stkUSDC")
    /// @param decimals_ Token decimals matching the underlying asset precision
    /// @param asset_ Underlying asset address that this vault will generate yield on
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

    /// @inheritdoc IVault
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

    /// @inheritdoc IVault
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

    /// @inheritdoc IVault
    function cancelStakeRequest(bytes32 requestId) external payable {
        // Open `nonReentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        BaseVaultTypes.StakeRequest storage request = $.stakeRequests[requestId];

        require($.userRequests[msg.sender].remove(requestId), KSTAKINGVAULT_REQUEST_NOT_FOUND);
        require(msg.sender == request.user, KSTAKINGVAULT_UNAUTHORIZED);
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE);

        request.status = BaseVaultTypes.RequestStatus.CANCELLED;

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

    /// @inheritdoc IVault
    function cancelUnstakeRequest(bytes32 requestId) external payable {
        // Open `nonReentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        BaseVaultTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];

        require(msg.sender == request.user, KSTAKINGVAULT_UNAUTHORIZED);
        require($.userRequests[msg.sender].remove(requestId), KSTAKINGVAULT_REQUEST_NOT_FOUND);
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE);

        request.status = BaseVaultTypes.RequestStatus.CANCELLED;

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

    /// @inheritdoc IVaultBatch
    function createNewBatch() external returns (bytes32) {
        _checkRelayer(msg.sender);
        return _createNewBatch();
    }

    /// @inheritdoc IVaultBatch
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

    /// @inheritdoc IVaultBatch
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

    function burnFees(uint256 shares) external {
        _checkAdmin(msg.sender);
        _burn(address(this), shares);
    }

    /// @notice Internal function to create deterministic batch IDs with collision resistance
    /// @dev This function generates unique batch identifiers using multiple entropy sources for security. The ID
    /// generation process: (1) Increments internal batch counter to ensure uniqueness within the vault, (2) Combines
    /// vault address, batch number, chain ID, timestamp, and asset address for collision resistance, (3) Uses
    /// optimized hashing function for gas efficiency, (4) Initializes batch storage with default state for new
    /// requests. The deterministic approach enables consistent batch identification across different contexts while
    /// the multiple entropy sources prevent prediction or collision attacks. Each batch starts in open state ready
    /// to accept user requests until explicitly closed by relayers.
    /// @return Deterministic batch identifier for the newly created batch period
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

    /// @notice Validates vault operational state preventing actions during emergency pause
    /// @dev This internal validation function ensures vault safety by blocking operations when paused. Emergency
    /// pause can be triggered by emergency admins during security incidents or market anomalies. The function
    /// provides consistent pause checking across all vault operations while maintaining gas efficiency through
    /// direct storage access. When paused, users cannot create new requests but can still query vault state.
    /// @param $ Direct storage pointer for gas-efficient pause state access
    function _checkPaused(BaseVaultStorage storage $) private view {
        require(!_getPaused($), KSTAKINGVAULT_IS_PAUSED);
    }

    /// @notice Validates non-zero amounts preventing invalid operations
    /// @dev This utility function prevents zero-amount operations that would waste gas or create invalid state.
    /// Zero amounts are rejected for staking, unstaking, and fee operations to maintain data integrity and
    /// prevent operational errors. The pure function enables gas-efficient validation without state access.
    /// @param amount The amount value to validate (must be greater than zero)
    function _checkAmountNotZero(uint256 amount) private pure {
        require(amount != 0, KSTAKINGVAULT_ZERO_AMOUNT);
    }

    /// @notice Validates basis point values preventing excessive fee configuration
    /// @dev This function ensures fee parameters remain within acceptable bounds (0-10000 bp = 0-100%) to
    /// protect users from excessive fee extraction. The 10000 bp limit enforces the maximum fee cap while
    /// enabling flexible fee configuration within reasonable ranges. Used for both management and performance
    /// fee validation to maintain consistent fee bounds across all fee types.
    /// @param bps The basis point value to validate (must be <= 10000)
    function _checkValidBPS(uint256 bps) private pure {
        require(bps <= 10_000, VAULTFEES_FEE_EXCEEDS_MAXIMUM);
    }

    /// @notice Validates relayer role authorization for batch management operations
    /// @dev This access control function ensures only authorized relayers can execute batch lifecycle operations.
    /// Relayers are responsible for automated batch creation, closure, and coordination with settlement processes.
    /// The role-based access prevents unauthorized manipulation of batch timing while enabling protocol automation.
    /// @param relayer The address to validate against registered relayer roles
    function _checkRelayer(address relayer) private view {
        require(_isRelayer(relayer), KSTAKINGVAULT_WRONG_ROLE);
    }

    /// @notice Validates kAssetRouter authorization for settlement and asset coordination
    /// @dev This critical access control ensures only the protocol's kAssetRouter can trigger settlement operations
    /// and coordinate cross-vault asset flows. The router manages complex settlement logic including yield distribution
    /// and virtual balance coordination, making this validation essential for protocol integrity and security.
    /// @param router The address to validate against the registered kAssetRouter contract
    function _checkRouter(address router) private view {
        require(_isKAssetRouter(router), KSTAKINGVAULT_WRONG_ROLE);
    }

    /// @notice Validates admin role authorization for vault configuration changes
    /// @dev This access control function restricts administrative operations to authorized admin addresses.
    /// Admins can modify fee parameters, update vault settings, and execute emergency functions requiring
    /// elevated privileges. The role validation maintains security while enabling necessary governance operations.
    /// @param admin The address to validate against registered admin roles
    function _checkAdmin(address admin) private view {
        require(_isAdmin(admin), KSTAKINGVAULT_WRONG_ROLE);
    }

    /// @notice Validates timestamp progression preventing manipulation and ensuring logical sequence
    /// @dev This function ensures fee timestamp updates follow logical progression and remain within valid ranges.
    /// Validation checks: (1) New timestamp must be >= last timestamp to prevent backwards time manipulation,
    /// (2) New timestamp must be <= current block time to prevent future-dating. These validations are critical
    /// for accurate fee calculations and preventing temporal manipulation attacks on the fee system.
    /// @param timestamp The new timestamp being set for fee tracking
    /// @param lastTimestamp The previous timestamp for progression validation
    function _validateTimestamp(uint256 timestamp, uint256 lastTimestamp) private view {
        require(timestamp >= lastTimestamp && timestamp <= block.timestamp, VAULTFEES_INVALID_TIMESTAMP);
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT CLAIMS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultClaim
    function claimStakedShares(bytes32 requestId) external payable {
        // Open `nonRentrant`
        _lockReentrant();
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);
        bytes32 batchId = $.stakeRequests[requestId].batchId;
        require($.batches[batchId].isSettled, VAULTCLAIMS_BATCH_NOT_SETTLED);

        BaseVaultTypes.StakeRequest storage request = $.stakeRequests[requestId];
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, VAULTCLAIMS_REQUEST_NOT_PENDING);
        require(msg.sender == request.user, VAULTCLAIMS_NOT_BENEFICIARY);
        require($.userRequests[msg.sender].remove(requestId), KSTAKINGVAULT_REQUEST_NOT_FOUND);

        request.status = BaseVaultTypes.RequestStatus.CLAIMED;

        // Calculate stkToken amount based on settlement-time share price
        uint256 netSharePrice = $.batches[batchId].netSharePrice;
        _checkAmountNotZero(netSharePrice);

        // Divide the deposited assets by the share price of the batch to obtain stkTokens to mint
        uint256 stkTokensToMint = (uint256(request.kTokenAmount)) * 10 ** _getDecimals($) / netSharePrice;

        emit StakingSharesClaimed(batchId, requestId, request.user, stkTokensToMint);

        // Reduce total pending stake and remove user stake request
        $.totalPendingStake -= request.kTokenAmount;

        // Mint stkTokens to user
        _mint(request.user, stkTokensToMint);

        // Close `nonRentrant`
        _unlockReentrant();
    }

    /// @inheritdoc IVaultClaim
    function claimUnstakedAssets(bytes32 requestId) external payable {
        // Open `nonRentrant`
        _lockReentrant();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _checkPaused($);

        bytes32 batchId = $.unstakeRequests[requestId].batchId;

        require($.batches[batchId].isSettled, VAULTCLAIMS_BATCH_NOT_SETTLED);

        BaseVaultTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];
        require(request.status == BaseVaultTypes.RequestStatus.PENDING, VAULTCLAIMS_REQUEST_NOT_PENDING);
        require(msg.sender == request.user, VAULTCLAIMS_NOT_BENEFICIARY);
        require($.userRequests[msg.sender].remove(requestId), KSTAKINGVAULT_REQUEST_NOT_FOUND);

        request.status = BaseVaultTypes.RequestStatus.CLAIMED;

        uint256 sharePrice = $.batches[batchId].sharePrice;
        uint256 netSharePrice = $.batches[batchId].netSharePrice;
        _checkAmountNotZero(sharePrice);

        // Calculate total kTokens to return based on settlement-time share price
        // Multply redeemed shares for net and gross share price to obtain gross and net amount of assets
        uint8 decimals = _getDecimals($);
        uint256 totalKTokensNet = (uint256(request.stkTokenAmount)) * netSharePrice / (10 ** decimals);
        uint256 netSharesToBurn = (uint256(request.stkTokenAmount)) * netSharePrice / sharePrice;

        // Burn stkTokens from vault (already transferred to vault during request)
        _burn(address(this), netSharesToBurn);
        emit UnstakingAssetsClaimed(batchId, requestId, request.user, totalKTokensNet);

        // Transfer kTokens to user
        $.kToken.safeTransfer(request.user, totalKTokensNet);
        emit KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensNet);

        // Close `nonRentrant`
        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                          VAULT FEES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultFees
    function setHardHurdleRate(bool _isHard) external {
        _checkAdmin(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _setIsHardHurdleRate($, _isHard);
        emit HardHurdleRateUpdated(_isHard);
    }

    /// @inheritdoc IVaultFees
    function setManagementFee(uint16 _managementFee) external {
        _checkAdmin(msg.sender);
        _checkValidBPS(_managementFee);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint16 oldFee = _getManagementFee($);
        _setManagementFee($, _managementFee);
        emit ManagementFeeUpdated(oldFee, _managementFee);
    }

    /// @inheritdoc IVaultFees
    function setPerformanceFee(uint16 _performanceFee) external {
        _checkAdmin(msg.sender);
        _checkValidBPS(_performanceFee);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint16 oldFee = _getPerformanceFee($);
        _setPerformanceFee($, _performanceFee);
        emit PerformanceFeeUpdated(oldFee, _performanceFee);
    }

    /// @inheritdoc IVaultFees
    function notifyManagementFeesCharged(uint64 _timestamp) external {
        _checkAdmin(msg.sender);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _validateTimestamp(_timestamp, _getLastFeesChargedManagement($));
        _setLastFeesChargedManagement($, _timestamp);
        _updateGlobalWatermark();
        emit ManagementFeesCharged(_timestamp);
    }

    /// @inheritdoc IVaultFees
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

    /// @inheritdoc IVault
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
