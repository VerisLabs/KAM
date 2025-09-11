// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC1967Factory } from "src/vendor/ERC1967Factory.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { VaultAdapter } from "src/adapters/VaultAdapter.sol";

contract DeployAdaptersScript is Script, DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(
            existing.contracts.ERC1967Factory != address(0), "ERC1967Factory not deployed - run 01_DeployRegistry first"
        );
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        console.log("=== DEPLOYING ADAPTERS ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        // Get factory reference
        ERC1967Factory factory = ERC1967Factory(existing.contracts.ERC1967Factory);

        // Deploy VaultAdapter implementation (shared by all adapters)
        VaultAdapter vaultAdapterImpl = new VaultAdapter();

        // Deploy DN Vault USDC Adapter
        bytes memory adapterInitData =
            abi.encodeWithSelector(VaultAdapter.initialize.selector, existing.contracts.kRegistry);
        address dnVaultAdapterUSDC = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        // Deploy DN Vault WBTC Adapter
        address dnVaultAdapterWBTC = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        // Deploy Alpha Vault Adapter
        address alphaVaultAdapter = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        // Deploy Beta Vault Adapter
        address betaVaultAdapter = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        // Deploy kMinter USDC Adapter
        address kMinterAdapterUSDC = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        // Deploy kMinter WBTC Adapter
        address kMinterAdapterWBTC = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("VaultAdapter implementation deployed at:", address(vaultAdapterImpl));
        console.log("DN Vault USDC Adapter deployed at:", dnVaultAdapterUSDC);
        console.log("DN Vault WBTC Adapter deployed at:", dnVaultAdapterWBTC);
        console.log("Alpha Vault Adapter deployed at:", alphaVaultAdapter);
        console.log("Beta Vault Adapter deployed at:", betaVaultAdapter);
        console.log("kMinter USDC Adapter deployed at:", kMinterAdapterUSDC);
        console.log("kMinter WBTC Adapter deployed at:", kMinterAdapterWBTC);
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Network:", config.network);
        console.log("");
        console.log("Note: All adapters inherit roles from registry");
        console.log("      Configure adapter permissions in next script");

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("vaultAdapterImpl", address(vaultAdapterImpl));
        writeContractAddress("dnVaultAdapterUSDC", dnVaultAdapterUSDC);
        writeContractAddress("dnVaultAdapterWBTC", dnVaultAdapterWBTC);
        writeContractAddress("alphaVaultAdapter", alphaVaultAdapter);
        writeContractAddress("betaVaultAdapter", betaVaultAdapter);
        writeContractAddress("kMinterAdapterUSDC", kMinterAdapterUSDC);
        writeContractAddress("kMinterAdapterWBTC", kMinterAdapterWBTC);
    }
}
