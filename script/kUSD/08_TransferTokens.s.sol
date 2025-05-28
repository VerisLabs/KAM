// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AddressBook } from "../helpers/AddressBook.sol";
import { Config } from "../helpers/Config.s.sol";
import { IRouterClient } from "chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import { Client } from "chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import { IERC20 } from
    "chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import { Script, console } from "forge-std/Script.sol";

contract TransferTokens is Script {
    enum Fee {
        Native,
        Link
    }

    address tokenAddress;
    uint64 destinationChainSelector;

    function run() external {

        if (block.chainid == AddressBook.OPTIMISM) {
            tokenAddress = AddressBook.OP_KUSD;
            destinationChainSelector = AddressBook.BASE_CHAIN_SELECTOR;
        } else if (block.chainid == AddressBook.BASE) {
            tokenAddress = AddressBook.BASE_KUSD;
            destinationChainSelector = AddressBook.OP_CHAIN_SELECTOR;
        } else {
            revert("Unsupported chain ID");
        }

        // Read the amount to transfer and feeType from config.json
        uint256 amount = 30_000_000;

        // Fetch the network configuration for the current chain
        Config helperConfig = new Config();
        (, address router,,,,,,) = helperConfig.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Invalid amount to transfer");
        require(destinationChainSelector != 0, "Chain selector not defined for the destination chain");

        address feeTokenAddress = address(0); // Use native token (e.g., ETH, AVAX)

        vm.startBroadcast();

        // Connect to the CCIP router contract
        IRouterClient routerContract = IRouterClient(router);

        // Check if the destination chain is supported by the router
        require(routerContract.isChainSupported(destinationChainSelector), "Destination chain not supported");

        // Prepare the CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(AddressBook.DEPLOYER_ADDRESS), // Receiver address on the destination chain
            data: abi.encode(), // No additional data
            tokenAmounts: new Client.EVMTokenAmount[](1), // Array of tokens to transfer
            feeToken: feeTokenAddress, // Fee token (native or LINK)
            extraArgs: abi.encodePacked(
                bytes4(keccak256("CCIP EVMExtraArgsV1")), // Extra arguments for CCIP (versioned)
                abi.encode(uint256(0)) // Placeholder for future use
            )
        });

        // Set the token and amount to transfer
        message.tokenAmounts[0] = Client.EVMTokenAmount({ token: tokenAddress, amount: amount });

        // Approve the router to transfer tokens on behalf of the sender
        IERC20(tokenAddress).approve(router, amount);

        // Estimate the fees required for the transfer
        uint256 fees = routerContract.getFee(destinationChainSelector, message);
        console.log("Estimated fees:", fees);

        // Send the CCIP message and handle fee payment
        bytes32 messageId;
        if (feeTokenAddress == address(0)) {
            // Pay fees with native token
            messageId = routerContract.ccipSend{ value: fees }(destinationChainSelector, message);
        } else {
            // Approve the router to spend LINK tokens for fees
            IERC20(feeTokenAddress).approve(router, fees);
            messageId = routerContract.ccipSend(destinationChainSelector, message);
        }

        // Log the Message ID
        console.log("Message ID:");
        console.logBytes32(messageId);

        // Provide a URL to check the status of the message
        string memory messageUrl = string(
            abi.encodePacked(
                "Check status of the message at https://ccip.chain.link/msg/",
                helperConfig.bytes32ToHexString(messageId)
            )
        );
        console.log(messageUrl);

        vm.stopBroadcast();
    }
}