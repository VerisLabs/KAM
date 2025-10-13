// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { ERC20ParameterChecker } from "kam/src/adapters/parameters/ERC20ParameterChecker.sol";

import { IERC7540 } from "kam/src/interfaces/IERC7540.sol";
import { IkRegistry } from "kam/src/interfaces/IkRegistry.sol";

contract ConfigureAdapterPermissionsScript is Script, DeploymentManager {
    // Helper function to configure kMinter adapter permissions (full ERC7540 access)
    function configureAdapterPermissions(
        IkRegistry registry,
        address adapter,
        address vault,
        address asset,
        bool isKMinterAdapter
    )
        internal
    {
        bytes4 approveSelector = IERC7540.approve.selector;
        bytes4 transferSelector = IERC7540.transfer.selector;
        bytes4 transferFromSelector = IERC7540.transferFrom.selector;

        registry.setAdapterAllowedSelector(adapter, vault, 0, approveSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, transferSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, transferFromSelector, true);

        if (isKMinterAdapter) {
            bytes4 requestDepositSelector = IERC7540.requestDeposit.selector;
            bytes4 depositSelector = bytes4(abi.encodeWithSignature("deposit(uint256,address,address)"));
            bytes4 requestRedeemSelector = IERC7540.requestRedeem.selector;
            bytes4 redeemSelector = IERC7540.redeem.selector;

            // Allow all ERC7540 vault functions for kMinter (full access)
            registry.setAdapterAllowedSelector(adapter, vault, 0, requestDepositSelector, true);
            registry.setAdapterAllowedSelector(adapter, vault, 0, depositSelector, true);
            registry.setAdapterAllowedSelector(adapter, vault, 0, requestRedeemSelector, true);
            registry.setAdapterAllowedSelector(adapter, vault, 0, redeemSelector, true);

            // Allow transfer and approve for asset
            registry.setAdapterAllowedSelector(adapter, asset, 0, transferSelector, true);
            registry.setAdapterAllowedSelector(adapter, asset, 0, approveSelector, true);
            registry.setAdapterAllowedSelector(adapter, asset, 0, transferFromSelector, true);
        }
    }

    // Helper function to configure custodial adapter permissions (targetType = 1)
    function configureCustodialAdapterPermissions(
        IkRegistry registry,
        address adapter,
        address custodialAddress
    )
        internal
    {
        bytes4 approveSelector = IERC7540.approve.selector;
        bytes4 transferSelector = IERC7540.transfer.selector;

        registry.setAdapterAllowedSelector(adapter, custodialAddress, 1, transferSelector, true);
        registry.setAdapterAllowedSelector(adapter, custodialAddress, 1, approveSelector, true);
    }

    // Helper function to configure parameter checkers
    function configureParameterChecker(
        IkRegistry registry,
        address adapter,
        address target,
        address paramChecker,
        bool isTransferFrom
    )
        internal
    {
        bytes4 transferSelector = IERC7540.transfer.selector;
        bytes4 approveSelector = IERC7540.approve.selector;

        registry.setAdapterParametersChecker(adapter, target, transferSelector, paramChecker);
        registry.setAdapterParametersChecker(adapter, target, approveSelector, paramChecker);

        if (isTransferFrom) {
            bytes4 transferFromSelector = IERC7540.transferFrom.selector;
            registry.setAdapterParametersChecker(adapter, target, transferFromSelector, paramChecker);
        }
    }

    function run() public {
        // Read network configuration and existing deployments
        NetworkConfig memory config = readNetworkConfig();
        DeploymentOutput memory existing = readDeploymentOutput();

        // Validate required contracts are deployed
        validateAdapterDeployments(existing);

        console.log("=== CONFIGURING ADAPTER PERMISSIONS ===");
        console.log("Network:", config.network);
        console.log("");

        vm.startBroadcast();

        IkRegistry registry = IkRegistry(payable(existing.contracts.kRegistry));

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
        address paramChecker = address(erc20ParameterChecker);
        address kMinterAdapterUSDC = existing.contracts.kMinterAdapterUSDC;
        address kMinterAdapterWBTC = existing.contracts.kMinterAdapterWBTC;
        address dnVaultAdapterUSDC = existing.contracts.dnVaultAdapterUSDC;
        address dnVaultAdapterWBTC = existing.contracts.dnVaultAdapterWBTC;
        address treasury = config.roles.treasury;

        console.log("1. Configuring Adapter permissions...");
        configureAdapterPermissions(registry, existing.contracts.kMinterAdapterUSDC, usdcVault, usdc, true);
        configureAdapterPermissions(registry, existing.contracts.kMinterAdapterWBTC, wbtcVault, wbtc, true);
        configureAdapterPermissions(registry, existing.contracts.dnVaultAdapterUSDC, usdcVault, usdc, false);
        configureAdapterPermissions(registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault, wbtc, false);
        configureCustodialAdapterPermissions(registry, existing.contracts.alphaVaultAdapter, usdcWallet);
        configureCustodialAdapterPermissions(registry, existing.contracts.betaVaultAdapter, usdcWallet);

        console.log("");
        console.log("2. Configuring parameter checkers...");
        configureParameterChecker(registry, existing.contracts.kMinterAdapterUSDC, usdc, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterWBTC, wbtc, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterUSDC, usdcVault, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterWBTC, wbtcVault, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterUSDC, usdcVault, paramChecker, false);
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault, paramChecker, false);
        configureParameterChecker(registry, existing.contracts.alphaVaultAdapter, usdcWallet, paramChecker, false);
        configureParameterChecker(registry, existing.contracts.betaVaultAdapter, usdcWallet, paramChecker, false);

        console.log("");
        console.log("3. Configuring parameter checker permissions...");
        console.log("   - Set allowed receivers for USDC and WBTC");
        erc20ParameterChecker.setAllowedReceiver(usdc, usdcWallet, true);
        erc20ParameterChecker.setAllowedReceiver(wbtc, usdcWallet, true); // WBTC can also go to USDC wallet
        erc20ParameterChecker.setAllowedReceiver(usdcVault, kMinterAdapterUSDC, true); // Metavault shares can be
            // transferred
        erc20ParameterChecker.setAllowedReceiver(wbtcVault, kMinterAdapterWBTC, true);
        erc20ParameterChecker.setAllowedReceiver(usdcVault, dnVaultAdapterUSDC, true);
        erc20ParameterChecker.setAllowedReceiver(wbtcVault, dnVaultAdapterWBTC, true);
        console.log("   - Set allowed sources for USDC and WBTC");
        erc20ParameterChecker.setAllowedSource(usdcVault, kMinterAdapterUSDC, true);
        erc20ParameterChecker.setAllowedSource(wbtcVault, kMinterAdapterWBTC, true);
        erc20ParameterChecker.setAllowedSource(usdcVault, dnVaultAdapterUSDC, true);
        erc20ParameterChecker.setAllowedSource(wbtcVault, dnVaultAdapterWBTC, true);
        erc20ParameterChecker.setAllowedSource(usdcVault, treasury, true);
        erc20ParameterChecker.setAllowedSource(wbtcVault, treasury, true);
        console.log("   - Set allowed spenders for USDC and WBTC");
        erc20ParameterChecker.setAllowedSpender(usdc, usdcVault, true);
        erc20ParameterChecker.setAllowedSpender(wbtc, wbtcVault, true);
        console.log("   - Set max transfer limits for USDC and WBTC");
        erc20ParameterChecker.setMaxSingleTransfer(usdc, 1_000_000 * 10 ** 6);
        erc20ParameterChecker.setMaxSingleTransfer(wbtc, 30 * 10 ** 8);
        console.log("   - Set max transfer limits for metavault shares");
        erc20ParameterChecker.setMaxSingleTransfer(usdcVault, 1_000_000 * 10 ** 6); // 1M USDC worth of shares
        erc20ParameterChecker.setMaxSingleTransfer(wbtcVault, 30 * 10 ** 8); // 30 WBTC worth of shares

        vm.stopBroadcast();
    }
}
