//// SPDX-License-Identifier: UNLICENSED
//pragma solidity 0.8.30;
//
//import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";
//import { IntegrationBaseTest } from "./IntegrationBaseTest.sol";
//import { IERC20 } from "forge-std/interfaces/IERC20.sol";
//
//import { IAdapter } from "src/interfaces/IAdapter.sol";
//import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
//import { IkMinter } from "src/interfaces/IkMinter.sol";
//import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
//
///// @title DNAlphaVaultIntegrationTest
///// @notice Integration tests for DN ↔ Alpha Vault interactions via kAssetRouter
///// @dev Tests asset rebalancing, yield distribution, and peg protection between institutional and retail vaults
//contract DNAlphaVaultIntegrationTest is IntegrationBaseTest {
//    /*//////////////////////////////////////////////////////////////
//                        ASSET REBALANCING TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test asset transfer from DN to Alpha for yield generation
//    function test_DNToAlphaAssetRebalancing() public {
//        uint256 institutionalMint = LARGE_AMOUNT;
//        uint256 rebalanceAmount = MEDIUM_AMOUNT;
//
//        // Setup: Institution mints, creating assets in DN vault
//        executeInstitutionalMint(users.institution, institutionalMint, users.institution);
//
//        // Validate initial state
//        assertVirtualBalance(
//            address(dnVault), USDC_MAINNET, institutionalMint, "DN vault should have full institutional mint"
//        );
//
//        assertVirtualBalance(address(alphaVault), USDC_MAINNET, 0, "Alpha vault should start empty");
//
//        // Execute rebalancing: Move excess assets to Alpha for yield generation
//        uint256 batchId = getCurrentDNBatchId();
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalanceAmount, batchId);
//
//        // Validate rebalancing results
//        assertVirtualBalance(
//            address(dnVault),
//            USDC_MAINNET,
//            institutionalMint - rebalanceAmount,
//            "DN vault balance after rebalancing out"
//        );
//
//        assertVirtualBalance(
//            address(alphaVault), USDC_MAINNET, rebalanceAmount, "Alpha vault balance after receiving rebalancing"
//        );
//
//        // Validate 1:1 backing still maintained for institutions
//        assert1to1BackingInvariant("After DN to Alpha rebalancing");
//    }
//
//    /// @dev Test retail staking with assets from DN vault rebalancing
//    function test_RetailStakingWithRebalancedAssets() public {
//        uint256 institutionalMint = LARGE_AMOUNT;
//        uint256 rebalanceAmount = MEDIUM_AMOUNT;
//        uint256 stakingAmount = SMALL_AMOUNT;
//
//        // Setup: Institutional mint and rebalance to Alpha
//        executeInstitutionalMint(users.institution, institutionalMint, users.institution);
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalanceAmount, getCurrentDNBatchId());
//
//        // Give user some kUSD for staking (from institutional mint)
//        vm.prank(users.institution);
//        kUSD.transfer(users.alice, stakingAmount);
//
//        // Execute retail staking in Alpha vault
//        uint256 requestId = executeRetailStaking(users.alice, address(alphaVault), stakingAmount, stakingAmount);
//
//        // Validate staking request created
//        assertTrue(requestId > 0, "Staking request should be created");
//
//        // Validate Alpha vault now has additional virtual balance from staking
//        assertVirtualBalance(
//            address(alphaVault),
//            USDC_MAINNET,
//            rebalanceAmount + stakingAmount,
//            "Alpha vault should have rebalanced + staked assets"
//        );
//
//        // Validate kUSD was transferred to Alpha vault
//        assertKTokenBalance(address(kUSD), users.alice, 0, "Alice should have transferred kUSD for staking");
//
//        assert1to1BackingInvariant("After retail staking with rebalanced assets");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        YIELD DISTRIBUTION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test yield generation in Alpha vault and distribution
//    function test_AlphaVaultYieldDistribution() public {
//        uint256 rebalanceAmount = LARGE_AMOUNT;
//        uint256 stakingAmount = MEDIUM_AMOUNT;
//        uint256 yieldAmount = SMALL_AMOUNT;
//
//        // Setup: DN rebalances to Alpha, retail user stakes
//        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalanceAmount, getCurrentDNBatchId());
//
//        // Give user kUSD and stake
//        vm.prank(users.institution);
//        kUSD.transfer(users.alice, stakingAmount);
//        executeRetailStaking(users.alice, address(alphaVault), stakingAmount, stakingAmount);
//
//        // Simulate yield generation in Alpha vault
//        uint256 preTotalAssets = IAdapter(alphaVault.adapter()).totalAssets(address(alphaVault));
//        uint256 newTotalAssets = preTotalAssets + yieldAmount;
//
//        // Update Alpha vault with new total assets (simulating yield)
//        vm.prank(users.admin);
//        alphaVault.updateLastTotalAssets(newTotalAssets);
//
//        // Validate yield was captured
//        assertEq(alphaVault.lastTotalAssets(), newTotalAssets, "Alpha vault should reflect yield generation");
//
//        // In a complete implementation, yield would be distributed
//        // For this test, we validate the yield is available for distribution
//        uint256 sharePrice = alphaVault.sharePrice();
//        assertTrue(sharePrice > _1_USDC, "Share price should increase with yield");
//
//        assert1to1BackingInvariant("After Alpha vault yield generation");
//    }
//
//    /// @dev Test yield distribution back to DN vault (profit sharing)
//    function test_YieldDistributionToDNVault() public {
//        uint256 rebalanceAmount = LARGE_AMOUNT;
//        uint256 yieldAmount = SMALL_AMOUNT;
//        uint256 dnSharePercent = 30; // 30% of yield goes back to DN
//
//        // Setup: DN vault rebalances to Alpha
//        executeInstitutionalMint(users.institution, LARGE_AMOUNT * 2, users.institution);
//        uint256 initialDNBalance = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);
//
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalanceAmount, getCurrentDNBatchId());
//
//        // Simulate yield generation in Alpha
//        uint256 preTotalAssets = alphaVault.lastTotalAssets();
//        vm.prank(users.admin);
//        alphaVault.updateLastTotalAssets(preTotalAssets + yieldAmount);
//
//        // Calculate DN vault's share of yield
//        uint256 dnYieldShare = (yieldAmount * dnSharePercent) / 100;
//
//        // Simulate yield distribution back to DN vault
//        executeVaultTransfer(address(alphaVault), address(dnVault), dnYieldShare, getCurrentAlphaBatchId());
//
//        // Validate DN vault received its share of yield
//        uint256 expectedDNBalance = initialDNBalance - rebalanceAmount + dnYieldShare;
//        assertVirtualBalance(address(dnVault), USDC_MAINNET, expectedDNBalance, "DN vault should receive yield
// share");
//
//        // Validate Alpha vault retains majority of yield
//        uint256 expectedAlphaBalance = rebalanceAmount + yieldAmount - dnYieldShare;
//        assertVirtualBalance(
//            address(alphaVault), USDC_MAINNET, expectedAlphaBalance, "Alpha vault should retain majority yield"
//        );
//
//        assert1to1BackingInvariant("After yield distribution to DN vault");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        PEG PROTECTION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test peg protection: DN pulls assets from Alpha for redemptions
//    function test_PegProtectionDNPullsFromAlpha() public {
//        uint256 institutionalMint = LARGE_AMOUNT;
//        uint256 rebalanceAmount = MEDIUM_AMOUNT * 2; // Large rebalance
//        uint256 redemptionAmount = LARGE_AMOUNT; // More than remaining in DN
//
//        // Setup: Institution mints, DN rebalances most assets to Alpha
//        executeInstitutionalMint(users.institution, institutionalMint, users.institution);
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalanceAmount, getCurrentDNBatchId());
//
//        uint256 dnBalanceBeforeRedemption = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);
//        uint256 alphaBalanceBeforeRedemption = assetRouter.getBalanceOf(address(alphaVault), USDC_MAINNET);
//
//        // Verify DN has insufficient assets for full redemption
//        assertTrue(dnBalanceBeforeRedemption < redemptionAmount, "DN vault should have insufficient assets");
//
//        // Institution requests large redemption
//        executeInstitutionalRedemption(users.institution, redemptionAmount, users.institution);
//
//        // Calculate shortfall and trigger peg protection
//        uint256 shortfall = redemptionAmount - dnBalanceBeforeRedemption;
//
//        // Execute peg protection: Alpha transfers assets back to DN
//        executeVaultTransfer(address(alphaVault), address(dnVault), shortfall, getCurrentAlphaBatchId());
//
//        // Validate peg protection worked
//        uint256 dnBalanceAfterProtection = assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET);
//        assertTrue(
//            dnBalanceAfterProtection >= redemptionAmount, "DN vault should have sufficient assets after peg
// protection"
//        );
//
//        assertEq(
//            assetRouter.getBalanceOf(address(alphaVault), USDC_MAINNET),
//            alphaBalanceBeforeRedemption - shortfall,
//            "Alpha vault should provide shortfall amount"
//        );
//
//        assert1to1BackingInvariant("After peg protection activation");
//    }
//
//    /// @dev Test peg protection with multiple Alpha vault positions
//    function test_PegProtectionMultipleAlphaPositions() public {
//        uint256 mintAmount = LARGE_AMOUNT * 2;
//        uint256 rebalance1 = MEDIUM_AMOUNT;
//        uint256 rebalance2 = SMALL_AMOUNT * 2;
//        uint256 redemptionAmount = mintAmount - SMALL_AMOUNT; // Almost full redemption
//
//        // Setup: Multiple rebalancing operations to Alpha
//        executeInstitutionalMint(users.institution, mintAmount, users.institution);
//
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalance1, getCurrentDNBatchId());
//        advanceToNextBatchCutoff();
//        executeVaultTransfer(address(dnVault), address(alphaVault), rebalance2, getCurrentDNBatchId());
//
//        uint256 totalRebalanced = rebalance1 + rebalance2;
//        uint256 dnBalanceBeforeRedemption = mintAmount - totalRebalanced;
//
//        // Large redemption requiring peg protection
//        executeInstitutionalRedemption(users.institution, redemptionAmount, users.institution);
//
//        uint256 shortfall = redemptionAmount - dnBalanceBeforeRedemption;
//
//        // Execute peg protection in portions (realistic scenario)
//        uint256 firstPull = shortfall / 2;
//        uint256 secondPull = shortfall - firstPull;
//
//        executeVaultTransfer(address(alphaVault), address(dnVault), firstPull, getCurrentAlphaBatchId());
//        executeVaultTransfer(address(alphaVault), address(dnVault), secondPull, getCurrentAlphaBatchId());
//
//        // Validate final balances
//        assertVirtualBalance(
//            address(dnVault),
//            USDC_MAINNET,
//            dnBalanceBeforeRedemption + shortfall,
//            "DN vault should have sufficient assets after staged peg protection"
//        );
//
//        assertVirtualBalance(
//            address(alphaVault), USDC_MAINNET, totalRebalanced - shortfall, "Alpha vault should provide total
// shortfall"
//        );
//
//        assert1to1BackingInvariant("After staged peg protection");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        COORDINATION TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test coordinated batch settlement across DN and Alpha vaults
//    function test_CoordinatedBatchSettlement() public {
//        uint256 dnAmount = LARGE_AMOUNT;
//        uint256 alphaAmount = MEDIUM_AMOUNT;
//
//        // Setup: Both vaults have pending operations
//        executeInstitutionalMint(users.institution, dnAmount, users.institution);
//        executeVaultTransfer(address(dnVault), address(alphaVault), alphaAmount, getCurrentDNBatchId());
//
//        // Add retail staking to Alpha
//        vm.prank(users.institution);
//        kUSD.transfer(users.alice, SMALL_AMOUNT);
//        executeRetailStaking(users.alice, address(alphaVault), SMALL_AMOUNT, SMALL_AMOUNT);
//
//        uint256 dnBatchId = getCurrentDNBatchId();
//        uint256 alphaBatchId = getCurrentAlphaBatchId();
//
//        // Advance to settlement time
//        advanceToSettlementTime();
//
//        // Execute coordinated settlement
//        executeBatchSettlement(address(dnVault), dnBatchId, dnAmount - alphaAmount);
//        executeBatchSettlement(address(alphaVault), alphaBatchId, alphaAmount + SMALL_AMOUNT);
//
//        // Validate both vaults settled correctly
//        assertBatchState(address(dnVault), dnBatchId, true, true, "DN vault batch settled");
//        assertBatchState(address(alphaVault), alphaBatchId, true, true, "Alpha vault batch settled");
//
//        // Validate consistency across vaults
//        assertVaultBalanceConsistency(address(dnVault), USDC_MAINNET, "DN vault post-settlement consistency");
//        assertVaultBalanceConsistency(address(alphaVault), USDC_MAINNET, "Alpha vault post-settlement consistency");
//
//        assert1to1BackingInvariant("After coordinated batch settlement");
//    }
//
//    /// @dev Test asset flow optimization between DN and Alpha
//    function test_AssetFlowOptimization() public {
//        uint256 baseAmount = LARGE_AMOUNT;
//
//        // Setup: Create imbalanced initial state
//        executeInstitutionalMint(users.institution, baseAmount, users.institution);
//
//        // Simulate multiple small rebalancing operations (inefficient)
//        uint256 numOperations = 5;
//        uint256 smallAmount = baseAmount / (numOperations * 2);
//
//        for (uint256 i = 0; i < numOperations; i++) {
//            executeVaultTransfer(address(dnVault), address(alphaVault), smallAmount, getCurrentDNBatchId() + i);
//        }
//
//        // Validate cumulative effect
//        assertVirtualBalance(
//            address(alphaVault), USDC_MAINNET, numOperations * smallAmount, "Alpha should accumulate small transfers"
//        );
//
//        // Now simulate optimization: Large reverse transfer
//        uint256 optimizationAmount = (numOperations * smallAmount) / 2;
//        executeVaultTransfer(address(alphaVault), address(dnVault), optimizationAmount, getCurrentAlphaBatchId());
//
//        // Validate optimization result
//        uint256 expectedAlphaBalance = (numOperations * smallAmount) - optimizationAmount;
//        assertVirtualBalance(
//            address(alphaVault), USDC_MAINNET, expectedAlphaBalance, "Alpha balance after optimization"
//        );
//
//        uint256 expectedDNBalance = baseAmount - (numOperations * smallAmount) + optimizationAmount;
//        assertVirtualBalance(address(dnVault), USDC_MAINNET, expectedDNBalance, "DN balance after optimization");
//
//        assert1to1BackingInvariant("After asset flow optimization");
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                        STRESS TESTS
//    //////////////////////////////////////////////////////////////*/
//
//    /// @dev Test high-frequency rebalancing between DN and Alpha
//    function test_HighFrequencyRebalancing() public {
//        uint256 totalAmount = LARGE_AMOUNT * 5;
//        uint256 numRebalances = 20;
//        uint256 rebalanceAmount = totalAmount / (numRebalances * 2);
//
//        // Setup: Large institutional mint
//        executeInstitutionalMint(users.institution, totalAmount, users.institution);
//
//        // Execute high-frequency back-and-forth rebalancing
//        for (uint256 i = 0; i < numRebalances; i++) {
//            if (i % 2 == 0) {
//                // DN to Alpha
//                executeVaultTransfer(address(dnVault), address(alphaVault), rebalanceAmount, getCurrentDNBatchId() +
// i);
//            } else {
//                // Alpha to DN
//                executeVaultTransfer(
//                    address(alphaVault), address(dnVault), rebalanceAmount / 2, getCurrentAlphaBatchId() + i
//                );
//            }
//        }
//
//        // Calculate expected final balances
//        uint256 netToAlpha = (numRebalances / 2) * rebalanceAmount - (numRebalances / 2) * (rebalanceAmount / 2);
//        uint256 expectedDNBalance = totalAmount - netToAlpha;
//        uint256 expectedAlphaBalance = netToAlpha;
//
//        // Validate final state
//        assertVirtualBalance(
//            address(dnVault), USDC_MAINNET, expectedDNBalance, "DN balance after high-frequency rebalancing"
//        );
//        assertVirtualBalance(
//            address(alphaVault), USDC_MAINNET, expectedAlphaBalance, "Alpha balance after high-frequency rebalancing"
//        );
//
//        // Validate consistency maintained throughout
//        assertVaultBalanceConsistency(address(dnVault), USDC_MAINNET, "DN vault consistency after stress test");
//        assertVaultBalanceConsistency(address(alphaVault), USDC_MAINNET, "Alpha vault consistency after stress test");
//
//        assert1to1BackingInvariant("After high-frequency rebalancing stress test");
//    }
//
//    /// @dev Test DN-Alpha coordination under extreme conditions
//    function test_ExtremeConditionCoordination() public {
//        uint256 massiveAmount = 1_000_000_000 * _1_USDC; // 1B USDC
//
//        // Setup: Massive institutional position
//        deal(USDC_MAINNET, users.institution, massiveAmount);
//        executeInstitutionalMint(users.institution, massiveAmount, users.institution);
//
//        // Extreme rebalancing: 90% to Alpha
//        uint256 extremeRebalance = (massiveAmount * 90) / 100;
//        executeVaultTransfer(address(dnVault), address(alphaVault), extremeRebalance, getCurrentDNBatchId());
//
//        // Validate extreme positions handled correctly
//        assertVirtualBalance(
//            address(dnVault), USDC_MAINNET, massiveAmount - extremeRebalance, "DN after extreme rebalance"
//        );
//        assertVirtualBalance(address(alphaVault), USDC_MAINNET, extremeRebalance, "Alpha after extreme rebalance");
//
//        // Extreme redemption request: 95% of institutional position
//        uint256 extremeRedemption = (massiveAmount * 95) / 100;
//        executeInstitutionalRedemption(users.institution, extremeRedemption, users.institution);
//
//        // Calculate massive shortfall requiring peg protection
//        uint256 dnBalance = massiveAmount - extremeRebalance;
//        uint256 shortfall = extremeRedemption - dnBalance;
//
//        // Execute massive peg protection
//        executeVaultTransfer(address(alphaVault), address(dnVault), shortfall, getCurrentAlphaBatchId());
//
//        // Validate extreme peg protection worked
//        assertTrue(
//            assetRouter.getBalanceOf(address(dnVault), USDC_MAINNET) >= extremeRedemption,
//            "DN should handle extreme peg protection"
//        );
//
//        assert1to1BackingInvariant("After extreme condition coordination");
//    }
//}
//
