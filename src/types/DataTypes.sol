// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title DataTypes
/// @notice Library containing all data structures used in the KAM protocol
/// @dev Defines standardized data types for cross-contract communication and storage
library DataTypes {
    /*//////////////////////////////////////////////////////////////
                        ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Status enumeration for tracking redemption request lifecycle
    /// @dev Used to prevent double-spending and track request processing
    enum RedemptionStatus {
        PENDING, // Request submitted but not yet processed
        REDEEMED, // Request successfully completed
        CANCELLED // Request cancelled before processing

    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialization parameters for kMinter contract deployment
    /// @dev Contains all required addresses and configuration for minter setup
    struct InitParams {
        address kToken; // Address of the kToken contract to manage
        address underlyingAsset; // Address of the underlying asset (USDC/WBTC)
        address owner; // Contract owner with ultimate authority
        address admin; // Administrator with operational privileges
        address emergencyAdmin; // Emergency administrator for pause/unpause
        address institution; // Initial institutional user address
        address settler; // Address authorized to settle batches
        address manager; // Address of the vault manager (kDNStakingVault)
        uint256 settlementInterval; // Time interval between batch settlements
    }

    /// @notice Initialization parameters for kToken contract deployment
    /// @dev Contains essential configuration for token setup and role assignment
    struct kTokenInitParams {
        uint8 decimals; // Number of decimal places for the token
        address owner; // Contract owner with ultimate authority
        address admin; // Administrator with role management privileges
        address emergencyAdmin; // Emergency administrator for pause/unpause
        address minter; // Initial minter address (typically kMinter)
    }

    /// @notice Initialization parameters for kDNStakingVault contract deployment
    /// @dev Contains all required addresses and configuration for vault setup
    struct kDNStakingVaultInitParams {
        uint8 decimals; // Number of decimal places for vault shares
        address asset; // Address of the underlying asset (kToken)
        address kToken; // Address of the kToken contract
        address owner; // Contract owner with ultimate authority
        address admin; // Administrator with operational privileges
        address emergencyAdmin; // Emergency administrator for pause/unpause
        address settler; // Address authorized to settle batches
        address strategyManager; // Address of the strategy manager contract
    }

    /// @notice Request structure for minting new kTokens
    /// @dev Used by institutions to request token minting with 1:1 asset backing
    struct MintRequest {
        uint256 amount; // Amount of underlying assets to deposit for minting
        address beneficiary; // Address that will receive the newly minted kTokens
    }

    /// @notice Request structure for redeeming kTokens back to underlying assets
    /// @dev Used by institutions to initiate redemption requests for batch processing
    struct RedeemRequest {
        uint256 amount; // Amount of kTokens to redeem
        address user; // Address of the user making the redemption request
        address recipient; // Address that will receive the underlying assets
    }

    /// @notice Comprehensive redemption request structure with full tracking data
    /// @dev Stored internally to track redemption requests through the batch settlement process
    struct RedemptionRequest {
        bytes32 id; // Unique identifier for this redemption request
        address user; // Address of the user who made the request
        uint96 amount; // Amount of kTokens being redeemed (gas-optimized)
        address recipient; // Address that will receive the underlying assets
        address batchReceiver; // BatchReceiver contract handling this request
        uint64 requestTimestamp; // Timestamp when the request was created (gas-optimized)
        RedemptionStatus status; // Current status of the redemption request
    }

    /// @notice Information structure for redemption batches
    /// @dev Contains timing and settlement data for batch processing
    struct BatchInfo {
        uint256 startTime; // Timestamp when the batch was created
        uint256 cutoffTime; // Timestamp when new requests stop being accepted
        uint256 settlementTime; // Timestamp when the batch will be settled
        bool isClosed; // Whether the batch is closed to new requests
        uint256 totalAmount; // Total amount of assets in this batch
        address batchReceiver; // BatchReceiver contract for this batch
    }

    /*//////////////////////////////////////////////////////////////
                    KDNSTAKING VAULT STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Unified batch structure for minter operations in kDNStakingVault
    /// @dev Handles both deposits and redemptions with netting to minimize actual transfers
    /// @dev Optimized for single minter per vault architecture
    struct Batch {
        uint256 totalDeposits; // Total amount of deposits in this batch
        uint256 totalRedeems; // Total amount of redemptions in this batch
        uint256 netDeposits; // Net deposits after netting (deposits - redeems)
        uint256 netRedeems; // Net redemptions after netting (redeems - deposits)
        uint256 sharesCreated; // Total vault shares created for deposits
        uint256 sharesBurned; // Total vault shares burned for redemptions
        address activeMinter; // Single minter address with operations in this batch
        mapping(address => uint256) depositAmounts; // Minter address => total deposit amount
        mapping(address => uint256) redeemAmounts; // Minter address => total redemption amount
        mapping(address => address) batchReceivers; // Minter address => BatchReceiver for redemptions
        bool settled; // Whether this batch has been settled
    }

    /// @notice Individual staking request structure for kToken to stkToken conversion
    /// @dev Represents a user's request to stake kTokens for yield-bearing stkTokens
    struct StakingRequest {
        address user; // Address of the user making the staking request
        uint96 kTokenAmount; // Amount of kTokens to stake (gas-optimized)
        uint96 stkTokenAmount; // Amount of stkTokens to be issued (gas-optimized)
        uint64 requestTimestamp; // Timestamp when the request was created (gas-optimized)
        bool claimed; // Whether the user has claimed their stkTokens
    }

    /// @notice Batch structure for processing multiple staking requests together
    /// @dev Implements dual accounting with assets flowing from minter pool to user pool
    struct StakingBatch {
        StakingRequest[] requests; // Array of individual staking requests in this batch
        uint256 stkTokenPrice; // Price of stkTokens at settlement time
        uint256 totalKTokens; // Total kTokens staked in this batch
        uint256 totalStkTokens; // Total stkTokens to be distributed
        uint256 totalStkTokensClaimed; // Total stkTokens claimed by users
        uint256 totalAssetsFromMinter; // Total assets transferred from minter pool
        bool settled; // Whether this batch has been settled
    }

    /// @notice Individual unstaking request structure for stkToken to kToken conversion
    /// @dev Represents a user's request to unstake stkTokens back to kTokens plus yield
    struct UnstakingRequest {
        address user; // Address of the user making the unstaking request
        uint96 stkTokenAmount; // Amount of stkTokens to unstake (gas-optimized)
        uint64 requestTimestamp; // Timestamp when the request was created (gas-optimized)
        bool claimed; // Whether the user has claimed their assets
    }

    /// @notice Batch structure for processing multiple unstaking requests together
    /// @dev Implements dual accounting with yield distribution and original kToken recovery
    struct UnstakingBatch {
        UnstakingRequest[] requests; // Array of individual unstaking requests in this batch
        uint256 stkTokenPrice; // Price of stkTokens at settlement time
        uint256 totalStkTokens; // Total stkTokens being unstaked
        uint256 totalKTokensToReturn; // Total kTokens to return to users (original + yield)
        uint256 totalYieldToMinter; // Total yield to transfer back to minter pool
        uint256 totalKTokensClaimed; // Total kTokens claimed by users
        uint256 originalKTokenRatio; // Ratio of original kTokens to stkTokens (scaled by PRECISION)
        bool settled; // Whether this batch has been settled
    }

    /// @notice Configuration structure for strategy adapters
    /// @dev Used by kStrategyManager to manage allocation strategies and limits
    struct AdapterConfig {
        bool enabled; // Whether this adapter is active and usable
        uint256 maxAllocation; // Maximum allocation percentage (basis points)
        uint256 currentAllocation; // Current allocation amount in this adapter
        address implementation; // Address of the adapter implementation contract
    }

    /*//////////////////////////////////////////////////////////////
                    KSTRATEGY MANAGER STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Enumeration of supported adapter types for strategy allocation
    /// @dev Defines different categories of strategies for asset allocation
    enum AdapterType {
        CUSTODIAL_WALLET, // Traditional custodial wallet solutions
        ERC7540_VAULT, // ERC-7540 compliant vault strategies
        LENDING_PROTOCOL // DeFi lending protocol integrations

    }

    /// @notice Individual allocation instruction within an allocation order
    /// @dev Represents a single strategy allocation with target and amount
    struct Allocation {
        AdapterType adapterType; // Type of adapter being used for this allocation
        address target; // Target address for the allocation
        uint256 amount; // Amount of assets to allocate
        bytes data; // Additional data for adapter-specific operations
    }

    /// @notice Complete allocation order with multiple allocations and validation data
    /// @dev Used for EIP-712 signed allocation orders with replay protection
    struct AllocationOrder {
        uint256 totalAmount; // Total amount being allocated across all strategies
        Allocation[] allocations; // Array of individual allocation instructions
        uint256 nonce; // Nonce for replay protection
        uint256 deadline; // Timestamp after which the order expires
    }

    /// @notice Parameters for protocol-wide settlement and allocation in kStrategyManager
    struct SettlementParams {
        uint256 stakingBatchId;
        uint256 unstakingBatchId;
        uint256 totalKTokensStaked;
        uint256 totalStkTokensUnstaked;
        uint256 totalKTokensToReturn;
        uint256 totalYieldToMinter;
        address[] stakingDestinations;
        uint256[] stakingAmounts;
        address[] unstakingSources;
        uint256[] unstakingAmounts;
    }
}
