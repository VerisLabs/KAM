// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IInsuranceStrategy } from "src/interfaces/IInsuranceStrategy.sol";

/// @title MockInsuranceStrategy
/// @notice Mock implementation of IInsuranceStrategy for testing
/// @dev Simulates a simple yield strategy for insurance funds
contract MockInsuranceStrategy is IInsuranceStrategy {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable asset;
    uint256 public deployedAmount;
    uint256 public totalDeployed;
    uint256 public totalWithdrawn;
    bool public isLiquidStrategy;
    uint256 public withdrawalTime;
    string public strategyName;

    // Mock yield rate (in basis points per year)
    uint256 public yieldRate = 1000; // 10% APY
    uint256 public lastUpdateTime;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _asset, string memory _strategyName, bool _isLiquid, uint256 _withdrawalTime) {
        asset = _asset;
        strategyName = _strategyName;
        isLiquidStrategy = _isLiquid;
        withdrawalTime = _withdrawalTime;
        lastUpdateTime = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys insurance funds to the mock strategy
    /// @param amount Amount of underlying assets to deploy
    /// @param data Strategy-specific data (unused in mock)
    /// @return result Encoded shares received
    function deploy(uint256 amount, bytes calldata data) external override returns (bytes memory result) {
        if (amount == 0) revert InvalidAmount();

        // Funds are already transferred by kSiloContract before calling this function
        // Just verify we received them
        uint256 balance = asset.balanceOf(address(this));
        if (balance < amount) revert InvalidAmount();

        // Update deployed amount
        deployedAmount += amount;
        totalDeployed += amount;

        // Mock shares (1:1 for simplicity)
        uint256 shares = amount;

        emit FundsDeployed(amount, data, abi.encode(shares));

        return abi.encode(shares);
    }

    /// @notice Withdraws insurance funds from the mock strategy
    /// @param amount Amount of underlying assets to withdraw
    /// @param data Strategy-specific data (unused in mock)
    /// @return result Encoded assets returned
    function withdraw(uint256 amount, bytes calldata data) external override returns (bytes memory result) {
        if (amount == 0) revert InvalidAmount();
        if (deployedAmount < amount) revert WithdrawalFailed();

        // Update deployed amount
        deployedAmount -= amount;
        totalWithdrawn += amount;

        // Transfer assets back to caller
        asset.safeTransfer(msg.sender, amount);

        emit FundsWithdrawn(amount, data, abi.encode(amount));

        return abi.encode(amount);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current value of deployed funds including mock yield
    /// @return value Current value with simulated yield
    function getDeployedValue() external view override returns (uint256 value) {
        if (deployedAmount == 0) return 0;

        // Calculate mock yield based on time elapsed
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        uint256 annualizedYield = (deployedAmount * yieldRate * timeElapsed) / (365 days * 10_000);

        return deployedAmount + annualizedYield;
    }

    /// @notice Returns the name of the strategy
    /// @return name Strategy name
    function getStrategyName() external pure override returns (string memory name) {
        return "Mock Strategy";
    }

    /// @notice Returns whether the strategy can provide immediate liquidity
    /// @return True if funds can be withdrawn immediately
    function isLiquid() external view override returns (bool) {
        return isLiquidStrategy;
    }

    /// @notice Returns the expected withdrawal time for this strategy
    /// @return Time in seconds for withdrawals to complete
    function getWithdrawalTime() external view override returns (uint256) {
        return withdrawalTime;
    }

    /*//////////////////////////////////////////////////////////////
                          MOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the mock yield rate for testing
    /// @param newYieldRate New yield rate in basis points per year
    function setYieldRate(uint256 newYieldRate) external {
        yieldRate = newYieldRate;
        lastUpdateTime = block.timestamp;
    }

    /// @notice Sets the liquidity status for testing
    /// @param _isLiquid New liquidity status
    function setLiquidityStatus(bool _isLiquid) external {
        isLiquidStrategy = _isLiquid;
    }

    /// @notice Sets the withdrawal time for testing
    /// @param _withdrawalTime New withdrawal time in seconds
    function setWithdrawalTime(uint256 _withdrawalTime) external {
        withdrawalTime = _withdrawalTime;
    }

    /// @notice Simulates a loss in the strategy for testing
    /// @param lossAmount Amount of loss to simulate
    function simulateLoss(uint256 lossAmount) external {
        if (lossAmount > deployedAmount) {
            deployedAmount = 0;
        } else {
            deployedAmount -= lossAmount;
        }
    }

    /// @notice Simulates a gain in the strategy for testing
    /// @param gainAmount Amount of gain to simulate
    function simulateGain(uint256 gainAmount) external {
        deployedAmount += gainAmount;
    }

    /// @notice Gets the current deployed amount (for testing)
    /// @return amount Current deployed amount
    function getCurrentDeployedAmount() external view returns (uint256 amount) {
        return deployedAmount;
    }

    /// @notice Gets total deployment statistics (for testing)
    /// @return totalDep Total amount deployed
    /// @return totalWith Total amount withdrawn
    function getDeploymentStats() external view returns (uint256 totalDep, uint256 totalWith) {
        return (totalDeployed, totalWithdrawn);
    }
}
