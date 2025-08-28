// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";

import { console } from "forge-std/console.sol";
import { kRegistry } from "src/kRegistry.sol";

contract DeployTokensScript is DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));

        console.log("=== KTOKEN DEPLOYMENT ===");
        console.log("Network:", config.network);
        console.log("Execute these calls via Defender Admin UI:");
        console.log("");

        console.log("1. Deploy kUSD:");
        console.log("   address kUSDAddr = registry.registerAsset(");
        console.log("     \"KAM USD\", // name");
        console.log("     \"kUSD\", // symbol");
        console.log("     ", config.assets.USDC, ", // underlying asset");
        console.log("     registry.USDC() // asset type ID");
        console.log("   );");
        console.log("");

        console.log("2. Grant emergency role to kUSD:");
        console.log("   kToken(kUSDAddr).grantEmergencyRole(", config.roles.emergencyAdmin, ");");
        console.log("");

        console.log("3. Deploy kBTC:");
        console.log("   address kBTCAddr = registry.registerAsset(");
        console.log("     \"KAM BTC\", // name");
        console.log("     \"kBTC\", // symbol");
        console.log("     ", config.assets.WBTC, ", // underlying asset");
        console.log("     registry.WBTC() // asset type ID");
        console.log("   );");
        console.log("");

        console.log("4. Grant emergency role to kBTC:");
        console.log("   kToken(kBTCAddr).grantEmergencyRole(", config.roles.emergencyAdmin, ");");
        console.log("");

        console.log("Admin address:", config.roles.admin);
        console.log("EmergencyAdmin address:", config.roles.emergencyAdmin);
        console.log("Registry address:", existing.contracts.kRegistry);
        console.log("=======================================");
        console.log("Note: After deployment, manually add addresses to JSON:");
        console.log("  writeContractAddress(\"kUSD\", kUSDAddr);");
        console.log("  writeContractAddress(\"kBTC\", kBTCAddr);");
    }
}
