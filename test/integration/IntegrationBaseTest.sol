// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    BATCH_CUTOFF_TIME,
    SETTLEMENT_INTERVAL,
    USDC_MAINNET,
    _1000_USDC,
    _100_USDC,
    _1_USDC
} from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

/// @title IntegrationBaseTest
/// @notice Base contract for integration tests with specialized utilities
/// @dev Extends DeploymentBaseTest with integration-specific helpers
contract IntegrationBaseTest is DeploymentBaseTest {
    bool useMetaVault = false;

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TEST CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant SMALL_AMOUNT = 100 * _1_USDC;
    uint256 internal constant MEDIUM_AMOUNT = 1000 * _1_USDC;
    uint256 internal constant LARGE_AMOUNT = 10_000 * _1_USDC;

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TEST EVENTS
    //////////////////////////////////////////////////////////////*/

    event IntegrationFlowStarted(string flowName, uint256 timestamp);
    event IntegrationFlowCompleted(string flowName, uint256 duration);
    event VirtualBalanceValidated(address vault, address asset, uint256 balance);
    event BatchStateValidated(bytes32 batchId, bool isClosed, bool isSettled);

    /*//////////////////////////////////////////////////////////////
                        SETUP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        super.setUp();

        // Additional setup for integration tests
        _prepareIntegrationEnvironment();

        if(useMetaVault) {
            vm.prank(users.admin);
            registry.removeAdapter(address(dnVault), address(custodialAdapter));
            vm.prank(users.admin);
            registry.registerAdapter(address(dnVault), address(metaVaultAdapter));
        }
    }

    /// @dev Prepare environment specifically for integration testing
    function _prepareIntegrationEnvironment() internal {
        // Ensure all users have sufficient balances for integration tests
        if (useMainnetFork) {
            deal(USDC_MAINNET, users.alice, 1_000_000 * _1_USDC);
            deal(USDC_MAINNET, users.bob, 1_000_000 * _1_USDC);
            deal(USDC_MAINNET, users.charlie, 1_000_000 * _1_USDC);
            deal(USDC_MAINNET, users.institution, 50_000_000 * _1_USDC);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TIME MANIPULATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Advance time to the next batch cutoff for integration tests
    function advanceToNextBatchCutoff() internal {
        vm.warp(block.timestamp + BATCH_CUTOFF_TIME);
        emit IntegrationFlowStarted("BatchCutoffAdvanced", block.timestamp);
    }

    /// @dev Advance time to settlement period for integration tests
    function advanceToSettlementTime() internal {
        vm.warp(block.timestamp + SETTLEMENT_INTERVAL);
        emit IntegrationFlowStarted("SettlementAdvanced", block.timestamp);
    }

    /// @dev Advance time by a specific duration
    function advanceTimeBy(uint256 duration) internal {
        vm.warp(block.timestamp + duration);
    }

    /// @dev Get current batch ID for a vault
    function getCurrentBatchId(IkStakingVault vault) internal view returns (bytes32) {
        return vault.getBatchId();
    }

    /// @dev Get current batch ID for DN vault
    function getCurrentDNBatchId() internal view returns (bytes32) {
        return IkStakingVault(address(dnVault)).getBatchId();
    }

    /// @dev Get current batch ID for Alpha vault
    function getCurrentAlphaBatchId() internal view returns (bytes32) {
        return IkStakingVault(address(alphaVault)).getBatchId();
    }

    /// @dev Get current batch ID for Beta vault
    function getCurrentBetaBatchId() internal view returns (bytes32) {
        return IkStakingVault(address(betaVault)).getBatchId();
    }

    /*//////////////////////////////////////////////////////////////
                        INSTITUTIONAL FLOW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Execute institutional mint through kMinter
    function executeInstitutionalMint(address user, uint256 amount, address recipient) internal {
        vm.startPrank(user);

        // Approve USDC to minter
        IERC20(USDC_MAINNET).approve(address(minter), amount);

        emit IntegrationFlowStarted("InstitutionalMint", block.timestamp);
        uint256 startTime = block.timestamp;

        // Execute mint with individual parameters
        minter.mint(USDC_MAINNET, recipient, amount);

        vm.stopPrank();

        emit IntegrationFlowCompleted("InstitutionalMint", block.timestamp - startTime);
    }

    /// @dev Execute institutional redemption request
    function executeInstitutionalRedemption(
        address user,
        uint256 amount,
        address recipient
    )
        internal
        returns (bytes32 requestId)
    {
        vm.startPrank(user);

        // Approve kUSD to minter for burning
        kUSD.approve(address(minter), amount);

        emit IntegrationFlowStarted("InstitutionalRedemption", block.timestamp);
        uint256 startTime = block.timestamp;

        // Execute redemption request with individual parameters
        requestId = minter.requestRedeem(USDC_MAINNET, recipient, amount);

        vm.stopPrank();

        emit IntegrationFlowCompleted("InstitutionalRedemption", block.timestamp - startTime);

        return requestId;
    }

    /// @dev Execute institutional redemption with backend simulation
    /// @param user The user requesting redemption
    /// @param amount Amount to redeem
    /// @param recipient Recipient of redeemed assets
    /// @return requestId The redemption request ID
    function executeInstitutionalRedemptionWithBackend(
        address user,
        uint256 amount,
        address recipient
    )
        internal
        returns (bytes32 requestId)
    {
        // Step 1: Execute redemption request
        requestId = executeInstitutionalRedemption(user, amount, recipient);

        // Step 2: Simulate backend retrieving assets during settlement window
        // Backend needs to ensure kAssetRouter has enough assets for the redemption
        simulateBackendAssetRetrieval(USDC_MAINNET, amount);

        // Note: In production, peg protection would ensure kMinter has virtual balance
        // through asset recalls from DN vault. For this test, we'll handle this
        // during the settlement process by ensuring proper virtual balance management.

        return requestId;
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT FLOW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Execute asset transfer between vaults via kAssetRouter
    /// @notice This must be called from a registered staking vault
    function executeVaultTransfer(address sourceVault, address targetVault, uint256 amount, bytes32 batchId) internal {
        emit IntegrationFlowStarted("VaultTransfer", block.timestamp);
        uint256 startTime = block.timestamp;

        // The kAssetTransfer function requires onlyStakingVault modifier
        // We need to call it from the target staking vault context (not source)
        // This matches the pattern: stakingVault.call(kAssetTransfer(kMinter, stakingVault, ...))
        vm.prank(targetVault);
        assetRouter.kAssetTransfer(sourceVault, targetVault, USDC_MAINNET, amount, batchId);

        emit IntegrationFlowCompleted("VaultTransfer", block.timestamp - startTime);
    }

    /// @dev Execute retail staking request
    function executeRetailStaking(
        address user,
        address vault,
        uint256 kTokenAmount,
        uint256 minStkTokens
    )
        internal
        returns (uint256 requestId)
    {
        vm.startPrank(user);

        // Approve kTokens to vault
        kUSD.approve(address(vault), kTokenAmount);

        emit IntegrationFlowStarted("RetailStaking", block.timestamp);
        uint256 startTime = block.timestamp;

        // Execute staking request
        requestId = IkStakingVault(vault).requestStake(user, uint96(kTokenAmount));

        vm.stopPrank();

        emit IntegrationFlowCompleted("RetailStaking", block.timestamp - startTime);

        return requestId;
    }

    /// @dev Execute batch settlement for a vault
    function executeBatchSettlement(address vault, bytes32 batchId, uint256 totalAssets) internal {
        emit IntegrationFlowStarted("BatchSettlement", block.timestamp);
        uint256 startTime = block.timestamp;

        // Ensure kAssetRouter has the physical assets for settlement
        // In production, backend would retrieve these from external strategies
        uint256 currentBalance = IERC20(USDC_MAINNET).balanceOf(address(assetRouter));
        if (currentBalance < totalAssets) {
            deal(USDC_MAINNET, address(assetRouter), totalAssets);
        }

        // kAssetRouter needs to approve adapter to spend USDC
        vm.startPrank(address(assetRouter));
        // When settling kMinter, get DN vault's adapter since that's where assets go
        address actualVault = vault == address(minter) ? address(dnVault) : vault;
        address[] memory adapters = registry.getAdapters(actualVault);
        IERC20(USDC_MAINNET).approve(adapters[0], totalAssets);
        vm.stopPrank();

        vm.prank(users.settler);
        bytes32 proposalId =
            assetRouter.proposeSettleBatch(USDC_MAINNET, address(vault), batchId, totalAssets, totalAssets, 0, false);

        // Wait for cooldown period(0 for testing)
        assetRouter.executeSettleBatch(proposalId);
        emit IntegrationFlowCompleted("BatchSettlement", block.timestamp - startTime);
    }

    /*//////////////////////////////////////////////////////////////
                        BACKEND SIMULATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Simulate backend retrieving assets from custodial address
    /// @param asset The asset to retrieve
    /// @param amount The amount to retrieve
    /// @dev In production, backend coordinates with custodian to transfer assets back
    function simulateCustodialAssetRetrieval(address asset, uint256 amount) internal {
        // Simulate custodian transferring assets back to kAssetRouter
        // In tests, we use deal() to simulate this
        uint256 currentBalance = IERC20(asset).balanceOf(address(assetRouter));
        deal(asset, address(assetRouter), currentBalance + amount);

        emit IntegrationFlowCompleted("CustodialAssetRetrieval", amount);
    }

    /// @dev Simulate backend retrieving assets from MetaVault
    /// @param asset The asset to retrieve
    /// @param amount The amount to retrieve
    /// @dev In production, backend calls MetaVault.redeem() functions
    function simulateMetaVaultAssetRetrieval(address asset, uint256 amount) internal {
        // Simulate MetaVault redemption returning assets to kAssetRouter
        // In tests, we use deal() to simulate this
        uint256 currentBalance = IERC20(asset).balanceOf(address(assetRouter));
        deal(asset, address(assetRouter), currentBalance + amount);

        emit IntegrationFlowCompleted("MetaVaultAssetRetrieval", amount);
    }

    /// @dev Simulate complete backend asset retrieval process
    /// @param asset The asset to retrieve
    /// @param totalAmount Total amount needed for settlement
    /// @dev This simulates the 4-hour window where backend retrieves all needed assets
    function simulateBackendAssetRetrieval(address asset, uint256 totalAmount) internal {
        // In production, backend would:
        // 1. Calculate how much is needed from each strategy
        // 2. Call redeem functions on MetaVaults
        // 3. Coordinate with custodians for asset transfers
        // 4. Ensure all assets are back in kAssetRouter before settlement

        // For tests, we simply ensure kAssetRouter has the needed assets
        uint256 currentBalance = IERC20(asset).balanceOf(address(assetRouter));
        if (currentBalance < totalAmount) {
            deal(asset, address(assetRouter), totalAmount);
        }

        emit IntegrationFlowCompleted("BackendAssetRetrieval", totalAmount);
    }

    /// @dev Simulate the complete batch cycle: close batch, asset retrieval, settlement
    /// @param vault The vault to settle
    /// @param batchId The batch ID
    /// @param totalAssets Total assets for settlement calculation
    /// @param assetsNeeded Assets that need to be retrieved from external strategies
    function simulateCompleteBatchCycle(
        address vault,
        bytes32 batchId,
        uint256 totalAssets,
        uint256 assetsNeeded
    )
        internal
    {
        // Step 1: Close batch (hour 4)
        // In production: backend calls closeBatch()
        // For tests: we skip this as it's not implemented yet

        // Step 2: Asset retrieval window (hours 4-8)
        if (assetsNeeded > 0) {
            simulateBackendAssetRetrieval(USDC_MAINNET, assetsNeeded);
        }

        // Step 3: Settlement (hour 8)
        executeBatchSettlement(vault, batchId, totalAssets);
    }

    /*//////////////////////////////////////////////////////////////
                        STATE VALIDATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Validate virtual balance for a vault
    function assertVirtualBalance(
        address vault,
        address asset,
        uint256 expectedBalance,
        string memory message
    )
        internal
    {
        uint256 actualBalance;

        // All staking vaults (DN, Alpha, Beta) use adapter's totalAssets since setTotalAssets is called during
        // settlement
        // Only kMinter (type 0) uses assetRouter's virtual balance tracking
        if (vault == address(minter)) {
            actualBalance = metaVaultAdapter.totalAssets(address(dnVault), asset);
        } else {
            // DN vault (type 1), Alpha vault (type 2), Beta vault (type 3) all use adapter balance
            actualBalance = custodialAdapter.totalAssets(vault, asset);
        }

        assertEq(actualBalance, expectedBalance, message);
        emit VirtualBalanceValidated(vault, asset, actualBalance);
    }

    /// @dev Assert DN vault balance
    function assertDNVaultBalance(address asset, uint256 expectedBalance, string memory message) internal {
        // DN vault (type 0) balance should be checked via adapter's virtual balance
        // since setTotalAssets is not called for vault types <= 1
        uint256 actualBalance = custodialAdapter.totalVirtualAssets(address(dnVault), asset);
        assertEq(actualBalance, expectedBalance, message);
        emit VirtualBalanceValidated(address(dnVault), asset, actualBalance);
    }

    /// @dev Assert kMinter balance (for institutional assets before settlement to DN)
    function assertKMinterBalance(address asset, uint256 expectedBalance, string memory message) internal {
        uint256 actualBalance = metaVaultAdapter.totalAssets(address(minter), asset);
        assertEq(actualBalance, expectedBalance, message);
        emit VirtualBalanceValidated(address(minter), asset, actualBalance);
    }

    /// @dev Validate batch state for a vault
    function assertBatchState(
        address vault,
        bytes32 expectedBatchId,
        bool shouldBeClosed,
        bool shouldBeSettled,
        string memory message
    )
        internal
    {
        (bytes32 batchId,, bool isClosed, bool isSettled) = IkStakingVault(vault).getBatchInfo();

        assertEq(batchId, expectedBatchId, string(abi.encodePacked(message, ": batch ID")));
        assertEq(isClosed, shouldBeClosed, string(abi.encodePacked(message, ": closed state")));
        assertEq(isSettled, shouldBeSettled, string(abi.encodePacked(message, ": settled state")));

        emit BatchStateValidated(batchId, isClosed, isSettled);
    }

    /// @dev Validate kToken balance matches expected amount
    function assertKTokenBalance(
        address token,
        address user,
        uint256 expectedBalance,
        string memory message
    )
        internal
    {
        uint256 actualBalance = IERC20(token).balanceOf(user);
        assertEq(actualBalance, expectedBalance, message);
    }

    /// @dev Validate asset balance matches expected amount
    function assertAssetBalance(address asset, address user, uint256 expectedBalance, string memory message) internal {
        uint256 actualBalance = IERC20(asset).balanceOf(user);
        assertEq(actualBalance, expectedBalance, message);
    }

    /// @dev Assert that vault balances are consistent between virtual and actual
    function assertVaultBalanceConsistency(address vault, address asset, string memory message) internal {
        uint256 virtualBalance = metaVaultAdapter.totalAssets(vault, asset);
        uint256 vaultLastAssets = IkStakingVault(vault).lastTotalAssets();

        // For integration tests, these should be reasonably close
        // (exact equality may not hold due to yield accrual)
        uint256 difference =
            virtualBalance > vaultLastAssets ? virtualBalance - vaultLastAssets : vaultLastAssets - virtualBalance;

        // Allow up to 1% difference for yield accrual
        uint256 tolerance = virtualBalance / 100;
        assertTrue(difference <= tolerance, string(abi.encodePacked(message, ": balance inconsistency")));
    }

    /*//////////////////////////////////////////////////////////////
                        PROTOCOL STATE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Get comprehensive protocol state for debugging
    function getProtocolIntegrationState()
        internal
        view
        returns (
            uint256 dnVaultBalance,
            uint256 alphaVaultBalance,
            uint256 betaVaultBalance,
            uint256 totalKUSDSupply,
            uint256 assetRouterUSDCBalance
        )
    {
        // DN vault (type 0) uses adapter's virtual balance
        dnVaultBalance = custodialAdapter.totalVirtualAssets(address(dnVault), USDC_MAINNET);
        alphaVaultBalance = metaVaultAdapter.totalAssets(address(alphaVault), USDC_MAINNET);
        betaVaultBalance = metaVaultAdapter.totalAssets(address(betaVault), USDC_MAINNET);
        totalKUSDSupply = kUSD.totalSupply();
        assetRouterUSDCBalance = IERC20(USDC_MAINNET).balanceOf(address(assetRouter));
    }

    /// @dev Assert 1:1 backing invariant holds (total kUSD <= total USDC in protocol)
    function assert1to1BackingInvariant(string memory message) internal {
        uint256 totalKUSD = kUSD.totalSupply();
        uint256 totalUSDC = IERC20(USDC_MAINNET).balanceOf(address(assetRouter));

        // Add virtual balances - for DN vault (type 0), use adapter's virtual balance
        // For other vaults, use kAssetRouter's balance tracking
        uint256 dnBalance = custodialAdapter.totalVirtualAssets(address(dnVault), USDC_MAINNET);
        uint256 alphaBalance = metaVaultAdapter.totalAssets(address(alphaVault), USDC_MAINNET);
        uint256 betaBalance = metaVaultAdapter.totalAssets(address(betaVault), USDC_MAINNET);

        uint256 totalProtocolUSDC = totalUSDC + dnBalance + alphaBalance + betaBalance;

        assertTrue(totalKUSD <= totalProtocolUSDC, string(abi.encodePacked(message, ": 1:1 backing violated")));
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-STEP FLOW HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Execute a complete institutional flow: mint → deploy → redeem
    function executeCompleteInstitutionalFlow(
        address institution,
        uint256 mintAmount,
        uint256 deployAmount,
        uint256 redeemAmount
    )
        internal
        returns (bytes32 redeemRequestId)
    {
        emit IntegrationFlowStarted("CompleteInstitutionalFlow", block.timestamp);

        // Step 1: Mint kTokens
        executeInstitutionalMint(institution, mintAmount, institution);

        // Step 2: Deploy assets to DN vault (simulated)
        executeVaultTransfer(address(0), address(dnVault), deployAmount, getCurrentDNBatchId());

        // Step 3: Request redemption
        redeemRequestId = executeInstitutionalRedemption(institution, redeemAmount, institution);

        emit IntegrationFlowCompleted("CompleteInstitutionalFlow", 0);

        return redeemRequestId;
    }

    /// @dev Execute a complete retail flow: stake → settle → unstake
    function executeCompleteRetailFlow(
        address user,
        address vault,
        uint256 stakeAmount,
        uint256 unstakeAmount
    )
        internal
        returns (uint256 stakeRequestId, uint256 unstakeRequestId)
    {
        emit IntegrationFlowStarted("CompleteRetailFlow", block.timestamp);

        // Step 1: Stake kTokens
        stakeRequestId = executeRetailStaking(user, vault, stakeAmount, stakeAmount);

        // Step 2: Advance time and settle
        advanceToSettlementTime();
        executeBatchSettlement(vault, IkStakingVault(vault).getBatchId(), stakeAmount);

        // Step 3: Claim staked shares (would be done in actual test)
        // Step 4: Request unstaking (simplified for base helper)

        emit IntegrationFlowCompleted("CompleteRetailFlow", 0);

        return (stakeRequestId, 0); // Simplified return
    }
}
