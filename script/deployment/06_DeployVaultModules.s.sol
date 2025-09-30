// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { ReaderModule } from "kam/src/kStakingVault/modules/ReaderModule.sol";

contract DeployVaultModulesScript is Script, DeploymentManager {
    function run() public {
        NetworkConfig memory config = readNetworkConfig();

        console.log("=== DEPLOYING VAULT MODULES ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        // Deploy modules (these are facet implementations, no proxy needed)
        ReaderModule readerModule = new ReaderModule();

        vm.stopBroadcast();

        // Write addresses to deployment JSON
        writeContractAddress("readerModule", address(readerModule));

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("ReaderModule:", address(readerModule));
        console.log("Addresses saved to deployments/output/", config.network, "/addresses.json");
    }
}
