// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { StdCheats } from "forge-std/StdCheats.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract Utilities is StdCheats {
    address constant HEVM_ADDRESS = address(bytes20(uint160(uint256(keccak256("hevm cheat code")))));
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    function createUser(string memory name, address[] memory tokens) external returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.deal({ account: addr, newBalance: 1000 ether });
        for (uint256 i; i < tokens.length;) {
            deal({ token: tokens[i], to: addr, give: 500_000_000 * 10 ** _getDecimals(tokens[i]) });
            unchecked {
                ++i;
            }
        }
    }

    function createUser(string memory name) external returns (address payable addr) {
        addr = payable(makeAddr(name));
        vm.deal({ account: addr, newBalance: 1000 ether });
    }

    function mineBlocks(uint256 numBlocks) external {
        uint256 targetBlock = block.number + numBlocks;
        vm.roll(targetBlock);
    }

    function mineTime(uint256 numSeconds) external {
        uint256 targetTime = block.timestamp + numSeconds;
        vm.warp(targetTime);
    }

    function _getDecimals(address token) internal view returns (uint8) {
        try this.getDecimals(token) returns (uint8 decimals) {
            return decimals;
        } catch {
            return 18; // Default to 18 decimals
        }
    }

    function getDecimals(address token) external view returns (uint8) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        if (success && data.length >= 32) {
            return abi.decode(data, (uint8));
        }
        return 18;
    }

    function mintTokens(address token, address to, uint256 amount) external {
        deal(token, to, amount);
    }

    function approveTokens(address user, address token, address spender, uint256 amount) external {
        vm.prank(user);
        IERC20(token).approve(spender, amount);
    }

    function transferTokens(address user, address token, address to, uint256 amount) external {
        vm.prank(user);
        IERC20(token).transfer(to, amount);
    }
}
