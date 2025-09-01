// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

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

        console.log("=== DEPLOYING VAULTS ===");
        console.log("Network:", config.network);

        vm.startBroadcast();

        // Get factory reference and deploy implementation
        factory = ERC1967Factory(existing.contracts.ERC1967Factory);
        stakingVaultImpl = address(new kStakingVault());

        // Deploy vaults
        address dnVault = _deployDNVault();
        address alphaVault = _deployAlphaVault();
        address betaVault = _deployBetaVault();

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kStakingVault implementation deployed at:", stakingVaultImpl);
        console.log("DN Vault proxy deployed at:", dnVault);
        console.log("Alpha Vault proxy deployed at:", alphaVault);
        console.log("Beta Vault proxy deployed at:", betaVault);
        console.log("Network:", config.network);

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("kStakingVaultImpl", stakingVaultImpl);
        writeContractAddress("dnVault", dnVault);
        writeContractAddress("alphaVault", alphaVault);
        writeContractAddress("betaVault", betaVault);
    }

    function _deployDNVault() internal returns (address) {
        uint128 DEFAULT_DUST_AMOUNT = 1000;
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                config.roles.admin,
                existing.contracts.kRegistry,
                false,
                "DN KAM Vault",
                "dnkUSD",
                6,
                DEFAULT_DUST_AMOUNT,
                config.assets.USDC
            )
        );
    }

    function _deployAlphaVault() internal returns (address) {
        uint128 DEFAULT_DUST_AMOUNT = 1000;
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                config.roles.admin,
                existing.contracts.kRegistry,
                false,
                "Alpha KAM Vault",
                "akUSD",
                6,
                DEFAULT_DUST_AMOUNT,
                config.assets.USDC
            )
        );
    }

    function _deployBetaVault() internal returns (address) {
        uint128 DEFAULT_DUST_AMOUNT = 1000;
        return factory.deployAndCall(
            stakingVaultImpl,
            msg.sender,
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner,
                config.roles.admin,
                existing.contracts.kRegistry,
                false,
                "Beta KAM Vault",
                "bkUSD",
                6,
                DEFAULT_DUST_AMOUNT,
                config.assets.USDC
            )
        );
    }
}
