// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";

import { console } from "forge-std/console.sol";
import { kRegistry } from "src/kRegistry.sol";

contract RegisterSingletonsScript is DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");
        require(
            existing.contracts.kAssetRouter != address(0), "kAssetRouter not deployed - run 03_DeployAssetRouter first"
        );
        require(existing.contracts.kMinter != address(0), "kMinter not deployed - run 02_DeployMinter first");

        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));

        console.log("=== REGISTRY SINGLETON REGISTRATION ===");
        console.log("Network:", config.network);
        console.log("Execute these calls via Defender Admin UI:");
        console.log("");
        console.log("1. registry.setSingletonContract(");
        console.log("     registry.K_ASSET_ROUTER(), // Contract ID");
        console.log("     ", existing.contracts.kAssetRouter, " // kAssetRouter address");
        console.log("   );");
        console.log("");
        console.log("2. registry.setSingletonContract(");
        console.log("     registry.K_MINTER(), // Contract ID");
        console.log("     ", existing.contracts.kMinter, " // kMinter address");
        console.log("   );");
        console.log("");
        console.log("Admin address:", config.roles.admin);
        console.log("Registry address:", existing.contracts.kRegistry);
        console.log("=======================================");
        console.log("Note: Execute via Defender Admin UI for security");
    }
}
