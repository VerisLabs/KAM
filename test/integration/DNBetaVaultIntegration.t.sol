// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";
import { IntegrationBaseTest } from "./IntegrationBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

/// @title DNBetaVaultIntegrationTest
/// @notice Integration tests for DN ↔ Beta Vault interactions via kAssetRouter
/// @dev Tests advanced strategies, risk isolation, and emergency recovery between institutional and beta vaults
contract DNBetaVaultIntegrationTest is IntegrationBaseTest {
    /*//////////////////////////////////////////////////////////////
                        ADVANCED STRATEGY DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test asset deployment from DN to Beta for advanced strategies
    function test_DNToBetaStrategyDeployment() public {
        uint256 institutionalMint = LARGE_AMOUNT;
        uint256 strategyDeployment = MEDIUM_AMOUNT;

        // Setup: Institution mints, creating assets in DN vault
        executeInstitutionalMint(users.institution, institutionalMint, users.institution);

        // Validate initial state
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, institutionalMint, "DN vault should have full institutional mint"
        );

        assertVirtualBalance(address(betaVault), USDC_MAINNET, 0, "Beta vault should start empty");

        // Execute strategy deployment: Move assets to Beta for advanced strategies
        uint256 batchId = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), strategyDeployment, batchId);

        // Validate deployment results
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            institutionalMint - strategyDeployment,
            "DN vault balance after strategy deployment"
        );

        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            strategyDeployment,
            "Beta vault balance after receiving strategy deployment"
        );

        // Validate 1:1 backing maintained despite risky deployment
        assert1to1BackingInvariant("After DN to Beta strategy deployment");
    }

    /// @dev Test Beta vault advanced strategy execution
    function test_BetaVaultAdvancedStrategyExecution() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyReturn = SMALL_AMOUNT; // Positive return

        // Setup: Deploy assets from DN to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        // Simulate advanced strategy execution with positive return
        uint256 preTotalAssets = betaVault.lastTotalAssets();
        uint256 newTotalAssets = preTotalAssets + strategyReturn;

        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(newTotalAssets);

        // Validate strategy return captured
        assertEq(betaVault.lastTotalAssets(), newTotalAssets, "Beta vault should reflect strategy returns");

        // Beta strategies should have higher risk/reward - check share price appreciation
        uint256 sharePrice = betaVault.sharePrice();
        assertTrue(sharePrice > _1_USDC, "Beta share price should increase with strategy returns");

        assert1to1BackingInvariant("After Beta strategy execution");
    }

    /*//////////////////////////////////////////////////////////////
                        RISK ISOLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test Beta vault losses don't affect DN vault 1:1 backing
    function test_BetaVaultLossIsolation() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyLoss = MEDIUM_AMOUNT; // Significant loss

        // Setup: Deploy assets from DN to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
        uint256 initialDNBalance = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);

        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        // Simulate strategy loss in Beta vault
        uint256 preTotalAssets = betaVault.lastTotalAssets();
        assertTrue(preTotalAssets >= strategyLoss, "Ensure loss doesn't exceed assets");

        uint256 newTotalAssets = preTotalAssets - strategyLoss;
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(newTotalAssets);

        // Validate loss is contained in Beta vault
        assertEq(betaVault.lastTotalAssets(), newTotalAssets, "Beta vault should reflect strategy losses");

        // Validate DN vault balance unaffected by Beta losses
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            initialDNBalance - deploymentAmount,
            "DN vault balance should be unaffected by Beta losses"
        );

        // Validate 1:1 backing still holds despite Beta losses
        assert1to1BackingInvariant("After Beta vault loss isolation");
    }

    /// @dev Test institutional redemption with Beta vault in loss position
    function test_InstitutionalRedemptionWithBetaLosses() public {
        uint256 mintAmount = LARGE_AMOUNT;
        uint256 deploymentAmount = MEDIUM_AMOUNT;
        uint256 strategyLoss = SMALL_AMOUNT;
        uint256 redemptionAmount = MEDIUM_AMOUNT;

        // Setup: Mint, deploy to Beta, simulate loss
        executeInstitutionalMint(users.institution, mintAmount, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        // Simulate Beta strategy loss
        uint256 betaAssets = betaVault.lastTotalAssets();
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(betaAssets - strategyLoss);

        // Institution requests redemption
        executeInstitutionalRedemption(users.institution, redemptionAmount, users.institution);

        // Validate redemption processed despite Beta losses
        assertEq(
            kUSD.balanceOf(users.institution),
            mintAmount - redemptionAmount,
            "Institution should receive full redemption despite Beta losses"
        );

        assertEq(kUSD.totalSupply(), mintAmount - redemptionAmount, "kUSD supply should decrease by redemption amount");

        // Beta losses should not impact institutional 1:1 backing
        assert1to1BackingInvariant("After institutional redemption with Beta losses");
    }

    /// @dev Test risk isolation with multiple Beta strategies
    function test_MultipleBetaStrategyRiskIsolation() public {
        uint256 deployment1 = MEDIUM_AMOUNT;
        uint256 deployment2 = SMALL_AMOUNT * 2;
        uint256 loss1 = SMALL_AMOUNT / 2;
        uint256 gain2 = SMALL_AMOUNT / 4;

        // Setup: Multiple deployments to Beta at different times
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // First strategy deployment
        executeVaultTransfer(address(dnVault), address(betaVault), deployment1, getCurrentDNBatchId());

        advanceToNextBatchCutoff();

        // Second strategy deployment
        executeVaultTransfer(address(dnVault), address(betaVault), deployment2, getCurrentDNBatchId());

        // Simulate mixed results: loss on first, gain on second
        uint256 initialBetaAssets = betaVault.lastTotalAssets();
        uint256 netResult = initialBetaAssets - loss1 + gain2;

        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(netResult);

        // Validate net result captured in Beta
        assertEq(betaVault.lastTotalAssets(), netResult, "Beta should reflect net strategy results");

        // Validate DN vault unaffected by Beta strategy results
        uint256 expectedDNBalance = (LARGE_AMOUNT * 2) - deployment1 - deployment2;
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should be isolated from Beta strategy results"
        );

        assert1to1BackingInvariant("After multiple Beta strategy risk isolation");
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY RECOVERY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test emergency asset recovery from Beta to DN
    function test_EmergencyAssetRecoveryFromBeta() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 emergencyRecoveryAmount = MEDIUM_AMOUNT;

        // Setup: Deploy significant assets to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        uint256 dnBalanceBeforeRecovery = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);
        uint256 betaBalanceBeforeRecovery = assetRouter.getBalanceOf(address(betaVault), USDC_MAINNET);

        // Simulate emergency condition requiring asset recovery
        // (e.g., large institutional redemption request)
        uint256 largeRedemption = dnBalanceBeforeRecovery + emergencyRecoveryAmount;
        executeInstitutionalRedemption(users.institution, largeRedemption, users.institution);

        // Execute emergency recovery from Beta to DN
        executeVaultTransfer(address(betaVault), address(dnVault), emergencyRecoveryAmount, getCurrentBetaBatchId());

        // Validate emergency recovery
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            dnBalanceBeforeRecovery + emergencyRecoveryAmount,
            "DN vault should receive emergency recovery assets"
        );

        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            betaBalanceBeforeRecovery - emergencyRecoveryAmount,
            "Beta vault should provide emergency recovery assets"
        );

        // Validate DN can now handle the large redemption
        assertTrue(
            assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET) >= largeRedemption,
            "DN should have sufficient assets after emergency recovery"
        );

        assert1to1BackingInvariant("After emergency asset recovery");
    }

    /// @dev Test Beta vault liquidation and recovery
    function test_BetaVaultLiquidationRecovery() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 majorLoss = deploymentAmount / 2; // 50% loss

        // Setup: Deploy to Beta and simulate major loss
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        // Simulate major strategy failure
        uint256 betaAssets = betaVault.lastTotalAssets();
        uint256 postLossAssets = betaAssets - majorLoss;

        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(postLossAssets);

        // Execute emergency liquidation - recover remaining assets
        uint256 recoveryAmount = postLossAssets;
        executeVaultTransfer(address(betaVault), address(dnVault), recoveryAmount, getCurrentBetaBatchId());

        // Validate complete liquidation recovery
        assertVirtualBalance(address(betaVault), USDC_MAINNET, 0, "Beta vault should be completely liquidated");

        // DN vault receives whatever was recoverable
        uint256 expectedDNBalance = (LARGE_AMOUNT * 2) - deploymentAmount + recoveryAmount;
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should receive liquidation recovery"
        );

        // Total protocol loss should be isolated to the strategy loss
        uint256 totalProtocolAssets = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET)
            + assetRouter.getBalanceOf(address(alphaVault), USDC_MAINNET)
            + assetRouter.getBalanceOf(address(betaVault), USDC_MAINNET);

        assertEq(
            totalProtocolAssets,
            (LARGE_AMOUNT * 2) - majorLoss,
            "Total protocol assets should reflect only the strategy loss"
        );

        assert1to1BackingInvariant("After Beta vault liquidation recovery");
    }

    /*//////////////////////////////////////////////////////////////
                        PROFIT/LOSS DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test Beta vault profit distribution back to DN
    function test_BetaVaultProfitDistribution() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyProfit = MEDIUM_AMOUNT;
        uint256 dnProfitShare = 25; // 25% to DN vault

        // Setup: Deploy to Beta and generate profit
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
        uint256 initialDNBalance = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);

        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        // Simulate significant Beta strategy profit
        uint256 betaAssets = betaVault.lastTotalAssets();
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(betaAssets + strategyProfit);

        // Calculate and distribute profit share to DN
        uint256 dnProfitAmount = (strategyProfit * dnProfitShare) / 100;
        executeVaultTransfer(address(betaVault), address(dnVault), dnProfitAmount, getCurrentBetaBatchId());

        // Validate profit distribution
        uint256 expectedDNBalance = initialDNBalance - deploymentAmount + dnProfitAmount;
        assertVirtualBalance(address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should receive profit share");

        uint256 expectedBetaBalance = deploymentAmount + strategyProfit - dnProfitAmount;
        assertVirtualBalance(
            address(betaVault), USDC_MAINNET, expectedBetaBalance, "Beta vault should retain majority of profit"
        );

        assert1to1BackingInvariant("After Beta profit distribution");
    }

    /// @dev Test Beta vault loss absorption (no impact on DN)
    function test_BetaVaultLossAbsorption() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyLoss = MEDIUM_AMOUNT;

        // Setup: Deploy to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
        uint256 initialDNBalance = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);

        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, getCurrentDNBatchId());

        // Simulate Beta strategy loss
        uint256 betaAssets = betaVault.lastTotalAssets();
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(betaAssets - strategyLoss);

        // No transfer back to DN - loss is absorbed by Beta

        // Validate DN vault unaffected
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            initialDNBalance - deploymentAmount,
            "DN vault should be unaffected by Beta losses"
        );

        // Beta vault absorbs the full loss
        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            deploymentAmount - strategyLoss,
            "Beta vault should absorb strategy losses"
        );

        // Protocol-wide loss is isolated to Beta deployment
        assert1to1BackingInvariant("After Beta loss absorption");
    }

    /*//////////////////////////////////////////////////////////////
                        ADVANCED COORDINATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test DN-Beta coordination during high volatility
    function test_DNBetaHighVolatilityCoordination() public {
        uint256 baseDeployment = LARGE_AMOUNT;
        uint256 volatilityRange = MEDIUM_AMOUNT;

        // Setup: Initial deployment to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 3, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), baseDeployment, getCurrentDNBatchId());

        // Simulate high volatility: rapid gains and losses
        for (uint256 i = 0; i < 5; i++) {
            uint256 betaAssets = betaVault.lastTotalAssets();

            if (i % 2 == 0) {
                // Volatile gain
                vm.prank(users.admin);
                betaVault.updateLastTotalAssets(betaAssets + volatilityRange);
            } else {
                // Volatile loss
                uint256 newAssets = betaAssets > volatilityRange ? betaAssets - volatilityRange : betaAssets / 2;
                vm.prank(users.admin);
                betaVault.updateLastTotalAssets(newAssets);
            }

            advanceToNextBatchCutoff();
        }

        // Validate DN vault remained stable throughout volatility
        uint256 expectedDNBalance = (LARGE_AMOUNT * 3) - baseDeployment;
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should remain stable during Beta volatility"
        );

        // Validate protocol integrity maintained
        assert1to1BackingInvariant("After high volatility coordination");
    }

    /// @dev Test Beta vault strategy rotation with DN coordination
    function test_BetaStrategyRotationWithDNCoordination() public {
        uint256 strategy1Deployment = LARGE_AMOUNT;
        uint256 strategy2Deployment = MEDIUM_AMOUNT;
        uint256 strategy1Return = SMALL_AMOUNT;

        // Setup: Deploy to Beta strategy 1
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 3, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), strategy1Deployment, getCurrentDNBatchId());

        // Strategy 1 generates return
        uint256 betaAssets = betaVault.lastTotalAssets();
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(betaAssets + strategy1Return);

        // Partially exit strategy 1, redeploy to strategy 2
        uint256 partialExit = strategy1Deployment / 2;
        executeVaultTransfer(address(betaVault), address(dnVault), partialExit, getCurrentBetaBatchId());

        advanceToNextBatchCutoff();

        // Redeploy for strategy 2
        executeVaultTransfer(address(dnVault), address(betaVault), strategy2Deployment, getCurrentDNBatchId());

        // Validate strategy rotation coordination
        uint256 expectedBetaBalance = (strategy1Deployment + strategy1Return) - partialExit + strategy2Deployment;
        assertVirtualBalance(
            address(betaVault), USDC_MAINNET, expectedBetaBalance, "Beta vault should reflect strategy rotation"
        );

        uint256 expectedDNBalance = (LARGE_AMOUNT * 3) - strategy1Deployment + partialExit - strategy2Deployment;
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should coordinate strategy rotation"
        );

        assert1to1BackingInvariant("After Beta strategy rotation");
    }

    /*//////////////////////////////////////////////////////////////
                        STRESS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test extreme Beta strategy performance scenarios
    function test_ExtremeBetaStrategyPerformance() public {
        uint256 massiveDeployment = 100_000_000 * _1_USDC; // 100M USDC
        uint256 extremeGain = 50_000_000 * _1_USDC; // 50M gain (50% return)
        uint256 extremeLoss = 30_000_000 * _1_USDC; // 30M loss (30% loss)

        // Setup: Massive deployment to Beta
        deal(USDC_MAINNET, users.institution, massiveDeployment * 2);
        executeInstitutionalMint(users.institution, massiveDeployment * 2, users.institution);
        executeVaultTransfer(address(dnVault), address(betaVault), massiveDeployment, getCurrentDNBatchId());

        // Test extreme gain scenario
        uint256 betaAssets = betaVault.lastTotalAssets();
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(betaAssets + extremeGain);

        // Validate extreme gain handled
        assertEq(betaVault.lastTotalAssets(), betaAssets + extremeGain, "Beta should handle extreme gains");

        // Test extreme loss scenario
        vm.prank(users.admin);
        betaVault.updateLastTotalAssets(betaAssets + extremeGain - extremeLoss);

        // Validate extreme loss handled and isolated
        assertEq(
            betaVault.lastTotalAssets(), betaAssets + extremeGain - extremeLoss, "Beta should handle extreme losses"
        );

        // DN vault should be completely unaffected
        uint256 expectedDNBalance = (massiveDeployment * 2) - massiveDeployment;
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            expectedDNBalance,
            "DN vault should be unaffected by extreme Beta performance"
        );

        assert1to1BackingInvariant("After extreme Beta strategy performance");
    }
}
