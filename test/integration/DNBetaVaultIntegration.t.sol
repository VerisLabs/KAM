// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";
import { IntegrationBaseTest } from "./IntegrationBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

/// @title DNBetaVaultIntegrationTest
/// @notice Integration tests for DN ↔ Beta Vault interactions via kAssetRouter
/// @dev Tests advanced strategies, risk isolation, and emergency recovery between institutional and beta vaults
contract DNBetaVaultIntegrationTest is IntegrationBaseTest {
    /// @dev Set up modules for DN and Beta vaults to support batch operations
    function setUp() public override {
        super.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                        ADVANCED STRATEGY DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test asset deployment from DN to Beta for advanced strategies
    function test_DNToBetaStrategyDeployment() public {
        uint256 institutionalMint = LARGE_AMOUNT;
        uint256 strategyDeployment = MEDIUM_AMOUNT;

        // Setup: Institution mints, creating assets in DN vault
        executeInstitutionalMint(users.institution, institutionalMint, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, institutionalMint);

        // Validate initial state
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, institutionalMint, "DN vault should have full institutional mint"
        );

        assertVirtualBalance(address(betaVault), USDC_MAINNET, 0, "Beta vault should start empty");

        // Execute strategy deployment: Move assets to Beta for advanced strategies
        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), strategyDeployment, transferBatch);

        // Settlement required to update virtual balances
        executeBatchSettlement(address(dnVault), transferBatch, institutionalMint - strategyDeployment);
        executeBatchSettlement(address(betaVault), transferBatch, strategyDeployment);

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

    /// @dev Test Beta vault advanced strategy execution with yield simulation
    function test_BetaVaultAdvancedStrategyExecution() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyReturn = SMALL_AMOUNT; // Positive return

        // Setup: Deploy assets from DN to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets to Beta vault
        executeBatchSettlement(address(dnVault), transferBatch, LARGE_AMOUNT * 2 - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        // Simulate advanced strategy execution with positive return through settlement
        bytes32 yieldBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), yieldBatch, deploymentAmount + strategyReturn);

        // Validate strategy return captured
        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            deploymentAmount + strategyReturn,
            "Beta vault should reflect strategy returns"
        );

        assert1to1BackingInvariant("After Beta strategy execution");
    }

    /*//////////////////////////////////////////////////////////////
                        RISK ISOLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test Beta vault losses don't affect DN vault 1:1 backing
    function test_BetaVaultLossIsolation() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyLoss = SMALL_AMOUNT; // Moderate loss to avoid underflow

        // Setup: Deploy assets from DN to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        uint256 initialDNBalance = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, initialDNBalance - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        // Simulate strategy loss in Beta vault through settlement with reduced amount
        bytes32 lossBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), lossBatch, deploymentAmount - strategyLoss);

        // Validate loss is contained in Beta vault
        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            deploymentAmount - strategyLoss,
            "Beta vault should reflect strategy losses"
        );

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
        uint256 strategyLoss = SMALL_AMOUNT / 2; // Small loss
        uint256 redemptionAmount = SMALL_AMOUNT; // Small redemption within DN capacity

        // Setup: Mint, deploy to Beta, simulate loss
        executeInstitutionalMint(users.institution, mintAmount, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, mintAmount);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, mintAmount - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        // Simulate Beta strategy loss through settlement
        bytes32 lossBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), lossBatch, deploymentAmount - strategyLoss);

        // Institution requests redemption (within DN capacity)
        executeInstitutionalRedemption(users.institution, redemptionAmount, users.institution);

        // Validate redemption processed despite Beta losses
        assertEq(
            kUSD.balanceOf(users.institution),
            mintAmount - redemptionAmount,
            "Institution should receive full redemption despite Beta losses"
        );

        // Note: kUSD supply doesn't decrease until redemption is settled, but request is processed
        assertEq(kUSD.totalSupply(), mintAmount, "kUSD supply remains unchanged until redemption settlement");

        // Beta losses should not impact institutional 1:1 backing
        assert1to1BackingInvariant("After institutional redemption with Beta losses");
    }

    /// @dev Test risk isolation with multiple Beta strategies
    function test_MultipleBetaStrategyRiskIsolation() public {
        uint256 deployment1 = MEDIUM_AMOUNT;
        uint256 deployment2 = SMALL_AMOUNT * 2;
        uint256 loss1 = SMALL_AMOUNT / 4; // Smaller loss
        uint256 gain2 = SMALL_AMOUNT / 8; // Smaller gain

        // Setup: Multiple deployments to Beta at different times
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        // First strategy deployment
        bytes32 transferBatch1 = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deployment1, transferBatch1);

        // Settlement for first deployment
        executeBatchSettlement(address(dnVault), transferBatch1, LARGE_AMOUNT * 2 - deployment1);
        executeBatchSettlement(address(betaVault), transferBatch1, deployment1);

        advanceToNextBatchCutoff();

        // Second strategy deployment
        bytes32 transferBatch2 = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deployment2, transferBatch2);

        // Settlement for second deployment
        uint256 dnBalanceAfterFirst = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);
        executeBatchSettlement(address(dnVault), transferBatch2, dnBalanceAfterFirst - deployment2);
        executeBatchSettlement(address(betaVault), transferBatch2, deployment1 + deployment2);

        // Simulate mixed results: net effect through settlement
        uint256 netResult = deployment1 + deployment2 - loss1 + gain2;
        bytes32 mixedBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), mixedBatch, netResult);

        // Validate net result captured in Beta
        assertVirtualBalance(address(betaVault), USDC_MAINNET, netResult, "Beta should reflect net strategy results");

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
        uint256 emergencyRecoveryAmount = MEDIUM_AMOUNT / 2; // Ensure DN has enough after initial redemption

        // Setup: Deploy significant assets to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, LARGE_AMOUNT * 2 - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        uint256 dnBalanceBeforeRecovery = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);
        uint256 betaBalanceBeforeRecovery = custodialAdapter.totalAssets(address(betaVault), USDC_MAINNET);

        // Simulate emergency condition requiring asset recovery (small redemption first)
        uint256 smallRedemption = dnBalanceBeforeRecovery / 2;
        executeInstitutionalRedemption(users.institution, smallRedemption, users.institution);

        // Now simulate additional need that requires Beta recovery
        uint256 additionalNeed = emergencyRecoveryAmount;

        // Execute emergency recovery from Beta to DN using consistent batch ID
        bytes32 recoveryBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(betaVault), address(dnVault), additionalNeed, recoveryBatch);

        // Settlement required for recovery
        executeBatchSettlement(address(betaVault), recoveryBatch, betaBalanceBeforeRecovery - additionalNeed);
        executeBatchSettlement(
            address(dnVault), recoveryBatch, dnBalanceBeforeRecovery - smallRedemption + additionalNeed
        );

        // Validate emergency recovery
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            dnBalanceBeforeRecovery - smallRedemption + additionalNeed,
            "DN vault should receive emergency recovery assets"
        );

        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            betaBalanceBeforeRecovery - additionalNeed,
            "Beta vault should provide emergency recovery assets"
        );

        assert1to1BackingInvariant("After emergency asset recovery");
    }

    /// @dev Test Beta vault liquidation and recovery
    function test_BetaVaultLiquidationRecovery() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 majorLoss = deploymentAmount / 4; // 25% loss to avoid excessive losses

        // Setup: Deploy to Beta and simulate loss
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, LARGE_AMOUNT * 2 - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        // Simulate major strategy failure through settlement with loss
        uint256 postLossAssets = deploymentAmount - majorLoss;
        bytes32 lossBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), lossBatch, postLossAssets);

        // Execute emergency liquidation - recover remaining assets
        bytes32 recoveryBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(betaVault), address(dnVault), postLossAssets, recoveryBatch);

        // Settlement for liquidation
        uint256 dnBalanceBeforeLiquidation = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);
        executeBatchSettlement(address(betaVault), recoveryBatch, 0);
        executeBatchSettlement(address(dnVault), recoveryBatch, dnBalanceBeforeLiquidation + postLossAssets);

        // Validate complete liquidation recovery
        assertVirtualBalance(address(betaVault), USDC_MAINNET, 0, "Beta vault should be completely liquidated");

        // DN vault receives whatever was recoverable
        uint256 expectedDNBalance = dnBalanceBeforeLiquidation + postLossAssets;
        assertVirtualBalance(
            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should receive liquidation recovery"
        );

        assert1to1BackingInvariant("After Beta vault liquidation recovery");
    }

    /*//////////////////////////////////////////////////////////////
                        PROFIT/LOSS DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test Beta vault profit distribution back to DN
    function test_BetaVaultProfitDistribution() public {
        uint256 deploymentAmount = LARGE_AMOUNT;
        uint256 strategyProfit = MEDIUM_AMOUNT / 2; // Reasonable profit
        uint256 dnProfitShare = 25; // 25% to DN vault

        // Setup: Deploy to Beta and generate profit
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        uint256 initialDNBalance = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, initialDNBalance - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        // Simulate significant Beta strategy profit through settlement
        bytes32 profitBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), profitBatch, deploymentAmount + strategyProfit);

        // Calculate and distribute profit share to DN
        uint256 dnProfitAmount = (strategyProfit * dnProfitShare) / 100;
        bytes32 distributionBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(betaVault), address(dnVault), dnProfitAmount, distributionBatch);

        // Settlement for profit distribution
        uint256 betaBalanceAfterProfit = custodialAdapter.totalAssets(address(betaVault), USDC_MAINNET);
        uint256 dnBalanceBeforeDistribution = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);

        executeBatchSettlement(address(betaVault), distributionBatch, betaBalanceAfterProfit - dnProfitAmount);
        executeBatchSettlement(address(dnVault), distributionBatch, dnBalanceBeforeDistribution + dnProfitAmount);

        // Validate profit distribution
        uint256 expectedDNBalance = dnBalanceBeforeDistribution + dnProfitAmount;
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
        uint256 strategyLoss = SMALL_AMOUNT; // Moderate loss

        // Setup: Deploy to Beta
        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, LARGE_AMOUNT * 2);

        uint256 initialDNBalance = custodialAdapter.totalAssets(address(dnVault), USDC_MAINNET);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), deploymentAmount, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, initialDNBalance - deploymentAmount);
        executeBatchSettlement(address(betaVault), transferBatch, deploymentAmount);

        // Simulate Beta strategy loss through settlement
        bytes32 lossBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), lossBatch, deploymentAmount - strategyLoss);

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
                        STRESS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test extreme Beta strategy performance scenarios
    function test_ExtremeBetaStrategyPerformance() public {
        uint256 massiveDeployment = 1_000_000_000 * _1_USDC; // 1B USDC
        uint256 extremeGain = 100_000_000 * _1_USDC; // 100M gain (10% return)
        uint256 extremeLoss = 50_000_000 * _1_USDC; // 50M loss (5% loss)

        // Setup: Massive deployment to Beta
        deal(USDC_MAINNET, users.institution, massiveDeployment * 2);
        executeInstitutionalMint(users.institution, massiveDeployment * 2, users.institution);

        // Settlement required to move assets from kMinter to DN vault
        bytes32 currentBatch = getCurrentDNBatchId();
        executeBatchSettlement(address(minter), currentBatch, massiveDeployment * 2);

        bytes32 transferBatch = getCurrentDNBatchId();
        executeVaultTransfer(address(dnVault), address(betaVault), massiveDeployment, transferBatch);

        // Settlement required to move assets
        executeBatchSettlement(address(dnVault), transferBatch, massiveDeployment * 2 - massiveDeployment);
        executeBatchSettlement(address(betaVault), transferBatch, massiveDeployment);

        // Test extreme gain scenario through settlement
        bytes32 gainBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), gainBatch, massiveDeployment + extremeGain);

        // Validate extreme gain handled
        assertVirtualBalance(
            address(betaVault), USDC_MAINNET, massiveDeployment + extremeGain, "Beta should handle extreme gains"
        );

        // Test extreme loss scenario through settlement
        bytes32 lossBatch = getCurrentBetaBatchId();
        executeBatchSettlement(address(betaVault), lossBatch, massiveDeployment + extremeGain - extremeLoss);

        // Validate extreme loss handled and isolated
        assertVirtualBalance(
            address(betaVault),
            USDC_MAINNET,
            massiveDeployment + extremeGain - extremeLoss,
            "Beta should handle extreme losses"
        );

        // DN vault should be completely unaffected
        uint256 expectedDNBalance = massiveDeployment;
        assertVirtualBalance(
            address(dnVault),
            USDC_MAINNET,
            expectedDNBalance,
            "DN vault should be unaffected by extreme Beta performance"
        );

        assert1to1BackingInvariant("After extreme Beta strategy performance");
    }
}
