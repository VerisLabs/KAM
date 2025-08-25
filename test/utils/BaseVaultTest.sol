// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";
import { DeploymentBaseTest } from "../utils/DeploymentBaseTest.sol";

import { console } from "forge-std/console.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title BaseVaultTest
/// @notice Base test contract for shared functionality
contract BaseVaultTest is DeploymentBaseTest {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 constant INITIAL_DEPOSIT = 1_000_000 * _1_USDC; // 1M USDC
    uint256 constant SMALL_DEPOSIT = 10_000 * _1_USDC; // 10K USDC
    uint256 constant LARGE_DEPOSIT = 5_000_000 * _1_USDC; // 5M USDC

    // Test fee rates
    uint16 constant TEST_MANAGEMENT_FEE = 100; // 1%
    uint16 constant TEST_PERFORMANCE_FEE = 2000; // 20%
    uint16 constant TEST_HURDLE_RATE = 500; // 5%

    /*//////////////////////////////////////////////////////////////
                              VARIABLES
    //////////////////////////////////////////////////////////////*/

    IkStakingVault vault;

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Mint kTokens to test users
        _mintKTokensToUsers();
    }

    /*//////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _performStakeAndSettle(address user, uint256 amount) internal returns (bytes32 requestId) {
        // Approve kUSD for staking
        vm.prank(user);
        kUSD.approve(address(vault), amount);

        bytes32 batchId = vault.getBatchId();
        uint256 lastTotalAssets = vault.totalAssets();
        // Request stake
        vm.prank(user);
        bytes32 requestId = vault.requestStake(user, amount);

        vm.prank(users.relayer);
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            USDC_MAINNET, address(vault), batchId, lastTotalAssets + amount, amount, 0, false
        );
        vm.prank(users.relayer);
        assetRouter.executeSettleBatch(proposalId);

        vm.prank(users.relayer);
        vault.closeBatch(batchId, true);

        vm.prank(user);
        vault.claimStakedShares(batchId, requestId);
    }

    /// @dev Setup test fees for comprehensive testing
    function _setupTestFees() internal {
        vm.startPrank(users.admin);
        vault.setManagementFee(TEST_MANAGEMENT_FEE);
        vault.setPerformanceFee(TEST_PERFORMANCE_FEE);
        vault.setHurdleRate(TEST_HURDLE_RATE);
        vault.setHardHurdleRate(false); // Soft hurdle by default
        vm.stopPrank();
    }

    function _mintKTokensToUsers() internal {
        vm.startPrank(users.institution);
        USDC_MAINNET.safeApprove(address(minter), type(uint256).max);
        _mintKTokenToUser(users.alice, INITIAL_DEPOSIT * 3, false);
        _mintKTokenToUser(users.bob, LARGE_DEPOSIT, false);
        _mintKTokenToUser(users.charlie, INITIAL_DEPOSIT, false);
        vm.stopPrank();

        // Settle batch
        bytes32 batchId = dnVault.getBatchId();
        uint256 totalAssets = INITIAL_DEPOSIT * 3 + LARGE_DEPOSIT + INITIAL_DEPOSIT;
        _executeBatchSettlement(address(minter), batchId, totalAssets, totalAssets, 0, false);

        vm.prank(users.relayer);
        IkStakingVault(address(dnVault)).closeBatch(batchId, true);
    }

    function _mintKTokenToUser(address user, uint256 amount, bool settle) internal {
        deal(USDC_MAINNET, users.institution, amount);
        vm.startPrank(users.institution);
        USDC_MAINNET.safeApprove(address(minter), type(uint256).max);
        minter.mint(USDC_MAINNET, user, amount);
        vm.stopPrank();

        if (settle) {
            bytes32 batchId = dnVault.getBatchId();
            uint256 lastTotalAsets = minter.getTotalLockedAssets(USDC_MAINNET);
            _executeBatchSettlement(address(minter), batchId, lastTotalAsets + amount, amount, 0, false);

            vm.prank(users.relayer);
            IkStakingVault(address(dnVault)).closeBatch(batchId, true);
        }
    }

    function _executeBatchSettlement(
        address vault,
        bytes32 batchId,
        uint256 totalAssets,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        internal
    {
        uint256 startTime = block.timestamp;

        // Ensure kAssetRouter has the physical assets for settlement
        // In production, backend would retrieve these from external strategies
        uint256 currentBalance = IERC20(USDC_MAINNET).balanceOf(address(assetRouter));
        if (currentBalance < totalAssets) {
            deal(USDC_MAINNET, address(assetRouter), totalAssets);
        }

        vm.prank(users.relayer);
        bytes32 proposalId =
            assetRouter.proposeSettleBatch(USDC_MAINNET, address(vault), batchId, totalAssets, netted, yield, profit);

        // Wait for cooldown period(0 for testing)
        assetRouter.executeSettleBatch(proposalId);

        if (vault != address(minter)) {
            vm.prank(users.relayer);
            IkStakingVault(vault).closeBatch(batchId, true);
        }
    }
}
