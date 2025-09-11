// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";

import { console } from "forge-std/console.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { ReaderModule } from "src/kStakingVault/modules/ReaderModule.sol";

contract RegisterModulesScript is DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.dnVaultUSDC != address(0), "dnVaultUSDC not deployed - run 07_DeployVaults first");
        require(existing.contracts.dnVaultWBTC != address(0), "dnVaultWBTC not deployed - run 07_DeployVaults first");
        require(existing.contracts.alphaVault != address(0), "alphaVault not deployed - run 07_DeployVaults first");
        require(existing.contracts.betaVault != address(0), "betaVault not deployed - run 07_DeployVaults first");
        require(
            existing.contracts.readerModule != address(0), "readerModule not deployed - run 06_DeployVaultModules first"
        );

        console.log("=== MODULE REGISTRATION ===");
        console.log("Network:", config.network);
        console.log("");

        // Get the ReaderModule selectors using the selectors() function
        ReaderModule readerModule = ReaderModule(existing.contracts.readerModule);
        bytes4[] memory readerSelectors = readerModule.selectors();

        vm.startBroadcast();

        // Register ReaderModule to DN Vault USDC
        kStakingVault dnVaultUSDC = kStakingVault(payable(existing.contracts.dnVaultUSDC));
        dnVaultUSDC.addFunctions(readerSelectors, existing.contracts.readerModule, true);
        console.log("Registered ReaderModule to DN Vault USDC");

        // Register ReaderModule to DN Vault WBTC
        kStakingVault dnVaultWBTC = kStakingVault(payable(existing.contracts.dnVaultWBTC));
        dnVaultWBTC.addFunctions(readerSelectors, existing.contracts.readerModule, true);
        console.log("Registered ReaderModule to DN Vault WBTC");

        // Register ReaderModule to Alpha Vault
        kStakingVault alphaVault = kStakingVault(payable(existing.contracts.alphaVault));
        alphaVault.addFunctions(readerSelectors, existing.contracts.readerModule, true);
        console.log("Registered ReaderModule to Alpha Vault");

        // Register ReaderModule to Beta Vault
        kStakingVault betaVault = kStakingVault(payable(existing.contracts.betaVault));
        betaVault.addFunctions(readerSelectors, existing.contracts.readerModule, true);
        console.log("Registered ReaderModule to Beta Vault");

        vm.stopBroadcast();

        console.log("");
        console.log("=======================================");
        console.log("Module registration complete!");
        console.log("ReaderModule registered to all vaults:");
        console.log("  - DN Vault USDC:", existing.contracts.dnVaultUSDC);
        console.log("  - DN Vault WBTC:", existing.contracts.dnVaultWBTC);
        console.log("  - Alpha Vault:", existing.contracts.alphaVault);
        console.log("  - Beta Vault:", existing.contracts.betaVault);
    }
}
