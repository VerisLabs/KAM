// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC20ParameterChecker } from "src/adapters/parameters/ERC20ParameterChecker.sol";

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

        // Deploy ERC20 parameters checker
        ERC20ParameterChecker erc20ParameterChecker = new ERC20ParameterChecker(address(registry));

        // Write mock target addresses to deployment output
        writeContractAddress("erc20ParameterChecker", address(erc20ParameterChecker));

        // Get function selectors for ERC7540
        bytes4 requestDepositSelector = IERC7540.requestDeposit.selector;
        bytes4 depositSelector = bytes4(abi.encodeWithSignature("deposit(uint256,address)"));
        bytes4 requestRedeemSelector = IERC7540.requestRedeem.selector;
        bytes4 redeemSelector = IERC7540.redeem.selector;
        bytes4 approveSelector = IERC7540.approve.selector;

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
        // Allow approve for USDC
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterUSDC, usdc, approveSelector, true);
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
        // Allow approve for WBTC
        registry.setAdapterAllowedSelector(existing.contracts.dnVaultAdapterWBTC, wbtc, approveSelector, true);
        console.log("   - Allowed ERC7540 functions on WBTC vault");
        console.log("   - Allowed transfer function on WBTC wallet");
        console.log("   - Allowed approve function on WBTC wallet");

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

        // Activate param checker
        registry.setAdapterParametersChecker(
            existing.contracts.dnVaultAdapterUSDC, usdc, transferSelector, address(erc20ParameterChecker)
        );
        registry.setAdapterParametersChecker(
            existing.contracts.dnVaultAdapterWBTC, wbtc, transferSelector, address(erc20ParameterChecker)
        );
        console.log("   - Set parameter checker for USDC and WBTC transfer");

        registry.setAdapterParametersChecker(
            existing.contracts.dnVaultAdapterUSDC, usdc, approveSelector, address(erc20ParameterChecker)
        );
        registry.setAdapterParametersChecker(
            existing.contracts.dnVaultAdapterWBTC, wbtc, approveSelector, address(erc20ParameterChecker)
        );
        console.log("   - Set parameter checker for USDC and WBTC approve");

        console.log("");
        console.log("5. Configuring parameter checker permissions...");

        // Set token permissions in parameters checker
        erc20ParameterChecker.setAllowedReceiver(usdc, usdcWallet, true);
        console.log("   - Set allowed receivers for USDC and WBTC");

        erc20ParameterChecker.setAllowedSpender(usdc, usdcVault, true);
        erc20ParameterChecker.setAllowedSpender(wbtc, wbtcVault, true);
        console.log("   - Set allowed spenders for USDC and WBTC");

        erc20ParameterChecker.setMaxSingleTransfer(usdc, 100_000 * 10 ** 6);
        erc20ParameterChecker.setMaxSingleTransfer(wbtc, 3 * 10 ** 8);
        console.log("   - Set max transfer limits: 100,000 USDC and 3 WBTC");

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
        console.log(" - USDC: can be only transfered to wallet");
        console.log(" - USDC: can be approved to vault");
        console.log(" - USDC: max transfer is 100,000 USDC");
        console.log(" - WBTC: can be only transfered to wallet");
        console.log(" - WBTC: can be approved to vault");
        console.log(" - WBTC: max transfer is 3 WBTC");
        console.log("");
    }
}
