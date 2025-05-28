// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AddressBook } from "../helpers/AddressBook.sol";
import { BurnMintERC677 } from "chainlink/contracts/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";
import { Script, console } from "forge-std/Script.sol";

contract MintTokens is Script {
    address tokenAddress;

    function run() external {

        if (block.chainid == AddressBook.OPTIMISM) {
            tokenAddress = AddressBook.OP_KUSD;
        } else if (block.chainid == AddressBook.BASE) {
            tokenAddress = AddressBook.BASE_KUSD;
        } else {
            revert("Unsupported chain ID");
        }

        uint256 amount = 1_000_000_000;
        // Use the sender's address as the receiver of the minted tokens
        address receiverAddress = AddressBook.DEPLOYER_ADDRESS;

        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Invalid amount to mint");

        vm.startBroadcast();

        // Instantiate the token contract at the retrieved address
        BurnMintERC677 tokenContract = BurnMintERC677(tokenAddress);

        // Mint the specified amount of tokens to the receiver address
        console.log("Minting", amount, "tokens to", receiverAddress);
        tokenContract.mint(receiverAddress, amount);

        console.log("Waiting for confirmations...");

        vm.stopBroadcast();

        console.log("Minted", amount, "tokens to", receiverAddress);
        console.log("Current balance of receiver is", tokenContract.balanceOf(receiverAddress), tokenContract.symbol());
    }
}