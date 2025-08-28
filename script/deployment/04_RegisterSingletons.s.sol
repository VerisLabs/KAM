// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kRegistry } from "src/kRegistry.sol";

contract RegisterSingletonsScript is Script, DeploymentManager {
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

        console.log("=== REGISTRY SINGLETON REGISTRATION ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));

        // Register kAssetRouter as singleton
        registry.setSingletonContract(registry.K_ASSET_ROUTER(), existing.contracts.kAssetRouter);

        // Register kMinter as singleton
        registry.setSingletonContract(registry.K_MINTER(), existing.contracts.kMinter);

        vm.stopBroadcast();

        console.log("=== REGISTRATION COMPLETE ===");
        console.log("Registered kAssetRouter:", existing.contracts.kAssetRouter);
        console.log("Registered kMinter:", existing.contracts.kMinter);
        console.log("Registry address:", existing.contracts.kRegistry);
    }
}
