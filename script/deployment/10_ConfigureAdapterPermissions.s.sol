// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC20ParameterChecker } from "src/adapters/parameters/ERC20ParameterChecker.sol";

import { IERC7540 } from "src/interfaces/IERC7540.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";

contract ConfigureAdapterPermissionsScript is Script, DeploymentManager {
    // Helper function to configure kMinter adapter permissions (full ERC7540 access)
    function configureKMinterAdapterPermissions(
        IRegistry registry,
        address adapter,
        address vault,
        address asset
    )
        internal
    {
        bytes4 requestDepositSelector = IERC7540.requestDeposit.selector;
        bytes4 depositSelector = bytes4(abi.encodeWithSignature("deposit(uint256,address)"));
        bytes4 requestRedeemSelector = IERC7540.requestRedeem.selector;
        bytes4 redeemSelector = IERC7540.redeem.selector;
        bytes4 approveSelector = IERC7540.approve.selector;
        bytes4 transferSelector = IERC7540.transfer.selector;

        // Allow all ERC7540 vault functions for kMinter (full access)
        registry.setAdapterAllowedSelector(adapter, vault, 0, requestDepositSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, depositSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, requestRedeemSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, redeemSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, approveSelector, true);
        registry.setAdapterAllowedSelector(adapter, vault, 0, transferSelector, true);

        // Allow transfer and approve for asset
        registry.setAdapterAllowedSelector(adapter, asset, 0, transferSelector, true);
        registry.setAdapterAllowedSelector(adapter, asset, 0, approveSelector, true);
    }

    // Helper function to configure metavault adapter permissions (targetType = 0)
    function configureMetavaultAdapterPermissions(
        IRegistry registry,
        address adapter,
        address metavault
    )
        internal
    {
        bytes4 approveSelector = IERC7540.approve.selector;
        bytes4 transferSelector = IERC7540.transfer.selector;

        registry.setAdapterAllowedSelector(adapter, metavault, 0, transferSelector, true);
        registry.setAdapterAllowedSelector(adapter, metavault, 0, approveSelector, true);
    }

    // Helper function to configure custodial adapter permissions (targetType = 1)
    function configureCustodialAdapterPermissions(
        IRegistry registry,
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
        IRegistry registry,
        address adapter,
        address target,
        address paramChecker
    )
        internal
    {
        bytes4 transferSelector = IERC7540.transfer.selector;
        bytes4 approveSelector = IERC7540.approve.selector;

        registry.setAdapterParametersChecker(adapter, target, transferSelector, paramChecker);
        registry.setAdapterParametersChecker(adapter, target, approveSelector, paramChecker);
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
        address usdcERC7540 = config.ERC7540s.USDC;
        address wbtcERC7540 = config.ERC7540s.WBTC;

        console.log("1. Configuring kMinter USDC Adapter permissions...");
        configureKMinterAdapterPermissions(registry, existing.contracts.kMinterAdapterUSDC, usdcVault, usdc);
        console.log("   - Allowed all ERC7540 functions on USDC vault + transfer/approve USDC");

        console.log("");
        console.log("2. Configuring kMinter WBTC Adapter permissions...");
        configureKMinterAdapterPermissions(registry, existing.contracts.kMinterAdapterWBTC, wbtcVault, wbtc);
        console.log("   - Allowed all ERC7540 functions on WBTC vault + transfer/approve WBTC");

        console.log("");
        console.log("3. Configuring DN Vault USDC Adapter permissions...");
        configureMetavaultAdapterPermissions(registry, existing.contracts.dnVaultAdapterUSDC, usdcVault);
        console.log("   - Allowed transfer and approve on USDC metavault");

        console.log("");
        console.log("4. Configuring DN Vault WBTC Adapter permissions...");
        configureMetavaultAdapterPermissions(registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault);
        console.log("   - Allowed transfer and approve on WBTC metavault");

        console.log("");
        console.log("5. Configuring Alpha Vault Adapter permissions...");
        configureCustodialAdapterPermissions(registry, existing.contracts.alphaVaultAdapter, usdcWallet);
        console.log("   - Allowed transfer and approve on USDC custodial address");

        console.log("");
        console.log("6. Configuring Beta Vault Adapter permissions...");
        configureCustodialAdapterPermissions(registry, existing.contracts.betaVaultAdapter, usdcWallet);
        console.log("   - Allowed transfer and approve on USDC custodial address");

        console.log("");
        console.log("7. Configuring parameter checkers...");

        // Activate param checker for kMinter adapters (on assets)
        configureParameterChecker(registry, existing.contracts.kMinterAdapterUSDC, usdc, address(erc20ParameterChecker));
        configureParameterChecker(registry, existing.contracts.kMinterAdapterWBTC, wbtc, address(erc20ParameterChecker));
        console.log("   - Set parameter checker for kMinter USDC and WBTC transfer/approve");

        // Activate param checker for DN vault adapters (on metavault shares)
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterUSDC, usdcVault, address(erc20ParameterChecker));
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault, address(erc20ParameterChecker));
        console.log("   - Set parameter checker for DN Vault USDC and WBTC metavault share transfer/approve");

        // Activate param checker for Alpha and Beta vault adapters (on custodial addresses)
        configureParameterChecker(registry, existing.contracts.alphaVaultAdapter, usdcWallet, address(erc20ParameterChecker));
        configureParameterChecker(registry, existing.contracts.betaVaultAdapter, usdcWallet, address(erc20ParameterChecker));
        console.log("   - Set parameter checker for Alpha and Beta Vault USDC custodial transfer/approve");

        console.log("");
        console.log("8. Configuring parameter checker permissions...");

        // Set token permissions in parameters checker
        erc20ParameterChecker.setAllowedReceiver(usdc, usdcWallet, true);
        erc20ParameterChecker.setAllowedReceiver(wbtc, usdcWallet, true); // WBTC can also go to USDC wallet
        console.log("   - Set allowed receivers for USDC and WBTC");

        erc20ParameterChecker.setAllowedSpender(usdc, usdcVault, true);
        erc20ParameterChecker.setAllowedSpender(wbtc, wbtcVault, true);
        console.log("   - Set allowed spenders for USDC and WBTC");

        // Set metavault share permissions
        erc20ParameterChecker.setAllowedReceiver(usdcVault, usdcVault, true); // Metavault shares can be transferred between vaults
        erc20ParameterChecker.setAllowedReceiver(wbtcVault, wbtcVault, true);
        erc20ParameterChecker.setAllowedSpender(usdcVault, usdcVault, true);
        erc20ParameterChecker.setAllowedSpender(wbtcVault, wbtcVault, true);
        console.log("   - Set metavault share transfer permissions");

        erc20ParameterChecker.setMaxSingleTransfer(usdc, 100_000 * 10 ** 6);
        erc20ParameterChecker.setMaxSingleTransfer(wbtc, 3 * 10 ** 8);
        // Set reasonable limits for metavault shares (higher since they represent larger positions)
        erc20ParameterChecker.setMaxSingleTransfer(usdcVault, 1_000_000 * 10 ** 6); // 1M USDC worth of shares
        erc20ParameterChecker.setMaxSingleTransfer(wbtcVault, 30 * 10 ** 8); // 30 WBTC worth of shares
        console.log("   - Set max transfer limits: 100,000 USDC, 3 WBTC, 1M USDC shares, 30 WBTC shares");

        vm.stopBroadcast();

        console.log("");
        console.log("=======================================");
        console.log("Adapter permissions configuration complete!");
        console.log("");
        console.log("Summary:");
        console.log("- kMinter USDC Adapter: Full ERC7540 access to USDC vault + transfer/approve USDC");
        console.log("- kMinter WBTC Adapter: Full ERC7540 access to WBTC vault + transfer/approve WBTC");
        console.log("- DN Vault USDC Adapter: Transfer/approve metavault shares (USDC vault)");
        console.log("- DN Vault WBTC Adapter: Transfer/approve metavault shares (WBTC vault)");
        console.log("- Alpha Vault Adapter: Transfer/approve USDC from custodial address");
        console.log("- Beta Vault Adapter: Transfer/approve USDC from custodial address");
        console.log("");
        console.log("Parameter Checker Settings:");
        console.log("- USDC: max transfer is 100,000 USDC");
        console.log("- WBTC: max transfer is 3 WBTC");
        console.log("- All transfers/approvals are validated by parameter checker");
        console.log("");
    }
}
