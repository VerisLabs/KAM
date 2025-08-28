// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";

import { console } from "forge-std/console.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

contract DeployMockTokenLocalhostScript is Script, DeploymentManager {
    function run() public {
        NetworkConfig memory config = readNetworkConfig();

        require(keccak256(bytes(config.network)) == keccak256(bytes("localhost")), "This script is only for localhost");

        console.log("=== DEPLOYING MOCK TOKENS ON LOCALHOST ==");
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);

        vm.startBroadcast();

        MockERC20 mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        MockERC20 mockWBTC = new MockERC20("Mock WBTC", "WBTC", 8);

        vm.stopBroadcast();

        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));

        _updateLocalhostConfig(address(mockUSDC), address(mockWBTC));

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Mock USDC:", address(mockUSDC));
        console.log("Mock WBTC:", address(mockWBTC));
        console.log("Localhost config updated at: deployments/config/localhost.json");

        // Mint tokens for testing
        mintTokensForTesting(mockUSDC, mockWBTC, config);
    }

    function _updateLocalhostConfig(address mockUSDC, address mockWBTC) internal {
        string memory configPath = "deployments/config/localhost.json";
        string memory json = vm.readFile(configPath);

        string memory updatedJson = string.concat(
            '{"network":"localhost","chainId":31337,"roles":{"owner":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.owner")),
            '","admin":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.admin")),
            '","emergencyAdmin":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.emergencyAdmin")),
            '","guardian":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.guardian")),
            '","relayer":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.relayer")),
            '","institution":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.institution")),
            '","treasury":"',
            vm.toString(vm.parseJsonAddress(json, ".roles.treasury")),
            '"},"assets":{"USDC":"',
            vm.toString(mockUSDC),
            '","WBTC":"',
            vm.toString(mockWBTC),
            '"}}'
        );

        vm.writeFile(configPath, updatedJson);
        console.log("Updated localhost.json with mock token addresses");
    }

    function mintTokensForTesting(MockERC20 mockUSDC, MockERC20 mockWBTC, NetworkConfig memory config) internal {
        console.log("=== MINTING TOKENS FOR TESTING ===");

        vm.startBroadcast();

        // Mint to deployer (msg.sender)
        mockUSDC.mint(msg.sender, 1_000_000 * 10 ** 6); // 1M USDC
        mockWBTC.mint(msg.sender, 100 * 10 ** 8); // 100 WBTC

        // Mint to treasury
        mockUSDC.mint(config.roles.treasury, 1_000_000 * 10 ** 6);
        mockWBTC.mint(config.roles.treasury, 100 * 10 ** 8);

        // Mint to owner
        mockUSDC.mint(config.roles.owner, 1_000_000 * 10 ** 6);
        mockWBTC.mint(config.roles.owner, 100 * 10 ** 8);

        vm.stopBroadcast();

        console.log("Minted 1M USDC and 100 WBTC to deployer:", msg.sender);
        console.log("Minted 1M USDC and 100 WBTC to treasury:", config.roles.treasury);
        console.log("Minted 1M USDC and 100 WBTC to owner:", config.roles.owner);
    }
}
