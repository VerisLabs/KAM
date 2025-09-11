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
        validateProtocolDeployments(existing);

        console.log("=== EXECUTING PROTOCOL CONFIGURATION ===");
        console.log("Network:", config.network);
        console.log("");

        vm.startBroadcast();

        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));

        console.log("1. Registering vaults with kRegistry...");

        // Register kMinter as MINTER vault type for both assets
        registry.registerVault(existing.contracts.kMinter, IkRegistry.VaultType.MINTER, config.assets.USDC);
        console.log("   - Registered kMinter as MINTER vault for USDC");
        registry.registerVault(existing.contracts.kMinter, IkRegistry.VaultType.MINTER, config.assets.WBTC);
        console.log("   - Registered kMinter as MINTER vault for WBTC");

        // Register DN Vaults
        registry.registerVault(existing.contracts.dnVaultUSDC, IkRegistry.VaultType.DN, config.assets.USDC);
        console.log("   - Registered DN Vault USDC as DN vault for USDC");
        registry.registerVault(existing.contracts.dnVaultWBTC, IkRegistry.VaultType.DN, config.assets.WBTC);
        console.log("   - Registered DN Vault WBTC as DN vault for WBTC");

        // Register Alpha Vault as ALPHA vault type
        registry.registerVault(existing.contracts.alphaVault, IkRegistry.VaultType.ALPHA, config.assets.USDC);
        console.log("   - Registered Alpha Vault as ALPHA vault for USDC");

        // Register Beta Vault as BETA vault type
        registry.registerVault(existing.contracts.betaVault, IkRegistry.VaultType.BETA, config.assets.USDC);
        console.log("   - Registered Beta Vault as BETA vault for USDC");

        console.log("");
        console.log("2. Registering adapters with vaults...");

        // Register adapters for kMinter
        registry.registerAdapter(
            existing.contracts.kMinter, config.assets.USDC, existing.contracts.kMinterAdapterUSDC
        );
        console.log("   - Registered kMinter USDC Adapter for kMinter");
        registry.registerAdapter(
            existing.contracts.kMinter, config.assets.WBTC, existing.contracts.kMinterAdapterWBTC
        );
        console.log("   - Registered kMinter WBTC Adapter for kMinter");

        // Register adapters for DN vaults
        registry.registerAdapter(
            existing.contracts.dnVaultUSDC, config.assets.USDC, existing.contracts.dnVaultAdapterUSDC
        );
        console.log("   - Registered DN Vault USDC Adapter for DN Vault USDC");
        registry.registerAdapter(
            existing.contracts.dnVaultWBTC, config.assets.WBTC, existing.contracts.dnVaultAdapterWBTC
        );
        console.log("   - Registered DN Vault WBTC Adapter for DN Vault WBTC");

        // Register adapters for Alpha and Beta vaults
        registry.registerAdapter(
            existing.contracts.alphaVault, config.assets.USDC, existing.contracts.alphaVaultAdapter
        );
        console.log("   - Registered Alpha Vault Adapter for Alpha Vault");
        registry.registerAdapter(existing.contracts.betaVault, config.assets.USDC, existing.contracts.betaVaultAdapter);
        console.log("   - Registered Beta Vault Adapter for Beta Vault");

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
        console.log("   - DN Vault USDC:", existing.contracts.dnVaultUSDC);
        console.log("   - DN Vault WBTC:", existing.contracts.dnVaultWBTC);
        console.log("   - Alpha Vault:", existing.contracts.alphaVault);
        console.log("   - Beta Vault:", existing.contracts.betaVault);
        console.log("");
        console.log("All adapters registered:");
        console.log("   - kMinter USDC Adapter:", existing.contracts.kMinterAdapterUSDC);
        console.log("   - kMinter WBTC Adapter:", existing.contracts.kMinterAdapterWBTC);
        console.log("   - DN Vault USDC Adapter:", existing.contracts.dnVaultAdapterUSDC);
        console.log("   - DN Vault WBTC Adapter:", existing.contracts.dnVaultAdapterWBTC);
        console.log("   - Alpha Vault Adapter:", existing.contracts.alphaVaultAdapter);
        console.log("   - Beta Vault Adapter:", existing.contracts.betaVaultAdapter);
    }
}
