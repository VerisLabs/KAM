// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title ModuleBase
/// @notice Base contract for kDNStakingVault and all modules
/// @dev Provides shared storage, roles, and common functionality
abstract contract ModuleBase is OwnableRoles, ReentrancyGuard {
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

    uint256 internal constant DEFAULT_DUST_AMOUNT = 1e12;
    uint256 internal constant DEFAULT_SETTLEMENT_INTERVAL = 1 hours;
    uint256 internal constant PRECISION = 1e18;
    uint256 internal constant MAX_YIELD_PER_SYNC = 1000e18;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kDNStakingVault.storage.kDNStakingVault
    struct kDNStakingVaultStorage {
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
        uint128 totalMinterAssets; // 16 bytes - up to ~3.4e20 tokens
        uint128 userTotalSupply; // 16 bytes - sufficient for token supply
        // SLOT 4: Asset Accounting Continued (32 bytes packed)
        uint128 userTotalAssets; // 16 bytes
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
        // SLOT 12-13: Metadata (stored as constants instead of storage)
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
    }

    bytes32 internal constant KDNSTAKINGVAULT_STORAGE_LOCATION =
        0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00;

    /// @notice Returns the storage struct for kDNStakingVault using ERC-7201 pattern
    /// @return $ Storage reference for kDNStakingVault state variables
    function _getkDNStakingVaultStorage() internal pure returns (kDNStakingVaultStorage storage $) {
        assembly {
            $.slot := KDNSTAKINGVAULT_STORAGE_LOCATION
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
    error AmountTooLarge();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict function execution when contract is paused
    /// @dev Reverts with Paused() if isPaused is true
    modifier whenNotPaused() virtual {
        if (_getkDNStakingVaultStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Safely casts uint256 to uint128 (main contract specific)
    /// @param value Value to cast
    /// @return Casted uint128 value
    function _safeToUint128(uint256 value) internal pure virtual returns (uint128) {
        if (value > type(uint128).max) revert AmountTooLarge();
        return uint128(value);
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
        if (value > type(uint32).max) revert AmountTooLarge();
        return uint32(value);
    }

    // Module-specific functions are implemented by individual modules
}
