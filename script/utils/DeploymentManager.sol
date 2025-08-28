// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";

import { stdJson } from "forge-std/StdJson.sol";
import { console } from "forge-std/console.sol";

/// @title DeploymentManager
/// @notice Utility for managing JSON-based deployment configurations and outputs
/// @dev Handles reading network configs and writing deployment addresses
abstract contract DeploymentManager is Script {
    using stdJson for string;

    struct NetworkConfig {
        string network;
        uint256 chainId;
        RoleAddresses roles;
        AssetAddresses assets;
    }

    struct RoleAddresses {
        address owner;
        address admin;
        address emergencyAdmin;
        address guardian;
        address relayer;
        address institution;
        address treasury;
    }

    struct AssetAddresses {
        address USDC;
        address WBTC;
    }

    struct DeploymentOutput {
        uint256 chainId;
        string network;
        uint256 timestamp;
        ContractAddresses contracts;
    }

    struct ContractAddresses {
        address ERC1967Factory;
        address kRegistryImpl;
        address kRegistry;
        address kMinterImpl;
        address kMinter;
        address kAssetRouterImpl;
        address kAssetRouter;
        address kUSD;
        address kBTC;
        address batchModule;
        address claimModule;
        address feesModule;
        address kStakingVaultImpl;
        address dnVault;
        address alphaVault;
        address betaVault;
        address custodialAdapterImpl;
        address custodialAdapter;
    }

    /// @notice Gets the current network name from foundry context
    /// @return network Network name (mainnet, sepolia, localhost)
    function getCurrentNetwork() internal view returns (string memory) {
        uint256 chainId = block.chainid;

        if (chainId == 1) return "mainnet";
        if (chainId == 11_155_111) return "sepolia";
        if (chainId == 31_337) return "localhost";

        // Fallback to localhost for unknown chains
        return "localhost";
    }

    /// @notice Reads network configuration from JSON file
    /// @return config Network configuration struct
    function readNetworkConfig() internal view returns (NetworkConfig memory config) {
        string memory network = getCurrentNetwork();
        string memory configPath = string.concat("deployments/config/", network, ".json");

        require(vm.exists(configPath), string.concat("Config file not found: ", configPath));

        string memory json = vm.readFile(configPath);

        config.network = json.readString(".network");
        config.chainId = json.readUint(".chainId");

        // Parse role addresses
        config.roles.owner = json.readAddress(".roles.owner");
        config.roles.admin = json.readAddress(".roles.admin");
        config.roles.emergencyAdmin = json.readAddress(".roles.emergencyAdmin");
        config.roles.guardian = json.readAddress(".roles.guardian");
        config.roles.relayer = json.readAddress(".roles.relayer");
        config.roles.institution = json.readAddress(".roles.institution");
        config.roles.treasury = json.readAddress(".roles.treasury");

        // Parse asset addresses
        config.assets.USDC = json.readAddress(".assets.USDC");
        config.assets.WBTC = json.readAddress(".assets.WBTC");

        return config;
    }

    /// @notice Reads existing deployment addresses from output JSON
    /// @return output Deployment output struct with contract addresses
    function readDeploymentOutput() internal view returns (DeploymentOutput memory output) {
        string memory network = getCurrentNetwork();
        string memory outputPath = string.concat("deployments/output/", network, "/addresses.json");

        if (!vm.exists(outputPath)) {
            // Return empty struct if file doesn't exist
            output.network = network;
            output.chainId = block.chainid;
            return output;
        }

        string memory json = vm.readFile(outputPath);

        output.chainId = json.readUint(".chainId");
        output.network = json.readString(".network");
        output.timestamp = json.readUint(".timestamp");

        // Parse contract addresses (use try/catch pattern for missing addresses)
        try vm.parseJson(json, ".contracts.ERC1967Factory") returns (bytes memory data) {
            output.contracts.ERC1967Factory = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kRegistryImpl") returns (bytes memory data) {
            output.contracts.kRegistryImpl = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kRegistry") returns (bytes memory data) {
            output.contracts.kRegistry = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kMinterImpl") returns (bytes memory data) {
            output.contracts.kMinterImpl = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kMinter") returns (bytes memory data) {
            output.contracts.kMinter = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kAssetRouterImpl") returns (bytes memory data) {
            output.contracts.kAssetRouterImpl = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kAssetRouter") returns (bytes memory data) {
            output.contracts.kAssetRouter = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kUSD") returns (bytes memory data) {
            output.contracts.kUSD = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kBTC") returns (bytes memory data) {
            output.contracts.kBTC = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.batchModule") returns (bytes memory data) {
            output.contracts.batchModule = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.claimModule") returns (bytes memory data) {
            output.contracts.claimModule = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.feesModule") returns (bytes memory data) {
            output.contracts.feesModule = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.kStakingVaultImpl") returns (bytes memory data) {
            output.contracts.kStakingVaultImpl = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.dnVault") returns (bytes memory data) {
            output.contracts.dnVault = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.alphaVault") returns (bytes memory data) {
            output.contracts.alphaVault = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.betaVault") returns (bytes memory data) {
            output.contracts.betaVault = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.custodialAdapterImpl") returns (bytes memory data) {
            output.contracts.custodialAdapterImpl = abi.decode(data, (address));
        } catch { }

        try vm.parseJson(json, ".contracts.custodialAdapter") returns (bytes memory data) {
            output.contracts.custodialAdapter = abi.decode(data, (address));
        } catch { }

        return output;
    }

    /// @notice Writes a single contract address to deployment output
    /// @param contractName Name of the contract
    /// @param contractAddress Address of the deployed contract
    function writeContractAddress(string memory contractName, address contractAddress) internal {
        string memory network = getCurrentNetwork();
        string memory outputPath = string.concat("deployments/output/", network, "/addresses.json");

        // Read existing output or create new
        DeploymentOutput memory output = readDeploymentOutput();
        output.chainId = block.chainid;
        output.network = network;
        output.timestamp = block.timestamp;

        // Update the specific contract address
        if (keccak256(bytes(contractName)) == keccak256(bytes("ERC1967Factory"))) {
            output.contracts.ERC1967Factory = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kRegistryImpl"))) {
            output.contracts.kRegistryImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kRegistry"))) {
            output.contracts.kRegistry = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kMinterImpl"))) {
            output.contracts.kMinterImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kMinter"))) {
            output.contracts.kMinter = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kAssetRouterImpl"))) {
            output.contracts.kAssetRouterImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kAssetRouter"))) {
            output.contracts.kAssetRouter = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kUSD"))) {
            output.contracts.kUSD = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kBTC"))) {
            output.contracts.kBTC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("batchModule"))) {
            output.contracts.batchModule = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("claimModule"))) {
            output.contracts.claimModule = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("feesModule"))) {
            output.contracts.feesModule = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kStakingVaultImpl"))) {
            output.contracts.kStakingVaultImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("dnVault"))) {
            output.contracts.dnVault = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("alphaVault"))) {
            output.contracts.alphaVault = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("betaVault"))) {
            output.contracts.betaVault = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("custodialAdapterImpl"))) {
            output.contracts.custodialAdapterImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("custodialAdapter"))) {
            output.contracts.custodialAdapter = contractAddress;
        }

        // Write to JSON file
        string memory json = _serializeDeploymentOutput(output);
        vm.writeFile(outputPath, json);

        console.log(string.concat(contractName, " address written to: "), outputPath);
    }

    /// @notice Serializes deployment output to JSON string
    /// @param output Deployment output struct
    /// @return JSON string representation
    function _serializeDeploymentOutput(DeploymentOutput memory output) private pure returns (string memory) {
        string memory json = "{";
        json = string.concat(json, '"chainId":', vm.toString(output.chainId), ",");
        json = string.concat(json, '"network":"', output.network, '",');
        json = string.concat(json, '"timestamp":', vm.toString(output.timestamp), ",");
        json = string.concat(json, '"contracts":{');

        json = string.concat(json, '"ERC1967Factory":"', vm.toString(output.contracts.ERC1967Factory), '",');
        json = string.concat(json, '"kRegistryImpl":"', vm.toString(output.contracts.kRegistryImpl), '",');
        json = string.concat(json, '"kRegistry":"', vm.toString(output.contracts.kRegistry), '",');
        json = string.concat(json, '"kMinterImpl":"', vm.toString(output.contracts.kMinterImpl), '",');
        json = string.concat(json, '"kMinter":"', vm.toString(output.contracts.kMinter), '",');
        json = string.concat(json, '"kAssetRouterImpl":"', vm.toString(output.contracts.kAssetRouterImpl), '",');
        json = string.concat(json, '"kAssetRouter":"', vm.toString(output.contracts.kAssetRouter), '",');
        json = string.concat(json, '"kUSD":"', vm.toString(output.contracts.kUSD), '",');
        json = string.concat(json, '"kBTC":"', vm.toString(output.contracts.kBTC), '",');
        json = string.concat(json, '"batchModule":"', vm.toString(output.contracts.batchModule), '",');
        json = string.concat(json, '"claimModule":"', vm.toString(output.contracts.claimModule), '",');
        json = string.concat(json, '"feesModule":"', vm.toString(output.contracts.feesModule), '",');
        json = string.concat(json, '"kStakingVaultImpl":"', vm.toString(output.contracts.kStakingVaultImpl), '",');
        json = string.concat(json, '"dnVault":"', vm.toString(output.contracts.dnVault), '",');
        json = string.concat(json, '"alphaVault":"', vm.toString(output.contracts.alphaVault), '",');
        json = string.concat(json, '"betaVault":"', vm.toString(output.contracts.betaVault), '",');
        json = string.concat(json, '"custodialAdapterImpl":"', vm.toString(output.contracts.custodialAdapterImpl), '",');
        json = string.concat(json, '"custodialAdapter":"', vm.toString(output.contracts.custodialAdapter), '"');

        json = string.concat(json, "}}");

        return json;
    }

    /// @notice Validates that required addresses are not zero
    /// @param config Network configuration to validate
    function validateConfig(NetworkConfig memory config) internal pure {
        require(config.roles.owner != address(0), "Missing owner address");
        require(config.roles.admin != address(0), "Missing admin address");
        require(config.roles.emergencyAdmin != address(0), "Missing emergencyAdmin address");
        require(config.roles.guardian != address(0), "Missing guardian address");
        require(config.roles.relayer != address(0), "Missing relayer address");
        require(config.assets.USDC != address(0), "Missing USDC address");
        require(config.assets.WBTC != address(0), "Missing WBTC address");
    }

    /// @notice Logs deployment configuration for verification
    /// @param config Network configuration
    function logConfig(NetworkConfig memory config) internal pure {
        console.log("=== DEPLOYMENT CONFIGURATION ===");
        console.log("Network:", config.network);
        console.log("Chain ID:", config.chainId);
        console.log("Owner:", config.roles.owner);
        console.log("Admin:", config.roles.admin);
        console.log("Emergency Admin:", config.roles.emergencyAdmin);
        console.log("Guardian:", config.roles.guardian);
        console.log("Relayer:", config.roles.relayer);
        console.log("Institution:", config.roles.institution);
        console.log("Treasury:", config.roles.treasury);
        console.log("USDC:", config.assets.USDC);
        console.log("WBTC:", config.assets.WBTC);
        console.log("===============================");
    }
}
