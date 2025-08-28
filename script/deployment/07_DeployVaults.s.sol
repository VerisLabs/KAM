// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";

import { console } from "forge-std/console.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";

contract DeployVaultsScript is DefenderScript {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");
        require(
            existing.contracts.batchModule != address(0), "batchModule not deployed - run 06_DeployVaultModules first"
        );
        require(
            existing.contracts.claimModule != address(0), "claimModule not deployed - run 06_DeployVaultModules first"
        );
        require(
            existing.contracts.feesModule != address(0), "feesModule not deployed - run 06_DeployVaultModules first"
        );

        // Vault configuration
        uint128 DEFAULT_DUST_AMOUNT = 1000; // 0.001 USDC (6 decimals)

        console.log("=== DEPLOYING VAULTS ===");
        console.log("Network:", config.network);

        // Deploy DN Vault (Type 0 - works with kMinter for institutional flows)
        address dnVault = _deployWithDefender(
            "dnVault",
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner, // owner_
                config.roles.admin, // admin_
                existing.contracts.kRegistry, // registry_
                false, // paused_
                "DN KAM Vault", // name_
                "dnkUSD", // symbol_
                6, // decimals_
                DEFAULT_DUST_AMOUNT, // dustAmount_
                config.assets.USDC, // asset_
                config.roles.treasury // feeCollector_
            )
        );

        // Deploy Alpha Vault (Type 1 - for retail staking)
        address alphaVault = _deployWithDefender(
            "alphaVault",
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner, // owner_
                config.roles.admin, // admin_
                existing.contracts.kRegistry, // registry_
                false, // paused_
                "Alpha KAM Vault", // name_
                "akUSD", // symbol_
                6, // decimals_
                DEFAULT_DUST_AMOUNT, // dustAmount_
                config.assets.USDC, // asset_
                config.roles.treasury // feeCollector_
            )
        );

        // Deploy Beta Vault (Type 2 - for advanced staking strategies)
        address betaVault = _deployWithDefender(
            "betaVault",
            abi.encodeWithSelector(
                kStakingVault.initialize.selector,
                config.roles.owner, // owner_
                config.roles.admin, // admin_
                existing.contracts.kRegistry, // registry_
                false, // paused_
                "Beta KAM Vault", // name_
                "bkUSD", // symbol_
                6, // decimals_
                DEFAULT_DUST_AMOUNT, // dustAmount_
                config.assets.USDC, // asset_
                config.roles.treasury // feeCollector_
            )
        );

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("DN Vault:", dnVault);
        console.log("Alpha Vault:", alphaVault);
        console.log("Beta Vault:", betaVault);
        console.log("Network:", config.network);
        console.log("Addresses saved to deployments/output/", config.network, "/addresses.json");
    }
}
