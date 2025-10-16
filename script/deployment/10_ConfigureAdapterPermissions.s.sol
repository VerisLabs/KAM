// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DeploymentManager } from "../utils/DeploymentManager.sol";
import { Script } from "forge-std/Script.sol";
import { console2 as console } from "forge-std/console2.sol";
import { ERC20ParameterChecker } from "kam/src/adapters/parameters/ERC20ParameterChecker.sol";

import { IERC7540 } from "kam/src/interfaces/IERC7540.sol";
import { IkRegistry } from "kam/src/interfaces/IkRegistry.sol";

contract ConfigureAdapterPermissionsScript is Script, DeploymentManager {
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

            registry.setAdapterAllowedSelector(adapter, vault, 0, requestDepositSelector, true);
            registry.setAdapterAllowedSelector(adapter, vault, 0, depositSelector, true);
            registry.setAdapterAllowedSelector(adapter, vault, 0, requestRedeemSelector, true);
            registry.setAdapterAllowedSelector(adapter, vault, 0, redeemSelector, true);

            registry.setAdapterAllowedSelector(adapter, asset, 0, transferSelector, true);
            registry.setAdapterAllowedSelector(adapter, asset, 0, approveSelector, true);
            registry.setAdapterAllowedSelector(adapter, asset, 0, transferFromSelector, true);
        }
    }

    function configureCustodialAdapterPermissions(IkRegistry registry, address adapter, address custodialAddress)
        internal
    {
        bytes4 approveSelector = IERC7540.approve.selector;
        bytes4 transferSelector = IERC7540.transfer.selector;

        registry.setAdapterAllowedSelector(adapter, custodialAddress, 1, transferSelector, true);
        registry.setAdapterAllowedSelector(adapter, custodialAddress, 1, approveSelector, true);
    }

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
        writeContractAddress("erc20ParameterChecker", address(erc20ParameterChecker));

        // Get addresses from config and existing deployments
        address usdcVault = existing.contracts.ERC7540USDC;
        address wbtcVault = existing.contracts.ERC7540WBTC;
        address usdcWallet = existing.contracts.WalletUSDC;
        address usdc = config.assets.USDC;
        address wbtc = config.assets.WBTC;

        console.log("1. Configuring Adapter permissions...");
        configureAdapterPermissions(registry, existing.contracts.kMinterAdapterUSDC, usdcVault, usdc, true);
        configureAdapterPermissions(registry, existing.contracts.kMinterAdapterWBTC, wbtcVault, wbtc, true);
        configureAdapterPermissions(registry, existing.contracts.dnVaultAdapterUSDC, usdcVault, usdc, false);
        configureAdapterPermissions(registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault, wbtc, false);
        configureCustodialAdapterPermissions(registry, existing.contracts.alphaVaultAdapter, usdcWallet);
        configureCustodialAdapterPermissions(registry, existing.contracts.betaVaultAdapter, usdcWallet);

        console.log("");
        console.log("2. Configuring parameter checkers...");
        address paramChecker = address(erc20ParameterChecker);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterUSDC, usdc, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterWBTC, wbtc, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterUSDC, usdcVault, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.kMinterAdapterWBTC, wbtcVault, paramChecker, true);
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterUSDC, usdcVault, paramChecker, false);
        configureParameterChecker(registry, existing.contracts.dnVaultAdapterWBTC, wbtcVault, paramChecker, false);
        configureParameterChecker(registry, existing.contracts.alphaVaultAdapter, usdcWallet, paramChecker, false);
        configureParameterChecker(registry, existing.contracts.betaVaultAdapter, usdcWallet, paramChecker, false);

        console.log("");
        console.log("3. Configuring parameter checker permissions from config...");
        
        // Set allowed receivers from config
        _configureAllowedReceivers(erc20ParameterChecker, config, existing, usdc, usdcVault, usdcWallet);
        
        // Set allowed sources from config
        _configureAllowedSources(erc20ParameterChecker, config, existing, usdcVault, wbtcVault);
        
        // Set allowed spenders from config
        _configureAllowedSpenders(erc20ParameterChecker, config, existing, usdc, wbtc, usdcVault, wbtcVault);
        
        // Set max transfer limits from config
        console.log("   - Set max transfer limits");
        erc20ParameterChecker.setMaxSingleTransfer(usdc, config.parameterChecker.maxSingleTransfer.USDC);
        erc20ParameterChecker.setMaxSingleTransfer(wbtc, config.parameterChecker.maxSingleTransfer.WBTC);
        erc20ParameterChecker.setMaxSingleTransfer(usdcVault, config.parameterChecker.maxSingleTransfer.ERC7540USDC);
        erc20ParameterChecker.setMaxSingleTransfer(wbtcVault, config.parameterChecker.maxSingleTransfer.ERC7540WBTC);

        vm.stopBroadcast();

        console.log("");
        console.log("=======================================");
        console.log("Adapter permissions configuration complete!");
    }

    function _configureAllowedReceivers(
        ERC20ParameterChecker checker,
        NetworkConfig memory config,
        DeploymentOutput memory existing,
        address usdc,
        address usdcVault,
        address usdcWallet
    ) internal {
        console.log("   - Set allowed receivers from config");
        
        // USDC receivers
        for (uint256 i = 0; i < config.parameterChecker.allowedReceivers.USDC.length; i++) {
            address receiver = _resolveAddress(config.parameterChecker.allowedReceivers.USDC[i], config, existing);
            if (receiver != address(0)) {
                checker.setAllowedReceiver(usdc, receiver, true);
            }
        }
        
        // WBTC receivers
        for (uint256 i = 0; i < config.parameterChecker.allowedReceivers.WBTC.length; i++) {
            address receiver = _resolveAddress(config.parameterChecker.allowedReceivers.WBTC[i], config, existing);
            if (receiver != address(0)) {
                checker.setAllowedReceiver(config.assets.WBTC, receiver, true);
            }
        }
        
        // ERC7540USDC receivers
        for (uint256 i = 0; i < config.parameterChecker.allowedReceivers.ERC7540USDC.length; i++) {
            address receiver = _resolveAddress(config.parameterChecker.allowedReceivers.ERC7540USDC[i], config, existing);
            if (receiver != address(0)) {
                checker.setAllowedReceiver(usdcVault, receiver, true);
            }
        }
        
        // ERC7540WBTC receivers
        for (uint256 i = 0; i < config.parameterChecker.allowedReceivers.ERC7540WBTC.length; i++) {
            address receiver = _resolveAddress(config.parameterChecker.allowedReceivers.ERC7540WBTC[i], config, existing);
            if (receiver != address(0)) {
                checker.setAllowedReceiver(existing.contracts.ERC7540WBTC, receiver, true);
            }
        }
    }

    function _configureAllowedSources(
        ERC20ParameterChecker checker,
        NetworkConfig memory config,
        DeploymentOutput memory existing,
        address usdcVault,
        address wbtcVault
    ) internal {
        console.log("   - Set allowed sources from config");
        
        // ERC7540USDC sources
        for (uint256 i = 0; i < config.parameterChecker.allowedSources.ERC7540USDC.length; i++) {
            address source = _resolveAddress(config.parameterChecker.allowedSources.ERC7540USDC[i], config, existing);
            if (source != address(0)) {
                checker.setAllowedSource(usdcVault, source, true);
            }
        }
        
        // ERC7540WBTC sources
        for (uint256 i = 0; i < config.parameterChecker.allowedSources.ERC7540WBTC.length; i++) {
            address source = _resolveAddress(config.parameterChecker.allowedSources.ERC7540WBTC[i], config, existing);
            if (source != address(0)) {
                checker.setAllowedSource(wbtcVault, source, true);
            }
        }
    }

    function _configureAllowedSpenders(
        ERC20ParameterChecker checker,
        NetworkConfig memory config,
        DeploymentOutput memory existing,
        address usdc,
        address wbtc,
        address usdcVault,
        address wbtcVault
    ) internal {
        console.log("   - Set allowed spenders from config");
        
        // USDC spenders
        for (uint256 i = 0; i < config.parameterChecker.allowedSpenders.USDC.length; i++) {
            address spender = _resolveAddress(config.parameterChecker.allowedSpenders.USDC[i], config, existing);
            if (spender != address(0)) {
                checker.setAllowedSpender(usdc, spender, true);
            }
        }
        
        // WBTC spenders
        for (uint256 i = 0; i < config.parameterChecker.allowedSpenders.WBTC.length; i++) {
            address spender = _resolveAddress(config.parameterChecker.allowedSpenders.WBTC[i], config, existing);
            if (spender != address(0)) {
                checker.setAllowedSpender(wbtc, spender, true);
            }
        }
    }

    function _resolveAddress(
        string memory key,
        NetworkConfig memory config,
        DeploymentOutput memory existing
    ) internal pure returns (address) {
        // Check if it's a contract key
        if (keccak256(bytes(key)) == keccak256(bytes("kMinterAdapterUSDC"))) {
            return existing.contracts.kMinterAdapterUSDC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("kMinterAdapterWBTC"))) {
            return existing.contracts.kMinterAdapterWBTC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("dnVaultAdapterUSDC"))) {
            return existing.contracts.dnVaultAdapterUSDC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("dnVaultAdapterWBTC"))) {
            return existing.contracts.dnVaultAdapterWBTC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("alphaVaultAdapter"))) {
            return existing.contracts.alphaVaultAdapter;
        } else if (keccak256(bytes(key)) == keccak256(bytes("betaVaultAdapter"))) {
            return existing.contracts.betaVaultAdapter;
        } else if (keccak256(bytes(key)) == keccak256(bytes("treasury"))) {
            return config.roles.treasury;
        } else if (keccak256(bytes(key)) == keccak256(bytes("walletUSDC"))) {
            return existing.contracts.WalletUSDC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("walletWBTC"))) {
            return existing.contracts.WalletWBTC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("ERC7540USDC"))) {
            return existing.contracts.ERC7540USDC;
        } else if (keccak256(bytes(key)) == keccak256(bytes("ERC7540WBTC"))) {
            return existing.contracts.ERC7540WBTC;
        }
        
        return address(0);
    }
}