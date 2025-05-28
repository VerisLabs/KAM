// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { kUSD } from "../../src/kUSDToken.sol";
import { AddressBook } from "../helpers/AddressBook.sol";
import { Config } from "../helpers/Config.s.sol";
import { RegistryModuleOwnerCustom } from
    "chainlink/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import { Script, console } from "forge-std/Script.sol";

contract ClaimAdminRole is Script {
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

        tokenAdmin = AddressBook.DEPLOYER_ADDRESS;

        // Fetch the network configuration
        Config config = new Config();
        (,,,, address registryModuleOwnerCustom,,,) = config.activeNetworkConfig();

        require(tokenAddress != address(0), "Invalid token address");
        require(registryModuleOwnerCustom != address(0), "Registry module owner custom is not defined for this network");

        vm.startBroadcast();

        kUSD token = kUSD(tokenAddress);
        RegistryModuleOwnerCustom registryContract = RegistryModuleOwnerCustom(registryModuleOwnerCustom);

        require(
            token.getCCIPAdmin() == tokenAdmin, "CCIP admin of token does not match the token admin address provided."
        );

        registryContract.registerAdminViaGetCCIPAdmin(tokenAddress);
        console.log("Admin claimed successfully for token:", tokenAddress);
        vm.stopBroadcast();
    }
}
