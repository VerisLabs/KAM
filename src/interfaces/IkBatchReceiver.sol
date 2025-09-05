// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IkBatchReceiver
/// @notice Interface for minimal proxy contracts that manage asset distribution for completed batch redemptions
/// @dev kBatchReceiver contracts are deployed as minimal proxies (one per batch) to efficiently manage the distribution
/// of settled assets to users who requested redemptions. This design pattern provides: (1) gas-efficient deployment
/// since each batch gets its own isolated distribution contract, (2) clear asset segregation preventing cross-batch
/// contamination, (3) simplified accounting where each receiver holds exactly the assets needed for one batch.
/// The contract serves as a temporary holding mechanism - kMinter transfers settled assets to the receiver, then users
/// can pull their proportional share. This architecture ensures fair distribution and prevents front-running during
/// the redemption settlement process. Only the originating kMinter contract can interact with receivers, maintaining
/// strict access control throughout the asset distribution phase.
interface IkBatchReceiver {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new batch receiver is initialized and ready for asset distribution
    /// @dev This event marks the successful deployment and configuration of a minimal proxy receiver
    /// for a specific batch. Essential for tracking the lifecycle of batch settlement processes and
    /// enabling off-chain systems to monitor when settlement assets can begin flowing to receivers.
    /// @param kMinter The address of the kMinter contract authorized to interact with this receiver
    /// @param batchId The unique identifier of the batch this receiver will serve
    /// @param asset The underlying asset address (USDC, WBTC, etc.) this receiver will distribute
    event BatchReceiverInitialized(address indexed kMinter, bytes32 indexed batchId, address asset);

    /// @notice Emitted when assets are successfully distributed from the receiver to a redemption user
    /// @dev This event tracks the actual fulfillment of redemption requests, recording when users
    /// receive their settled assets. Critical for reconciliation and ensuring all batch participants
    /// receive their proportional share during the distribution phase.
    /// @param receiver The address that received the distributed assets (the redeeming user)
    /// @param asset The asset contract address that was transferred
    /// @param amount The quantity of assets successfully distributed to the receiver
    event PulledAssets(address indexed receiver, address indexed asset, uint256 amount);

    /// @notice Emitted when accidentally sent ERC20 tokens are rescued from the receiver contract
    /// @dev Provides a safety mechanism for recovering tokens that were mistakenly sent to the receiver
    /// outside of normal operations. This prevents permanent loss of assets while maintaining security.
    /// @param asset The address of the ERC20 token contract that was rescued
    /// @param to The address that received the rescued tokens (typically the kMinter)
    /// @param amount The quantity of tokens that were successfully rescued
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);

    /// @notice Emitted when accidentally sent ETH is rescued from the receiver contract
    /// @dev Handles recovery of native ETH that was mistakenly sent to the contract, ensuring no
    /// value is permanently locked in the receiver contracts during their operational lifecycle.
    /// @param asset The address that received the rescued ETH (typically the kMinter)
    /// @param amount The amount of ETH (in wei) that was successfully rescued
    event RescuedETH(address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the address of the kMinter contract authorized to interact with this receiver
    /// @dev Returns the immutable kMinter address set during receiver deployment. This address has
    /// exclusive permission to call pullAssets() and rescueAssets(), ensuring only the originating
    /// kMinter can manage asset distribution for this batch. Critical for maintaining access control
    /// and preventing unauthorized asset movements during the redemption settlement process.
    /// @return The address of the kMinter contract with administrative permissions over this receiver
    function kMinter() external view returns (address);

    /// @notice Retrieves the underlying asset contract address managed by this receiver
    /// @dev Returns the asset address configured during initialization (e.g., USDC, WBTC). This
    /// determines which token type the receiver will distribute to redemption users. The asset type
    /// must match the asset that was originally deposited and requested for redemption in the batch.
    /// @return The contract address of the underlying asset this receiver distributes
    function asset() external view returns (address);

    /// @notice Retrieves the unique batch identifier this receiver serves
    /// @dev Returns the batch ID set during initialization, which links this receiver to a specific
    /// batch of redemption requests. Used for validation when pulling assets to ensure operations
    /// are performed on the correct batch. Essential for maintaining batch isolation and preventing
    /// cross-contamination between different settlement periods.
    /// @return The unique batch identifier as a bytes32 hash
    function batchId() external view returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers settled assets from the receiver to a redemption user completing their withdrawal
    /// @dev This is the core asset distribution function that fulfills redemption requests after batch settlement.
    /// The process works as follows: (1) kMinter calls this function with user's proportional share, (2) receiver
    /// validates the batch ID matches to prevent cross-batch contamination, (3) assets are transferred directly
    /// to the user completing their redemption. Only callable by the authorized kMinter contract to maintain strict
    /// access control. This function is typically called multiple times per batch as individual users claim their
    /// settled redemptions, ensuring fair and orderly asset distribution.
    /// @param receiver The address that will receive the settled assets (the user completing redemption)
    /// @param amount The quantity of assets to transfer based on the user's proportional share
    /// @param _batchId The batch identifier for validation (must match this receiver's configured batch)
    function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external;

    /// @notice Emergency recovery function for accidentally sent assets to prevent permanent loss
    /// @dev Provides a safety mechanism for recovering tokens or ETH that were mistakenly sent to the receiver
    /// outside of normal settlement operations. The function handles both ERC20 tokens and native ETH recovery.
    /// For ERC20 tokens, it validates that the rescue asset is not the receiver's designated settlement asset
    /// (to prevent interfering with normal operations). Only the authorized kMinter can execute rescues, ensuring
    /// recovered assets return to the proper custodial system. Essential for maintaining protocol security while
    /// preventing accidental asset loss during the receiver contract's operational lifecycle.
    /// @param asset_ The contract address of the asset to rescue (use address(0) for native ETH recovery)
    function rescueAssets(address asset_) external payable;
}
