// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ADMIN_ROLE, INSTITUTION_ROLE, MINTER_ROLE, _1_USDC, _1_WBTC } from "../utils/Constants.sol";

import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { IRegistry } from "kam/src/interfaces/IRegistry.sol";
import { OptimizedOwnableRoles } from "solady/auth/OptimizedOwnableRoles.sol";

contract DeploymentTest is DeploymentBaseTest {
    function test_ProtocolDeployment() public view {
        assertTrue(address(registry) != address(0), "Registry not deployed");
        assertTrue(address(assetRouter) != address(0), "AssetRouter not deployed");
        assertTrue(address(kUSD) != address(0), "kUSD not deployed");
        assertTrue(address(kBTC) != address(0), "kBTC not deployed");
        assertTrue(address(minter) != address(0), "Minter not deployed");
        assertTrue(address(dnVault) != address(0), "DN Vault not deployed");
        assertTrue(address(alphaVault) != address(0), "Alpha Vault not deployed");
        assertTrue(address(betaVault) != address(0), "Beta Vault not deployed");

        assertTrue(address(registryImpl) != address(0), "Registry impl not deployed");
        assertTrue(address(assetRouterImpl) != address(0), "AssetRouter impl not deployed");
        assertTrue(address(minterImpl) != address(0), "Minter impl not deployed");
        assertTrue(address(stakingVaultImpl) != address(0), "StakingVault impl not deployed");
    }

    function test_ProtocolInitialization() public view {
        assertProtocolInitialized();
    }

    function test_TokenProperties() public view {
        assertEq(kUSD.name(), KUSD_NAME, "kUSD name incorrect");
        assertEq(kUSD.symbol(), KUSD_SYMBOL, "kUSD symbol incorrect");
        assertEq(kUSD.decimals(), 6, "kUSD decimals incorrect");

        assertEq(kBTC.name(), KBTC_NAME, "kBTC name incorrect");
        assertEq(kBTC.symbol(), KBTC_SYMBOL, "kBTC symbol incorrect");
        assertEq(kBTC.decimals(), 8, "kBTC decimals incorrect");

        assertEq(dnVault.name(), DN_VAULT_NAME, "DN Vault name incorrect");
        assertEq(dnVault.symbol(), DN_VAULT_SYMBOL, "DN Vault symbol incorrect");
        assertEq(dnVault.decimals(), 6, "DN Vault decimals incorrect");

        assertEq(alphaVault.name(), ALPHA_VAULT_NAME, "Alpha Vault name incorrect");
        assertEq(alphaVault.symbol(), ALPHA_VAULT_SYMBOL, "Alpha Vault symbol incorrect");
        assertEq(alphaVault.decimals(), 6, "Alpha Vault decimals incorrect");

        assertEq(betaVault.name(), BETA_VAULT_NAME, "Beta Vault name incorrect");
        assertEq(betaVault.symbol(), BETA_VAULT_SYMBOL, "Beta Vault symbol incorrect");
        assertEq(betaVault.decimals(), 6, "Beta Vault decimals incorrect");
    }

    function test_RoleAssignments() public {
        assertHasRole(address(registry), users.admin, ADMIN_ROLE);
        assertHasRole(address(kUSD), users.admin, ADMIN_ROLE);
        assertHasRole(address(kBTC), users.admin, ADMIN_ROLE);
        assertHasRole(address(registry), users.institution, INSTITUTION_ROLE);

        assertHasRole(address(kUSD), address(minter), MINTER_ROLE);
        assertHasRole(address(kBTC), address(minter), MINTER_ROLE);

        assertHasRole(address(kUSD), address(assetRouter), MINTER_ROLE);
        assertHasRole(address(kBTC), address(assetRouter), MINTER_ROLE);

        assertFalse(
            OptimizedOwnableRoles(address(kUSD)).hasAnyRole(address(dnVault), MINTER_ROLE),
            "DN vault should not have kToken MINTER_ROLE"
        );
        assertFalse(
            OptimizedOwnableRoles(address(kUSD)).hasAnyRole(address(alphaVault), MINTER_ROLE),
            "Alpha vault should not have kToken MINTER_ROLE"
        );
        assertFalse(
            OptimizedOwnableRoles(address(kUSD)).hasAnyRole(address(betaVault), MINTER_ROLE),
            "Beta vault should not have kToken MINTER_ROLE"
        );
    }

    function test_AssetRegistration() public view {
        assertTrue(registry.isAsset(tokens.usdc), "tokens.usdc not registered");
        assertEq(registry.assetToKToken(tokens.usdc), address(kUSD), "USDC->kUSD mapping incorrect");

        assertTrue(registry.isAsset(tokens.wbtc), "WBTC not registered");
        assertEq(registry.assetToKToken(tokens.wbtc), address(kBTC), "WBTC->kBTC mapping incorrect");
    }

    function test_VaultRegistration() public view {
        assertTrue(registry.isVault(address(minter)), "Minter Vault not registered");
        assertTrue(registry.isVault(address(dnVault)), "DN Vault not registered");
        assertTrue(registry.isVault(address(alphaVault)), "Alpha Vault not registered");
        assertTrue(registry.isVault(address(betaVault)), "Beta Vault not registered");

        assertEq(registry.getVaultAssets(address(dnVault))[0], tokens.usdc, "DN Vault asset mapping incorrect");
        assertEq(registry.getVaultAssets(address(alphaVault))[0], tokens.usdc, "Alpha Vault asset mapping incorrect");
        assertEq(registry.getVaultAssets(address(betaVault))[0], tokens.usdc, "Beta Vault asset mapping incorrect");

        assertEq(registry.getVaultType(address(minter)), uint8(0), "Minter Vault type incorrect"); // Minter = 0
        assertEq(registry.getVaultType(address(dnVault)), uint8(1), "DN Vault type incorrect"); // DN = 1
        assertEq(registry.getVaultType(address(alphaVault)), uint8(2), "Alpha Vault type incorrect"); // ALPHA = 2
        assertEq(registry.getVaultType(address(betaVault)), uint8(3), "Beta Vault type incorrect"); // BETA = 3
    }

    function test_UserFunding() public view {
        assertEq(getAssetBalance(tokens.usdc, users.alice), 1_000_000 * _1_USDC, "Alice USDC balance incorrect");
        assertEq(getAssetBalance(tokens.usdc, users.bob), 500_000 * _1_USDC, "Bob USDC balance incorrect");
        assertEq(
            getAssetBalance(tokens.usdc, users.institution),
            10_000_000 * _1_USDC,
            "Institution tokens.usdc balance incorrect"
        );

        assertEq(getAssetBalance(tokens.wbtc, users.alice), 100 * _1_WBTC, "Alice WBTC balance incorrect");
        assertEq(getAssetBalance(tokens.wbtc, users.bob), 50 * _1_WBTC, "Bob WBTC balance incorrect");
        assertEq(getAssetBalance(tokens.wbtc, users.institution), 1000 * _1_WBTC, "Institution WBTC balance incorrect");
    }

    function test_BasicMinting() public {
        uint256 mintAmount = 1000 * _1_USDC;

        mintKTokens(address(kUSD), users.alice, mintAmount);

        assertKTokenBalance(address(kUSD), users.alice, mintAmount);

        assertEq(kUSD.totalSupply(), mintAmount, "Total supply incorrect");
    }

    function test_ContractOwnership() public view {
        assertEq(registry.owner(), users.owner, "Registry owner incorrect");
        assertEq(kUSD.owner(), users.owner, "kUSD owner incorrect");
        assertEq(kBTC.owner(), users.owner, "kBTC owner incorrect");
        assertEq(dnVault.owner(), users.owner, "DN Vault owner incorrect");
        assertEq(alphaVault.owner(), users.owner, "Alpha Vault owner incorrect");
        assertEq(betaVault.owner(), users.owner, "Beta Vault owner incorrect");
    }

    function test_ProtocolState() public view {
        (
            address registryAddr,
            address assetRouterAddr,
            address kUSDAddr,
            address kBTCAddr,
            address minterAddr,
            address dnVaultAddr,
            address alphaVaultAddr,
            address betaVaultAddr
        ) = getProtocolState();

        assertEq(registryAddr, address(registry), "Registry address mismatch");
        assertEq(assetRouterAddr, address(assetRouter), "AssetRouter address mismatch");
        assertEq(kUSDAddr, address(kUSD), "kUSD address mismatch");
        assertEq(kBTCAddr, address(kBTC), "kBTC address mismatch");
        assertEq(minterAddr, address(minter), "Minter address mismatch");
        assertEq(dnVaultAddr, address(dnVault), "DN Vault address mismatch");
        assertEq(alphaVaultAddr, address(alphaVault), "Alpha Vault address mismatch");
        assertEq(betaVaultAddr, address(betaVault), "Beta Vault address mismatch");
    }

    function test_PauseUnpause() public {
        assertFalse(kUSD.isPaused(), "kUSD should be unpaused");

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(true);

        assertTrue(kUSD.isPaused(), "kUSD should be paused");

        vm.prank(users.emergencyAdmin);
        kUSD.setPaused(false);

        assertFalse(kUSD.isPaused(), "kUSD should be unpaused");
    }

    function test_VaultTypeHelper() public view {
        assertEq(address(getVaultByType(IRegistry.VaultType.DN)), address(dnVault), "DN vault helper incorrect");
        assertEq(
            address(getVaultByType(IRegistry.VaultType.ALPHA)), address(alphaVault), "Alpha vault helper incorrect"
        );
        assertEq(address(getVaultByType(IRegistry.VaultType.BETA)), address(betaVault), "Beta vault helper incorrect");
    }
}
