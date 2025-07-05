// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title kDNStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools
contract kDNStakingVault is
    Initializable,
    UUPSUpgradeable,
    ERC20,
    OwnableRoles,
    ReentrancyGuard,
    Multicallable,
    Extsload
{
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant MINTER_ROLE = _ROLE_2;
    uint256 public constant SETTLER_ROLE = _ROLE_3;
    uint256 public constant STRATEGY_MANAGER_ROLE = _ROLE_4;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant DEFAULT_DUST_AMOUNT = 1e12;
    uint256 private constant DEFAULT_SETTLEMENT_INTERVAL = 1 hours;
    uint256 private constant PRECISION = 1e18; // 18 decimal precision
    uint256 private constant MAX_YIELD_PER_SYNC = 1000e18; // Max 1000 tokens yield per sync

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kDNStakingVault.storage.kDNStakingVault
    struct kDNStakingVaultStorage {
        string name;
        string symbol;
        uint8 decimals;
        bool isPaused;
        uint256 dustAmount;
        address underlyingAsset;
        address kToken;
        // DUAL ACCOUNTING MODEL
        // 1. Fixed 1:1 accounting for kMinter (assets = shares always)
        mapping(address => uint256) minterAssetBalances; // 1:1 with deposited assets
        mapping(address => int256) minterPendingNetAmounts; // Pending net amounts
        uint256 totalMinterAssets; // Total assets under 1:1 management
        // 2. Yield-bearing accounting for users
        uint256 userTotalSupply; // User shares that can appreciate
        uint256 userTotalAssets; // Assets backing user shares (can grow with yield)
        mapping(address => uint256) userShareBalances; // User's yield-bearing shares
        uint256 currentBatchId;
        uint256 lastSettledBatchId;
        mapping(uint256 => DataTypes.Batch) batches;
        // Staking batches (kToken -> shares)
        uint256 currentStakingBatchId;
        uint256 lastSettledStakingBatchId;
        mapping(uint256 => DataTypes.StakingBatch) stakingBatches;
        // Unstaking batches (shares -> assets)
        uint256 currentUnstakingBatchId;
        uint256 lastSettledUnstakingBatchId;
        mapping(uint256 => DataTypes.UnstakingBatch) unstakingBatches;
        // stkToken tracking (rebase token for yield distribution)
        uint256 totalStkTokenSupply; // Total stkTokens minted
        uint256 totalStkTokenAssets; // Total assets backing stkTokens (including yield)
        mapping(address => uint256) userStkTokenBalances; // User stkToken balances
        mapping(address => uint256) userUnclaimedStkTokens; // Unclaimed stkTokens from requests
        mapping(address => uint256) userOriginalKTokens; // Track original kToken amounts per user
        uint256 totalStakedKTokens; // Total kTokens held by vault for staking
        // Settlement configuration
        uint256 settlementInterval;
        uint256 lastSettlement;
        uint256 lastStakingSettlement;
        uint256 lastUnstakingSettlement;
        // Variance tracking
        uint256 totalVariance;
        address varianceRecipient;
        // Strategy integration moved to StrategyManager
        address strategyManager; // StrategyManager contract address
        // Admin yield distribution
        uint256 pendingYieldToDistribute;
        mapping(address => uint256) userPendingYield;
    }

    // keccak256(abi.encode(uint256(keccak256("kDNStakingVault.storage.kDNStakingVault")) - 1)) &
    // ~bytes32(uint256(0xff))
    bytes32 private constant KDNSTAKINGVAULT_STORAGE_LOCATION =
        0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00;

    function _getkDNStakingVaultStorage() private pure returns (kDNStakingVaultStorage storage $) {
        assembly {
            $.slot := KDNSTAKINGVAULT_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event PauseState(bool isPaused);
    event MinterDepositRequested(address indexed minter, uint256 assetAmount, uint256 indexed batchId);
    event MinterRedeemRequested(
        address indexed minter, uint256 assetAmount, address batchReceiver, uint256 indexed batchId
    );
    event KTokenStakingRequested(
        address indexed user, address indexed minter, uint256 kTokenAmount, uint256 indexed batchId
    );
    event ShareUnstakingRequested(address indexed user, uint256 shares, uint256 indexed batchId);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
    event KTokenStaked(address indexed user, uint256 kTokenAmount, uint256 shares, uint256 indexed batchId);
    event MinterDeposited(address indexed minter, uint256 assets);
    event MinterWithdrawn(address indexed minter, address indexed receiver, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
    event StkTokensRedeemed(address indexed user, uint256 stkTokenAmount, uint256 kTokenAmount);
    event SharesTransferredToUser(address indexed user, address indexed fromMinter, uint256 shares);
    event BatchSettled(
        uint256 indexed batchId, uint256 netDeposits, uint256 netRedeems, uint256 sharesCreated, uint256 sharesBurned
    );
    event StakingBatchSettled(uint256 indexed batchId, uint256 totalShares, uint256 sharePrice);
    event UnstakingBatchSettled(uint256 indexed batchId, uint256 totalAssets, uint256 assetPrice);
    event StakingSharesClaimed(uint256 indexed batchId, uint256 requestIndex, address indexed user, uint256 shares);
    event UnstakingAssetsClaimed(uint256 indexed batchId, uint256 requestIndex, address indexed user, uint256 assets);
    event MinterNetted(address indexed minter, int256 netAmount, uint256 sharesAdjusted);
    event VarianceRecorded(uint256 amount, bool positive);
    event StrategyManagerUpdated(address indexed newStrategyManager);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);
    event Initialized(
        string name,
        string symbol,
        uint8 decimals,
        address asset,
        address kToken,
        address owner,
        address admin,
        address emergencyAdmin,
        address settler,
        address strategyManager
    );

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error BatchNotFound();
    error BatchAlreadySettled();
    error InsufficientMinterShares();
    error InsufficientShares();
    error InvalidBatchReceiver();
    error SettlementTooEarly();
    error AlreadyClaimed();
    error NotBeneficiary();
    error InvalidRequestIndex();
    error AmountTooLarge();
    error ExcessiveYield();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures function cannot be called when contract is paused
    modifier whenNotPaused() {
        if (_getkDNStakingVaultStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kDNStakingVault contract
    /// @param name_ Vault token name (unused)
    /// @param symbol_ Vault token symbol (unused)
    /// @param asset_ Underlying asset address
    /// @param kToken_ kToken address
    /// @param owner_ Address to set as owner
    /// @param admin_ Address to grant admin role
    /// @param emergencyAdmin_ Address to grant emergency admin role
    /// @param settler_ Address to grant settler role
    /// @param strategyManager_ Address to grant strategy manager role
    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address asset_,
        address kToken_,
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address settler_,
        address strategyManager_
    )
        external
        initializer
    {
        if (asset_ == address(0)) revert ZeroAddress();
        if (kToken_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();
        if (settler_ == address(0)) revert ZeroAddress();
        if (strategyManager_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(settler_, SETTLER_ROLE);
        _grantRoles(strategyManager_, STRATEGY_MANAGER_ROLE);

        // Initialize storage
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        $.underlyingAsset = asset_;
        $.name = name_;
        $.symbol = symbol_;
        $.decimals = decimals_;
        $.kToken = kToken_;
        $.strategyManager = strategyManager_;
        $.dustAmount = DEFAULT_DUST_AMOUNT;
        $.varianceRecipient = owner_;
        $.settlementInterval = DEFAULT_SETTLEMENT_INTERVAL;

        // Initialize batch IDs (start at 1)
        $.currentBatchId = 1;
        $.currentStakingBatchId = 1;
        $.currentUnstakingBatchId = 1;

        emit Initialized(
            name_, symbol_, decimals_, asset_, kToken_, owner_, admin_, emergencyAdmin_, settler_, strategyManager_
        );
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Requests deposit from authorized minter with exact asset amount
    /// @param assetAmount Exact amount of assets to deposit
    /// @return batchId Batch ID for this request
    function requestMinterDeposit(uint256 assetAmount)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(MINTER_ROLE)
        returns (uint256 batchId)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (assetAmount == 0) revert ZeroAmount();

        // Get current batch
        batchId = $.currentBatchId;
        DataTypes.Batch storage batch = $.batches[batchId];

        // Update state
        batch.depositAmounts[msg.sender] += assetAmount;
        batch.totalDeposits += assetAmount;
        $.minterPendingNetAmounts[msg.sender] += int256(assetAmount);

        // Track minter if first operation in batch
        if (!batch.hasMinterOperation[msg.sender]) {
            batch.hasMinterOperation[msg.sender] = true;
            batch.minters.push(msg.sender);
        }

        $.underlyingAsset.safeTransferFrom(msg.sender, address(this), assetAmount);

        emit MinterDepositRequested(msg.sender, assetAmount, batchId);
    }

    /// @notice Requests redemption from authorized minter with exact asset amount
    /// @param assetAmount Exact amount of assets to redeem
    /// @param minter Minter address for tracking
    /// @param batchReceiver BatchReceiver to send assets to
    /// @return batchId Batch ID for this request
    function requestMinterRedeem(
        uint256 assetAmount,
        address minter,
        address batchReceiver
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(MINTER_ROLE)
        returns (uint256 batchId)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (assetAmount == 0) revert ZeroAmount();
        if (batchReceiver == address(0)) revert InvalidBatchReceiver();

        // Get current batch
        batchId = $.currentBatchId;
        DataTypes.Batch storage batch = $.batches[batchId];

        // Add to batch redeems
        batch.redeemAmounts[minter] += assetAmount;
        batch.totalRedeems += assetAmount;
        batch.batchReceivers[minter] = batchReceiver;

        // Update minter's net pending (negative for redeems)
        $.minterPendingNetAmounts[minter] -= int256(assetAmount);

        // Track minter if first operation in batch
        if (!batch.hasMinterOperation[minter]) {
            batch.hasMinterOperation[minter] = true;
            batch.minters.push(minter);
        }

        emit MinterRedeemRequested(minter, assetAmount, batchReceiver, batchId);
    }

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param amount Amount of kTokens to stake
    /// @return requestId Request ID for this staking request
    function requestStake(uint256 amount) external payable nonReentrant whenNotPaused returns (uint256 requestId) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (amount == 0) revert ZeroAmount();
        if (amount < $.dustAmount) revert("Amount below dust threshold");

        // Get current staking batch
        uint256 batchId = $.currentStakingBatchId;
        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];

        $.totalStakedKTokens += amount;

        // Add to batch (stkToken amount calculated at settlement)
        batch.requests.push(
            DataTypes.StakingRequest({
                user: msg.sender,
                kTokenAmount: _safeToUint96(amount),
                stkTokenAmount: 0, // Will be calculated at settlement with real pricing
                requestTimestamp: _safeToUint64(block.timestamp),
                claimed: false
            })
        );

        batch.totalKTokens += amount;
        requestId = batch.requests.length - 1; // Request index as ID

        // External call LAST (interactions)
        $.kToken.safeTransferFrom(msg.sender, address(this), amount);

        emit KTokenStakingRequested(msg.sender, address(0), amount, batchId);
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(uint256 stkTokenAmount)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (stkTokenAmount == 0) revert ZeroAmount();

        // Check available stkTokens using ERC20 balance
        uint256 totalAvailable = balanceOf(msg.sender);
        if (totalAvailable < stkTokenAmount) revert InsufficientShares();

        // Burn stkTokens using proper ERC20 mechanism
        _burn(msg.sender, stkTokenAmount);

        // Get current unstaking batch
        uint256 batchId = $.currentUnstakingBatchId;
        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];

        // Add to batch (amounts calculated at settlement)
        batch.requests.push(
            DataTypes.UnstakingRequest({
                user: msg.sender,
                stkTokenAmount: _safeToUint96(stkTokenAmount),
                originalKTokenAmount: 0, // Will be calculated at settlement
                yieldAssets: 0, // Will be calculated at settlement
                requestTimestamp: _safeToUint64(block.timestamp),
                claimed: false
            })
        );

        batch.totalStkTokens += stkTokenAmount;
        requestId = batch.requests.length - 1; // Request index as ID

        emit ShareUnstakingRequested(msg.sender, stkTokenAmount, batchId);
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles a unified batch with netting
    /// @param batchId Batch ID to settle
    function settleBatch(uint256 batchId) external nonReentrant onlyRoles(SETTLER_ROLE) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch
        if (batchId == 0 || batchId > $.currentBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledBatchId) revert BatchAlreadySettled();

        // Enforce sequential settlement
        if (batchId != $.lastSettledBatchId + 1) revert BatchNotFound();

        // Check settlement interval
        if (block.timestamp < $.lastSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        DataTypes.Batch storage batch = $.batches[batchId];

        // Calculate net flows with overflow protection
        uint256 netDeposits = 0;
        uint256 netRedeems = 0;

        if (batch.totalDeposits > batch.totalRedeems) {
            netDeposits = batch.totalDeposits - batch.totalRedeems;
            // Sanity check for reasonable amounts
            if (netDeposits > type(uint128).max) revert("Net deposits too large");
        } else if (batch.totalRedeems > batch.totalDeposits) {
            netRedeems = batch.totalRedeems - batch.totalDeposits;
            // Sanity check for reasonable amounts
            if (netRedeems > type(uint128).max) revert("Net redeems too large");
        }

        // Process based on net flow (dual accounting)
        uint256 sharesCreated = 0;
        uint256 sharesBurned = 0;

        if (netDeposits > 0) {
            // Net deposits: increase total minter assets (1:1)
            // No user shares created here - only minter asset tracking
            sharesCreated = netDeposits; // 1:1 for tracking
        } else if (netRedeems > 0) {
            // Net redeems: decrease total minter assets (1:1)
            // No user shares burned here - only minter asset tracking
            sharesBurned = netRedeems; // 1:1 for tracking
        }

        // Process each minter's net position
        _processMinterPositions(batch, $);

        // Mark batch as settled
        batch.settled = true;
        batch.netDeposits = netDeposits;
        batch.netRedeems = netRedeems;
        batch.sharesCreated = sharesCreated;
        batch.sharesBurned = sharesBurned;

        $.lastSettledBatchId = batchId;
        $.lastSettlement = block.timestamp;

        // Create new batch
        unchecked {
            $.currentBatchId++;
        }

        emit BatchSettled(batchId, netDeposits, netRedeems, sharesCreated, sharesBurned);
    }

    /// @notice Processes staking batch settlement by updating global state and batch parameters
    /// @dev Validates batch sequence, applies automatic rebase, calculates stkToken price, and updates accounting
    /// @param batchId The identifier of the staking batch to settle
    /// @param totalKTokensStaked Aggregated amount of kTokens from all requests in the batch
    function settleStakingBatch(
        uint256 batchId,
        uint256 totalKTokensStaked
    )
        external
        nonReentrant
        onlyRoles(SETTLER_ROLE | STRATEGY_MANAGER_ROLE)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch
        if (batchId == 0 || batchId > $.currentStakingBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledStakingBatchId) revert BatchAlreadySettled();

        // Enforce sequential settlement
        if (batchId != $.lastSettledStakingBatchId + 1) revert BatchNotFound();

        // Check settlement interval
        if (block.timestamp < $.lastStakingSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];

        if (totalKTokensStaked == 0) {
            // Empty batch, just mark as settled
            $.lastSettledStakingBatchId = batchId;
            $.lastStakingSettlement = block.timestamp;
            emit StakingBatchSettled(batchId, 0, 0);
            return;
        }

        // TODO: Validate ACCOUNTING! SHOULD USE RAV!?
        // AUTOMATIC REBASE: Update stkToken assets with real
        uint256 totalVaultAssets = getTotalVaultAssets(); // Real assets
        uint256 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;

        // Auto-rebase stkTokens with unaccounted yield
        if (totalVaultAssets > accountedAssets) {
            uint256 yield = totalVaultAssets - accountedAssets;
            if (yield <= MAX_YIELD_PER_SYNC) {
                // Add yield directly to stkToken pool - DO NOT reduce minter assets
                // Yield comes from external sources (strategies), not minter funds
                $.totalStkTokenAssets += yield;
                $.userTotalAssets += yield;
                emit VarianceRecorded(yield, true);
            }
        }

        // Calculate stkToken price AFTER rebase (includes yield)
        uint256 currentStkTokenPrice = $.totalStkTokenSupply == 0
            ? PRECISION // 1:1 initial
            : ($.totalStkTokenAssets * PRECISION) / $.totalStkTokenSupply;

        // O(1) OPTIMIZATION: Calculate total stkTokens for entire batch
        uint256 totalStkTokensToMint = (totalKTokensStaked * PRECISION) / currentStkTokenPrice;

        // O(1) STATE UPDATE: Update global accounting without loops
        // NOTE: kTokens were already transferred to vault in requestStake()
        // Just update accounting to track that these assets are now in user pool
        $.totalStkTokenAssets += totalKTokensStaked;
        $.userTotalAssets += totalKTokensStaked;

        // Mint user shares using proper ERC20 mechanism
        // This will update userTotalSupply via _update override
        _mint(address(this), totalStkTokensToMint);

        // O(1) BATCH STATE: Mark batch as settled with settlement parameters
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        batch.totalStkTokens = totalStkTokensToMint;
        batch.totalAssetsFromMinter = totalKTokensStaked;
        $.lastSettledStakingBatchId = batchId;
        $.lastStakingSettlement = block.timestamp;

        // Create new batch
        unchecked {
            $.currentStakingBatchId++;
        }

        emit StakingBatchSettled(batchId, totalStkTokensToMint, currentStkTokenPrice);
    }

    /// @notice Settles an unstaking batch with O(1) efficiency - only updates batch state
    /// @param batchId Batch ID to settle
    /// @param totalStkTokensUnstaked Total stkTokens in the batch (from backend aggregation)
    /// @param totalKTokensToReturn Total original kTokens to return to users
    /// @param totalYieldToMinter Total yield to transfer back to minter pool
    function settleUnstakingBatch(
        uint256 batchId,
        uint256 totalStkTokensUnstaked,
        uint256 totalKTokensToReturn,
        uint256 totalYieldToMinter
    )
        external
        nonReentrant
        onlyRoles(SETTLER_ROLE | STRATEGY_MANAGER_ROLE)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch
        if (batchId == 0 || batchId > $.currentUnstakingBatchId) revert BatchNotFound();
        if (batchId <= $.lastSettledUnstakingBatchId) revert BatchAlreadySettled();

        // Enforce sequential settlement
        if (batchId != $.lastSettledUnstakingBatchId + 1) revert BatchNotFound();

        // Check settlement interval
        if (block.timestamp < $.lastUnstakingSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];

        if (totalStkTokensUnstaked == 0) {
            // Empty batch, just mark as settled
            $.lastSettledUnstakingBatchId = batchId;
            $.lastUnstakingSettlement = block.timestamp;
            emit UnstakingBatchSettled(batchId, 0, 0);
            return;
        }

        // AUTOMATIC REBASE: Update stkToken assets with latest performance
        uint256 totalVaultAssets = getTotalVaultAssets(); // Real assets
        uint256 accountedAssets = $.totalMinterAssets + $.totalStkTokenAssets;

        // Auto-rebase stkTokens with unaccounted yield
        if (totalVaultAssets > accountedAssets) {
            uint256 Yield = totalVaultAssets - accountedAssets;
            if (Yield <= MAX_YIELD_PER_SYNC) {
                // Add yield directly to stkToken pool - DO NOT reduce minter assets
                // Yield comes from external sources (strategies), not minter funds
                $.totalStkTokenAssets += Yield;
                $.userTotalAssets += Yield;
                emit VarianceRecorded(Yield, true);
            }
        }

        // Calculate current stkToken price AFTER rebase (maximum yield to users)
        uint256 currentStkTokenPrice =
            $.totalStkTokenSupply == 0 ? PRECISION : ($.totalStkTokenAssets * PRECISION) / $.totalStkTokenSupply;

        // O(1) OPTIMIZATION: Use backend-calculated values for exact split
        uint256 totalAssetsValue = (totalStkTokensUnstaked * currentStkTokenPrice) / PRECISION;

        // Validate backend calculations
        if (totalKTokensToReturn + totalYieldToMinter != totalAssetsValue) {
            revert("Invalid split calculation");
        }

        // O(1) STATE UPDATE: Update global accounting without loops
        $.totalStkTokenSupply -= totalStkTokensUnstaked;
        $.totalStkTokenAssets -= totalAssetsValue;
        $.totalMinterAssets += totalYieldToMinter; // Return yield to minter pool

        // O(1) BATCH STATE: Mark batch as settled with settlement parameters
        batch.settled = true;
        batch.stkTokenPrice = currentStkTokenPrice;
        batch.totalKTokensToReturn = totalKTokensToReturn;
        batch.totalYieldToMinter = totalYieldToMinter;
        $.lastSettledUnstakingBatchId = batchId;
        $.lastUnstakingSettlement = block.timestamp;

        // Create new batch
        $.currentUnstakingBatchId++;

        emit UnstakingBatchSettled(batchId, totalAssetsValue, currentStkTokenPrice);
    }

    /*//////////////////////////////////////////////////////////////
                          CLAIM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Claims stkTokens from a settled staking batch
    /// @param batchId Batch ID to claim from
    /// @param requestIndex Index of the request in the batch
    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable nonReentrant whenNotPaused {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch is settled
        if (batchId > $.lastSettledStakingBatchId) revert BatchNotFound();

        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];
        if (!batch.settled) revert BatchNotFound();

        // Validate request
        if (requestIndex >= batch.requests.length) revert InvalidRequestIndex();

        DataTypes.StakingRequest storage request = batch.requests[requestIndex];
        if (request.claimed) revert AlreadyClaimed();

        // Verify caller is the beneficiary
        if (msg.sender != request.user) revert NotBeneficiary();

        // Mark as claimed
        request.claimed = true;

        // Calculate stkTokens to mint based on batch settlement price
        uint256 stkTokensToMint = (request.kTokenAmount * PRECISION) / batch.stkTokenPrice;

        // O(1) CLAIM: Transfer stkTokens from vault to user using proper ERC20 transfer
        // This will update userShareBalances via _update override
        _transfer(address(this), request.user, stkTokensToMint);

        // Track the specific kToken amount staked by this user
        $.userOriginalKTokens[request.user] += request.kTokenAmount;

        // Update batch tracking
        batch.totalStkTokensClaimed += stkTokensToMint;

        emit StakingSharesClaimed(batchId, requestIndex, request.user, stkTokensToMint);
        emit StkTokensIssued(request.user, stkTokensToMint);
    }

    /// @notice Claims kTokens from a settled unstaking batch (yield goes to minter)
    /// @param batchId Batch ID to claim from
    /// @param requestIndex Index of the request in the batch
    function claimUnstakedAssets(uint256 batchId, uint256 requestIndex) external payable nonReentrant whenNotPaused {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Validate batch is settled
        if (batchId > $.lastSettledUnstakingBatchId) revert BatchNotFound();

        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];
        if (!batch.settled) revert BatchNotFound();

        // Validate request
        if (requestIndex >= batch.requests.length) revert InvalidRequestIndex();

        DataTypes.UnstakingRequest storage request = batch.requests[requestIndex];
        if (request.claimed) revert AlreadyClaimed();

        // Verify caller is the beneficiary
        if (msg.sender != request.user) revert NotBeneficiary();

        // Mark as claimed
        request.claimed = true;

        uint256 kTokensToReturn = request.originalKTokenAmount;

        $.totalStakedKTokens -= kTokensToReturn;
        batch.totalKTokensClaimed += kTokensToReturn;

        emit UnstakingAssetsClaimed(batchId, requestIndex, request.user, kTokensToReturn);

        $.kToken.safeTransfer(request.user, kTokensToReturn);

        // Note: yield assets already transferred to minter pool during settlement
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if address is authorized minter
    function isAuthorizedMinter(address minter) external view returns (bool) {
        return hasAnyRole(minter, MINTER_ROLE);
    }

    /// @notice Check if a unified batch is settled
    /// @param batchId The batch ID to check
    /// @return settled Whether the batch is settled
    function isBatchSettled(uint256 batchId) external view returns (bool settled) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return batchId <= $.lastSettledBatchId;
    }

    /// @notice Get total vault assets (vault balance only - StrategyManager handles external assets)
    function getTotalVaultAssets() public view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Only return vault balance - StrategyManager tracks external allocations
        return $.underlyingAsset.balanceOf(address(this));
    }

    /// @notice Returns total user assets including automatic yield
    /// @return Total user assets including unaccounted yield
    function getTotalUserAssets() public view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        uint256 userAssets = $.userTotalAssets; // Cache storage read
        uint256 totalVaultBalance = getTotalVaultAssets();
        uint256 accountedAssets = $.totalMinterAssets + userAssets;

        // Return total user assets including unaccounted yield
        // This ensures user shares appreciate with vault yield automatically
        return totalVaultBalance > accountedAssets ? userAssets + (totalVaultBalance - accountedAssets) : userAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
        return _getkDNStakingVaultStorage().underlyingAsset;
    }

    /// @notice Returns the vault shares token name
    /// @return Token name
    function name() public view override returns (string memory) {
        return _getkDNStakingVaultStorage().name;
    }

    /// @notice Returns the vault shares token symbol
    /// @return Token symbol
    function symbol() public view override returns (string memory) {
        return _getkDNStakingVaultStorage().symbol;
    }

    /// @notice Returns the vault shares token decimals
    /// @return Token decimals
    function decimals() public view override returns (uint8) {
        return _getkDNStakingVaultStorage().decimals;
    }

    /// @notice Get user's stkToken balance (alias for balanceOf)
    /// @param user User address
    /// @return User's stkToken balance
    function getStkTokenBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    /// @notice Get user's claimed stkToken balance (same as total balance in new model)
    /// @param user User address
    /// @return User's claimed stkToken balance
    function getClaimedStkTokenBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    /// @notice Get user's unclaimed stkToken balance (always 0 in new model since we use proper transfers)
    /// @param user User address
    /// @return Always 0 since we use proper ERC20 transfers now
    function getUnclaimedStkTokenBalance(address user) external pure returns (uint256) {
        user; // silence warning
        return 0; // No unclaimed balance in new model
    }

    /// @notice Get total stkTokens in circulation
    /// @return Total stkToken supply
    function getTotalStkTokens() external view returns (uint256) {
        return totalSupply();
    }

    /// @notice Get current stkToken price
    /// @return Current price in terms of assets per stkToken
    function getStkTokenPrice() external view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.totalStkTokenSupply == 0 ? PRECISION : ($.totalStkTokenAssets * PRECISION) / $.totalStkTokenSupply;
    }

    /// @notice Get minter's asset balance (for 1:1 guarantee validation)
    /// @param minter Minter address
    /// @return Minter's tracked asset balance
    function getMinterAssetBalance(address minter) external view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.minterAssetBalances[minter];
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants admin role to address
    /// @param admin Address to grant role to
    function grantAdminRole(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN_ROLE);
    }

    /// @notice Revokes admin role from address
    /// @param admin Address to revoke role from
    function revokeAdminRole(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN_ROLE);
    }

    /// @notice Grants minter role to address
    /// @param minter Address to grant role to
    function grantMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(minter, MINTER_ROLE);
    }

    /// @notice Revokes minter role from address
    /// @param minter Address to revoke role from
    function revokeMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(minter, MINTER_ROLE);
    }

    /// @notice Grants settler role to address
    /// @param settler Address to grant role to
    function grantSettlerRole(address settler) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(settler, SETTLER_ROLE);
    }

    /// @notice Revokes settler role from address
    /// @param settler Address to revoke role from
    function revokeSettlerRole(address settler) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(settler, SETTLER_ROLE);
    }

    /// @notice Grants strategy manager role to address
    /// @param strategyManager Address to grant role to
    function grantStrategyManagerRole(address strategyManager) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(strategyManager, STRATEGY_MANAGER_ROLE);
    }

    /// @notice Revokes strategy manager role from address
    /// @param strategyManager Address to revoke role from
    function revokeStrategyManagerRole(address strategyManager) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(strategyManager, STRATEGY_MANAGER_ROLE);
    }

    /// @notice Rebase stkTokens with yield (like Ethena sUSDe)
    /// @param yieldAmount Amount of yield to distribute to stkToken holders
    function rebaseStkTokens(uint256 yieldAmount) external onlyRoles(ADMIN_ROLE) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (yieldAmount == 0) revert ZeroAmount();
        if (yieldAmount > MAX_YIELD_PER_SYNC) revert ExcessiveYield();

        // Add yield to stkToken backing assets (automatic appreciation)
        $.totalStkTokenAssets += yieldAmount;
        $.userTotalAssets += yieldAmount;

        // DO NOT reduce minter assets - yield comes from external sources
        // Minter assets must remain 1:1 to preserve guarantee

        emit VarianceRecorded(yieldAmount, true);
    }

    /// @notice Syncs yield from minter assets to user pool
    function syncYield() external onlyRoles(ADMIN_ROLE) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        uint256 totalVaultBalance = getTotalVaultAssets();
        uint256 accountedAssets = $.totalMinterAssets + $.userTotalAssets;

        if (totalVaultBalance > accountedAssets) {
            // Unaccounted yield exists - transfer to user pool
            uint256 yieldAmount = totalVaultBalance - accountedAssets;

            // Add validation to prevent excessive yield manipulation
            if (yieldAmount > MAX_YIELD_PER_SYNC) revert ExcessiveYield();

            $.userTotalAssets += yieldAmount;

            emit VarianceRecorded(yieldAmount, true);
        }
    }

    /// @notice Distributes yield from minter pool to user pool
    /// @param amount Amount of yield to distribute
    function distributeYield(uint256 amount) external onlyRoles(ADMIN_ROLE) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (amount == 0) revert ZeroAmount();
        if (amount > $.totalMinterAssets) revert("Insufficient minter assets");

        // Move assets from minter pool to user pool
        $.totalMinterAssets -= amount;
        $.userTotalAssets += amount;

        // This increases user share value without changing supply
        emit VarianceRecorded(amount, true);
    }

    /// @notice Transfers yield directly to user as shares
    /// @param user User address to receive yield
    /// @param assets Amount of assets to transfer as yield
    function transferYieldToUser(address user, uint256 assets) external onlyRoles(ADMIN_ROLE) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (user == address(0)) revert ZeroAddress();
        if (assets == 0) revert ZeroAmount();
        if (assets > $.totalMinterAssets) revert("Insufficient minter assets");

        // Convert assets to user shares at current rate
        uint256 shares = _calculateShares(assets);

        // Move assets from minter pool to user pool
        $.totalMinterAssets -= assets;
        $.userTotalAssets += assets;

        // Mint new shares to user
        _mint(user, shares);

        emit SharesTransferredToUser(user, address(this), shares);
    }

    /// @notice Sets strategy manager address
    /// @param newStrategyManager New strategy manager address
    function setStrategyManager(address newStrategyManager) external onlyRoles(ADMIN_ROLE) {
        if (newStrategyManager == address(0)) revert ZeroAddress();
        _getkDNStakingVaultStorage().strategyManager = newStrategyManager;
        _grantRoles(newStrategyManager, STRATEGY_MANAGER_ROLE);
        emit StrategyManagerUpdated(newStrategyManager);
    }

    /// @notice Sets variance recipient address
    /// @param newRecipient New recipient address
    function setVarianceRecipient(address newRecipient) external onlyRoles(ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();
        _getkDNStakingVaultStorage().varianceRecipient = newRecipient;
    }

    /// @notice Sets settlement interval
    /// @param newInterval New interval in seconds
    function setSettlementInterval(uint256 newInterval) external onlyRoles(ADMIN_ROLE) {
        if (newInterval == 0) revert("Invalid interval");
        _getkDNStakingVaultStorage().settlementInterval = newInterval;
    }

    /// @notice Pauses or unpauses the contract
    /// @param _isPaused True to pause, false to unpause
    function setPaused(bool _isPaused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _getkDNStakingVaultStorage().isPaused = _isPaused;
        emit PauseState(_isPaused);
    }

    /// @notice Emergency withdraws tokens when paused
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        if (!_getkDNStakingVaultStorage().isPaused) revert("Not paused");
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (token == address(0)) {
            // Withdraw ETH
            to.safeTransferETH(amount);
        } else {
            // Withdraw ERC20 token
            token.safeTransfer(to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes minter positions for batch settlement
    /// @param batch Batch storage pointer
    /// @param $ Storage pointer
    function _processMinterPositions(DataTypes.Batch storage batch, kDNStakingVaultStorage storage $) private {
        uint256 length = batch.minters.length;

        address minter;
        uint256 deposits;
        uint256 redeems;

        for (uint256 i = 0; i < length;) {
            minter = batch.minters[i];
            deposits = batch.depositAmounts[minter];
            redeems = batch.redeemAmounts[minter];

            if (deposits > redeems) {
                unchecked {
                    _processMinterDeposit(minter, deposits - redeems, $);
                }
            } else if (redeems > deposits) {
                unchecked {
                    _processMinterRedeem(minter, redeems - deposits, batch.batchReceivers[minter], $);
                }
            }

            // Clear pending
            $.minterPendingNetAmounts[minter] = 0;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Processes minter deposit with 1:1 accounting
    /// @param minter Minter address
    /// @param netAmount Net deposit amount
    /// @param $ Storage pointer
    function _processMinterDeposit(address minter, uint256 netAmount, kDNStakingVaultStorage storage $) private {
        // Use 1:1 accounting for minters
        $.minterAssetBalances[minter] += netAmount;
        $.totalMinterAssets += netAmount;
        emit MinterNetted(minter, int256(netAmount), netAmount); // assets = shares for minters
    }

    /// @notice Processes minter redemption with 1:1 accounting
    /// @param minter Minter address
    /// @param netAmount Net redemption amount
    /// @param batchReceiver Batch receiver address
    /// @param $ Storage pointer
    function _processMinterRedeem(
        address minter,
        uint256 netAmount,
        address batchReceiver,
        kDNStakingVaultStorage storage $
    )
        private
    {
        // Use 1:1 accounting for minters
        if ($.minterAssetBalances[minter] < netAmount) {
            revert InsufficientMinterShares();
        }

        $.minterAssetBalances[minter] -= netAmount;
        $.totalMinterAssets -= netAmount;

        $.underlyingAsset.safeTransfer(batchReceiver, netAmount);

        emit MinterNetted(minter, -int256(netAmount), netAmount); // assets = shares for minters
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 OVERRIDES FOR DUAL ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns total supply of user shares (not including minter accounting)
    /// @dev Overrides ERC20 to provide user-only share accounting
    function totalSupply() public view override returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.userTotalSupply;
    }

    /// @notice Returns user's stkToken balance
    /// @dev Overrides ERC20 to provide user share balance
    function balanceOf(address account) public view override returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.userShareBalances[account];
    }

    /// @notice Override internal mint to update our dual accounting
    /// @dev Updates userTotalSupply and userShareBalances
    function _mint(address to, uint256 value) internal override {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        $.userTotalSupply += value;
        $.userShareBalances[to] += value;

        emit Transfer(address(0), to, value);
    }

    /// @notice Override internal burn to update our dual accounting
    /// @dev Updates userTotalSupply and userShareBalances
    function _burn(address from, uint256 value) internal override {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        $.userShareBalances[from] -= value;
        $.userTotalSupply -= value;

        emit Transfer(from, address(0), value);
    }

    /// @notice Override internal transfer to update our dual accounting
    /// @dev Updates userShareBalances for both from and to
    function _transfer(address from, address to, uint256 value) internal override {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (from == address(0)) {
            // This is a mint
            _mint(to, value);
            return;
        }

        if (to == address(0)) {
            // This is a burn
            _burn(from, value);
            return;
        }

        // Regular transfer
        $.userShareBalances[from] -= value;
        $.userShareBalances[to] += value;

        emit Transfer(from, to, value);
    }

    /// @notice Calculate shares for given assets
    /// @param assets Assets to calculate shares for
    /// @return Shares
    function _calculateShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply();
        uint256 totalUserAssets = getTotalUserAssets();
        return supply == 0 ? assets : (assets * supply) / totalUserAssets;
    }

    /// @notice Safely casts uint256 to uint96
    /// @param value Value to cast
    /// @return Casted uint96 value
    function _safeToUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) revert AmountTooLarge();
        return uint96(value);
    }

    /// @notice Safely casts uint256 to uint64
    /// @param value Value to cast
    /// @return Casted uint64 value
    function _safeToUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) revert AmountTooLarge();
        return uint64(value);
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
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kDNStakingVault";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
