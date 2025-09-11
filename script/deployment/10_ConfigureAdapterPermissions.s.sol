// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { IERC7540 } from "src/interfaces/IERC7540.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { kRegistry } from "src/kRegistry/kRegistry.sol";

contract ConfigureAdapterPermissionsScript is Script, DeploymentManager {
    function run() public {
        bool _isProduction = isProduction();

        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        validateAdapterDeployments(existing);

        console.log("=== CONFIGURING ADAPTER PERMISSIONS ===");
        console.log("Network:", config.network);
        console.log("");

        vm.startBroadcast();

        IRegistry registry = IRegistry(payable(existing.contracts.kRegistry));

        // Get function selectors for ERC7540
        bytes4 requestDepositSelector = IERC7540.requestDeposit.selector;
        bytes4 depositSelector = bytes4(abi.encodeWithSignature("deposit(uint256,address)"));
        bytes4 requestRedeemSelector = IERC7540.requestRedeem.selector;
        bytes4 redeemSelector = IERC7540.redeem.selector;

        // Get function selector for wallet transfer
        bytes4 transferSelector = IERC7540.transfer.selector;

        // Determine which contracts to use based on environment
        address usdcVault = _isProduction ? existing.contracts.ERC7540USDC : existing.contracts.mockERC7540USDC;
        address wbtcVault = _isProduction ? existing.contracts.ERC7540WBTC : existing.contracts.mockERC7540WBTC;
        address usdcWallet = _isProduction ? existing.contracts.WalletUSDC : existing.contracts.mockWalletUSDC;
        address usdc = config.assets.USDC;
        address wbtc = config.assets.WBTC;

        console.log("1. Configuring DN Vault USDC Adapter permissions...");
        // Allow ERC7540 USDC vault functions
        registry.setAdapterAllowedSelector(
            existing.contracts.dnVaultAdapterUSDC, usdcVault, requestDepositSelector, true
        );
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterUSDC, usdcVault, depositSelector, true);
        registry.setAdapterAllowedSelector(
            existing.contracts.dnVaultAdapterUSDC, usdcVault, requestRedeemSelector, true
        );
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterUSDC, usdcVault, redeemSelector, true);
        // Allow wallet transfer for USDC
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterUSDC, usdc, transferSelector, true);

        console.log("   - Allowed ERC7540 functions on USDC vault");
        console.log("   - Allowed transfer function on USDC wallet");

        console.log("");
        console.log("2. Configuring DN Vault WBTC Adapter permissions...");
        // Allow ERC7540 WBTC vault functions (no wallet for WBTC)
        registry.setAdapterAllowedSelector(
            existing.contracts.dnVaultAdapterWBTC, wbtcVault, requestDepositSelector, true
        );
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterWBTC, wbtcVault, depositSelector, true);
        registry.setAdapterAllowedSelector(
            existing.contracts.dnVaultAdapterWBTC, wbtcVault, requestRedeemSelector, true
        );
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterWBTC, wbtcVault, redeemSelector, true);
        // Allow wallet transfer for WBTC
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterWBTC, wbtc, transferSelector, true);
        console.log("   - Allowed ERC7540 functions on WBTC vault");

        console.log("");
        console.log("3. Configuring Alpha Vault Adapter permissions...");
        // Allow only wallet transfer for Alpha vault
        registry.setAdapterAllowedSelector(existing.contracts.alphaVaultAdapter, usdc, transferSelector, true);
        console.log("   - Allowed transfer function on USDC wallet");

        console.log("");
        console.log("4. Configuring Beta Vault Adapter permissions...");
        // Allow only wallet transfer for Beta vault
        registry.setAdapterAllowedSelector(existing.contracts.betaVaultAdapter, usdc, transferSelector, true);
        console.log("   - Allowed transfer function on USDC wallet");

        vm.stopBroadcast();

        console.log("");
        console.log("=======================================");
        console.log("Adapter permissions configuration complete!");
        console.log("");
        console.log("Summary:");
        console.log("- DN Vault USDC Adapter: Can interact with ERC7540 USDC vault and USDC wallet");
        console.log("- DN Vault WBTC Adapter: Can interact with ERC7540 WBTC vault only");
        console.log("- Alpha Vault Adapter: Can interact with USDC wallet only");
        console.log("- Beta Vault Adapter: Can interact with USDC wallet only");
    }
}
