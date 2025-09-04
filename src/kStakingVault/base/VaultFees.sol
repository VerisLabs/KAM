// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeCastLib } from "solady/utils/SafeCastLib.sol";

import { VAULTFEES_FEE_EXCEEDS_MAXIMUM, VAULTFEES_INVALID_TIMESTAMP, VAULTFEES_WRONG_ROLE } from "src/errors/Errors.sol";
import { BaseVault } from "src/kStakingVault/base/BaseVault.sol";

/// @title VaultFees
/// @notice Handles batch operations for staking and unstaking
/// @dev Contains batch functions for staking and unstaking operations
contract VaultFees is BaseVault {
    using SafeCastLib for uint256;

    /// @notice Emitted when the management fee is updated
    /// @param oldFee Previous management fee in basis points
    /// @param newFee New management fee in basis points
    event ManagementFeeUpdated(uint16 oldFee, uint16 newFee);

    /// @notice Emitted when the performance fee is updated
    /// @param oldFee Previous performance fee in basis points
    /// @param newFee New performance fee in basis points
    event PerformanceFeeUpdated(uint16 oldFee, uint16 newFee);

    /// @notice Emitted when fees are charged to the vault
    /// @param managementFees Amount of management fees collected
    /// @param performanceFees Amount of performance fees collected
    event FeesAssesed(uint256 managementFees, uint256 performanceFees);

    /// @notice Emitted when the hurdle rate is updated
    /// @param newRate New hurdle rate in basis points
    event HurdleRateUpdated(uint16 newRate);

    /// @notice Emitted when the hard hurdle rate is updated
    /// @param newRate New hard hurdle rate in basis points
    event HardHurdleRateUpdated(bool newRate);

    /// @notice Emitted when management fees are charged
    /// @param timestamp Timestamp of the fee charge
    event ManagementFeesCharged(uint256 timestamp);

    /// @notice Emitted when performance fees are charged
    /// @param timestamp Timestamp of the fee charge
    event PerformanceFeesCharged(uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum basis points
    uint256 constant MAX_BPS = 10_000;

    /// @notice Sets the yearly hurdle rate for the underlying asset
    /// @param _hurdleRate The new yearly hurdle rate
    /// @dev Fee is a basis point (1% = 100)
    function setHurdleRate(uint16 _hurdleRate) external {
        require(_isAdmin(msg.sender), VAULTFEES_WRONG_ROLE);
        require(_hurdleRate <= MAX_BPS, VAULTFEES_FEE_EXCEEDS_MAXIMUM);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _setHurdleRate($, _hurdleRate);
        emit HurdleRateUpdated(_hurdleRate);
    }

    /// @notice Sets the hard hurdle rate
    /// @param _isHard Whether the hard hurdle rate is enabled
    /// @dev If true, performance fees will only be charged to the excess return
    function setHardHurdleRate(bool _isHard) external {
        require(_isAdmin(msg.sender), VAULTFEES_WRONG_ROLE);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        _setIsHardHurdleRate($, _isHard);
        emit HardHurdleRateUpdated(_isHard);
    }

    /// @notice Sets the management fee
    /// @param _managementFee The new management fee
    /// @dev Fee is a basis point (1% = 100)
    function setManagementFee(uint16 _managementFee) external {
        require(_isAdmin(msg.sender), VAULTFEES_WRONG_ROLE);
        require(_managementFee <= MAX_BPS, VAULTFEES_FEE_EXCEEDS_MAXIMUM);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint16 oldFee = _getManagementFee($);
        _setManagementFee($, _managementFee);
        emit ManagementFeeUpdated(oldFee, _managementFee);
    }

    /// @notice Sets the performance fee
    /// @param _performanceFee The new performance fee
    /// @dev Fee is a basis point (1% = 100)
    function setPerformanceFee(uint16 _performanceFee) external {
        require(_isAdmin(msg.sender), VAULTFEES_WRONG_ROLE);
        require(_performanceFee <= MAX_BPS, VAULTFEES_FEE_EXCEEDS_MAXIMUM);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint16 oldFee = _getPerformanceFee($);
        _setPerformanceFee($, _performanceFee);
        emit PerformanceFeeUpdated(oldFee, _performanceFee);
    }

    /// @notice Notifies the module that management fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyManagementFeesCharged(uint64 _timestamp) external {
        require(_isAdmin(msg.sender), VAULTFEES_WRONG_ROLE);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(
            _timestamp >= _getLastFeesChargedManagement($) && _timestamp <= block.timestamp, VAULTFEES_INVALID_TIMESTAMP
        );
        _setLastFeesChargedManagement($, _timestamp);
        _updateGlobalWatermark();
        emit ManagementFeesCharged(_timestamp);
    }

    /// @notice Notifies the module that performance fees have been charged from backend
    /// @param _timestamp The timestamp of the fee charge
    /// @dev Should only be called by the vault
    function notifyPerformanceFeesCharged(uint64 _timestamp) external {
        require(_isAdmin(msg.sender), VAULTFEES_WRONG_ROLE);
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        require(
            _timestamp >= _getLastFeesChargedPerformance($) && _timestamp <= block.timestamp,
            VAULTFEES_INVALID_TIMESTAMP
        );
        _setLastFeesChargedPerformance($, _timestamp);
        _updateGlobalWatermark();
        emit PerformanceFeesCharged(_timestamp);
    }

    /// @notice Updates the share price watermark
    /// @dev Updates the high water mark if the current share price exceeds the previous mark
    function _updateGlobalWatermark() private {
        uint256 sp = _netSharePrice();
        if (sp > _getBaseVaultStorage().sharePriceWatermark) {
            _getBaseVaultStorage().sharePriceWatermark = sp.toUint128();
        }
    }
}
