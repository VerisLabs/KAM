// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IVersioned } from "kam/src/interfaces/IVersioned.sol";

interface ISettleBatch {
    function settleBatch(bytes32 _batchId) external;
}

/// @title IkAssetRouter
/// @notice Central money flow coordinator for the KAM protocol managing all asset movements and settlements
/// @dev This interface defines the core functionality for kAssetRouter, which serves as the primary coordinator
/// for all asset movements within the KAM protocol ecosystem. Key responsibilities include: (1) Managing asset
/// flows from kMinter institutional deposits to DN vaults for yield generation, (2) Coordinating asset transfers
/// between kStakingVaults for optimal allocation, (3) Processing batch settlements with yield distribution through
/// kToken minting/burning, (4) Maintaining virtual balance tracking across all vaults, (5) Implementing settlement
/// cooldown periods for security, (6) Executing peg protection mechanisms during market stress. The router acts as
/// the central hub that enables efficient capital allocation while maintaining the 1:1 backing guarantee of kTokens
/// through precise yield distribution and loss management across the protocol's vault network.
interface IkAssetRouter is IVersioned {
    /* ///////////////////////////////////////////////////////////////
                                STRUCTS
    ///////////////////////////////////////////////////////////////*/

    /// @notice Tracks requested and deposited asset amounts for batch processing coordination
    /// @dev Used by kAssetRouter to maintain virtual balance accounting across vaults and coordinate
    /// asset flows between kMinter redemption requests and vault settlements. Enables efficient
    /// batch processing by tracking pending operations before physical asset movement occurs.
    struct Balances {
        /// @dev Amount of assets requested for redemption by kMinter but not yet processed
        uint128 requested;
        /// @dev Amount of assets deposited into vaults and available for yield generation
        uint128 deposited;
    }

    /// @notice Contains all parameters for a batch settlement proposal in the yield distribution system
    /// @dev Settlement proposals implement a cooldown mechanism for security, allowing guardians to verify
    /// yield calculations before execution. Once executed, the proposal triggers kToken minting/burning to
    /// distribute yield or account for losses, maintaining the 1:1 backing ratio across all kTokens.
    struct VaultSettlementProposal {
        /// @dev The underlying asset address being settled (USDC, WBTC, etc.)
        address asset;
        /// @dev The DN vault address where yield was generated
        address vault;
        /// @dev The batch identifier for this settlement period
        bytes32 batchId;
        /// @dev Total asset value in the vault after yield generation
        uint256 totalAssets;
        /// @dev Net amount of new deposits/redemptions in this batch
        int256 netted;
        /// @dev Absolute yield amount (positive or negative) generated in this batch
        int256 yield;
        /// @dev Timestamp after which this proposal can be executed (cooldown protection)
        uint64 executeAfter;
        /// @dev Timestamp of last management fee charged
        uint64 lastFeesChargedManagement;
        /// @dev Timestamp of last performance fee charged
        uint64 lastFeesChargedPerformance;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the kAssetRouter contract is initialized with registry configuration
    /// @param registry The address of the kRegistry contract that manages protocol configuration
    event ContractInitialized(address indexed registry);

    /// @notice Emitted when assets are pushed from kMinter to a DN vault for yield generation
    /// @dev This occurs when institutional users deposit assets through kMinter, and the router
    /// forwards these assets to the appropriate DN vault for yield farming strategies
    /// @param from The address initiating the asset push (typically kMinter)
    /// @param amount The quantity of assets being pushed to the vault
    event AssetsPushed(address indexed from, uint256 amount);

    /// @notice Emitted when assets are requested for pull from a vault to fulfill kMinter redemptions
    /// @dev Part of the two-phase redemption process - assets are first requested, then later pulled
    /// after batch settlement. The batchReceiver is deployed to hold assets for distribution.
    /// @param vault The vault address from which assets are being requested
    /// @param asset The underlying asset address being requested for redemption
    /// @param amount The quantity of assets requested for redemption
    event AssetsRequestPulled(address indexed vault, address indexed asset, uint256 amount);

    /// @notice Emitted when assets are transferred between kStakingVaults for optimal allocation
    /// @dev This is a virtual transfer for accounting purposes - actual assets may remain in the same
    /// physical location while vault balances are updated to reflect the new allocation
    /// @param sourceVault The vault transferring assets (losing virtual balance)
    /// @param targetVault The vault receiving assets (gaining virtual balance)
    /// @param asset The underlying asset address being transferred
    /// @param amount The quantity of assets being transferred between vaults
    event AssetsTransfered(
        address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount
    );
    /// @notice Emitted when shares are requested for push operations in kStakingVault flows
    /// @dev Part of the share-based accounting system for retail users in kStakingVaults
    /// @param vault The kStakingVault requesting the share push operation
    /// @param batchId The batch identifier for this operation
    /// @param amount The quantity of shares being pushed
    event SharesRequestedPushed(address indexed vault, bytes32 indexed batchId, uint256 amount);

    /// @notice Emitted when shares are requested for pull operations in kStakingVault redemptions
    /// @dev Coordinates share-based redemptions for retail users through the batch system
    /// @param vault The kStakingVault requesting the share pull operation
    /// @param batchId The batch identifier for this redemption batch
    /// @param amount The quantity of shares being pulled for redemption
    event SharesRequestedPulled(address indexed vault, bytes32 indexed batchId, uint256 amount);

    /// @notice Emitted when shares are settled across multiple vaults with calculated share prices
    /// @dev Marks the completion of a cross-vault settlement with final share price determination
    /// @param vaults Array of vault addresses participating in the settlement
    /// @param batchId The batch identifier for this settlement period
    /// @param totalRequestedShares Total shares requested across all vaults in this settlement
    /// @param totalAssets Array of total assets for each vault after settlement
    /// @param sharePrice The final calculated share price for this settlement period
    event SharesSettled(
        address[] vaults,
        bytes32 indexed batchId,
        uint256 totalRequestedShares,
        uint256[] totalAssets,
        uint256 sharePrice
    );

    /// @notice Emitted when a vault batch is settled with final asset accounting
    /// @dev Indicates completion of yield distribution and final asset allocation for a batch
    /// @param vault The vault address that completed batch settlement
    /// @param batchId The batch identifier that was settled
    /// @param totalAssets The final total asset value in the vault after settlement
    event BatchSettled(address indexed vault, bytes32 indexed batchId, uint256 totalAssets);

    /// @notice Emitted when peg protection mechanism is activated due to vault shortfall
    /// @dev Triggered when a vault cannot fulfill redemption requests, requiring asset transfers
    /// from other vaults to maintain the protocol's 1:1 backing guarantee
    /// @param vault The vault experiencing shortfall that triggered peg protection
    /// @param shortfall The amount of assets needed to fulfill pending redemption requests
    event PegProtectionActivated(address indexed vault, uint256 shortfall);

    /// @notice Emitted when peg protection transfers assets between vaults to cover shortfalls
    /// @dev Maintains protocol solvency by redistributing assets from surplus to deficit vaults
    /// @param sourceVault The vault providing assets to cover the shortfall
    /// @param targetVault The vault receiving assets to fulfill its redemption obligations
    /// @param amount The quantity of assets transferred for peg protection
    event PegProtectionExecuted(address indexed sourceVault, address indexed targetVault, uint256 amount);

    /// @notice Emitted when yield is distributed through kToken minting/burning operations
    /// @dev This is the core mechanism for maintaining 1:1 backing while distributing yield.
    /// Positive yield increases kToken supply, negative yield (losses) decreases supply.
    /// @param vault The vault that generated the yield being distributed
    /// @param yield The amount of yield (positive or negative) being distributed
    event YieldDistributed(address indexed vault, int256 yield);

    /// @notice Emitted when assets are deposited into a vault through various protocol mechanisms
    /// @dev Tracks all asset deposits whether from kMinter institutional flows or other sources
    /// @param vault The vault address receiving the deposit
    /// @param asset The underlying asset address being deposited
    /// @param amount The quantity of assets deposited
    event Deposited(address indexed vault, address indexed asset, uint256 amount);

    /// @notice Emitted when a new settlement proposal is created with cooldown period
    /// @dev Begins the settlement process with a security cooldown to allow verification
    /// @param proposalId The unique identifier for this settlement proposal
    /// @param vault The vault address for which settlement is proposed
    /// @param batchId The batch identifier being settled
    /// @param totalAssets Total asset value in the vault after yield generation
    /// @param netted Net amount of new deposits/redemptions in this batch
    /// @param yield Absolute yield amount generated in this batch
    /// @param executeAfter Timestamp after which the proposal can be executed
    /// @param lastFeesChargedManagement Last management fees charged
    /// @param lastFeesChargedPerformance Last performance fees charged
    event SettlementProposed(
        bytes32 indexed proposalId,
        address indexed vault,
        bytes32 indexed batchId,
        uint256 totalAssets,
        int256 netted,
        int256 yield,
        uint256 executeAfter,
        uint256 lastFeesChargedManagement,
        uint256 lastFeesChargedPerformance
    );

    /// @notice Emitted when a settlement proposal is successfully executed
    /// @dev Marks completion of the settlement process with yield distribution
    /// @param proposalId The unique identifier of the executed proposal
    /// @param vault The vault address that was settled
    /// @param batchId The batch identifier that was settled
    /// @param executor The address that executed the settlement (guardian or admin)
    event SettlementExecuted(
        bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId, address executor
    );

    /// @notice Emitted when a settlement proposal is cancelled before execution
    /// @dev Allows guardians to cancel potentially incorrect settlement proposals
    /// @param proposalId The unique identifier of the cancelled proposal
    /// @param vault The vault address for which settlement was cancelled
    /// @param batchId The batch identifier for which settlement was cancelled
    event SettlementCancelled(bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId);

    /// @notice Emitted when a settlement proposal is updated with new yield calculation data
    /// @dev Allows for correction of settlement proposals before execution if needed
    /// @param proposalId The unique identifier of the updated proposal
    /// @param totalAssets Updated total asset value in the vault
    /// @param netted Updated net amount of deposits/redemptions
    /// @param yield Updated yield amount for distribution
    /// @param profit Updated profit flag (true for gains, false for losses)
    event SettlementUpdated(
        bytes32 indexed proposalId, uint256 totalAssets, uint256 netted, uint256 yield, bool profit
    );

    /// @notice Emitted when the settlement cooldown period is updated by protocol governance
    /// @dev Cooldown provides security by allowing time to verify settlement proposals before execution
    /// @param oldCooldown The previous cooldown period in seconds
    /// @param newCooldown The new cooldown period in seconds
    event SettlementCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    /// @notice Emitted when the yield tolerance threshold is updated by protocol governance
    /// @dev Yield tolerance acts as a safety mechanism to prevent settlement proposals with excessive
    /// yield deviations that could indicate calculation errors or potential manipulation attempts
    /// @param oldTolerance The previous yield tolerance in basis points
    /// @param newTolerance The new yield tolerance in basis points
    event MaxAllowedDeltaUpdated(uint256 oldTolerance, uint256 newTolerance);

    /// @notice Emitted when yield exceeds the tolerance threshold
    /// @param vault The DN vault address
    /// @param asset The underlying asset address
    /// @param batchId The batch identifier
    /// @param yield The yield amount
    /// @param maxAllowedYield The maximum allowed yield
    event YieldExceedsMaxDeltaWarning(
        address vault, address asset, bytes32 batchId, int256 yield, uint256 maxAllowedYield
    );

    /* //////////////////////////////////////////////////////////////
                            KMINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Pushes assets from kMinter institutional deposits to the designated DN vault for yield generation
    /// @dev This function is called by kMinter when institutional users deposit underlying assets. The process
    /// involves: (1) receiving assets already transferred from kMinter, (2) forwarding them to the appropriate
    /// DN vault for the asset type, (3) updating virtual balance tracking for accurate accounting. This enables
    /// immediate kToken minting (1:1 with deposits) while assets begin generating yield in the vault system.
    /// The assets enter the current batch for eventual settlement and yield distribution back to kToken holders.
    /// @param _asset The underlying asset address being deposited (must be registered in protocol)
    /// @param amount The quantity of assets being pushed to the vault for yield generation
    /// @param batchId The current batch identifier from the DN vault for tracking and settlement
    function kAssetPush(address _asset, uint256 amount, bytes32 batchId) external payable;

    /// @notice Requests asset withdrawal from vault to fulfill institutional redemption through kMinter
    /// @dev This function initiates the first phase of the institutional redemption process. The workflow
    /// involves: (1) registering the redemption request with the vault, (2) creating a kBatchReceiver minimal
    /// proxy to hold assets for distribution, (3) updating virtual balance accounting, (4) preparing for
    /// batch settlement. The actual asset transfer occurs later during batch settlement when the vault
    /// processes all pending requests together. This two-phase approach optimizes gas costs and ensures
    /// fair settlement across all institutional redemption requests in the batch.
    /// @param _asset The underlying asset address being redeemed
    /// @param amount The quantity of assets requested for redemption
    /// @param batchId The batch identifier for coordinating this redemption with other requests
    function kAssetRequestPull(address _asset, uint256 amount, bytes32 batchId) external payable;

    /* //////////////////////////////////////////////////////////////
                        KSTAKING VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers assets between kStakingVaults for optimal capital allocation and yield optimization
    /// @dev This function enables dynamic rebalancing of assets across the vault network to optimize yields
    /// and manage capacity. The transfer is virtual in nature - actual underlying assets may remain in the
    /// same physical vault while accounting balances are updated. This mechanism allows for: (1) moving
    /// assets from lower-yield to higher-yield opportunities, (2) rebalancing vault capacity during high
    /// demand periods, (3) optimizing capital efficiency across the protocol. The batch system ensures
    /// all transfers are processed fairly during settlement periods.
    /// @param sourceVault The kStakingVault address transferring assets (will lose virtual balance)
    /// @param targetVault The kStakingVault address receiving assets (will gain virtual balance)
    /// @param _asset The underlying asset address being transferred between vaults
    /// @param amount The quantity of assets to transfer for rebalancing
    /// @param batchId The batch identifier for coordinating this transfer with settlement
    function kAssetTransfer(address sourceVault, address targetVault, address _asset, uint256 amount, bytes32 batchId)
        external
        payable;

    /// @notice Requests shares to be pushed for kStakingVault staking operations and batch processing
    /// @dev This function is part of the share-based accounting system for retail users in kStakingVaults.
    /// When users stake kTokens, the vault requests shares to be pushed to track their ownership. The
    /// process coordinates: (1) conversion of kTokens to vault shares at current share price, (2) updating
    /// user balances in the vault system, (3) preparing for batch settlement. Share requests are batched
    /// to optimize gas costs and ensure fair pricing across all users in the same settlement period.
    /// @param sourceVault The kStakingVault address requesting share push operations
    /// @param amount The quantity of shares being requested for push to users
    /// @param batchId The batch identifier for coordinating share operations with settlement
    function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable;

    /// @notice Requests shares to be pulled for kStakingVault redemption operations
    /// @dev This function handles the share-based redemption process for retail users withdrawing from
    /// kStakingVaults. The process involves: (1) calculating share amounts to redeem based on user
    /// requests, (2) preparing for conversion back to kTokens at settlement time, (3) coordinating
    /// with the batch settlement system for fair pricing. Unlike institutional redemptions through
    /// kMinter, this uses share-based accounting to handle smaller, more frequent retail operations
    /// efficiently through the vault's batch processing system.
    /// @param sourceVault The kStakingVault address requesting share pull for redemptions
    /// @param amount The quantity of shares being requested for pull from users
    /// @param batchId The batch identifier for coordinating share redemptions with settlement
    function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable;

    /* //////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes a batch settlement for a vault with yield distribution through kToken minting/burning
    /// @dev This is the core function that initiates yield distribution in the KAM protocol. The settlement
    /// process involves: (1) calculating final yields after a batch period, (2) determining net new deposits/
    /// redemptions, (3) creating a proposal with cooldown period for security verification, (4) preparing for
    /// kToken supply adjustment to maintain 1:1 backing. Positive yields result in kToken minting (distributing
    /// gains to all holders), while losses result in kToken burning (socializing losses). The cooldown period
    /// allows guardians to verify calculations before execution, ensuring protocol integrity.
    /// @param asset The underlying asset address being settled (USDC, WBTC, etc.)
    /// @param vault The DN vault address where yield was generated
    /// @param batchId The batch identifier for this settlement period
    /// @param totalAssets Total asset value in the vault after yield generation/loss
    /// @param lastFeesChargedManagement Last management fees charged
    /// @param lastFeesChargedPerformance Last performance fees charged
    function proposeSettleBatch(
        address asset,
        address vault,
        bytes32 batchId,
        uint256 totalAssets,
        uint64 lastFeesChargedManagement,
        uint64 lastFeesChargedPerformance
    )
        external
        payable
        returns (bytes32 proposalId);

    /// @notice Executes a settlement proposal after the security cooldown period has elapsed
    /// @dev This function completes the yield distribution process by: (1) verifying the cooldown period has
    /// passed, (2) executing the actual kToken minting/burning to distribute yield or account for losses,
    /// (3) updating all vault balances and user accounting, (4) processing any pending redemption requests
    /// from the batch. This is where the 1:1 backing is maintained - the kToken supply is adjusted to exactly
    /// reflect the underlying asset changes, ensuring every kToken remains backed by real assets plus distributed
    /// yield.
    /// @param proposalId The unique identifier of the settlement proposal to execute
    function executeSettleBatch(bytes32 proposalId) external payable;

    /// @notice Cancels a settlement proposal before execution if errors are detected
    /// @dev Provides a safety mechanism for guardians to cancel potentially incorrect settlement proposals.
    /// This can be used when: (1) yield calculations appear incorrect, (2) system errors are detected,
    /// (3) market conditions require recalculation. Cancellation allows for proposal correction and
    /// resubmission with accurate data, preventing incorrect yield distribution that could affect the
    /// protocol's 1:1 backing guarantee. Only callable before the proposal execution.
    /// @param proposalId The unique identifier of the settlement proposal to cancel
    function cancelProposal(bytes32 proposalId) external;

    /* //////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the security cooldown period for settlement proposals
    /// @dev The cooldown period provides critical security by requiring a delay between proposal creation
    /// and execution. This allows: (1) protocol guardians to verify yield calculations, (2) detection of
    /// potential errors or malicious proposals, (3) emergency intervention if needed. The cooldown should
    /// balance security (longer is safer) with operational efficiency (shorter enables faster yield
    /// distribution). Only admin roles can modify this parameter as it affects protocol safety.
    /// @param cooldown The new cooldown period in seconds before settlement proposals can be executed
    function setSettlementCooldown(uint256 cooldown) external;

    /// @notice Updates the yield tolerance threshold for settlement proposals
    /// @dev This function allows protocol governance to adjust the maximum acceptable yield deviation before
    /// settlement proposals are rejected. The yield tolerance acts as a safety mechanism to prevent settlement
    /// proposals with extremely high or low yield values that could indicate calculation errors, data corruption,
    /// or potential manipulation attempts. Setting an appropriate tolerance balances protocol safety with
    /// operational flexibility, allowing normal yield fluctuations while blocking suspicious proposals.
    /// Only admin roles can modify this parameter as it affects protocol safety.
    /// @param tolerance_ The new yield tolerance in basis points (e.g., 1000 = 10%)
    function setMaxAllowedDelta(uint256 tolerance_) external;

    /* //////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves all pending settlement proposals for a specific vault
    /// @dev Returns proposal IDs that have been created but not yet executed or cancelled.
    /// Used for monitoring and management of the settlement queue. Essential for guardians
    /// to track proposals awaiting verification during the cooldown period.
    /// @param vault_ The vault address to query for pending settlement proposals
    /// @return pendingProposals Array of proposal IDs currently pending execution
    function getPendingProposals(address vault_) external view returns (bytes32[] memory pendingProposals);
    /// @notice Gets the DN vault address responsible for yield generation for a specific asset
    /// @dev Each supported asset (USDC, WBTC, etc.) has a designated DN vault that handles
    /// yield farming strategies. This mapping is critical for routing institutional deposits
    /// and coordinating settlement processes across the protocol's vault network.
    /// @param asset The underlying asset address to query
    /// @return vault The DN vault address that generates yield for this asset
    function getDNVaultByAsset(address asset) external view returns (address vault);

    /// @notice Retrieves the virtual balance accounting for a specific batch in a vault
    /// @dev Returns the deposited and requested amounts that are tracked virtually for batch
    /// processing. These balances coordinate institutional flows (kMinter) and retail flows
    /// (kStakingVault) within the same settlement period, ensuring fair processing and accurate
    /// yield distribution across all participants in the batch.
    /// @param vault The vault address to query batch balances for
    /// @param batchId The batch identifier to retrieve balance information
    /// @return deposited Total amount of assets deposited into this batch
    /// @return requested Total amount of assets requested for redemption from this batch
    function getBatchIdBalances(address vault, bytes32 batchId)
        external
        view
        returns (uint256 deposited, uint256 requested);

    /// @notice Retrieves the total shares requested for redemption in a specific vault batch
    /// @dev Tracks share-based redemption requests from retail users in kStakingVaults.
    /// This is separate from asset-based tracking and enables the protocol to coordinate
    /// both institutional (asset-based) and retail (share-based) operations within the
    /// same batch settlement process, ensuring consistent share price calculations.
    /// @param vault The kStakingVault address to query
    /// @param batchId The batch identifier for the redemption period
    /// @return The total amount of shares requested for redemption in this batch
    function getRequestedShares(address vault, bytes32 batchId) external view returns (uint256);

    /// @notice Checks if the kAssetRouter contract is currently paused
    /// @dev When paused, all critical functions (asset movements, settlements) are halted
    /// for emergency protection. This affects the entire protocol's money flow coordination,
    /// preventing new deposits, redemptions, and yield distributions until unpaused.
    /// @return True if the contract is paused and operations are halted
    function isPaused() external view returns (bool);

    /// @notice Retrieves complete details of a specific settlement proposal
    /// @dev Returns the full VaultSettlementProposal struct containing all parameters needed
    /// for yield distribution verification. Essential for guardians to review proposal accuracy
    /// during the cooldown period before execution. Contains asset amounts, yield calculations,
    /// and timing information for comprehensive proposal analysis.
    /// @param proposalId The unique identifier of the settlement proposal to query
    /// @return proposal The complete settlement proposal struct with all details
    function getSettlementProposal(bytes32 proposalId) external view returns (VaultSettlementProposal memory proposal);

    /// @notice Checks if a settlement proposal is ready for execution with detailed status
    /// @dev Validates all execution requirements: (1) proposal exists and is pending, (2) cooldown
    /// period has elapsed, (3) proposal hasn't been cancelled. Returns both boolean result and
    /// human-readable reason for failures, enabling better error handling and user feedback.
    /// @param proposalId The unique identifier of the proposal to check
    /// @return canExecute True if the proposal can be executed immediately
    /// @return reason Descriptive message explaining why execution is blocked (if applicable)
    function canExecuteProposal(bytes32 proposalId) external view returns (bool canExecute, string memory reason);

    /// @notice Gets the current security cooldown period for settlement proposals
    /// @dev The cooldown period determines how long proposals must wait before execution.
    /// This security mechanism allows guardians to verify yield calculations and prevents
    /// immediate execution of potentially malicious or incorrect proposals. Critical for
    /// maintaining protocol integrity during yield distribution processes.
    /// @return cooldown The current cooldown period in seconds
    function getSettlementCooldown() external view returns (uint256 cooldown);

    /// @notice Gets the current yield tolerance threshold for settlement proposals
    /// @dev The yield tolerance determines the maximum acceptable yield deviation before settlement proposals
    /// are automatically rejected. This acts as a safety mechanism to prevent processing of settlement proposals
    /// with excessive yield values that could indicate calculation errors or potential manipulation. The tolerance
    /// is expressed in basis points where 10000 equals 100%.
    /// @return tolerance The current yield tolerance in basis points
    function getMaxAllowedDelta() external view returns (uint256 tolerance);

    /// @notice Retrieves the virtual balance of assets for a vault across all its adapters
    /// @dev This function aggregates asset balances across all adapters connected to a vault to determine
    /// the total virtual balance available for operations. Essential for coordination between physical
    /// asset locations and protocol accounting. Used for settlement calculations and ensuring sufficient
    /// assets are available for redemptions and transfers within the money flow system.
    /// @param vault The vault address to calculate virtual balance for
    /// @param asset The underlying asset of the vault
    /// @return balance The total virtual asset balance across all vault adapters
    function virtualBalance(address vault, address asset) external view returns (uint256);

    // contractName() and contractVersion() functions are inherited from IVersioned
}
