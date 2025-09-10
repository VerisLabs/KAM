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

        // Deploy CustodialAdapter implementation
        VaultAdapter vaultAdapterImpl = new VaultAdapter();

        // Deploy CustodialAdapter proxy with initialization
        bytes memory adapterInitData =
            abi.encodeWithSelector(VaultAdapter.initialize.selector, existing.contracts.kRegistry);
        address vaultAdapterProxy = factory.deployAndCall(address(vaultAdapterImpl), msg.sender, adapterInitData);

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("VaultAdapter implementation deployed at:", address(vaultAdapterImpl));
        console.log("VaultAdapter proxy deployed at:", vaultAdapterProxy);
        console.log("Registry:", existing.contracts.kRegistry);
        console.log("Network:", config.network);
        console.log("");
        console.log("Note: VaultAdapter inherits roles from registry");
        console.log("      Configure vault destinations in next script");

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("vaultAdapterImpl", address(vaultAdapterImpl));
        writeContractAddress("vaultAdapter", vaultAdapterProxy);
    }
}
