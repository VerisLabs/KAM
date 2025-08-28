// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";

import { console } from "forge-std/console.sol";
import { CustodialAdapter } from "src/adapters/CustodialAdapter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { kRegistry } from "src/kRegistry.sol";
import { kToken } from "src/kToken.sol";

contract ConfigureProtocolScript is DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate critical contracts are deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed");
        require(existing.contracts.kMinter != address(0), "kMinter not deployed");
        require(existing.contracts.kAssetRouter != address(0), "kAssetRouter not deployed");
        require(existing.contracts.dnVault != address(0), "dnVault not deployed");
        require(existing.contracts.alphaVault != address(0), "alphaVault not deployed");
        require(existing.contracts.betaVault != address(0), "betaVault not deployed");
        require(existing.contracts.custodialAdapter != address(0), "custodialAdapter not deployed");

        console.log("=== PROTOCOL CONFIGURATION ===");
        console.log("Network:", config.network);
        console.log("");

        console.log("Execute these calls via Defender Admin UI:");
        console.log("");

        console.log("1. Contract addresses:");
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Minter:", existing.contracts.kMinter);
        console.log("AssetRouter:", existing.contracts.kAssetRouter);
        console.log("DN Vault:", existing.contracts.dnVault);
        console.log("Alpha Vault:", existing.contracts.alphaVault);
        console.log("Beta Vault:", existing.contracts.betaVault);
        console.log("CustodialAdapter:", existing.contracts.custodialAdapter);
        console.log("");

        console.log("2. Asset addresses:");
        console.log("USDC:", config.assets.USDC);
        console.log("WBTC:", config.assets.WBTC);
        console.log("");

        console.log("3. Role addresses:");
        console.log("Admin:", config.roles.admin);
        console.log("Institution:", config.roles.institution);
        console.log("Treasury:", config.roles.treasury);
        console.log("Relayer:", config.roles.relayer);
        console.log("");

        console.log("4. Configuration steps:");
        console.log("a) Register vaults with registry:");
        console.log("   - Call registerVault() for MINTER, DN, ALPHA, BETA types");
        console.log("b) Register adapter with all vaults:");
        console.log("   - Call registerAdapter() for each vault");
        console.log("c) Configure adapter destinations:");
        console.log("   - Call setVaultDestination() for each vault");
        console.log("d) Grant MINTER_ROLE to kMinter and kAssetRouter (if kTokens exist)");
        console.log("e) Grant INSTITUTION_ROLE to institution address");
        console.log("f) Create initial batches via relayer (optional)");
        console.log("");

        if (existing.contracts.kUSD != address(0)) {
            console.log("kUSD deployed at:", existing.contracts.kUSD);
        }
        if (existing.contracts.kBTC != address(0)) {
            console.log("kBTC deployed at:", existing.contracts.kBTC);
        }

        console.log("=======================================");
        console.log("Protocol deployment complete!");
        console.log("Use Defender Admin UI for secure configuration");
    }
}
