// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";

import { console2 as console } from "forge-std/console2.sol";
import { MockERC20 } from "kam/test/mocks/MockERC20.sol";
import { MockERC7540 } from "kam/test/mocks/MockERC7540.sol";
import { MockWallet } from "kam/test/mocks/MockWallet.sol";

contract DeployMockAssetsScript is Script, DeploymentManager {
    function run() public {
        require(!isProduction(), "This script is NOT for production");
        NetworkConfig memory config = readNetworkConfig();

        // Check if mock assets are enabled in config
        if (!config.mockAssets.enabled) {
            console.log("=== MOCK ASSETS DISABLED IN CONFIG ===");
            console.log("Set mockAssets.enabled to true in config to deploy mocks");
            return;
        }

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

        // Deploy mock ERC7540 vaults
        MockERC7540 mockERC7540USDC = new MockERC7540(address(mockUSDC), "Mock ERC7540 USDC", "mERC7540USDC", 6);
        MockERC7540 mockERC7540WBTC = new MockERC7540(address(mockWBTC), "Mock ERC7540 WBTC", "mERC7540WBTC", 8);

        // Deploy mock wallet for USDC
        MockWallet mockWalletUSDC = new MockWallet("Mock USDC Wallet");

        vm.stopBroadcast();

        console.log("Mock USDC deployed at:", address(mockUSDC));
        console.log("Mock WBTC deployed at:", address(mockWBTC));
        console.log("Mock ERC7540 USDC deployed at:", address(mockERC7540USDC));
        console.log("Mock ERC7540 WBTC deployed at:", address(mockERC7540WBTC));
        console.log("Mock Wallet USDC deployed at:", address(mockWalletUSDC));

        // Update network config with deployed addresses
        _updateNetworkConfig(
            config.network, address(mockUSDC), address(mockWBTC), address(mockERC7540USDC), address(mockERC7540WBTC)
        );

        // Write mock target addresses to deployment output
        writeContractAddress("ERC7540USDC", address(mockERC7540USDC));
        writeContractAddress("ERC7540WBTC", address(mockERC7540WBTC));
        writeContractAddress("WalletUSDC", address(mockWalletUSDC));

        // Mint tokens using config amounts
        _mintTokensForTesting(mockUSDC, mockWBTC, config);

        // Also mint tokens to mock targets for testing
        _mintTokensToMockTargets(mockUSDC, mockWBTC, mockERC7540USDC, mockERC7540WBTC, mockWalletUSDC, config);

        console.log("=== MOCK ASSET DEPLOYMENT COMPLETE ===");
        console.log("Mock USDC:", address(mockUSDC));
        console.log("Mock WBTC:", address(mockWBTC));
        console.log("Mock ERC7540 USDC:", address(mockERC7540USDC));
        console.log("Mock ERC7540 WBTC:", address(mockERC7540WBTC));
        console.log("Mock Wallet USDC:", address(mockWalletUSDC));
        console.log("Config updated at: deployments/config/", string.concat(config.network, ".json"));
    }

    function _assetsAlreadyDeployed(NetworkConfig memory config) internal pure returns (bool) {
        // Check if assets are already deployed (not zero address and not placeholder addresses)
        bool usdcDeployed = config.assets.USDC != address(0) && config.assets.USDC != address(1);
        bool wbtcDeployed = config.assets.WBTC != address(0) && config.assets.WBTC != address(2);

        return usdcDeployed && wbtcDeployed;
    }

    function _updateNetworkConfig(
        string memory network,
        address mockUSDC,
        address mockWBTC,
        address mockERC7540USDC,
        address mockERC7540WBTC
    )
        internal
    {
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
            '"},"ERC7540s":{"USDC":"',
            vm.toString(mockERC7540USDC),
            '","WBTC":"',
            vm.toString(mockERC7540WBTC),
            '"}}'
        );

        vm.writeFile(configPath, updatedJson);
        console.log("Updated config file with mock asset addresses");
    }

    function _mintTokensForTesting(MockERC20 mockUSDC, MockERC20 mockWBTC, NetworkConfig memory config) internal {
        console.log("=== MINTING TOKENS FOR TESTING (from config) ===");

        vm.startBroadcast();

        // Use mint amounts from config
        uint256 usdcMintAmount = config.mockAssets.mintAmounts.USDC;
        uint256 wbtcMintAmount = config.mockAssets.mintAmounts.WBTC;

        console.log("Minting", usdcMintAmount, "USDC");
        console.log(wbtcMintAmount, "WBTC per account");

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

        console.log("Minted to deployer:", msg.sender);
        if (config.roles.treasury != address(0)) {
            console.log("Minted to treasury:", config.roles.treasury);
        }
        if (config.roles.owner != address(0) && config.roles.owner != msg.sender) {
            console.log("Minted to owner:", config.roles.owner);
        }
        if (
            config.roles.admin != address(0) && config.roles.admin != msg.sender
                && config.roles.admin != config.roles.owner
        ) {
            console.log("Minted to admin:", config.roles.admin);
        }
    }

    function _mintTokensToMockTargets(
        MockERC20 mockUSDC,
        MockERC20 mockWBTC,
        MockERC7540 mockERC7540USDC,
        MockERC7540 mockERC7540WBTC,
        MockWallet mockWalletUSDC,
        NetworkConfig memory config
    )
        internal
    {
        console.log("=== MINTING TOKENS TO MOCK TARGETS (from config) ===");

        vm.startBroadcast();

        // Use mock target amounts from config
        uint256 usdcAmount = config.mockAssets.mockTargetAmounts.USDC;
        uint256 wbtcAmount = config.mockAssets.mockTargetAmounts.WBTC;

        console.log("Minting", usdcAmount, "USDC");
        console.log(wbtcAmount, "WBTC per account");

        mockUSDC.mint(address(mockERC7540USDC), usdcAmount);
        mockWBTC.mint(address(mockERC7540WBTC), wbtcAmount);
        mockUSDC.mint(address(mockWalletUSDC), usdcAmount);

        vm.stopBroadcast();

        console.log("Minted to Mock ERC7540 USDC vault");
        console.log("Minted to Mock ERC7540 WBTC vault");
        console.log("Minted to Mock Wallet");
    }
}