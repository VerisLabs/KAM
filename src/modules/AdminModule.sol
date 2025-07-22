// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title AdminModule
/// @notice Handles all administrative operations for kStakingVault
/// @dev Contains role management, configuration, and emergency functions
/// @dev This module is called via delegatecall and operates on the main vault's storage
contract AdminModule is ModuleBase {
    using SafeCastLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event PauseState(bool isPaused);
    event StrategyManagerUpdated(address indexed newStrategyManager);
    event VarianceRecipientUpdated(address indexed newRecipient);
    event SettlementIntervalUpdated(uint256 newInterval);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);

    // SECURITY FIX: New emergency events
    event EmergencyUserWithdrawal(address indexed user, uint256 assetsReturned, uint256 stkTokensBurned);
    event EmergencyStakingRefund(
        address indexed user, uint256 indexed batchId, uint256 requestIndex, uint256 refundAmount
    );
    event EmergencyUnstakingRefund(
        address indexed user, uint256 indexed batchId, uint256 requestIndex, uint256 stkTokenAmount
    );
    event EmergencyBatchSettled(uint256 indexed batchId, uint8 batchType, uint256 settlementPrice);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant STRATEGY_MANAGER_ROLE = _ROLE_6;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ContractNotPaused();
    error NotBeneficiary();
    error InvalidRequestIndex();
    error WithdrawalAlreadyProcessed();
    error BatchAlreadySettled();

    /*//////////////////////////////////////////////////////////////
                               ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants admin role to an address
    /// @param admin Address to grant admin role to
    function grantAdminRole(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN_ROLE);
    }

    /// @notice Revokes admin role from an address
    /// @param admin Address to revoke admin role from
    function revokeAdminRole(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN_ROLE);
    }

    /// @notice Grants minter role to an address
    /// @param minter Address to grant minter role to
    function grantMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(minter, MINTER_ROLE);
    }

    /// @notice Revokes minter role from an address
    /// @param minter Address to revoke minter role from
    function revokeMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(minter, MINTER_ROLE);
    }

    /// @notice Grants settler role to an address
    /// @param settler Address to grant settler role to
    function grantSettlerRole(address settler) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(settler, SETTLER_ROLE);
    }

    /// @notice Revokes settler role from an address
    /// @param settler Address to revoke settler role from
    function revokeSettlerRole(address settler) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(settler, SETTLER_ROLE);
    }

    /// @notice Grants strategy manager role to an address
    /// @param strategyManager Address to grant strategy manager role to
    function grantStrategyManagerRole(address strategyManager) external onlyRoles(ADMIN_ROLE) {
        _grantRoles(strategyManager, STRATEGY_MANAGER_ROLE);
    }

    /// @notice Revokes strategy manager role from an address
    /// @param strategyManager Address to revoke strategy manager role from
    function revokeStrategyManagerRole(address strategyManager) external onlyRoles(ADMIN_ROLE) {
        _removeRoles(strategyManager, STRATEGY_MANAGER_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the strategy manager address
    /// @param newStrategyManager New strategy manager address
    function setStrategyManager(address newStrategyManager) external onlyRoles(ADMIN_ROLE) {
        if (newStrategyManager == address(0)) revert ZeroAddress();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.strategyManager = newStrategyManager;

        emit StrategyManagerUpdated(newStrategyManager);
    }

    /// @notice Sets the variance recipient address
    /// @param newRecipient New variance recipient address
    function setVarianceRecipient(address newRecipient) external onlyRoles(ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.varianceRecipient = newRecipient;

        emit VarianceRecipientUpdated(newRecipient);
    }

    /// @notice Sets the settlement interval
    /// @param newInterval New settlement interval in seconds
    function setSettlementInterval(uint256 newInterval) external onlyRoles(ADMIN_ROLE) {
        if (newInterval == 0) revert ZeroAmount();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.settlementInterval = uint64(newInterval);

        emit SettlementIntervalUpdated(newInterval);
    }

    /// @notice Sets the paused state of the vault
    /// @param _isPaused True to pause, false to unpause
    function setPaused(bool _isPaused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.isPaused = _isPaused;

        emit PauseState(_isPaused);
    }

    /// @notice Sets the dust amount threshold
    /// @param newDustAmount New dust amount threshold
    function setDustAmount(uint256 newDustAmount) external onlyRoles(ADMIN_ROLE) {
        if (newDustAmount == 0) revert ZeroAmount();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.dustAmount = uint128(newDustAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency withdrawal function for stuck tokens (admin only)
    /// @param token Token address (address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();

        if (!$.isPaused) revert ContractNotPaused();
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

    /// @notice SECURITY FIX: Emergency user withdrawal for their own staked tokens
    /// @dev Allows users to withdraw their staked tokens in emergency when contract is paused
    /// @param user User address to withdraw for (must be msg.sender for security)
    function emergencyUserWithdrawal(address user) external nonReentrant {
        // DISABLED: Emergency withdrawal function - needs architecture update
        revert("Emergency withdrawal disabled - pending architecture update");
    }

    /// @notice SECURITY FIX: Emergency refund for users with pending requests
    /// @dev Allows users to get refunds for pending staking/unstaking requests when system is paused
    /// @param batchId Batch ID containing the user's request
    /// @param requestIndex Index of the request in the batch
    /// @param isStaking True if it's a staking request, false if unstaking
    function emergencyRequestRefund(uint256 batchId, uint256 requestIndex, bool isStaking) external nonReentrant {
        // DISABLED: Emergency refund function - needs architecture update
        revert("Emergency refund disabled - pending architecture update");
    }

    /// @notice SECURITY FIX: Force settlement of pending batches in emergency (admin only)
    /// @dev Allows admin to force settlement with current prices when normal settlement fails
    /// @param batchType 0 = staking, 1 = unstaking
    /// @param batchId Batch ID to force settle
    function emergencyForceSettlement(uint8 batchType, uint256 batchId) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        // DISABLED: Emergency settlement function - needs architecture update
        revert("Emergency settlement disabled - pending architecture update");
    }

    /// @notice Sets the kReceiver address for custodial asset security
    /// @param newReceiver Address of the new receiver contract
    function setkReceiver(address newReceiver) external onlyRoles(ADMIN_ROLE) {
        if (newReceiver == address(0)) revert ZeroAddress();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.kReceiver = newReceiver;
    }

    /// @notice Gets destination configuration (placeholder - not implemented in current architecture)
    /// @param destination Address of the destination
    /// @return isActive Whether destination is active
    function getDestinationConfig(address destination) external view returns (bool isActive) {
        // Simplified implementation - destinations are managed by kAssetRouter
        return destination != address(0);
    }

    /// @notice Gets all registered destinations (placeholder - not implemented in current architecture)
    /// @return destinations Empty array - destinations managed by kAssetRouter
    function getRegisteredDestinations() external view returns (address[] memory destinations) {
        // Return empty array - destinations are managed by kAssetRouter
        return new address[](0);
    }

    /// @notice Gets allocation percentages
    /// @return custodialPercentage Custodial allocation percentage
    /// @return metavaultPercentage Metavault allocation percentage
    function getAllocationPercentages()
        external
        pure
        returns (uint64 custodialPercentage, uint64 metavaultPercentage)
    {
        return (80, 20); // 80% custodial, 20% metavault
    }

    /// @notice Gets total allocations by type
    /// @return totalCustodial Total allocated to custodial strategies
    /// @return totalMetavault Total allocated to metavault strategies
    function getTotalAllocations() external pure returns (uint128 totalCustodial, uint128 totalMetavault) {
        return (0, 0); // Not implemented in current architecture
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers yield from minter pool to user
    /// @param user User address to receive yield
    /// @param assets Amount of assets to transfer as yield
    function transferYieldToUser(address user, uint256 assets) external onlyRoles(ADMIN_ROLE) {
        // DISABLED: Yield transfer function - needs architecture update
        revert("Yield transfer disabled - pending architecture update");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate shares for a given amount of assets (simplified)
    function _calculateShares(uint256 assets, BaseVaultStorage storage $) private view returns (uint256) {
        return assets; // 1:1 for now
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the function selectors for this module
    /// @return Array of function selectors that this module implements
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](16); // Updated count for existing functions only
        s[0] = this.grantAdminRole.selector;
        s[1] = this.revokeAdminRole.selector;
        s[2] = this.grantMinterRole.selector;
        s[3] = this.revokeMinterRole.selector;
        s[4] = this.grantSettlerRole.selector;
        s[5] = this.revokeSettlerRole.selector;
        s[6] = this.grantStrategyManagerRole.selector;
        s[7] = this.revokeStrategyManagerRole.selector;
        s[8] = this.setStrategyManager.selector;
        s[9] = this.setVarianceRecipient.selector;
        s[10] = this.setSettlementInterval.selector;
        s[11] = this.setPaused.selector;
        s[12] = this.setDustAmount.selector;
        s[13] = this.emergencyWithdraw.selector;
        s[14] = this.transferYieldToUser.selector;
        s[15] = this.setkReceiver.selector;
        // Note: Other functions disabled pending architecture update
        return s;
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    // Errors inherited from ModuleBase
}
