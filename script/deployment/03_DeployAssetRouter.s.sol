// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";

import { console } from "forge-std/console.sol";
import { kAssetRouter } from "src/kAssetRouter.sol";

contract DeployAssetRouterScript is DefenderScript {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate registry was deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        address deployment = _deployWithDefender(
            "kAssetRouter", abi.encodeWithSelector(kAssetRouter.initialize.selector, existing.contracts.kRegistry)
        );

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kAssetRouter deployed at:", deployment);
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Network:", config.network);
        console.log("");
        console.log("TODO: Set settlement cooldown via admin call after deployment:");
        if (keccak256(bytes(config.network)) == keccak256(bytes("localhost"))) {
            console.log("      assetRouter.setSettlementCooldown(0); // Testing");
        } else {
            console.log("      assetRouter.setSettlementCooldown(3600); // 1 hour production");
        }
    }
}
