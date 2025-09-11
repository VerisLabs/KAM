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
        address readerModule;
        address adapterGuardianModule;
        address kStakingVaultImpl;
        address dnVault;
        address dnVaultUSDC;
        address dnVaultWBTC;
        address alphaVault;
        address betaVault;
        address vaultAdapterImpl;
        address vaultAdapter;
        address dnVaultAdapterUSDC;
        address dnVaultAdapterWBTC;
        address alphaVaultAdapter;
        address betaVaultAdapter;
        address mockERC7540USDC;
        address mockERC7540WBTC;
        address mockWalletUSDC;
        address mockWalletWBTC;
        address ERC7540USDC;
        address ERC7540WBTC;
        address WalletUSDC;
        address WalletWBTC;
        address erc20ParameterChecker;
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

    function isProduction() internal view returns (bool) {
        bool isProd = vm.envOr("PRODUCTION", false);
        return isProd;
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

        // Parse contract addresses (check if keys exist before reading)
        if (json.keyExists(".contracts.ERC1967Factory")) {
            output.contracts.ERC1967Factory = json.readAddress(".contracts.ERC1967Factory");
        }

        if (json.keyExists(".contracts.kRegistryImpl")) {
            output.contracts.kRegistryImpl = json.readAddress(".contracts.kRegistryImpl");
        }

        if (json.keyExists(".contracts.kRegistry")) {
            output.contracts.kRegistry = json.readAddress(".contracts.kRegistry");
        }

        if (json.keyExists(".contracts.kMinterImpl")) {
            output.contracts.kMinterImpl = json.readAddress(".contracts.kMinterImpl");
        }

        if (json.keyExists(".contracts.kMinter")) {
            output.contracts.kMinter = json.readAddress(".contracts.kMinter");
        }

        if (json.keyExists(".contracts.kAssetRouterImpl")) {
            output.contracts.kAssetRouterImpl = json.readAddress(".contracts.kAssetRouterImpl");
        }

        if (json.keyExists(".contracts.kAssetRouter")) {
            output.contracts.kAssetRouter = json.readAddress(".contracts.kAssetRouter");
        }

        if (json.keyExists(".contracts.kUSD")) {
            output.contracts.kUSD = json.readAddress(".contracts.kUSD");
        }

        if (json.keyExists(".contracts.kBTC")) {
            output.contracts.kBTC = json.readAddress(".contracts.kBTC");
        }

        if (json.keyExists(".contracts.readerModule")) {
            output.contracts.readerModule = json.readAddress(".contracts.readerModule");
        }

        if (json.keyExists(".contracts.adapterGuardianModule")) {
            output.contracts.adapterGuardianModule = json.readAddress(".contracts.adapterGuardianModule");
        }

        if (json.keyExists(".contracts.kStakingVaultImpl")) {
            output.contracts.kStakingVaultImpl = json.readAddress(".contracts.kStakingVaultImpl");
        }

        if (json.keyExists(".contracts.dnVaultUSDC")) {
            output.contracts.dnVaultUSDC = json.readAddress(".contracts.dnVaultUSDC");
        }

        if (json.keyExists(".contracts.dnVaultWBTC")) {
            output.contracts.dnVaultWBTC = json.readAddress(".contracts.dnVaultWBTC");
        }

        if (json.keyExists(".contracts.alphaVault")) {
            output.contracts.alphaVault = json.readAddress(".contracts.alphaVault");
        }

        if (json.keyExists(".contracts.betaVault")) {
            output.contracts.betaVault = json.readAddress(".contracts.betaVault");
        }

        if (json.keyExists(".contracts.vaultAdapterImpl")) {
            output.contracts.vaultAdapterImpl = json.readAddress(".contracts.vaultAdapterImpl");
        }

        if (json.keyExists(".contracts.dnVaultAdapterUSDC")) {
            output.contracts.dnVaultAdapterUSDC = json.readAddress(".contracts.dnVaultAdapterUSDC");
        }

        if (json.keyExists(".contracts.dnVaultAdapterWBTC")) {
            output.contracts.dnVaultAdapterWBTC = json.readAddress(".contracts.dnVaultAdapterWBTC");
        }

        if (json.keyExists(".contracts.alphaVaultAdapter")) {
            output.contracts.alphaVaultAdapter = json.readAddress(".contracts.alphaVaultAdapter");
        }

        if (json.keyExists(".contracts.betaVaultAdapter")) {
            output.contracts.betaVaultAdapter = json.readAddress(".contracts.betaVaultAdapter");
        }

        if (json.keyExists(".contracts.ERC7540USDC")) {
            output.contracts.ERC7540USDC = json.readAddress(".contracts.ERC7540USDC");
        }

        if (json.keyExists(".contracts.ERC7540WBTC")) {
            output.contracts.ERC7540WBTC = json.readAddress(".contracts.ERC7540WBTC");
        }

        if (json.keyExists(".contracts.WalletUSDC")) {
            output.contracts.WalletUSDC = json.readAddress(".contracts.WalletUSDC");
        }

        if (json.keyExists(".contracts.erc20ParameterChecker")) {
            output.contracts.erc20ParameterChecker = json.readAddress(".contracts.erc20ParameterChecker");
        }

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
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("readerModule"))) {
            output.contracts.readerModule = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("AdapterGuardianModule"))) {
            output.contracts.adapterGuardianModule = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("kStakingVaultImpl"))) {
            output.contracts.kStakingVaultImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("dnVaultUSDC"))) {
            output.contracts.dnVaultUSDC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("dnVaultWBTC"))) {
            output.contracts.dnVaultWBTC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("alphaVault"))) {
            output.contracts.alphaVault = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("betaVault"))) {
            output.contracts.betaVault = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("vaultAdapterImpl"))) {
            output.contracts.vaultAdapterImpl = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("dnVaultAdapterUSDC"))) {
            output.contracts.dnVaultAdapterUSDC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("dnVaultAdapterWBTC"))) {
            output.contracts.dnVaultAdapterWBTC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("alphaVaultAdapter"))) {
            output.contracts.alphaVaultAdapter = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("betaVaultAdapter"))) {
            output.contracts.betaVaultAdapter = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("ERC7540USDC"))) {
            output.contracts.ERC7540USDC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("ERC7540WBTC"))) {
            output.contracts.ERC7540WBTC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("WalletUSDC"))) {
            output.contracts.WalletUSDC = contractAddress;
        } else if (keccak256(bytes(contractName)) == keccak256(bytes("erc20ParameterChecker"))) {
            output.contracts.erc20ParameterChecker = contractAddress;
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
        json = string.concat(json, '"kStakingVaultImpl":"', vm.toString(output.contracts.kStakingVaultImpl), '",');
        json = string.concat(json, '"readerModule":"', vm.toString(output.contracts.readerModule), '",');
        json =
            string.concat(json, '"adapterGuardianModule":"', vm.toString(output.contracts.adapterGuardianModule), '",');
        json = string.concat(json, '"dnVaultUSDC":"', vm.toString(output.contracts.dnVaultUSDC), '",');
        json = string.concat(json, '"dnVaultWBTC":"', vm.toString(output.contracts.dnVaultWBTC), '",');
        json = string.concat(json, '"alphaVault":"', vm.toString(output.contracts.alphaVault), '",');
        json = string.concat(json, '"betaVault":"', vm.toString(output.contracts.betaVault), '",');
        json = string.concat(json, '"vaultAdapterImpl":"', vm.toString(output.contracts.vaultAdapterImpl), '",');
        json = string.concat(json, '"dnVaultAdapterUSDC":"', vm.toString(output.contracts.dnVaultAdapterUSDC), '",');
        json = string.concat(json, '"dnVaultAdapterWBTC":"', vm.toString(output.contracts.dnVaultAdapterWBTC), '",');
        json = string.concat(json, '"alphaVaultAdapter":"', vm.toString(output.contracts.alphaVaultAdapter), '",');
        json = string.concat(json, '"betaVaultAdapter":"', vm.toString(output.contracts.betaVaultAdapter), '",');
        json = string.concat(json, '"ERC7540USDC":"', vm.toString(output.contracts.ERC7540USDC), '",');
        json = string.concat(json, '"ERC7540WBTC":"', vm.toString(output.contracts.ERC7540WBTC), '",');
        json = string.concat(json, '"WalletUSDC":"', vm.toString(output.contracts.WalletUSDC), '",');
        json = string.concat(json, '"erc20ParameterChecker":"', vm.toString(output.contracts.erc20ParameterChecker), '"');
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
        require(config.roles.institution != address(0), "Missing institution address");
        require(config.roles.treasury != address(0), "Missing treasury address");
        require(config.assets.USDC != address(0), "Missing USDC address");
        require(config.assets.WBTC != address(0), "Missing WBTC address");
    }

    /// @notice Validates that required deployment outputs are not zero for adapter configuration
    /// @param existing Deployment output to validate
    function validateAdapterDeployments(DeploymentOutput memory existing) internal pure {
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed");
        require(existing.contracts.dnVaultAdapterUSDC != address(0), "dnVaultAdapterUSDC not deployed");
        require(existing.contracts.dnVaultAdapterWBTC != address(0), "dnVaultAdapterWBTC not deployed");
        require(existing.contracts.alphaVaultAdapter != address(0), "alphaVaultAdapter not deployed");
        require(existing.contracts.betaVaultAdapter != address(0), "betaVaultAdapter not deployed");
        require(existing.contracts.ERC7540USDC != address(0), "ERC7540USDC not deployed");
        require(existing.contracts.ERC7540WBTC != address(0), "ERC7540WBTC not deployed");
        require(existing.contracts.WalletUSDC != address(0), "WalletUSDC not deployed");
    }

    /// @notice Validates that required deployment outputs are not zero for protocol configuration
    /// @param existing Deployment output to validate
    function validateProtocolDeployments(DeploymentOutput memory existing) internal pure {
        require(existing.contracts.kRegistry != address(0), "kRegistry not deployed");
        require(existing.contracts.kMinter != address(0), "kMinter not deployed");
        require(existing.contracts.kAssetRouter != address(0), "kAssetRouter not deployed");
        require(existing.contracts.dnVaultUSDC != address(0), "dnVaultUSDC not deployed");
        require(existing.contracts.dnVaultWBTC != address(0), "dnVaultWBTC not deployed");
        require(existing.contracts.alphaVault != address(0), "alphaVault not deployed");
        require(existing.contracts.betaVault != address(0), "betaVault not deployed");
        require(existing.contracts.dnVaultAdapterUSDC != address(0), "dnVaultAdapterUSDC not deployed");
        require(existing.contracts.dnVaultAdapterWBTC != address(0), "dnVaultAdapterWBTC not deployed");
        require(existing.contracts.alphaVaultAdapter != address(0), "alphaVaultAdapter not deployed");
        require(existing.contracts.betaVaultAdapter != address(0), "betaVaultAdapter not deployed");
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
