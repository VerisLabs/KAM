// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";

/// @title AdminModule
/// @notice Handles all administrative operations for kDNStakingVault
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

    /// @notice Emergency withdrawal function for stuck tokens
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

    /*//////////////////////////////////////////////////////////////
                    DESTINATION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new strategy destination
    /// @param destination Address of the destination
    /// @param destinationType Type of destination (CUSTODIAL_WALLET, METAVAULT, STRATEGY_VAULT)
    /// @param maxAllocation Maximum allocation percentage in basis points (0-10000)
    /// @param name Human-readable name for the destination
    /// @param implementation Implementation contract address if applicable
    function registerDestination(
        address destination,
        DestinationType destinationType,
        uint256 maxAllocation,
        string calldata name,
        address implementation
    )
        external
        onlyRoles(ADMIN_ROLE)
    {
        if (destination == address(0)) revert ZeroAddress();
        if (maxAllocation > ONE_HUNDRED_PERCENT) revert InvalidAllocationPercentage(); // Max 100%

        BaseVaultStorage storage $ = _getBaseVaultStorage();

        // Check if destination already exists
        if ($.destinations[destination].isActive) revert DestinationAlreadyRegistered();

        // Register the destination
        $.destinations[destination] = DestinationConfig({
            destinationType: destinationType,
            isActive: true,
            maxAllocation: maxAllocation,
            currentAllocation: 0,
            name: name,
            implementation: implementation
        });

        // Add to registered destinations array
        $.registeredDestinations.push(destination);

        emit DestinationRegistered(destination, destinationType, maxAllocation, name);
    }

    /// @notice Updates an existing destination configuration
    /// @param destination Address of the destination to update
    /// @param isActive Whether the destination should be active
    /// @param maxAllocation New maximum allocation percentage in basis points
    function updateDestination(
        address destination,
        bool isActive,
        uint256 maxAllocation
    )
        external
        onlyRoles(ADMIN_ROLE)
    {
        if (destination == address(0)) revert ZeroAddress();
        if (maxAllocation > ONE_HUNDRED_PERCENT) revert InvalidAllocationPercentage();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        DestinationConfig storage config = $.destinations[destination];

        // Check if destination exists
        if (!config.isActive && !isActive) revert DestinationNotFound();

        // Update configuration
        config.isActive = isActive;
        config.maxAllocation = maxAllocation;

        emit DestinationUpdated(destination, isActive, maxAllocation);
    }

    /// @notice Sets allocation percentages for custodial vs metavault strategies
    /// @param custodialPercentage Percentage for custodial strategies (basis points)
    /// @param metavaultPercentage Percentage for metavault strategies (basis points)
    function setAllocationPercentages(
        uint64 custodialPercentage,
        uint64 metavaultPercentage
    )
        external
        onlyRoles(ADMIN_ROLE)
    {
        if (custodialPercentage + metavaultPercentage > ONE_HUNDRED_PERCENT) {
            revert InvalidAllocationPercentage();
        }

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.custodialAllocationPercentage = custodialPercentage;
        $.metavaultAllocationPercentage = metavaultPercentage;

        emit AllocationPercentagesUpdated(custodialPercentage, metavaultPercentage);
    }

    /// @notice Sets the kSiloContract address for custodial asset security
    /// @param newSiloContract Address of the new silo contract
    function setkSiloContract(address newSiloContract) external onlyRoles(ADMIN_ROLE) {
        if (newSiloContract == address(0)) revert ZeroAddress();

        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.kSiloContract = newSiloContract;
    }

    /// @notice Gets destination configuration
    /// @param destination Address of the destination
    /// @return config The destination configuration
    function getDestinationConfig(address destination) external view returns (DestinationConfig memory config) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return $.destinations[destination];
    }

    /// @notice Gets all registered destinations
    /// @return destinations Array of all registered destination addresses
    function getRegisteredDestinations() external view returns (address[] memory destinations) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return $.registeredDestinations;
    }

    /// @notice Gets allocation percentages
    /// @return custodialPercentage Custodial allocation percentage
    /// @return metavaultPercentage Metavault allocation percentage
    function getAllocationPercentages()
        external
        view
        returns (uint64 custodialPercentage, uint64 metavaultPercentage)
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return ($.custodialAllocationPercentage, $.metavaultAllocationPercentage);
    }

    /// @notice Gets total allocations by type
    /// @return totalCustodial Total allocated to custodial strategies
    /// @return totalMetavault Total allocated to metavault strategies
    function getTotalAllocations() external view returns (uint128 totalCustodial, uint128 totalMetavault) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return ($.totalCustodialAllocated, $.totalMetavaultAllocated);
    }

    /*//////////////////////////////////////////////////////////////
                        YIELD MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers yield from minter pool to user
    /// @param user User address to receive yield
    /// @param assets Amount of assets to transfer as yield
    function transferYieldToUser(address user, uint256 assets) external onlyRoles(ADMIN_ROLE) {
        if (user == address(0)) revert ZeroAddress();
        if (assets == 0) revert ZeroAmount();

        BaseVaultStorage storage $ = _getBaseVaultStorage();

        if (assets > $.totalMinterAssets) revert("Insufficient minter assets");

        // Convert assets to user shares at current rate
        uint256 shares = _calculateShares(assets, $);

        // Move assets from minter pool to user pool
        $.totalMinterAssets = (uint256($.totalMinterAssets) - assets).toUint128();
        $.userTotalAssets = (uint256($.userTotalAssets) + assets).toUint128();

        // Mint new shares to user
        $.userShareBalances[user] += shares;
        $.userTotalSupply = (uint256($.userTotalSupply) + shares).toUint128();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate shares for a given amount of assets
    function _calculateShares(uint256 assets, BaseVaultStorage storage $) private view returns (uint256) {
        if ($.userTotalSupply == 0) return assets; // 1:1 for first deposit
        return (assets * $.userTotalSupply) / $.userTotalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the function selectors for this module
    /// @return Array of function selectors that this module implements
    function selectors() external pure returns (bytes4[] memory) {
        bytes4[] memory s = new bytes4[](23);
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
        s[15] = this.registerDestination.selector;
        s[16] = this.updateDestination.selector;
        s[17] = this.setAllocationPercentages.selector;
        s[18] = this.setkSiloContract.selector;
        s[19] = this.getDestinationConfig.selector;
        s[20] = this.getRegisteredDestinations.selector;
        s[21] = this.getAllocationPercentages.selector;
        s[22] = this.getTotalAllocations.selector;
        return s;
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ContractNotPaused();
}
