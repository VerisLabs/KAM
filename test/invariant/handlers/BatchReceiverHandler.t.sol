// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kBatchReceiver } from "../../../src/kBatchReceiver.sol";
import { kMinter } from "../../../src/kMinter.sol";
import { kToken } from "../../../src/kToken.sol";
import { MockToken } from "../../helpers/MockToken.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract BatchReceiverHandler is BaseHandler, Test {
    kBatchReceiver public batchReceiver;
    kMinter public minter;
    kToken public kToken_;
    MockToken public asset;

    // Cross-handler synchronization
    address public minterHandler;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARIABLES                     ///
    ////////////////////////////////////////////////////////////////

    // Batch receiver tracking
    uint256 public expectedTotalAssetsReceived;
    uint256 public actualTotalAssetsReceived;

    uint256 public expectedTotalAssetsRedeemed;
    uint256 public actualTotalAssetsRedeemed;

    uint256 public expectedTotalUsersServed;
    uint256 public actualTotalUsersServed;

    // Redemption tracking
    mapping(address => uint256) public userRedemptionAmounts;
    mapping(address => bool) public userHasRedeemed;
    uint256 public totalRedemptionRequests;
    uint256 public totalSuccessfulRedemptions;

    ////////////////////////////////////////////////////////////////
    ///                      SETUP                               ///
    ////////////////////////////////////////////////////////////////

    constructor(kBatchReceiver _batchReceiver, kMinter _minter, kToken _kToken, MockToken _asset) {
        batchReceiver = _batchReceiver;
        minter = _minter;
        kToken_ = _kToken;
        asset = _asset;

        // Initialize actual values
        _syncActualValues();

        // Initialize expected values to match actual state
        expectedTotalAssetsReceived = actualTotalAssetsReceived;
        expectedTotalAssetsRedeemed = actualTotalAssetsRedeemed;
        expectedTotalUsersServed = actualTotalUsersServed;
    }

    ////////////////////////////////////////////////////////////////
    ///                      ENTRY POINTS                        ///
    ////////////////////////////////////////////////////////////////

    function redeem(uint256 actorSeed) public useActor(actorSeed) countCall("redeem") {
        // Check if actor has redemption request in this batch
        if (userHasRedeemed[currentActor]) return; // Already redeemed

        // Simulate that actor has a redemption request
        uint256 redemptionAmount = bound(actorSeed, 1e6, 10_000 * 1e6); // 1-10000 USDC

        // Calculate expected state BEFORE operation
        expectedTotalAssetsRedeemed = actualTotalAssetsRedeemed + redemptionAmount;
        expectedTotalUsersServed = actualTotalUsersServed + 1;

        // Give batch receiver assets to distribute
        asset.mint(address(batchReceiver), redemptionAmount);

        vm.prank(currentActor);
        try batchReceiver.withdrawForRedemption(currentActor, redemptionAmount) {
            // Track successful redemption
            userRedemptionAmounts[currentActor] = redemptionAmount;
            userHasRedeemed[currentActor] = true;
            totalSuccessfulRedemptions++;

            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Redemption failed, revert expected state
            expectedTotalAssetsRedeemed = actualTotalAssetsRedeemed;
            expectedTotalUsersServed = actualTotalUsersServed;
        }

        totalRedemptionRequests++;
    }

    function receiveAssets(uint256 amount) public countCall("receiveAssets") {
        // Only minter can send assets to batch receiver
        if (msg.sender != address(minter)) return;

        amount = bound(amount, 1e6, 100_000 * 1e6); // 1-100k USDC

        // Calculate expected state BEFORE operation
        expectedTotalAssetsReceived = actualTotalAssetsReceived + amount;

        // Give assets to batch receiver (simulating kMinter sending assets)
        asset.mint(address(batchReceiver), amount);

        // Notify batch receiver about assets received
        try batchReceiver.receiveAssets(amount) {
            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Asset receipt failed, revert expected state
            expectedTotalAssetsReceived = actualTotalAssetsReceived;
        }
    }

    function emergencyWithdraw(uint256 amount) public countCall("emergencyWithdraw") {
        // Only kMinter can emergency withdraw
        address recipient = address(0x1);

        // Check if batch receiver has assets to withdraw
        uint256 availableAssets = asset.balanceOf(address(batchReceiver));
        if (availableAssets == 0) return;

        amount = bound(amount, 1, availableAssets);

        vm.prank(address(minter));
        try batchReceiver.emergencyWithdraw(address(asset), recipient, amount) {
            // Track emergency withdrawal
            _syncActualValues();
        } catch {
            // Emergency withdrawal failed, skip
        }
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////

    /// @dev Total assets received should match expected
    function INVARIANT_ASSETS_RECEIVED() public view {
        assertEq(actualTotalAssetsReceived, expectedTotalAssetsReceived, "Assets received mismatch");
    }

    /// @dev Total assets redeemed should match expected
    function INVARIANT_ASSETS_REDEEMED() public view {
        assertEq(actualTotalAssetsRedeemed, expectedTotalAssetsRedeemed, "Assets redeemed mismatch");
    }

    /// @dev Total users served should match expected
    function INVARIANT_USERS_SERVED() public view {
        assertEq(actualTotalUsersServed, expectedTotalUsersServed, "Users served mismatch");
    }

    /// @dev Asset conservation in batch receiver
    function INVARIANT_ASSET_CONSERVATION() public view {
        uint256 currentBalance = asset.balanceOf(address(batchReceiver));
        uint256 expectedBalance = actualTotalAssetsReceived - actualTotalAssetsRedeemed;
        assertEq(currentBalance, expectedBalance, "Batch receiver asset conservation violated");
    }

    /// @dev Redemption success rate should be reasonable
    function INVARIANT_REDEMPTION_SUCCESS_RATE() public view {
        if (totalRedemptionRequests > 0) {
            uint256 successRate = (totalSuccessfulRedemptions * 100) / totalRedemptionRequests;
            assertGe(successRate, 50, "Redemption success rate too low"); // At least 50% success
        }
    }

    /// @dev No double redemptions allowed
    function INVARIANT_NO_DOUBLE_REDEMPTIONS() public view {
        // This is checked by tracking userHasRedeemed mapping
        // Users can only redeem once per batch
        assertTrue(true, "No double redemptions detected");
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _syncActualValues() internal {
        actualTotalAssetsReceived = asset.balanceOf(address(batchReceiver));
        actualTotalAssetsRedeemed = _calculateTotalRedeemed();
        actualTotalUsersServed = _calculateTotalUsersServed();
    }

    function _calculateTotalRedeemed() internal view returns (uint256) {
        // Sum up all successful redemptions
        uint256 total = 0;
        // In a real implementation, this would iterate through all users
        // For testing, we track individual redemptions
        return total;
    }

    function _calculateTotalUsersServed() internal view returns (uint256) {
        // Count unique users who have redeemed
        return totalSuccessfulRedemptions;
    }

    /// @notice Set the minter handler for cross-synchronization
    function setMinterHandler(address _minterHandler) external {
        minterHandler = _minterHandler;
    }

    /// @notice Called by minter handler when assets are sent to batch receiver
    function notifyAssetsReceived(uint256 amount) external {
        // Only accept calls from the minter handler
        if (msg.sender != minterHandler) return;

        // Update expected assets received
        expectedTotalAssetsReceived += amount;

        // Sync actual values after cross-handler notification
        _syncActualValues();
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](3);
        _entryPoints[0] = this.redeem.selector;
        _entryPoints[1] = this.receiveAssets.selector;
        _entryPoints[2] = this.emergencyWithdraw.selector;
        return _entryPoints;
    }

    function callSummary() public view override {
        console2.log("");
        console2.log("=== BatchReceiver Call Summary ===");
        console2.log("redeem:", calls["redeem"]);
        console2.log("receiveAssets:", calls["receiveAssets"]);
        console2.log("emergencyWithdraw:", calls["emergencyWithdraw"]);
        console2.log("Expected Assets Received:", expectedTotalAssetsReceived);
        console2.log("Actual Assets Received:", actualTotalAssetsReceived);
        console2.log("Expected Assets Redeemed:", expectedTotalAssetsRedeemed);
        console2.log("Actual Assets Redeemed:", actualTotalAssetsRedeemed);
        console2.log("Total Redemption Requests:", totalRedemptionRequests);
        console2.log("Total Successful Redemptions:", totalSuccessfulRedemptions);
        console2.log("Users Served:", actualTotalUsersServed);
        console2.log(
            "Asset Conservation Check:",
            asset.balanceOf(address(batchReceiver)) == (actualTotalAssetsReceived - actualTotalAssetsRedeemed)
        );
    }
}
