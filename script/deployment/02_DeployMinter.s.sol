// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";

import { console } from "forge-std/console.sol";
import { kMinter } from "src/kMinter.sol";

contract DeployMinterScript is DefenderScript {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate registry was deployed
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        address deployment = _deployWithDefender(
            "kMinter", abi.encodeWithSelector(kMinter.initialize.selector, existing.contracts.kRegistry)
        );

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kMinter deployed at:", deployment);
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Network:", config.network);
        console.log("Note: kMinter inherits roles from registry via kBase");
    }
}
