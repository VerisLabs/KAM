// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";

/// @title BaseVaultTest
/// @notice Base test contract for shared functionality
contract BaseVaultTest is DeploymentBaseTest {
    using OptimizedFixedPointMathLib for uint256;
    using SafeTransferLib for address;

    uint256 constant INITIAL_DEPOSIT = 1_000_000 * _1_USDC; // 1M USDC
    uint256 constant SMALL_DEPOSIT = 10_000 * _1_USDC; // 10K USDC
    uint256 constant LARGE_DEPOSIT = 5_000_000 * _1_USDC; // 5M USDC

    // Test fee rates
    uint16 constant TEST_MANAGEMENT_FEE = 100; //1%
    uint16 constant TEST_PERFORMANCE_FEE = 2000; // 20%
    uint16 constant TEST_HURDLE_RATE = 500; //5%

    IkStakingVault vault;

    function setUp() public virtual override {
        // Mint kTokens to test users
        _mintKTokensToUsers();
    }

    /* //////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _performStakeAndSettle(address user, uint256 amount, int256 profit) internal returns (bytes32 requestId) {
        // Approve kUSD for staking
        vm.prank(user);
        kUSD.approve(address(vault), amount);

        bytes32 batchId = vault.getBatchId();
        uint256 lastTotalAssets = vault.totalAssets();
        // Request stake
        vm.prank(user);
        bytes32 requestId = vault.requestStake(user, amount);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        vm.prank(users.relayer);
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            tokens.usdc,
            address(vault),
            batchId,
            profit > 0 ? lastTotalAssets + uint256(profit) : lastTotalAssets - uint256(profit),
            0,
            0
        );

        vm.prank(users.relayer);
        assetRouter.executeSettleBatch(proposalId);

        vm.prank(user);
        vault.claimStakedShares(requestId);
    }

    function _setupTestFees() internal {
        vm.startPrank(users.admin);
        vault.setManagementFee(TEST_MANAGEMENT_FEE);
        vault.setPerformanceFee(TEST_PERFORMANCE_FEE);
        vault.setHardHurdleRate(false); // Soft hurdle by default
        vm.stopPrank();

        vm.prank(users.relayer);
        registry.setHurdleRate(tokens.usdc, TEST_HURDLE_RATE);
    }

    function _mintKTokensToUsers() internal {
        vm.startPrank(users.institution);
        tokens.usdc.safeApprove(address(minter), type(uint256).max);
        _mintKTokenToUser(users.alice, INITIAL_DEPOSIT * 3, false);
        _mintKTokenToUser(users.bob, LARGE_DEPOSIT, false);
        _mintKTokenToUser(users.charlie, INITIAL_DEPOSIT, false);
        vm.stopPrank();

        bytes32 batchId = minter.getBatchId(tokens.usdc);
        vm.prank(users.relayer);
        IkStakingVault(address(minter)).closeBatch(batchId, true);

        // Settle batch
        uint256 totalAssets = assetRouter.virtualBalance(address(minter), tokens.usdc);
        _executeBatchSettlement(address(minter), batchId, totalAssets);
    }

    function _mintKTokenToUser(address user, uint256 amount, bool settle) internal {
        mockUSDC.mint(users.institution, amount);
        vm.startPrank(users.institution);
        tokens.usdc.safeApprove(address(minter), type(uint256).max);
        minter.mint(tokens.usdc, user, amount);
        vm.stopPrank();

        if (settle) {
            bytes32 batchId = minter.getBatchId(tokens.usdc);
            vm.prank(users.relayer);
            IkStakingVault(address(minter)).closeBatch(batchId, true);
            uint256 lastTotalAssets = assetRouter.virtualBalance(address(minter), tokens.usdc);
            _executeBatchSettlement(address(minter), batchId, lastTotalAssets);
        }
    }

    function _executeBatchSettlement(address vault, bytes32 batchId, uint256 totalAssets) internal {
        vm.prank(users.relayer);
        bytes32 proposalId = assetRouter.proposeSettleBatch(tokens.usdc, address(vault), batchId, totalAssets, 0, 0);

        // Wait for cooldown period(0 for testing)
        assetRouter.executeSettleBatch(proposalId);
    }
}
