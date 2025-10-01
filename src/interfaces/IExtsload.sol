// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @title IExtsload
/// @notice Interface for external storage access
interface IExtsload {
    /// @notice Reads a single storage slot
    /// @param slot Storage slot to read
    /// @return Value at the storage slot
    function extsload(bytes32 slot) external view returns (bytes32);

    /// @notice Reads multiple consecutive storage slots
    /// @param startSlot Starting storage slot
    /// @param nSlots Number of slots to read
    /// @return Array of values from the storage slots
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);

    /// @notice Reads multiple arbitrary storage slots
    /// @param slots Array of storage slots to read
    /// @return Array of values from the storage slots
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory);
}
