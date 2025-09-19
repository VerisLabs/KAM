// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IVaultClaim
/// @notice Interface for claiming settled staking rewards and unstaking assets after batch processing completion
/// @dev This interface defines the final phase of the two-phase staking/unstaking system where users collect
/// their rewards after batch settlement. The claiming mechanism operates after batches have been settled by
/// kAssetRouter with finalized share prices and yield calculations. Key features include: (1) Share Distribution:
/// For staking claims, users receive stkTokens at the settled share price reflecting vault performance during
/// the batch period, (2) Asset Distribution: For unstaking claims, users receive kTokens (including accrued yield)
/// distributed through batch-specific receiver contracts, (3) Request Validation: Claims are validated against
/// original requests to ensure only authorized recipients can claim, (4) State Management: Claimed requests are
/// marked to prevent double-claiming while maintaining audit trails. The two-phase approach (request → claim)
/// provides several advantages: fair pricing through synchronized settlement, gas efficiency by separating request
/// processing from asset distribution, security through settled price finalization, and operational flexibility
/// for users to claim rewards at their convenience after settlement.
interface IVaultClaim {
    /// @notice Claims stkTokens from a settled staking batch at the finalized share price
    /// @dev This function completes the staking process by distributing stkTokens to users after batch settlement.
    /// Process: (1) Validates batch has been settled and share prices are finalized to ensure accurate distribution,
    /// (2) Verifies request ownership and pending status to prevent unauthorized or duplicate claims, (3) Calculates
    /// stkToken amount based on original kToken deposit and settled net share price (after fees), (4) Mints stkTokens
    /// to specified recipient reflecting their proportional vault ownership, (5) Marks request as claimed to prevent
    /// future reprocessing. The net share price accounts for management and performance fees, ensuring users receive
    /// their accurate yield-adjusted position. stkTokens are ERC20-compatible shares that continue accruing yield
    /// through share price appreciation until unstaking.
    /// @param requestId The specific staking request identifier to claim rewards for
    function claimStakedShares(bytes32 requestId) external payable;

    /// @notice Claims kTokens plus accrued yield from a settled unstaking batch through batch receiver distribution
    /// @dev This function completes the unstaking process by distributing redeemed assets to users after settlement.
    /// Process: (1) Validates batch settlement and asset distribution readiness through batch receiver verification,
    /// (2) Confirms request ownership and pending status to ensure authorized claiming, (3) Calculates kToken amount
    /// based on original stkToken redemption and settled share price including yield, (4) Burns locked stkTokens
    /// that were held during settlement period, (5) Triggers batch receiver to transfer calculated kTokens to
    /// recipient,
    /// (6) Marks request as claimed completing the unstaking cycle. The batch receiver pattern ensures asset isolation
    /// between settlement periods while enabling efficient distribution. Users receive their original investment plus
    /// proportional share of vault yields earned during their staking period.
    /// @param requestId The specific unstaking request identifier to claim assets for
    function claimUnstakedAssets(bytes32 requestId) external payable;
}
