// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IVaultBatch } from "./IVaultBatch.sol";
import { IVaultClaim } from "./IVaultClaim.sol";
import { IVaultFees } from "./IVaultFees.sol";

/// @title IVault
/// @notice Interface for single vault contract
interface IVault is IVaultBatch, IVaultClaim, IVaultFees {
    /*//////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request to stake kTokens to the vault
    /// @param to The address to receive the stkTokens
    /// @param kTokensAmount The amount of kTokens to stake
    /// @return requestId The ID of the request
    function requestStake(address to, uint256 kTokensAmount) external payable returns (bytes32 requestId);

    /// @notice Request to unstake stkTokens from the vault
    /// @param to The address to receive the kTokens
    /// @param stkTokenAmount The amount of stkTokens to unstake
    /// @return requestId The ID of the request
    function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
}
