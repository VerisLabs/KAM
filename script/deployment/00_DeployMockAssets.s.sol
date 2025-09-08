// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";

import { console } from "forge-std/console.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

contract DeployMockAssetsScript is Script, DeploymentManager {
    function run() public {
        NetworkConfig memory config = readNetworkConfig();

        // Only deploy mock assets for testnets (localhost and sepolia)
        require(
            keccak256(bytes(config.network)) == keccak256(bytes("localhost"))
                || keccak256(bytes(config.network)) == keccak256(bytes("sepolia")),
            "This script is only for localhost and sepolia networks"
        );

        // For localhost, always deploy fresh mock assets
        // For other networks, check if assets are already deployed
        if (keccak256(bytes(config.network)) != keccak256(bytes("localhost"))) {
            if (_assetsAlreadyDeployed(config)) {
                console.log("=== MOCK ASSETS ALREADY DEPLOYED ===");
                console.log("USDC:", config.assets.USDC);
                console.log("WBTC:", config.assets.WBTC);
                console.log("Skipping mock asset deployment");
                return;
            }
        }

        console.log("=== DEPLOYING MOCK ASSETS ===");
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);

        vm.startBroadcast();

        MockERC20 mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        MockERC20 mockWBTC = new MockERC20("Mock WBTC", "WBTC", 8);

        vm.stopBroadcast();

        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));

        // Update network config with deployed addresses
        _updateNetworkConfig(config.network, address(mockUSDC), address(mockWBTC));

        // Mint tokens for testing
        _mintTokensForTesting(mockUSDC, mockWBTC, config);

        console.log("=== MOCK ASSET DEPLOYMENT COMPLETE ===");
        console.log("Mock USDC:", address(mockUSDC));
        console.log("Mock WBTC:", address(mockWBTC));
        console.log("Config updated at: deployments/config/", string.concat(config.network, ".json"));
    }

    function _assetsAlreadyDeployed(NetworkConfig memory config) internal pure returns (bool) {
        // Check if assets are already deployed (not zero address and not placeholder addresses)
        bool usdcDeployed = config.assets.USDC != address(0) && config.assets.USDC != address(1); // localhost
            // placeholder
        bool wbtcDeployed = config.assets.WBTC != address(0) && config.assets.WBTC != address(2); // localhost
            // placeholder

        return usdcDeployed && wbtcDeployed;
    }

    function _updateNetworkConfig(string memory network, address mockUSDC, address mockWBTC) internal {
        string memory configPath = string.concat("deployments/config/", network, ".json");
        string memory json = vm.readFile(configPath);

        // Build updated JSON string with new asset addresses
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
        console.log("Updated config file with mock asset addresses");
    }

    function _mintTokensForTesting(MockERC20 mockUSDC, MockERC20 mockWBTC, NetworkConfig memory config) internal {
        console.log("=== MINTING TOKENS FOR TESTING ===");

        vm.startBroadcast();

        // Mint large amounts for testing to key accounts
        uint256 usdcMintAmount = 10_000_000 * 10 ** 6; // 10M USDC
        uint256 wbtcMintAmount = 1000 * 10 ** 8; // 1,000 WBTC

        // Mint to deployer (msg.sender)
        mockUSDC.mint(msg.sender, usdcMintAmount);
        mockWBTC.mint(msg.sender, wbtcMintAmount);

        // Mint to treasury
        if (config.roles.treasury != address(0)) {
            mockUSDC.mint(config.roles.treasury, usdcMintAmount);
            mockWBTC.mint(config.roles.treasury, wbtcMintAmount);
        }

        // Mint to owner (if different from deployer)
        if (config.roles.owner != address(0) && config.roles.owner != msg.sender) {
            mockUSDC.mint(config.roles.owner, usdcMintAmount);
            mockWBTC.mint(config.roles.owner, wbtcMintAmount);
        }

        // Mint to admin (if different from others)
        if (
            config.roles.admin != address(0) && config.roles.admin != msg.sender
                && config.roles.admin != config.roles.owner
        ) {
            mockUSDC.mint(config.roles.admin, usdcMintAmount);
            mockWBTC.mint(config.roles.admin, wbtcMintAmount);
        }

        vm.stopBroadcast();

        console.log("Minted 10M USDC and 1K WBTC to deployer:", msg.sender);
        if (config.roles.treasury != address(0)) {
            console.log("Minted 10M USDC and 1K WBTC to treasury:", config.roles.treasury);
        }
        if (config.roles.owner != address(0) && config.roles.owner != msg.sender) {
            console.log("Minted 10M USDC and 1K WBTC to owner:", config.roles.owner);
        }
        if (
            config.roles.admin != address(0) && config.roles.admin != msg.sender
                && config.roles.admin != config.roles.owner
        ) {
            console.log("Minted 10M USDC and 1K WBTC to admin:", config.roles.admin);
        }
    }
}
