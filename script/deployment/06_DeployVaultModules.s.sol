// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { BatchModule } from "src/kStakingVault/modules/BatchModule.sol";
import { ClaimModule } from "src/kStakingVault/modules/ClaimModule.sol";
import { FeesModule } from "src/kStakingVault/modules/FeesModule.sol";

contract DeployVaultModulesScript is Script, DeploymentManager {
    function run() public {
        NetworkConfig memory config = readNetworkConfig();

        console.log("=== DEPLOYING VAULT MODULES ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        // Deploy modules (these are facet implementations, no proxy needed)
        BatchModule batchModule = new BatchModule();
        ClaimModule claimModule = new ClaimModule();
        FeesModule feesModule = new FeesModule();

        vm.stopBroadcast();

        // Write addresses to deployment JSON
        writeContractAddress("batchModule", address(batchModule));
        writeContractAddress("claimModule", address(claimModule));
        writeContractAddress("feesModule", address(feesModule));

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("BatchModule:", address(batchModule));
        console.log("ClaimModule:", address(claimModule));
        console.log("FeesModule:", address(feesModule));
        console.log("Addresses saved to deployments/output/", config.network, "/addresses.json");
    }
}
