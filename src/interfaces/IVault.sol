// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IVaultBatch } from "./IVaultBatch.sol";
import { IVaultClaim } from "./IVaultClaim.sol";
import { IVaultFees } from "./IVaultFees.sol";

/// @title IVault
/// @notice Core interface for retail staking operations enabling kToken holders to earn yield through vault strategies
/// @dev This interface defines the primary user entry points for the KAM protocol's retail staking system. Vaults
/// implementing this interface provide a gateway for individual kToken holders to participate in yield generation
/// alongside institutional flows. The system operates on a dual-token model: (1) Users deposit kTokens (1:1 backed
/// tokens) and receive stkTokens (share tokens) that accrue yield, (2) Batch processing aggregates multiple user
/// operations for gas efficiency and fair pricing, (3) Two-phase operations (request → claim) enable optimal
/// settlement coordination with the broader protocol. Key features include: asset flow coordination with kAssetRouter
/// for virtual balance management, integration with DN vaults for yield source diversification, batch settlement
/// system for gas-efficient operations, and automated yield distribution through share price appreciation rather
/// than token rebasing. This approach maintains compatibility with existing DeFi infrastructure while providing
/// transparent yield accrual for retail participants.
interface IVault is IVaultBatch, IVaultClaim, IVaultFees {
    /* //////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initiates kToken staking request for yield-generating stkToken shares in a batch processing system
    /// @dev This function begins the retail staking process by: (1) Validating user has sufficient kToken balance
    /// and vault is not paused, (2) Creating a pending stake request with user-specified recipient and current
    /// batch ID for fair settlement, (3) Transferring kTokens from user to vault while updating pending stake
    /// tracking for accurate share calculations, (4) Coordinating with kAssetRouter to virtually move underlying
    /// assets from DN vault to staking vault, enabling proper asset allocation across the protocol. The request
    /// enters pending state until batch settlement, when the final share price is calculated based on vault
    /// performance. Users must later call claimStakedShares() after settlement to receive their stkTokens at
    /// the settled price. This two-phase approach ensures fair pricing for all users within a batch period.
    /// @param to The recipient address that will receive the stkTokens after successful settlement and claiming
    /// @param kTokensAmount The quantity of kTokens to stake (must not exceed user balance, cannot be zero)
    /// @return requestId Unique identifier for tracking this staking request through settlement and claiming
    function requestStake(address to, uint256 kTokensAmount) external payable returns (bytes32 requestId);

    /// @notice Initiates stkToken unstaking request for kToken redemption plus accrued yield through batch processing
    /// @dev This function begins the retail unstaking process by: (1) Validating user has sufficient stkToken balance
    /// and vault is operational, (2) Creating pending unstake request with current batch ID for settlement
    /// coordination,
    /// (3) Transferring stkTokens from user to vault contract to maintain stable share price during settlement period,
    /// (4) Notifying kAssetRouter of share redemption request for proper accounting across vault network. The stkTokens
    /// remain locked in the vault until settlement when they are burned and equivalent kTokens (including yield) are
    /// made available. Users must later call claimUnstakedAssets() after settlement to receive their kTokens from
    /// the batch receiver contract. This two-phase design ensures accurate yield calculations and prevents share
    /// price manipulation during the settlement process.
    /// @param to The recipient address that will receive the kTokens after successful settlement and claiming
    /// @param stkTokenAmount The quantity of stkTokens to unstake (must not exceed user balance, cannot be zero)
    /// @return requestId Unique identifier for tracking this unstaking request through settlement and claiming
    function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);

    /// @notice Cancels a pending stake request and returns kTokens to the user before batch settlement
    /// @dev This function allows users to reverse their staking request before batch processing by: (1) Validating
    /// the request exists, belongs to the caller, and remains in pending status, (2) Checking the associated batch
    /// hasn't been closed or settled to prevent manipulation of finalized operations, (3) Updating request status
    /// to cancelled and removing from user's active requests tracking, (4) Reducing total pending stake amount
    /// to maintain accurate vault accounting, (5) Notifying kAssetRouter to reverse the virtual asset movement
    /// from staking vault back to DN vault, ensuring proper asset allocation, (6) Returning the originally deposited
    /// kTokens to the user's address. This cancellation mechanism provides flexibility for users who change their
    /// mind or need immediate liquidity before the batch settlement occurs. The operation is only valid during
    /// the open batch period before closure by relayers.
    /// @param requestId The unique identifier of the stake request to cancel (must be owned by caller)
    function cancelStakeRequest(bytes32 requestId) external payable;

    /// @notice Cancels a pending unstake request and returns stkTokens to the user before batch settlement
    /// @dev This function allows users to reverse their unstaking request before batch processing by: (1) Validating
    /// the request exists, belongs to the caller, and remains in pending status, (2) Checking the associated batch
    /// hasn't been closed or settled to prevent reversal of finalized operations, (3) Updating request status
    /// to cancelled and removing from user's active requests tracking, (4) Notifying kAssetRouter to reverse the
    /// share redemption request, maintaining proper share accounting across the protocol, (5) Returning the originally
    /// transferred stkTokens from the vault back to the user's address. This cancellation mechanism enables users
    /// to maintain their staked position if market conditions change or they reconsider their unstaking decision.
    /// The stkTokens are returned without any yield impact since the batch hasn't settled. The operation is only
    /// valid during the open batch period before closure by relayers.
    /// @param requestId The unique identifier of the unstake request to cancel (must be owned by caller)
    function cancelUnstakeRequest(bytes32 requestId) external payable;

    /// @notice Controls the vault's operational state for emergency situations and maintenance periods
    /// @dev This function provides critical safety controls for vault operations by: (1) Enabling emergency admins
    /// to pause all user-facing operations during security incidents, market anomalies, or critical upgrades,
    /// (2) Preventing new stake/unstake requests and claims while preserving existing vault state and user balances,
    /// (3) Maintaining read-only access to vault data and view functions during pause periods for transparency,
    /// (4) Allowing authorized emergency admins to resume operations once issues are resolved or maintenance completed.
    /// When paused, all state-changing functions (requestStake, requestUnstake, cancelStakeRequest,
    /// cancelUnstakeRequest,
    /// claimStakedShares, claimUnstakedAssets) will revert with KSTAKINGVAULT_IS_PAUSED error. The pause mechanism
    /// serves as a circuit breaker protecting user funds during unexpected events while maintaining protocol integrity.
    /// Only emergency admins have permission to toggle this state, ensuring rapid response capabilities during critical
    /// situations without compromising decentralization principles.
    /// @param paused_ The desired operational state (true = pause operations, false = resume operations)
    function setPaused(bool paused_) external;

    /// @notice Sets the maximum total assets
    /// @param maxTotalAssets_ Maximum total assets
    function setMaxTotalAssets(uint128 maxTotalAssets_) external;
}
