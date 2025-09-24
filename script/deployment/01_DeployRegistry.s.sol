// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { kRegistry } from "src/kRegistry/kRegistry.sol";
import { AdapterGuardianModule } from "src/kRegistry/modules/AdapterGuardianModule.sol";
import { ProcessRouterModule } from "src/kRegistry/modules/ProcessRouterModule.sol";

contract DeployRegistryScript is Script, DeploymentManager {
    function run() public {
        // Read network configuration from JSON
        NetworkConfig memory config = readNetworkConfig();
        validateConfig(config);
        logConfig(config);

        vm.startBroadcast();

        // Deploy factory for proxy deployment
        ERC1967Factory factory = new ERC1967Factory();

        // Deploy kRegistry implementation
        kRegistry registryImpl = new kRegistry();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kRegistry.initialize.selector,
            config.roles.owner,
            config.roles.admin,
            config.roles.emergencyAdmin,
            config.roles.guardian,
            config.roles.relayer,
            config.roles.treasury
        );

        address registryProxy = factory.deployAndCall(address(registryImpl), msg.sender, initData);

        // Deploy AdapterGuardianModule (facet implementation)
        AdapterGuardianModule adapterGuardianModule = new AdapterGuardianModule();

        // Deploy ProcessRouterModule (facet implementation)
        ProcessRouterModule processRouterModule = new ProcessRouterModule();

        // Add AdapterGuardianModule functions to kRegistry
        kRegistry registry = kRegistry(payable(registryProxy));
        bytes4[] memory adapterSelectors = adapterGuardianModule.selectors();
        registry.addFunctions(adapterSelectors, address(adapterGuardianModule), false);

        // Add ProcessRouterModule functions to kRegistry
        bytes4[] memory processSelectors = processRouterModule.selectors();
        registry.addFunctions(processSelectors, address(processRouterModule), false);

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("ERC1967Factory deployed at:", address(factory));
        console.log("kRegistry implementation deployed at:", address(registryImpl));
        console.log("kRegistry proxy deployed at:", registryProxy);
        console.log("AdapterGuardianModule deployed at:", address(adapterGuardianModule));
        console.log("ProcessRouterModule deployed at:", address(processRouterModule));
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);

        // Auto-write contract addresses to deployment JSON
        writeContractAddress("ERC1967Factory", address(factory));
        writeContractAddress("kRegistryImpl", address(registryImpl));
        writeContractAddress("kRegistry", registryProxy);
        writeContractAddress("AdapterGuardianModule", address(adapterGuardianModule));
        writeContractAddress("ProcessRouterModule", address(processRouterModule));
    }
}
