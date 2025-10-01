// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title IVaultFees
/// @notice Interface for vault fee management including performance and management fees with hurdle rate mechanisms
/// @dev This interface defines the fee structure for staking vaults, implementing traditional fund management fee
/// models adapted for DeFi yield generation. The system supports two primary fee types: (1) Management Fees: Charged
/// periodically on assets under management regardless of performance, compensating vault operators for operational
/// costs and risk management, (2) Performance Fees: Charged on excess returns above hurdle rates, aligning operator
/// incentives with user returns. The hurdle rate mechanism can operate in two modes: soft hurdle (fees on all profits)
/// or hard hurdle (fees only on excess above hurdle). Fee calculations integrate with the batch settlement system,
/// ensuring accurate deductions from user returns during share price calculations. Backend coordination allows for
/// off-chain fee processing with on-chain validation and tracking. All fees are expressed in basis points (1% = 100 bp)
/// for precision and standard financial terminology alignment.
interface IVaultFees {
    /// @notice Configures the hurdle rate fee calculation mechanism for performance fee determination
    /// @dev This function switches between soft and hard hurdle rate modes affecting performance fee calculations.
    /// Hurdle Rate Modes: (1) Soft Hurdle (_isHard = false): Performance fees are charged on all profits when returns
    /// exceed the hurdle rate threshold, providing simpler fee calculation while maintaining performance incentives,
    /// (2) Hard Hurdle (_isHard = true): Performance fees are only charged on the excess return above the hurdle rate,
    /// ensuring users keep the full hurdle rate return before any performance fees. The hurdle rate itself is set
    /// globally in the registry per asset, providing consistent benchmarks across vaults. This mechanism ensures
    /// vault operators are only rewarded for generating returns above market expectations, protecting user interests
    /// while incentivizing superior performance.
    /// @param _isHard True for hard hurdle (fees only on excess), false for soft hurdle (fees on all profits)
    function setHardHurdleRate(bool _isHard) external;

    /// @notice Sets the annual management fee rate charged on assets under management
    /// @dev This function configures the periodic fee charged regardless of vault performance, compensating operators
    /// for ongoing vault management, risk monitoring, and operational costs. Management fees are calculated based on
    /// time elapsed since last fee charge and total assets under management. Process: (1) Validates fee rate does not
    /// exceed maximum allowed to protect users from excessive fees, (2) Updates stored management fee rate for future
    /// calculations, (3) Emits event for transparency and off-chain tracking. The fee accrues continuously and is
    /// realized during batch settlements, ensuring users see accurate net returns. Management fees are deducted from
    /// vault assets before performance fee calculations, following traditional fund management practices.
    /// @param _managementFee Annual management fee rate in basis points (1% = 100 bp, max 10000 bp)
    function setManagementFee(uint16 _managementFee) external;

    /// @notice Sets the performance fee rate charged on vault returns above hurdle rates
    /// @dev This function configures the success fee charged when vault performance exceeds benchmark hurdle rates,
    /// aligning operator incentives with user returns. Performance fees are calculated during settlement based on
    /// share price appreciation above the watermark (highest previous share price) and hurdle rate requirements.
    /// Process: (1) Validates fee rate is within acceptable bounds for user protection, (2) Updates performance fee
    /// rate for future calculations, (3) Emits tracking event for transparency. The fee applies only to new high
    /// watermarks, preventing double-charging on recovered losses. Combined with hurdle rates, this ensures operators
    /// are rewarded for generating superior risk-adjusted returns while protecting users from excessive fee extraction.
    /// @param _performanceFee Performance fee rate in basis points charged on excess returns (max 10000 bp)
    function setPerformanceFee(uint16 _performanceFee) external;

    /// @notice Updates the timestamp tracking for management fee calculations after backend fee processing
    /// @dev This function maintains accurate management fee accrual by recording when fees were last processed.
    /// Backend Coordination: (1) Off-chain systems calculate and process management fees based on time elapsed and
    /// assets under management, (2) Fees are deducted from vault assets through settlement mechanisms, (3) This
    /// function
    /// updates the tracking timestamp to prevent double-charging in future calculations. The timestamp validation
    /// ensures logical progression and prevents manipulation. Management fees accrue continuously, and proper timestamp
    /// tracking is essential for accurate pro-rata fee calculations across all vault participants.
    /// @param _timestamp The timestamp when management fees were processed (must be >= last timestamp, <= current time)
    function notifyManagementFeesCharged(uint64 _timestamp) external;

    /// @notice Updates the timestamp tracking for performance fee calculations after backend fee processing
    /// @dev This function maintains accurate performance fee tracking by recording when performance fees were last
    /// calculated and charged. Backend Processing: (1) Off-chain systems evaluate vault performance against watermarks
    /// and hurdle rates, (2) Performance fees are calculated on excess returns and deducted during settlement,
    /// (3) This notification updates tracking timestamp and potentially adjusts watermark levels. The timestamp ensures
    /// proper sequencing of performance evaluations and prevents fee calculation errors. Performance fees are
    /// event-driven
    /// based on new high watermarks, making accurate timestamp tracking crucial for fair fee assessment across all
    /// users.
    /// @param _timestamp The timestamp when performance fees were processed (must be >= last timestamp, <= current
    /// time)
    function notifyPerformanceFeesCharged(uint64 _timestamp) external;
}
