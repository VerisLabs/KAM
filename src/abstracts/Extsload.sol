// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IExtsload } from "../interfaces/IExtsload.sol";

/// @title Extsload
/// @notice Enables public storage access for efficient state retrieval by external contracts
/// @notice This was taken from https://github.com/Uniswap/v4-core/blob/main/src/Extsload.sol
abstract contract Extsload is IExtsload {
    /// @inheritdoc IExtsload
    function extsload(bytes32 slot) external view returns (bytes32) {
        assembly ("memory-safe") {
            mstore(0, sload(slot))
            return(0, 0x20)
        }
    }

    /// @inheritdoc IExtsload
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory) {
        assembly ("memory-safe") {
            let memptr := mload(0x40)
            let start := memptr
            let length := shl(5, nSlots)
            mstore(memptr, 0x20)
            mstore(add(memptr, 0x20), nSlots)
            memptr := add(memptr, 0x40)
            let end := add(memptr, length)
            for { } 1 { } {
                mstore(memptr, sload(startSlot))
                memptr := add(memptr, 0x20)
                startSlot := add(startSlot, 1)
                if iszero(lt(memptr, end)) { break }
            }
            return(start, sub(end, start))
        }
    }

    /// @inheritdoc IExtsload
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory) {
        assembly ("memory-safe") {
            let memptr := mload(0x40)
            let start := memptr
            mstore(memptr, 0x20)
            mstore(add(memptr, 0x20), slots.length)
            memptr := add(memptr, 0x40)
            let end := add(memptr, shl(5, slots.length))
            let calldataptr := slots.offset
            for { } 1 { } {
                mstore(memptr, sload(calldataload(calldataptr)))
                memptr := add(memptr, 0x20)
                calldataptr := add(calldataptr, 0x20)
                if iszero(lt(memptr, end)) { break }
            }
            return(start, sub(end, start))
        }
    }
}
