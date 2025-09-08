// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IVault } from "./IVault.sol";
import { IVaultReader } from "./modules/IVaultReader.sol";

/// @title IkStakingVault
/// @notice Comprehensive interface combining retail staking operations with ERC20 share tokens and vault state reading
/// @dev This interface aggregates all kStakingVault functionality by extending IVault (staking/batch/claims/fees) and
/// IVaultReader (state queries) while adding standard ERC20 operations for stkToken management. The interface provides
/// a complete view of vault capabilities: (1) Staking Operations: Full request/claim lifecycle for retail users,
/// (2) Batch Management: Lifecycle control for settlement periods, (3) Share Tokens: Standard ERC20 functionality for
/// stkTokens that accrue yield, (4) State Reading: Comprehensive vault metrics and calculations, (5) Fee Management:
/// Performance and management fee configuration. This unified interface enables complete vault interaction through a
/// single contract, simplifying integration for front-ends and external protocols while maintaining modularity through
/// interface composition. The combination of vault-specific operations with standard ERC20 compatibility ensures
/// stkTokens work seamlessly with existing DeFi infrastructure while providing specialized staking functionality.
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
