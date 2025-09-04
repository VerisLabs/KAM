// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Library for efficiently performing keccak256 hashes.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/OptimizedEfficientHashLib.sol)
/// @dev To avoid stack-too-deep, you can use:
/// ```
/// bytes32[] memory buffer = OptimizedEfficientHashLib.malloc(10);
/// OptimizedEfficientHashLib.set(buffer, 0, value0);
/// ..
/// OptimizedEfficientHashLib.set(buffer, 9, value9);
/// bytes32 finalHash = OptimizedEfficientHashLib.hash(buffer);
/// ```
library OptimizedEfficientHashLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               MALLOC-LESS HASHING OPERATIONS               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns `keccak256(abi.encode(v0, v1, v2, v3))`.
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            result := keccak256(m, 0x80)
        }
    }

    /// @dev Returns `keccak256(abi.encode(v0, .., v4))`.
    function hash(uint256 v0, uint256 v1, uint256 v2, uint256 v3, uint256 v4) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, v0)
            mstore(add(m, 0x20), v1)
            mstore(add(m, 0x40), v2)
            mstore(add(m, 0x60), v3)
            mstore(add(m, 0x80), v4)
            result := keccak256(m, 0xa0)
        }
    }
}
