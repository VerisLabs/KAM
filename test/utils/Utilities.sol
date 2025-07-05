// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { StdCheats } from "forge-std/StdCheats.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract Utilities is StdCheats {
    address constant HEVM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    /// @dev Generates an address by hashing the name, labels the address and funds it with test assets
    function createUser(string memory name, address[] memory tokens) external returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.deal({ account: addr, newBalance: 1000 ether });
        for (uint256 i; i < tokens.length;) {
            deal({ token: tokens[i], to: addr, give: 2000 * 10 ** _getDecimals(tokens[i]) });
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Creates a simple user with ETH balance only
    function createUser(string memory name) external returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.deal({ account: addr, newBalance: 1000 ether });
    }

    /// @dev Moves block.number forward by a given number of blocks
    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }

    /// @dev Moves block.timestamp forward by a given number of seconds
    function mineTime(uint256 numSeconds) external {
        uint256 targetTime = block.timestamp + numSeconds;
        vm.warp(targetTime);
    }

    /// @dev Helper to get token decimals
    function _getDecimals(address token) internal view returns (uint8) {
        try this.getDecimals(token) returns (uint8 decimals) {
            return decimals;
        } catch {
            return 18; // Default to 18 decimals
        }
    }

    /// @dev External function to get decimals (for try/catch)
    function getDecimals(address token) external view returns (uint8) {
        // Try to call decimals() on the token
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }
        return 18;
    }

    /// @dev Helper to mint tokens to an address using deal
    function mintTokens(address token, address to, uint256 amount) external {
        deal(token, to, amount);
    }

    /// @dev Helper to approve tokens
    function approveTokens(address user, address token, address spender, uint256 amount) external {
        vm.prank(user);
        IERC20(token).approve(spender, amount);
    }

    /// @dev Helper to transfer tokens
    function transferTokens(address user, address token, address to, uint256 amount) external {
        vm.prank(user);
        IERC20(token).transfer(to, amount);
    }
}
