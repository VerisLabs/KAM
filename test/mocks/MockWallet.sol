// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";

/// @title MockWallet
/// @notice Mock wallet contract for testing asset transfers
contract MockWallet {
    using SafeTransferLib for address;

    string public name;

    constructor(string memory name_) {
        name = name_;
    }

    /// @notice Transfer tokens from this wallet to a recipient
    /// @param token The token address to transfer
    /// @param to The recipient address
    /// @param amount The amount to transfer
    function transfer(address token, address to, uint256 amount) external {
        token.safeTransfer(to, amount);
    }

    /// @notice Receive ETH
    receive() external payable { }

    /// @notice Get balance of a token in this wallet
    /// @param token The token address
    /// @return The balance of the token
    function getBalance(address token) external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}
