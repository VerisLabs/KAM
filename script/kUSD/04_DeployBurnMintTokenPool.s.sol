// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AddressBook } from "../helpers/AddressBook.sol";
import { Config } from "../helpers/Config.s.sol";
import { BurnMintTokenPool } from "chainlink/contracts/src/v0.8/ccip/pools/BurnMintTokenPool.sol";
import { IBurnMintERC20 } from "chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";
import { BurnMintERC677 } from "chainlink/contracts/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployBurnMintTokenPool is Script {
    address tokenAddress;
    address tokenAdmin;

    function run() external {

        if (block.chainid == AddressBook.OPTIMISM) {
            tokenAddress = AddressBook.OP_KUSD;
        } else if (block.chainid == AddressBook.BASE) {
            tokenAddress = AddressBook.BASE_KUSD;
        } else {
            revert("Unsupported chain ID");
        }

        Config helperConfig = new Config();
        (, address router, address rmnProxy,,,,,) = helperConfig.activeNetworkConfig();

        // Ensure that the token address, router, and RMN proxy are valid
        require(tokenAddress != address(0), "Invalid token address");
        require(router != address(0) && rmnProxy != address(0), "Router or RMN Proxy not defined for this network");

        // Cast the token address to the IBurnMintERC20 interface
        IBurnMintERC20 token = IBurnMintERC20(tokenAddress);

        vm.startBroadcast();

        // Deploy the BurnMintTokenPool contract associated with the token
        BurnMintTokenPool tokenPool = new BurnMintTokenPool(
            token,
            18, // The number of decimals of the token
            new address[](0), // Empty array for initial operators
            rmnProxy,
            router
        );

        console.log("Burn & Mint token pool deployed to:", address(tokenPool));

        // Grant mint and burn roles to the token pool on the token contract
        BurnMintERC677(tokenAddress).grantMintAndBurnRoles(address(tokenPool));
        console.log("Granted mint and burn roles to token pool:", address(tokenPool));

        vm.stopBroadcast();
    }
}