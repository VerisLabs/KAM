// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";

import { console } from "forge-std/console.sol";
import { kRegistry } from "src/kRegistry.sol";

contract DeployRegistryScript is DefenderScript {
    function run() public {
        // Read network configuration from JSON
        NetworkConfig memory config = readNetworkConfig();
        validateConfig(config);
        logConfig(config);

        address deployment = _deployWithDefender(
            "kRegistry",
            abi.encodeWithSelector(
                kRegistry.initialize.selector,
                config.roles.owner,
                config.roles.admin,
                config.roles.emergencyAdmin,
                config.roles.guardian,
                config.roles.relayer
            )
        );

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("kRegistry deployed at:", deployment);
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);
    }
}
