// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Optimized Library for making calls.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibCall.sol)
/// @author Modified from ExcessivelySafeCall (https://github.com/nomad-xyz/ExcessivelySafeCall)
/// @dev NOTE: This is a reduced version of the original Solady library.
/// We have extracted only the necessary contract calls functionality to optimize contract size.
/// Original code by Solady, modified for size optimization.
library OptimizedLibCall {
    /* ´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /* CUSTOM ERRORS */
    /* .•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The target of the call is not a contract.
    error TargetIsNotContract();

    /* ´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /* CONTRACT CALL OPERATIONS */
    /* .•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // These functions will revert if called on a non-contract
    // (i.e. address without code).
    // They will bubble up the revert if the call fails.

    /// @dev Makes a call to `target`, with `data` and `value`.
    function callContract(address target, uint256 value, bytes memory data) internal returns (bytes memory result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := mload(0x40)
            if iszero(call(gas(), target, value, add(data, 0x20), mload(data), codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            if iszero(returndatasize()) {
                if iszero(extcodesize(target)) {
                    mstore(0x00, 0x5a836a5f) // `TargetIsNotContract()`.
                    revert(0x1c, 0x04)
                }
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }
}
