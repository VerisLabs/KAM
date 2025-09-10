// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";

import { console } from "forge-std/console.sol";
import { VaultAdapter } from "src/adapters/VaultAdapter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { kRegistry } from "src/kRegistry/kRegistry.sol";
import { kToken } from "src/kToken.sol";

contract ConfigureProtocolScript is Script, DeploymentManager {
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
        require(existing.contracts.vaultAdapter != address(0), "vaultAdapter not deployed");

        console.log("=== EXECUTING PROTOCOL CONFIGURATION ===");
        console.log("Network:", config.network);
        console.log("");

        vm.startBroadcast();

        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));
        VaultAdapter vaultAdapter = VaultAdapter(existing.contracts.vaultAdapter);

        console.log("1. Registering vaults with kRegistry...");

        // Register kMinter as MINTER vault type
        registry.registerVault(existing.contracts.kMinter, IkRegistry.VaultType.MINTER, config.assets.USDC);
        console.log("   - Registered kMinter as MINTER vault");

        // Register DN Vault as DN vault type
        registry.registerVault(existing.contracts.dnVault, IkRegistry.VaultType.DN, config.assets.USDC);
        console.log("   - Registered DN Vault as DN vault");

        // Register Alpha Vault as ALPHA vault type
        registry.registerVault(existing.contracts.alphaVault, IkRegistry.VaultType.ALPHA, config.assets.USDC);
        console.log("   - Registered Alpha Vault as ALPHA vault");

        // Register Beta Vault as BETA vault type
        registry.registerVault(existing.contracts.betaVault, IkRegistry.VaultType.BETA, config.assets.USDC);
        console.log("   - Registered Beta Vault as BETA vault");

        console.log("");
        console.log("2. Registering adapters with vaults...");

        // Register custodial adapter for each vault
        registry.registerAdapter(existing.contracts.kMinter, existing.contracts.vaultAdapter);
        registry.registerAdapter(existing.contracts.dnVault, existing.contracts.vaultAdapter);
        registry.registerAdapter(existing.contracts.alphaVault, existing.contracts.vaultAdapter);
        registry.registerAdapter(existing.contracts.betaVault, existing.contracts.vaultAdapter);
        console.log("   - Registered custodial adapter for all vaults");

        console.log("");
        console.log("3. Granting roles...");

        // Grant MINTER_ROLE to kMinter and kAssetRouter on kTokens (if they exist)
        if (existing.contracts.kUSD != address(0)) {
            kToken kUSD = kToken(payable(existing.contracts.kUSD));
            kUSD.grantMinterRole(existing.contracts.kMinter);
            kUSD.grantMinterRole(existing.contracts.kAssetRouter);
            console.log("   - Granted MINTER_ROLE on kUSD to kMinter and kAssetRouter");
        }

        if (existing.contracts.kBTC != address(0)) {
            kToken kBTC = kToken(payable(existing.contracts.kBTC));
            kBTC.grantMinterRole(existing.contracts.kMinter);
            kBTC.grantMinterRole(existing.contracts.kAssetRouter);
            console.log("   - Granted MINTER_ROLE on kBTC to kMinter and kAssetRouter");
        }

        // Grant INSTITUTION_ROLE to institution address
        registry.grantInstitutionRole(config.roles.institution);
        console.log("   - Granted INSTITUTION_ROLE to institution address");

        vm.stopBroadcast();

        console.log("");
        console.log("=======================================");
        console.log("Protocol configuration complete!");
        console.log("All vaults registered in kRegistry:");
        console.log("   - kMinter:", existing.contracts.kMinter);
        console.log("   - DN Vault:", existing.contracts.dnVault);
        console.log("   - Alpha Vault:", existing.contracts.alphaVault);
        console.log("   - Beta Vault:", existing.contracts.betaVault);
    }
}
