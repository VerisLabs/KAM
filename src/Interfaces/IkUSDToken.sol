// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IkUSDToken
/// @notice Interface for the kUSDToken (Chainlink CCT) contract
interface IkUSDToken {

    // =========================
    //        VIEWS
    // =========================
    /// @notice Returns the name of the token
    function name() external view returns (string memory);
    /// @notice Returns the symbol of the token
    function symbol() external view returns (string memory);
    /// @notice Returns the decimals of the token
    function decimals() external view returns (uint8);
    /// @notice Returns the total supply
    function totalSupply() external view returns (uint256);
    /// @notice Returns the balance of an account
    function balanceOf(address account) external view returns (uint256);
    /// @notice Returns the allowance from owner to spender
    function allowance(address owner, address spender) external view returns (uint256);
    /// @notice Returns the minimum transaction amount
    function minAmount() external view returns (uint256);
    /// @notice Returns the maximum transaction amount
    function maxAmount() external view returns (uint256);
    /// @notice Returns whether the contract is paused
    function paused() external view returns (bool);
    /// @notice Returns the CCIP admin address
    function ccipAdmin() external view returns (address);
    /// @notice Returns the CCIP admin address (legacy getter)
    function getCCIPAdmin() external view returns (address);

    // =========================
    //        ERC20
    // =========================
    /// @notice Transfers tokens to a recipient
    function transfer(address recipient, uint256 amount) external returns (bool);
    /// @notice Approves a spender
    function approve(address spender, uint256 amount) external returns (bool);
    /// @notice Transfers tokens from sender to recipient
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    // =========================
    //        MINT/BURN
    // =========================
    /// @notice Mints tokens to an account
    function mint(address account, uint256 amount) external;
    /// @notice Burns tokens from the caller
    function burn(uint256 amount) external;
    /// @notice Burns tokens from an account
    function burn(address account, uint256 amount) external;
    /// @notice Burns tokens from an account (with approval)
    function burnFrom(address account, uint256 amount) external;

    // =========================
    //        ADMIN
    // =========================
    /// @notice Transfers CCIP admin role to a new address
    function transferCCIPAdmin(address newAdmin) external;
    /// @notice Pauses the contract
    function pause() external;
    /// @notice Unpauses the contract
    function unpause() external;
}
