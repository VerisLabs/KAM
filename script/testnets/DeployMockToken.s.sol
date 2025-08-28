// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";

import { console } from "forge-std/console.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

contract DeployMockTokenScript is Script, DeploymentManager {
    function run() public {
        NetworkConfig memory config = readNetworkConfig();

        require(
            keccak256(bytes(config.network)) == keccak256(bytes("sepolia"))
                || keccak256(bytes(config.network)) == keccak256(bytes("localhost")),
            "This script is only for Sepolia testnet and localhost"
        );

        console.log("=== DEPLOYING MOCK TOKENS ===");
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);

        vm.startBroadcast();

        MockERC20 mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        MockERC20 mockWBTC = new MockERC20("Mock WBTC", "WBTC", 8);

        vm.stopBroadcast();

        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));

        _updateNetworkConfig(config.network, address(mockUSDC), address(mockWBTC));

        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Mock USDC:", address(mockUSDC));
        console.log("Mock WBTC:", address(mockWBTC));
        console.log("Config updated at: deployments/config/", string.concat(config.network, ".json"));
    }

    function _updateNetworkConfig(string memory network, address mockUSDC, address mockWBTC) internal {
        string memory configPath = string.concat("deployments/config/", network, ".json");
        string memory json = vm.readFile(configPath);

        string memory updatedJson = string.concat(
            '{"network":"',
            network,
            '","chainId":',
            vm.toString(vm.parseJsonUint(json, ".chainId")),
            ',"roles":{"owner":"',
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
        console.log("Updated config with mock token addresses");
    }

    function mintTokensForTesting() external {
        NetworkConfig memory config = readNetworkConfig();

        require(
            keccak256(bytes(config.network)) == keccak256(bytes("sepolia"))
                || keccak256(bytes(config.network)) == keccak256(bytes("localhost")),
            "This function is only for Sepolia testnet and localhost"
        );

        MockERC20 mockUSDC = MockERC20(config.assets.USDC);
        MockERC20 mockWBTC = MockERC20(config.assets.WBTC);

        vm.startBroadcast();

        mockUSDC.mint(msg.sender, 1_000_000 * 10 ** 6);
        mockWBTC.mint(msg.sender, 100 * 10 ** 8);

        mockUSDC.mint(config.roles.treasury, 1_000_000 * 10 ** 6);
        mockWBTC.mint(config.roles.treasury, 100 * 10 ** 8);

        vm.stopBroadcast();

        console.log("Minted 1M USDC and 100 WBTC to:", msg.sender);
        console.log("Minted 1M USDC and 100 WBTC to treasury:", config.roles.treasury);
    }
}
