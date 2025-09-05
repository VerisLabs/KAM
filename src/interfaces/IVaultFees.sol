// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IVaultFees {
    /// @notice Sets the hard hurdle rate
    /// @param _isHard Whether the hard hurdle rate is enabled
    /// @dev If true, performance fees will only be charged to the excess return
    function setHardHurdleRate(bool _isHard) external;

    /// @notice Sets the management fee
    /// @param _managementFee The new management fee
    /// @dev Fee is a basis point (1% = 100)
    function setManagementFee(uint16 _managementFee) external;

    /// @notice Sets the performance fee
    /// @param _performanceFee The new performance fee
    /// @dev Fee is a basis point (1% = 100)
    function setPerformanceFee(uint16 _performanceFee) external;

    /// @notice Notifies the module that management fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyManagementFeesCharged(uint64 _timestamp) external;

    /// @notice Notifies the module that performance fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyPerformanceFeesCharged(uint64 _timestamp) external;
}
