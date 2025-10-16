// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kStakingVault } from "kam/src/kStakingVault/kStakingVault.sol";
import { kRegistry } from "kam/src/kRegistry/kRegistry.sol";

contract DeployVaultsScript is Script, DeploymentManager {
    ERC1967Factory factory;
    address stakingVaultImpl;
    NetworkConfig config;
    DeploymentOutput existing;

    function run() public {
        // Read network configuration and existing deployments
        config = readNetworkConfig();
        existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(
            existing.contracts.ERC1967Factory != address(0), "ERC1967Factory not deployed - run 01_DeployRegistry first"
        );
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");
        require(
            existing.contracts.readerModule != address(0), "readerModule not deployed - run 06_DeployVaultModules first"
        );
        require(existing.contracts.kUSD != address(0), "kUSD not deployed - run 05_DeployTokens first");
        require(existing.contracts.kBTC != address(0), "kBTC not deployed - run 05_DeployTokens first");

        console.log("=== DEPLOYING VAULTS ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        // Get factory reference and deploy implementation
        factory = ERC1967Factory(existing.contracts.ERC1967Factory);
        stakingVaultImpl = address(new kStakingVault());

        // Deploy vaults
        address dnVaultUSDC = _deployDNVaultUSDC();
        address dnVaultWBTC = _deployDNVaultWBTC();
        address alphaVault = _deployAlphaVault();
        address betaVault = _deployBetaVault();

        console.log("");
        console.log("=== SETTING BATCH LIMITS IN REGISTRY ===");

        // Get registry reference
        kRegistry registry = kRegistry(payable(existing.contracts.kRegistry));

        // Set batch limits for DN Vault USDC
        console.log("Setting batch limits for DN Vault USDC:");
        console.log("  Max Deposit:", config.dnVaultUSDC.maxDepositPerBatch);
        console.log("  Max Withdraw:", config.dnVaultUSDC.maxWithdrawPerBatch);
        registry.setAssetBatchLimits(
            dnVaultUSDC, // vault as token
            config.dnVaultUSDC.maxDepositPerBatch,
            config.dnVaultUSDC.maxWithdrawPerBatch
        );

        // Set batch limits for DN Vault WBTC
        console.log("Setting batch limits for DN Vault WBTC:");
        console.log("  Max Deposit:", config.dnVaultWBTC.maxDepositPerBatch);
        console.log("  Max Withdraw:", config.dnVaultWBTC.maxWithdrawPerBatch);
        registry.setAssetBatchLimits(
            dnVaultWBTC, // vault as token
            config.dnVaultWBTC.maxDepositPerBatch,
            config.dnVaultWBTC.maxWithdrawPerBatch
        );

        // Set batch limits for Alpha Vault
        console.log("Setting batch limits for Alpha Vault:");
        console.log("  Max Deposit:", config.alphaVault.maxDepositPerBatch);
        console.log("  Max Withdraw:", config.alphaVault.maxWithdrawPerBatch);
        registry.setAssetBatchLimits(
            alphaVault, // vault as token
            config.alphaVault.maxDepositPerBatch,
            config.alphaVault.maxWithdrawPerBatch
        );

        // Set batch limits for Beta Vault
        console.log("Setting batch limits for Beta Vault:");
        console.log("  Max Deposit:", config.betaVault.maxDepositPerBatch);
        console.log("  Max Withdraw:", config.betaVault.maxWithdrawPerBatch);
        registry.setAssetBatchLimits(
            betaVault, // vault as token
            config.betaVault.maxDepositPerBatch,
            config.betaVault.maxWithdrawPerBatch
        );

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kStakingVault implementation deployed at:", stakingVaultImpl);
        console.log("DN Vault USDC proxy deployed at:", dnVaultUSDC);
        console.log("DN Vault WBTC proxy deployed at:", dnVaultWBTC);
        console.log("Alpha Vault proxy deployed at:", alphaVault);
        console.log("Beta Vault proxy deployed at:", betaVault);
        console.log("Network:", config.network);
        console.log("");
        console.log("Batch limits configured in registry for all vaults");

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("kStakingVaultImpl", stakingVaultImpl);
        writeContractAddress("dnVaultUSDC", dnVaultUSDC);
        writeContractAddress("dnVaultWBTC", dnVaultWBTC);
        writeContractAddress("alphaVault", alphaVault);
        writeContractAddress("betaVault", betaVault);
    }

    function _deployDNVaultUSDC() internal returns (address) {
        console.log("Deploying DN Vault USDC:");
        console.log("  Name:", config.dnVaultUSDC.name);
        console.log("  Symbol:", config.dnVaultUSDC.symbol);
        console.log("  Max Total Assets:", config.dnVaultUSDC.maxTotalAssets);
        
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                config.dnVaultUSDC.useKToken,
                config.dnVaultUSDC.name,
                config.dnVaultUSDC.symbol,
                config.dnVaultUSDC.decimals,
                config.assets.USDC, // Uses USDC as underlying asset
                config.dnVaultUSDC.maxTotalAssets
            )
        );
    }

    function _deployDNVaultWBTC() internal returns (address) {
        console.log("Deploying DN Vault WBTC:");
        console.log("  Name:", config.dnVaultWBTC.name);
        console.log("  Symbol:", config.dnVaultWBTC.symbol);
        console.log("  Max Total Assets:", config.dnVaultWBTC.maxTotalAssets);
        
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                config.dnVaultWBTC.useKToken,
                config.dnVaultWBTC.name,
                config.dnVaultWBTC.symbol,
                config.dnVaultWBTC.decimals,
                config.assets.WBTC, // Uses WBTC as underlying asset
                config.dnVaultWBTC.maxTotalAssets
            )
        );
    }

    function _deployAlphaVault() internal returns (address) {
        console.log("Deploying Alpha Vault:");
        console.log("  Name:", config.alphaVault.name);
        console.log("  Symbol:", config.alphaVault.symbol);
        console.log("  Max Total Assets:", config.alphaVault.maxTotalAssets);
        
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                config.alphaVault.useKToken,
                config.alphaVault.name,
                config.alphaVault.symbol,
                config.alphaVault.decimals,
                config.assets.USDC, // Uses USDC as underlying asset
                config.alphaVault.maxTotalAssets
            )
        );
    }

    function _deployBetaVault() internal returns (address) {
        console.log("Deploying Beta Vault:");
        console.log("  Name:", config.betaVault.name);
        console.log("  Symbol:", config.betaVault.symbol);
        console.log("  Max Total Assets:", config.betaVault.maxTotalAssets);
        
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                config.betaVault.useKToken,
                config.betaVault.name,
                config.betaVault.symbol,
                config.betaVault.decimals,
                config.assets.USDC, // Uses USDC as underlying asset
                config.betaVault.maxTotalAssets
            )
        );
    }
}