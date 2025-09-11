// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC1967Factory } from "src/vendor/ERC1967Factory.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";

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

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kStakingVault implementation deployed at:", stakingVaultImpl);
        console.log("DN Vault USDC proxy deployed at:", dnVaultUSDC);
        console.log("DN Vault WBTC proxy deployed at:", dnVaultWBTC);
        console.log("Alpha Vault proxy deployed at:", alphaVault);
        console.log("Beta Vault proxy deployed at:", betaVault);
        console.log("Network:", config.network);

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("kStakingVaultImpl", stakingVaultImpl);
        writeContractAddress("dnVaultUSDC", dnVaultUSDC);
        writeContractAddress("dnVaultWBTC", dnVaultWBTC);
        writeContractAddress("alphaVault", alphaVault);
        writeContractAddress("betaVault", betaVault);
    }

    function _deployDNVaultUSDC() internal returns (address) {
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                false,
                "KAM DN Vault USD",
                "dnkUSD",
                6,
                config.assets.USDC  // Uses USDC as underlying asset
            )
        );
    }

    function _deployDNVaultWBTC() internal returns (address) {
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                false,
                "KAM DN Vault BTC",
                "dnkBTC",
                8,
                config.assets.WBTC  // Uses WBTC as underlying asset
            )
        );
    }

    function _deployAlphaVault() internal returns (address) {
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                false,
                "KAM Alpha Vault USD",
                "akUSD",
                6,
                config.assets.USDC  // Uses USDC as underlying asset
            )
        );
    }

    function _deployBetaVault() internal returns (address) {
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                existing.contracts.kRegistry,
                false,
                "KAM Beta Vault USD",
                "bkUSD",
                6,
                config.assets.USDC  // Uses USDC as underlying asset
            )
        );
    }
}
