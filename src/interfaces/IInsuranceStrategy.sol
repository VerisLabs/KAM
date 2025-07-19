// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IInsuranceStrategy
/// @notice Interface for pluggable insurance fund strategies
/// @dev Allows kSilo to deploy insurance funds to different yield strategies
interface IInsuranceStrategy {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when funds are deployed to the strategy
    event FundsDeployed(uint256 amount, bytes data, bytes result);

    /// @notice Emitted when funds are withdrawn from the strategy
    event FundsWithdrawn(uint256 amount, bytes data, bytes result);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error DeploymentFailed();
    error WithdrawalFailed();
    error InvalidAmount();
    error InvalidData();

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys insurance funds to the underlying strategy
    /// @param amount Amount of underlying assets to deploy
    /// @param data Strategy-specific data for deployment
    /// @return result Encoded result data from the deployment
    function deploy(uint256 amount, bytes calldata data) external returns (bytes memory result);

    /// @notice Withdraws insurance funds from the underlying strategy
    /// @param amount Amount of underlying assets to withdraw
    /// @param data Strategy-specific data for withdrawal
    /// @return result Encoded result data from the withdrawal
    function withdraw(uint256 amount, bytes calldata data) external returns (bytes memory result);

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current value of deployed funds in the strategy
    /// @return value Current value of funds deployed to this strategy
    function getDeployedValue() external view returns (uint256 value);

    /// @notice Returns the name of the strategy
    /// @return name Human-readable name of the strategy
    function getStrategyName() external pure returns (string memory name);

    /// @notice Returns whether the strategy can provide immediate liquidity
    /// @return isLiquid True if funds can be withdrawn immediately
    function isLiquid() external view returns (bool isLiquid);

    /// @notice Returns the expected withdrawal time for this strategy
    /// @return withdrawalTime Time in seconds for withdrawals to complete
    function getWithdrawalTime() external view returns (uint256 withdrawalTime);
}
