// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";

import { console } from "forge-std/console.sol";
import { CustodialAdapter } from "src/adapters/CustodialAdapter.sol";

contract DeployAdaptersScript is DefenderScript {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        console.log("=== DEPLOYING ADAPTERS ===");
        console.log("Network:", config.network);

        // Deploy CustodialAdapter with DefenderScript
        address custodialAdapter = _deployWithDefender(
            "custodialAdapter",
            abi.encodeWithSelector(CustodialAdapter.initialize.selector, existing.contracts.kRegistry)
        );

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("CustodialAdapter:", custodialAdapter);
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Network:", config.network);
        console.log("Address saved to deployments/output/", config.network, "/addresses.json");
        console.log("");
        console.log("Note: CustodialAdapter inherits roles from registry");
        console.log("      Configure vault destinations in next script");
    }
}
