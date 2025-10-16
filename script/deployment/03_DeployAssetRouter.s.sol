// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kAssetRouter } from "kam/src/kAssetRouter.sol";

contract DeployAssetRouterScript is Script, DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate factory and registry were deployed
        require(
            existing.contracts.ERC1967Factory != address(0), "ERC1967Factory not deployed - run 01_DeployRegistry first"
        );
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        vm.startBroadcast();

        // Get factory reference
        ERC1967Factory factory = ERC1967Factory(existing.contracts.ERC1967Factory);

        // Deploy kAssetRouter implementation
        kAssetRouter assetRouterImpl = new kAssetRouter();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(kAssetRouter.initialize.selector, existing.contracts.kRegistry);

        address assetRouterProxy = factory.deployAndCall(address(assetRouterImpl), msg.sender, initData);

        // Set settlement cooldown from config
        kAssetRouter assetRouter = kAssetRouter(payable(assetRouterProxy));
        assetRouter.setSettlementCooldown(config.assetRouter.settlementCooldown);
        assetRouter.setMaxAllowedDelta(config.assetRouter.maxAllowedDelta);

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kAssetRouter implementation deployed at:", address(assetRouterImpl));
        console.log("kAssetRouter proxy deployed at:", assetRouterProxy);
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Network:", config.network);
        console.log("Settlement cooldown set to:", config.assetRouter.settlementCooldown);

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("kAssetRouterImpl", address(assetRouterImpl));
        writeContractAddress("kAssetRouter", assetRouterProxy);
    }
}