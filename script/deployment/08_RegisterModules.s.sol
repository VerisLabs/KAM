// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";

import { console } from "forge-std/console.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { ReaderModule } from "src/kStakingVault/modules/ReaderModule.sol";

contract RegisterModulesScript is DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.dnVault != address(0), "dnVault not deployed - run 07_DeployVaults first");
        require(existing.contracts.alphaVault != address(0), "alphaVault not deployed - run 07_DeployVaults first");
        require(existing.contracts.betaVault != address(0), "betaVault not deployed - run 07_DeployVaults first");
        require(
            existing.contracts.readerModule != address(0), "readerModule not deployed - run 06_DeployVaultModules first"
        );

        console.log("=== MODULE REGISTRATION ===");
        console.log("Network:", config.network);
        console.log("");

        console.log("Execute these admin calls:");
        console.log("");

        console.log("1. Get module selectors:");
        console.log("readerModule address:", existing.contracts.readerModule);
        console.log("");

        console.log("2. Vault addresses:");
        console.log("DN Vault:", existing.contracts.dnVault);
        console.log("Alpha Vault:", existing.contracts.alphaVault);
        console.log("Beta Vault:", existing.contracts.betaVault);
        console.log("");

        console.log("3. Registration pattern:");
        console.log("For each vault, call:");
        console.log("  vault.addFunctions(readerSelectors, readerModuleAddr, true)");
        console.log("");

        console.log("Admin address:", config.roles.admin);
        console.log("=======================================");
        console.log("Note: Execute via admin account for security");
    }
}
