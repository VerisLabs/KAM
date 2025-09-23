// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC20ParameterChecker } from "src/adapters/parameters/ERC20ParameterChecker.sol";

import { IERC7540 } from "src/interfaces/IERC7540.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";

contract ConfigureAdapterPermissionsScript is Script, DeploymentManager {
    // Helper function to configure vault adapter permissions
    function configureVaultAdapterPermissions(
        IRegistry registry,
        address adapter,
        address vault,
        address asset,
        string memory adapterName
    )
        internal
    {
        bytes4 requestDepositSelector = IERC7540.requestDeposit.selector;
        bytes4 depositSelector = bytes4(abi.encodeWithSignature("deposit(uint256,address)"));
        bytes4 requestRedeemSelector = IERC7540.requestRedeem.selector;
        bytes4 redeemSelector = IERC7540.redeem.selector;
        bytes4 approveSelector = IERC7540.approve.selector;
        bytes4 transferSelector = IERC7540.transfer.selector;

        console.log(string.concat("Configuring ", adapterName, " permissions..."));

        // Allow ERC7540 vault functions
        registry.setAdapterAllowedSelector(adapter, vault, 0, requestDepositSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, depositSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, requestRedeemSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, redeemSelector, true);

        // Allow transfer and approve for asset
        registry.setAdapterAllowedSelector(adapter, asset, 1, transferSelector, true);
        registry.setAdapterAllowedSelector(adapter, asset, 1, approveSelector, true);

        console.log("   - Allowed ERC7540 functions on vault");
        console.log("   - Allowed transfer and approve functions on asset");
    }

    // Helper function to configure parameter checkers
    function configureParameterChecker(
        IRegistry registry,
        address adapter,
        address asset,
        address paramChecker
    )
        internal
    {
        bytes4 transferSelector = IERC7540.transfer.selector;
        bytes4 approveSelector = IERC7540.approve.selector;

        registry.setAdapterParametersChecker(adapter, asset, transferSelector, paramChecker);
        registry.setAdapterParametersChecker(adapter, asset, approveSelector, paramChecker);
    }

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

        // Determine which contracts to use based on environment
        address usdcVault = existing.contracts.ERC7540USDC;
        address wbtcVault = existing.contracts.ERC7540WBTC;
        address usdcWallet = existing.contracts.WalletUSDC;
        address usdc = config.assets.USDC;
        address wbtc = config.assets.WBTC;

        console.log("1. ");
        configureVaultAdapterPermissions(
            registry, existing.contracts.kMinterAdapterUSDC, usdcVault, usdc, "kMinter USDC Adapter"
        );

        console.log("");
        console.log("2. ");
        configureVaultAdapterPermissions(
            registry, existing.contracts.kMinterAdapterWBTC, wbtcVault, wbtc, "kMinter WBTC Adapter"
        );

        console.log("");
        console.log("3. ");
        configureVaultAdapterPermissions(
            registry, existing.contracts.dnVaultAdapterUSDC, usdcVault, usdc, "DN Vault USDC Adapter"
        );

        console.log("");
        console.log("4. ");
        configureVaultAdapterPermissions(
            registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault, wbtc, "DN Vault WBTC Adapter"
        );

        console.log("");
        console.log("5. Configuring Alpha Vault Adapter permissions...");
        // Allow only wallet transfer for Alpha vault
        bytes4 transferSelector = IERC7540.transfer.selector;
        registry.setAdapterAllowedSelector(existing.contracts.alphaVaultAdapter, usdc, 1, transferSelector, true);
        console.log("   - Allowed transfer function on USDC wallet");

        console.log("");
        console.log("6. Configuring Beta Vault Adapter permissions...");
        // Allow only wallet transfer for Beta vault
        registry.setAdapterAllowedSelector(existing.contracts.betaVaultAdapter, usdc, 1, transferSelector, true);
        console.log("   - Allowed transfer function on USDC wallet");

        console.log("");
        console.log("7. Configuring parameter checkers...");

        // Activate param checker for kMinter adapters
        configureParameterChecker(registry, existing.contracts.kMinterAdapterUSDC, usdc, address(erc20ParameterChecker));
        configureParameterChecker(registry, existing.contracts.kMinterAdapterWBTC, wbtc, address(erc20ParameterChecker));
        console.log("   - Set parameter checker for kMinter USDC and WBTC transfer/approve");

        // Activate param checker for DN vault adapters
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterUSDC, usdc, address(erc20ParameterChecker));
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterWBTC, wbtc, address(erc20ParameterChecker));
        console.log("   - Set parameter checker for DN Vault USDC and WBTC transfer/approve");

        console.log("");
        console.log("8. Configuring parameter checker permissions...");

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
        console.log("- kMinter USDC Adapter: Can interact with ERC7540 USDC vault, transfer and approve USDC");
        console.log("- kMinter WBTC Adapter: Can interact with ERC7540 WBTC vault, transfer and approve WBTC");
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
