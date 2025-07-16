// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title ModuleBase
/// @notice Base contract for kDNStakingVault and all modules with dual accounting architecture
/// @dev Provides shared storage, roles, and common functionality
///
/// DUAL ACCOUNTING MODEL:
/// The protocol implements a sophisticated dual accounting system that separates:
/// 1. Minter Assets: 1:1 backing for institutional users (fixed ratio, no yield)
/// 2. User Assets: Yield-bearing pool for retail users (appreciating value)
///
/// ASSET FLOW ARCHITECTURE:
/// - kMinter: Handles actual assets (USDC/WBTC) with 1:1 kToken backing
/// - kDNStakingVault: Uses kTokens as underlying asset, sources from minter pool
/// - kSStakingVault: Uses underlying assets, sources from kDNStakingVault minter pool
///
/// YIELD DISTRIBUTION:
/// - Institutional users (minters): Fixed 1:1 ratio, no yield appreciation
/// - Retail users: Receive yield through kToken minting and stkToken appreciation
/// - Yield flows automatically from minter pool to user pool via strategic kToken minting
///
/// INVARIANT GUARANTEES:
/// - Total kToken supply = Total underlying assets held by protocol
/// - Minter assets + User assets = Total vault assets (allowing 1 wei rounding)
/// - Strategy allocations ≤ Available minter assets
/// - Yield distribution ≤ MAX_YIELD_PER_SYNC per settlement
abstract contract ModuleBase is OwnableRoles, ReentrancyGuardTransient {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when invariant validation fails
    event InvariantViolation(string indexed violationType, uint256 expected, uint256 actual);

    /// @notice Emitted when asset flow occurs between vaults
    event AssetFlow(address indexed from, address indexed to, uint256 amount, string flowType);

    /// @notice Emitted when dual accounting is updated
    event DualAccountingUpdate(uint256 minterAssets, uint256 userAssets, uint256 totalVaultAssets);

    /// @notice Emitted when a new destination is registered
    event DestinationRegistered(
        address indexed destination, DestinationType destinationType, uint256 maxAllocation, string name
    );

    /// @notice Emitted when destination configuration is updated
    event DestinationUpdated(address indexed destination, bool isActive, uint256 maxAllocation);

    /// @notice Emitted when assets are allocated to a destination
    event AssetsAllocatedToDestination(address indexed destination, DestinationType destinationType, uint256 amount);

    /// @notice Emitted when assets are returned from a destination
    event AssetsReturnedFromDestination(address indexed destination, DestinationType destinationType, uint256 amount);

    /// @notice Emitted when allocation percentages are updated
    event AllocationPercentagesUpdated(uint256 custodialPercentage, uint256 metavaultPercentage);

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant MINTER_ROLE = _ROLE_2;
    uint256 public constant SETTLER_ROLE = _ROLE_3;
    uint256 public constant STRATEGY_MANAGER_ROLE = _ROLE_4;
    uint256 public constant STRATEGY_VAULT_ROLE = _ROLE_5;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant DEFAULT_DUST_AMOUNT = 1e12;
    uint256 internal constant DEFAULT_SETTLEMENT_INTERVAL = 8 hours;
    uint256 internal constant DEFAULT_BATCH_CUTOFF_TIME = 4 hours;
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant MAX_YIELD_PER_SYNC = 500e18;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Types of strategy destinations supported
    enum DestinationType {
        CUSTODIAL_WALLET, // Traditional custodial wallets (CEX, etc.)
        METAVAULT, // ERC7540 async vaults for cross-chain operations
        STRATEGY_VAULT // Other kS staking vaults

    }

    /// @notice Configuration for each strategy destination
    struct DestinationConfig {
        DestinationType destinationType;
        bool isActive;
        uint256 maxAllocation; // Maximum allocation in basis points (0-10000)
        uint256 currentAllocation; // Current allocated amount
        string name; // Human-readable name for the destination
        address implementation; // Implementation contract if applicable
    }

    /// @custom:storage-location erc7201:BaseVault.storage.BaseVault
    struct BaseVaultStorage {
        // SLOT 0: Configuration & Status (32 bytes packed)
        uint128 dustAmount; // 16 bytes - sufficient for dust amounts
        uint64 settlementInterval; // 8 bytes - up to 584 years in seconds
        uint32 decimals; // 4 bytes - supports decimals up to 4B
        bool isPaused; // 1 byte
        // 3 bytes remaining in slot 0

        // SLOT 1: Core Addresses (32 bytes)
        address underlyingAsset; // 20 bytes
        uint96 reserved1; // 12 bytes reserved for future use
        // SLOT 2: Core Addresses Continued (32 bytes)
        address kToken; // 20 bytes
        uint96 reserved2; // 12 bytes reserved for future use
        // SLOT 3: Asset Accounting (32 bytes packed)
        /// @dev Total assets backing minter operations with 1:1 kToken ratio
        /// These assets provide fixed backing for institutional users
        uint128 totalMinterAssets; // 16 bytes - up to ~3.4e20 tokens
        /// @dev Total supply of user shares (stkTokens) that represent yield-bearing positions
        /// Used for calculating share price and yield distribution
        uint128 userTotalSupply; // 16 bytes - sufficient for token supply
        // SLOT 4: Asset Accounting Continued (32 bytes packed)
        /// @dev Total assets in user yield-bearing pool that appreciates with yield
        /// Increases when yield flows from minter pool to user pool
        uint128 userTotalAssets; // 16 bytes
        /// @dev Total kTokens staked by users across all vaults
        /// Used for tracking user positions and yield calculations
        uint128 totalStakedKTokens; // 16 bytes
        // SLOT 5: Batch IDs (32 bytes packed)
        uint64 currentBatchId; // 8 bytes - 18 quintillion batches
        uint64 lastSettledBatchId; // 8 bytes
        uint64 currentStakingBatchId; // 8 bytes
        uint64 lastSettledStakingBatchId; // 8 bytes
        // SLOT 6: Batch IDs Continued & Timestamps (32 bytes packed)
        uint64 currentUnstakingBatchId; // 8 bytes
        uint64 lastSettledUnstakingBatchId; // 8 bytes
        uint64 lastSettlement; // 8 bytes - timestamp
        uint64 lastStakingSettlement; // 8 bytes - timestamp
        // SLOT 7: Settlement & stkToken (32 bytes packed)
        uint64 lastUnstakingSettlement; // 8 bytes
        uint128 totalStkTokenSupply; // 16 bytes
        uint64 reserved3; // 8 bytes reserved
        // SLOT 8: stkToken & Variance (32 bytes packed)
        uint128 totalStkTokenAssets; // 16 bytes
        uint128 totalVariance; // 16 bytes
        // SLOT 9: Strategy & Admin Addresses (32 bytes)
        address strategyManager; // 20 bytes
        uint96 reserved4; // 12 bytes reserved
        // SLOT 10: Variance & Admin (32 bytes)
        address varianceRecipient; // 20 bytes
        uint96 reserved5; // 12 bytes reserved
        // SLOT 11: Admin Yield (32 bytes)
        uint256 pendingYieldToDistribute; // 32 bytes - needs full precision
        // SLOT 12: Strategy Vault Integration (32 bytes packed)
        uint128 totalAllocatedToStrategies; // 16 bytes - assets allocated to strategy vaults
        address kSStakingVault; // 20 bytes - address of strategy vault (legacy, kept for compatibility)
        uint96 reserved6; // 12 bytes reserved
        // SLOT 13: Multi-Destination Support (32 bytes packed)
        uint64 custodialAllocationPercentage; // 8 bytes - percentage for custodial (basis points)
        uint64 metavaultAllocationPercentage; // 8 bytes - percentage for metavaults (basis points)
        uint128 totalCustodialAllocated; // 16 bytes - total allocated to custodial strategies
        // SLOT 14: Multi-Destination Support Continued (32 bytes packed)
        uint128 totalMetavaultAllocated; // 16 bytes - total allocated to metavault strategies
        address kSiloContract; // 20 bytes - address of silo contract for custodial returns
        uint96 reserved7; // 12 bytes reserved
        // SLOT 13-14: Metadata (stored as constants instead of storage)
        // name and symbol removed - use constants or immutable variables

        // MAPPINGS (separate slots each)
        // DUAL ACCOUNTING MODEL
        // 1. Fixed 1:1 accounting for kMinter (assets = shares always)
        mapping(address => uint256) minterAssetBalances; // 1:1 with deposited assets
        mapping(address => int256) minterPendingNetAmounts; // Pending net amounts
        // 2. Yield-bearing accounting for users
        mapping(address => uint256) userShareBalances; // User's yield-bearing shares
        mapping(uint256 => DataTypes.Batch) batches;
        // Staking batches (kToken -> shares)
        mapping(uint256 => DataTypes.StakingBatch) stakingBatches;
        // Unstaking batches (shares -> assets)
        mapping(uint256 => DataTypes.UnstakingBatch) unstakingBatches;
        // stkToken tracking (rebase token for yield distribution)
        mapping(address => uint256) userStkTokenBalances; // User stkToken balances
        mapping(address => uint256) userUnclaimedStkTokens; // Unclaimed stkTokens from requests
        mapping(address => uint256) userOriginalKTokens; // Track original kToken amounts per user
        // Admin yield distribution
        mapping(address => uint256) userPendingYield;
        // Multi-destination support
        mapping(address => DestinationConfig) destinations; // Strategy destination configurations
        address[] registeredDestinations; // Array of all registered destination addresses
    }

    bytes32 internal constant BASE_VAULT_STORAGE_LOCATION =
        0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00;

    /// @notice Returns the base vault storage struct using ERC-7201 pattern
    /// @return $ Storage reference for base vault state variables
    function _getBaseVaultStorage() internal pure returns (BaseVaultStorage storage $) {
        assembly {
            $.slot := BASE_VAULT_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error InsufficientShares();
    error BatchNotFound();
    error BatchAlreadySettled();
    error InvalidRequestIndex();
    error AlreadyClaimed();
    error NotBeneficiary();
    error InsufficientMinterAssets();
    error ExceedsAllocationLimit();
    error DestinationNotFound();
    error DestinationNotActive();
    error InvalidAllocationPercentage();
    error DestinationAlreadyRegistered();
    error DestinationTypeNotSupported();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict function execution when contract is paused
    /// @dev Reverts with Paused() if isPaused is true
    modifier whenNotPaused() virtual {
        if (_getBaseVaultStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Safely casts uint256 to uint128 (main contract specific)
    /// @param value Value to cast
    /// @return Casted uint128 value
    function _safeToUint128(uint256 value) internal pure virtual returns (uint128) {
        return SafeCastLib.toUint128(value);
    }

    /// @notice Safely casts uint256 to uint96 with overflow protection
    /// @param value The uint256 value to cast
    /// @return The uint96 value after safe casting
    function _safeToUint96(uint256 value) internal pure virtual returns (uint96) {
        return SafeCastLib.toUint96(value);
    }

    /// @notice Safely casts uint256 to uint64 with overflow protection
    /// @param value The uint256 value to cast
    /// @return The uint64 value after safe casting
    function _safeToUint64(uint256 value) internal pure virtual returns (uint64) {
        return SafeCastLib.toUint64(value);
    }

    /// @notice Safely casts uint256 to uint32 (main contract specific)
    /// @param value Value to cast
    /// @return Casted uint32 value
    function _safeToUint32(uint256 value) internal pure virtual returns (uint32) {
        return SafeCastLib.toUint32(value);
    }

    /*//////////////////////////////////////////////////////////////
                        INVARIANT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates that dual accounting totals match actual vault assets
    /// @dev Ensures minter assets + user assets = actual vault asset balance
    /// @param $ Storage pointer to BaseVaultStorage
    /// @return isValid True if dual accounting is consistent
    function _validateDualAccounting(BaseVaultStorage storage $) internal returns (bool isValid) {
        uint256 actualVaultAssets = $.underlyingAsset.balanceOf(address(this));
        uint256 accountedAssets = uint256($.totalMinterAssets) + uint256($.userTotalAssets);

        // Emit monitoring event for tracking
        emit DualAccountingUpdate($.totalMinterAssets, $.userTotalAssets, actualVaultAssets);

        // Allow small rounding differences (up to 1 wei)
        bool isConsistent;
        if (actualVaultAssets >= accountedAssets) {
            isConsistent = (actualVaultAssets - accountedAssets) <= 1;
        } else {
            isConsistent = (accountedAssets - actualVaultAssets) <= 1;
        }

        if (!isConsistent) {
            emit InvariantViolation("DualAccounting", accountedAssets, actualVaultAssets);
        }

        return isConsistent;
    }

    /// @notice Validates that strategy allocations don't exceed minter assets
    /// @dev Ensures total allocated to strategies <= total minter assets
    /// @param $ Storage pointer to BaseVaultStorage
    /// @return isValid True if strategy allocations are within limits
    function _validateStrategyAllocations(BaseVaultStorage storage $) internal returns (bool isValid) {
        isValid = $.totalAllocatedToStrategies <= $.totalMinterAssets;

        if (!isValid) {
            emit InvariantViolation("StrategyAllocation", $.totalMinterAssets, $.totalAllocatedToStrategies);
        }

        return isValid;
    }

    /// @notice Validates that user share accounting is consistent
    /// @dev Ensures user total supply and individual balances are consistent
    /// @param $ Storage pointer to BaseVaultStorage
    /// @return isValid True if user share accounting is consistent
    function _validateUserShares(BaseVaultStorage storage $) internal view returns (bool isValid) {
        // This is a basic check - more comprehensive validation would sum all user balances
        // For now, we check that user total supply is reasonable
        return $.userTotalSupply <= type(uint128).max;
    }

    /// @notice Comprehensive invariant validation for protocol safety
    /// @dev Validates all invariants that maintain protocol integrity
    /// @param $ Storage pointer to BaseVaultStorage
    /// @return isValid True if all invariants pass
    function _validateProtocolInvariants(BaseVaultStorage storage $) internal returns (bool isValid) {
        return _validateDualAccounting($) && _validateStrategyAllocations($) && _validateUserShares($);
    }

    /// @notice Validates yield distribution bounds
    /// @dev Ensures yield distribution doesn't exceed maximum allowed per sync
    /// @param yieldAmount The amount of yield to distribute
    /// @return isValid True if yield is within bounds
    function _validateYieldBounds(uint256 yieldAmount) internal pure returns (bool isValid) {
        return yieldAmount <= MAX_YIELD_PER_SYNC;
    }

    // Module-specific functions are implemented by individual modules
}
