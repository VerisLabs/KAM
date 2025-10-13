// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for date time operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/DateTimeLib.sol)
/// @dev Some functions were removed
// forgefmt: disable-start
library OptimizedDateTimeLib {
    /* ´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /* DATE TIME OPERATIONS */
    /* .•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the number of days since 1970-01-01 from (`year`,`month`,`day`).
    /// See: https://howardhinnant.github.io/date_algorithms.html
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDate} to check if the inputs are supported.
    function dateToEpochDay(uint256 year, uint256 month, uint256 day) internal pure returns (uint256 epochDay) {
        /// @solidity memory-safe-assembly
        assembly {
            year := sub(year, lt(month, 3))
            let doy := add(shr(11, add(mul(62719, mod(add(month, 9), 12)), 769)), day)
            let yoe := mod(year, 400)
            let doe := sub(add(add(mul(yoe, 365), shr(2, yoe)), doy), div(yoe, 100))
            epochDay := sub(add(mul(div(year, 400), 146097), doe), 719469)
        }
    }

    /// @dev Returns (`year`,`month`,`day`) from the number of days since 1970-01-01.
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDays} to check if the inputs is supported.
    function epochDayToDate(uint256 epochDay) internal pure returns (uint256 year, uint256 month, uint256 day) {
        /// @solidity memory-safe-assembly
        assembly {
            epochDay := add(epochDay, 719468)
            let doe := mod(epochDay, 146097)
            let yoe := div(sub(sub(add(doe, div(doe, 36524)), div(doe, 1460)), eq(doe, 146096)), 365)
            let doy := sub(doe, sub(add(mul(365, yoe), shr(2, yoe)), div(yoe, 100)))
            let mp := div(add(mul(5, doy), 2), 153)
            day := add(sub(doy, shr(11, add(mul(mp, 62719), 769))), 1)
            month := byte(mp, shl(160, 0x030405060708090a0b0c0102))
            year := add(add(yoe, mul(div(epochDay, 146097), 400)), lt(month, 3))
        }
    }

    /// @dev Returns (`year`,`month`,`day`) from the given unix timestamp.
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedTimestamp} to check if the inputs are supported.
    function timestampToDate(uint256 timestamp) internal pure returns (uint256 year, uint256 month, uint256 day) {
        (year, month, day) = epochDayToDate(timestamp / 86_400);
    }

    /// @dev Returns the unix timestamp from
    /// (`year`,`month`,`day`,`hour`,`minute`,`second`).
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedDateTime} to check if the inputs are supported.
    function dateTimeToTimestamp(uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            result = dateToEpochDay(year, month, day) * 86_400 + hour * 3600 + minute * 60 + second;
        }
    }

    /// @dev Returns (`year`,`month`,`day`,`hour`,`minute`,`second`)
    /// from the given unix timestamp.
    /// Note: Inputs outside the supported ranges result in undefined behavior.
    /// Use {isSupportedTimestamp} to check if the inputs are supported.
    function timestampToDateTime(uint256 timestamp)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day, uint256 hour, uint256 minute, uint256 second)
    {
        unchecked {
            (year, month, day) = epochDayToDate(timestamp / 86_400);
            uint256 secs = timestamp % 86_400;
            hour = secs / 3600;
            secs = secs % 3600;
            minute = secs / 60;
            second = secs % 60;
        }
    }

    /// @dev Returns number of days in given `month` of `year`.
    function daysInMonth(uint256 year, uint256 month) internal pure returns (uint256 result) {
        bool flag = isLeapYear(year);
        /// @solidity memory-safe-assembly
        assembly {
            // `daysInMonths = [31,28,31,30,31,30,31,31,30,31,30,31]`.
            // `result = daysInMonths[month - 1] + isLeapYear(year)`.
            result := add(byte(month, shl(152, 0x1f1c1f1e1f1e1f1f1e1f1e1f)), and(eq(month, 2), flag))
        }
    }

    /// @dev Returns if the `year` is leap.
    function isLeapYear(uint256 year) internal pure returns (bool leap) {
        /// @solidity memory-safe-assembly
        assembly {
            leap := iszero(and(add(mul(iszero(mod(year, 25)), 12), 3), year))
        }
    }
}
// forgefmt: disable-end
