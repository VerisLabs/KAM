// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kRegistry } from "kam/src/kRegistry/kRegistry.sol";
import { kToken } from "kam/src/kToken.sol";

contract DeployTokensScript is Script, DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");
        require(existing.contracts.kMinter != address(0), "kMinter not deployed - run 02_DeployMinter first");
        require(
            existing.contracts.kAssetRouter != address(0), "kAssetRouter not deployed - run 03_DeployAssetRouter first"
        );

        console.log("=== KTOKEN DEPLOYMENT ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));

        // Deploy kUSD using config values
        console.log("Deploying kUSD with config:");
        console.log("  Name:", config.kUSD.name);
        console.log("  Symbol:", config.kUSD.symbol);
        console.log("  Decimals:", config.kUSD.decimals);
        console.log("  Max Mint Per Batch:", config.kUSD.maxMintPerBatch);
        console.log("  Max Redeem Per Batch:", config.kUSD.maxRedeemPerBatch);

        address kUSDAddress = registry.registerAsset(
            config.kUSD.name,
            config.kUSD.symbol,
            config.assets.USDC,
            registry.USDC(),
            config.kUSD.maxMintPerBatch,
            config.kUSD.maxRedeemPerBatch
        );

        // Grant emergency role to kUSD
        kToken(payable(kUSDAddress)).grantEmergencyRole(config.roles.emergencyAdmin);

        // Deploy kBTC using config values
        console.log("Deploying kBTC with config:");
        console.log("  Name:", config.kBTC.name);
        console.log("  Symbol:", config.kBTC.symbol);
        console.log("  Decimals:", config.kBTC.decimals);
        console.log("  Max Mint Per Batch:", config.kBTC.maxMintPerBatch);
        console.log("  Max Redeem Per Batch:", config.kBTC.maxRedeemPerBatch);

        address kBTCAddress = registry.registerAsset(
            config.kBTC.name,
            config.kBTC.symbol,
            config.assets.WBTC,
            registry.WBTC(),
            config.kBTC.maxMintPerBatch,
            config.kBTC.maxRedeemPerBatch
        );

        // Grant emergency role to kBTC
        kToken(payable(kBTCAddress)).grantEmergencyRole(config.roles.emergencyAdmin);

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kUSD deployed at:", kUSDAddress);
        console.log("kBTC deployed at:", kBTCAddress);
        console.log("Admin address:", config.roles.admin);
        console.log("EmergencyAdmin address:", config.roles.emergencyAdmin);
        console.log("Registry address:", existing.contracts.kRegistry);

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("kUSD", kUSDAddress);
        writeContractAddress("kBTC", kBTCAddress);
    }
}