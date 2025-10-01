// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kMinter } from "kam/src/kMinter.sol";

contract DeployMinterScript is Script, DeploymentManager {
    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate factory and registry were deployed
        require(
            existing.contracts.ERC1967Factory != address(0), "ERC1967Factory not deployed - run 01_DeployRegistry first"
        );
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed - run 01_DeployRegistry first");

        vm.startBroadcast();

        // Get factory reference
        ERC1967Factory factory = ERC1967Factory(existing.contracts.ERC1967Factory);

        // Deploy kMinter implementation
        kMinter minterImpl = new kMinter();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, existing.contracts.kRegistry);

        address minterProxy = factory.deployAndCall(address(minterImpl), msg.sender, initData);

        vm.stopBroadcast();

        console2.log("=== DEPLOYMENT COMPLETE ===");
        console2.log("kMinter implementation deployed at:", address(minterImpl));
        console2.log("kMinter proxy deployed at:", minterProxy);
        console2.log("Registry:", existing.contracts.kRegistry);
        console2.log("Network:", config.network);
        console2.log("Note: kMinter inherits roles from registry via kBase");

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("kMinterImpl", address(minterImpl));
        writeContractAddress("kMinter", minterProxy);
    }
}
