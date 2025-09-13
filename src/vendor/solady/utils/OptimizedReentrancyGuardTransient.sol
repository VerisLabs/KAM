// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title OptimizedReentrancyGuardTransient
/// @notice Optimized reentrancy guard mixin (transient storage variant).
/// @dev This implementation utilizes a internal function instead of a modifier
/// to check the reentrant condition, with the purpose of reducing contract size
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ReentrancyGuardTransient.sol)
abstract contract OptimizedReentrancyGuardTransient {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Unauthorized reentrant call.
    error Reentrancy();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Equivalent to: `uint32(bytes4(keccak256("Reentrancy()"))) | 1 << 71`.
    /// 9 bytes is large enough to avoid collisions in practice,
    /// but not too large to result in excessive bytecode bloat.
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x8000000000ab143c06;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      REENTRANCY GUARD                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _lockReentrant() internal {
        uint256 s = _REENTRANCY_GUARD_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            if tload(s) {
                mstore(0x00, s) // `Reentrancy()`.
                revert(0x1c, 0x04)
            }
            tstore(s, address())
        }
    }

    function _unlockReentrant() internal {
        uint256 s = _REENTRANCY_GUARD_SLOT;
        /// @solidity memory-safe-assembly
        assembly {
            tstore(s, 0)
        }
    }
}
