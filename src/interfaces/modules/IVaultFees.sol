// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IVaultFees {
    /// @notice Sets the yearly hurdle rate for the underlying asset
    /// @param _hurdleRate The new yearly hurdle rate
    /// @dev Fee is a basis point (1% = 100)
    function setHurdleRate(uint16 _hurdleRate) external;

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

    /// @notice Computes the last fee batch
    /// @return managementFees The management fees for the last batch
    /// @return performanceFees The performance fees for the last batch
    /// @return totalFees The total fees for the last batch
    function computeLastBatchFees()
        external
        view
        returns (uint256 managementFees, uint256 performanceFees, uint256 totalFees);

    /// @notice Returns the last time management fees were charged
    /// @return lastFeesChargedManagement Timestamp of last management fee charge
    function lastFeesChargedManagement() external view returns (uint256);

    /// @notice Returns the last time performance fees were charged
    /// @return lastFeesChargedPerformance Timestamp of last performance fee charge
    function lastFeesChargedPerformance() external view returns (uint256);

    /// @notice Returns the current hurdle rate used for performance fee calculations
    /// @return The hurdle rate in basis points (e.g., 500 = 5%)
    function hurdleRate() external view returns (uint16);

    /// @notice Returns the current performance fee percentage
    /// @return The performance fee in basis points (e.g., 2000 = 20%)
    function performanceFee() external view returns (uint16);

    /// @notice Returns the next performance fee timestamp so the backend can schedule the fee collection
    /// @return The next performance fee timestamp
    function nextPerformanceFeeTimestamp() external view returns (uint256);

    /// @notice Returns the next management fee timestamp so the backend can schedule the fee collection
    /// @return The next management fee timestamp
    function nextManagementFeeTimestamp() external view returns (uint256);

    /// @notice Returns the current management fee percentage
    /// @return The management fee in basis points (e.g., 100 = 1%)
    function managementFee() external view returns (uint16);

    /// @notice Returns the high watermark for share price used in performance fee calculations
    /// @return The share price watermark value
    function sharePriceWatermark() external view returns (uint256);
}
