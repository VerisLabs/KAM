// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IVault } from "./IVault.sol";
import { IVaultReader } from "./modules/IVaultReader.sol";

/// @title IkStakingVault
/// @notice Interface for kStakingVault(single vault + reader module) that manages minter operations and user staking
/// @dev Matches kStakingVault implementation
interface IkStakingVault is IVault, IVaultReader {
    /// @notice Returns the owner of the contract
    function owner() external view returns (address);

    /// @notice Returns the name of the token
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals of the token
    function decimals() external view returns (uint8);

    /// @notice Returns the total supply of the token
    function totalSupply() external view returns (uint256);

    /// @notice Returns the balance of the specified account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers tokens to the specified recipient
    function transfer(address to, uint256 amount) external returns (bool);

    /// @notice Returns the remaining allowance that spender has to spend on behalf of owner
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Sets amount as the allowance of spender over the caller's tokens
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers tokens from sender to recipient using the allowance mechanism
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
