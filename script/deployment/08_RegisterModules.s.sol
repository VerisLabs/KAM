// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";

import { console } from "forge-std/console.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { BatchModule } from "src/kStakingVault/modules/BatchModule.sol";
import { ClaimModule } from "src/kStakingVault/modules/ClaimModule.sol";
import { FeesModule } from "src/kStakingVault/modules/FeesModule.sol";

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
            existing.contracts.batchModule != address(0), "batchModule not deployed - run 06_DeployVaultModules first"
        );
        require(
            existing.contracts.claimModule != address(0), "claimModule not deployed - run 06_DeployVaultModules first"
        );
        require(
            existing.contracts.feesModule != address(0), "feesModule not deployed - run 06_DeployVaultModules first"
        );

        console.log("=== MODULE REGISTRATION ===");
        console.log("Network:", config.network);
        console.log("");

        console.log("Execute these calls via Defender Admin UI:");
        console.log("");

        console.log("1. Get module selectors:");
        console.log("BatchModule address:", existing.contracts.batchModule);
        console.log("ClaimModule address:", existing.contracts.claimModule);
        console.log("FeesModule address:", existing.contracts.feesModule);
        console.log("");

        console.log("2. Vault addresses:");
        console.log("DN Vault:", existing.contracts.dnVault);
        console.log("Alpha Vault:", existing.contracts.alphaVault);
        console.log("Beta Vault:", existing.contracts.betaVault);
        console.log("");

        console.log("3. Registration pattern:");
        console.log("For each vault, call:");
        console.log("  vault.addFunctions(batchSelectors, batchModuleAddr, true)");
        console.log("  vault.addFunctions(claimSelectors, claimModuleAddr, true)");
        console.log("  vault.addFunctions(feesSelectors, feesModuleAddr, true)");
        console.log("");

        console.log("Admin address:", config.roles.admin);
        console.log("=======================================");
        console.log("Note: Execute via Defender Admin UI for security");
    }
}
