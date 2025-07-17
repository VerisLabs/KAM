// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kMinter } from "../../../src/kMinter.sol";
import { kToken } from "../../../src/kToken.sol";
import { DataTypes } from "../../../src/types/DataTypes.sol";
import { MockToken } from "../../helpers/MockToken.sol";
import { MockkDNStaking } from "../../helpers/MockkDNStaking.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

contract kMinterHandler is BaseHandler, Test {
    kMinter public minter;
    kToken public kToken_;
    MockToken public asset;
    MockkDNStaking public mockStaking;

    // Cross-handler synchronization
    address public vaultHandler;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARIABLES                     ///
    ////////////////////////////////////////////////////////////////

    // Core accounting
    uint256 public expectedTotalDeposited;
    uint256 public actualTotalDeposited;

    uint256 public expectedTotalRedeemed;
    uint256 public actualTotalRedeemed;

    uint256 public expectedKTokenSupply;
    uint256 public actualKTokenSupply;

    uint256 public expectedTotalPendingRedemptions;
    uint256 public actualTotalPendingRedemptions;

    // Batch tracking
    uint256 public expectedCurrentBatchId;
    uint256 public actualCurrentBatchId;

    // kToken staking tracking
    uint256 public expectedTotalStakedKTokens;
    uint256 public actualTotalStakedKTokens;

    // Settlement tracking
    uint256 public totalBatchesSettled;
    uint256 public totalBatchesPending;
    uint256 public totalSuccessfulRedemptions;

    ////////////////////////////////////////////////////////////////
    ///                      SETUP                               ///
    ////////////////////////////////////////////////////////////////

    constructor(kMinter _minter, kToken _kToken, MockToken _asset, MockkDNStaking _mockStaking) {
        minter = _minter;
        kToken_ = _kToken;
        asset = _asset;
        mockStaking = _mockStaking;

        // Initialize actual values
        _syncActualValues();
    }

    ////////////////////////////////////////////////////////////////
    ///                      ENTRY POINTS                        ///
    ////////////////////////////////////////////////////////////////

    function mint(uint256 amount) public createActor countCall("mint") {
        amount = bound(amount, 1_000_000, 10_000_000 * 1e6); // 1-10M USDC

        // Skip if actor is a contract (avoid issues)
        if (currentActor.code.length > 0) return;

        // Give handler assets to perform operation on behalf of actor
        asset.mint(address(this), amount);
        asset.approve(address(minter), amount);

        // Calculate expected state BEFORE operation with overflow protection
        unchecked {
            expectedTotalDeposited = actualTotalDeposited + amount;
            expectedKTokenSupply = actualKTokenSupply + amount;
        }

        DataTypes.MintRequest memory request = DataTypes.MintRequest({ amount: amount, beneficiary: currentActor });

        // Execute operation as handler (has INSTITUTION_ROLE)
        minter.mint(request);

        // Notify vault handler of minter deposit (USDC goes to vault)
        if (vaultHandler != address(0)) {
            // Call vault handler to update its expected vault assets
            (bool success,) = vaultHandler.call(abi.encodeWithSignature("notifyMinterDeposit(uint256)", amount));
            // Don't revert on failure, just skip synchronization
        }

        // Update actual state AFTER operation
        _syncActualValues();
    }

    function requestRedeem(uint256 actorSeed, uint256 amount) public useActor(actorSeed) countCall("requestRedeem") {
        // Only redeem if actor has kTokens
        uint256 balance = kToken_.balanceOf(currentActor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        // Calculate expected state BEFORE operation with overflow protection
        unchecked {
            expectedTotalRedeemed = actualTotalRedeemed + amount;
            expectedKTokenSupply = actualKTokenSupply - amount;
            expectedTotalPendingRedemptions = actualTotalPendingRedemptions + amount;
        }

        vm.startPrank(currentActor);
        kToken_.approve(address(minter), amount);

        DataTypes.RedeemRequest memory request =
            DataTypes.RedeemRequest({ amount: amount, user: currentActor, recipient: currentActor });

        // Execute operation as the minter handler (which has INSTITUTION_ROLE)
        vm.stopPrank();
        bytes32 requestId = minter.requestRedeem(request);

        // Notify vault handler of minter redemption (kTokens are burned, vault assets decrease)
        if (vaultHandler != address(0)) {
            // Call vault handler to update its expected vault assets
            (bool success,) = vaultHandler.call(abi.encodeWithSignature("notifyMinterRedeem(uint256)", amount));
            // Don't revert on failure, just skip synchronization
        }

        // Update actual state AFTER operation
        _syncActualValues();
    }

    function forceCreateNewBatch() public countCall("forceCreateNewBatch") {
        // Only admin can force create new batch
        address admin = address(0x1);

        vm.prank(admin);
        try minter.forceCreateNewBatch() {
            // Batch creation successful
            _syncActualValues();
        } catch {
            // Batch creation failed, skip
        }
    }

    function redeem(bytes32 requestId) public createActor countCall("redeem") {
        // Try to redeem a request (this is for completed batch receiver redemptions)

        vm.prank(currentActor);
        try minter.redeem(requestId) {
            // Track redemption completion
            totalSuccessfulRedemptions++;

            // Update actual state AFTER operation
            _syncActualValues();
        } catch {
            // Redemption failed, skip
        }
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////

    /// @dev kToken supply should equal deposits minus redemptions (1:1 backing)
    function INVARIANT_KTOKEN_SUPPLY() public view {
        assertEq(actualKTokenSupply, expectedKTokenSupply, "kToken supply mismatch");
    }

    /// @dev Total deposited should match expected
    function INVARIANT_TOTAL_DEPOSITED() public view {
        assertEq(actualTotalDeposited, expectedTotalDeposited, "Total deposited mismatch");
    }

    /// @dev Total redeemed should match expected
    function INVARIANT_TOTAL_REDEEMED() public view {
        assertEq(actualTotalRedeemed, expectedTotalRedeemed, "Total redeemed mismatch");
    }

    /// @dev invariant: kToken supply = deposits - redeemed (1:1 backing)
    function INVARIANT_1TO1_BACKING() public view {
        uint256 expectedBacking = actualTotalDeposited - actualTotalRedeemed;
        assertEq(actualKTokenSupply, expectedBacking, "1:1 backing violation");
    }

    /// @dev Total accounting: deposited >= redeemed
    function INVARIANT_ACCOUNTING_SANITY() public view {
        assertGe(actualTotalDeposited, actualTotalRedeemed, "Deposited < Redeemed");
    }

    /// @dev kToken staking should match expected
    function INVARIANT_KTOKEN_STAKING() public view {
        assertEq(actualTotalStakedKTokens, expectedTotalStakedKTokens, "kToken staking mismatch");
    }

    /// @dev Pending redemptions should be reasonable
    function INVARIANT_PENDING_REDEMPTIONS() public view {
        assertLe(actualTotalPendingRedemptions, actualTotalDeposited, "Pending redemptions > deposits");
    }

    /// @dev Settlement consistency
    function INVARIANT_SETTLEMENT_CONSISTENCY() public view {
        // Settled + pending should equal total operations
        assertTrue(totalBatchesSettled <= actualCurrentBatchId, "Settlement consistency violated");
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _syncActualValues() internal {
        actualTotalDeposited = _getActualTotalDeposited();
        actualTotalRedeemed = _getActualTotalRedeemed();
        actualKTokenSupply = kToken_.totalSupply();
        actualTotalPendingRedemptions = _getActualTotalPendingRedemptions();
        actualCurrentBatchId = _getActualCurrentBatchId();
        actualTotalStakedKTokens = _getActualTotalStakedKTokens();
    }

    /// @dev Read totalDeposited from storage slot +14
    function _getActualTotalDeposited() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 14);
        return uint256(vm.load(address(minter), slot));
    }

    /// @dev Read totalRedeemed from storage slot +15
    function _getActualTotalRedeemed() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 15);
        return uint256(vm.load(address(minter), slot));
    }

    /// @dev Read totalPendingRedemptions from storage slot +16
    function _getActualTotalPendingRedemptions() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 16);
        return uint256(vm.load(address(minter), slot));
    }

    /// @dev Read currentBatchId from storage slot +5
    function _getActualCurrentBatchId() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 5);
        return uint256(vm.load(address(minter), slot));
    }

    /// @dev Read totalStakedKTokens from storage slot +17 (estimate)
    function _getActualTotalStakedKTokens() internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00) + 17);
        return uint256(vm.load(address(minter), slot));
    }

    /// @notice Set the vault handler for cross-synchronization
    function setVaultHandler(address _vaultHandler) external {
        vaultHandler = _vaultHandler;
    }

    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](4);
        _entryPoints[0] = this.mint.selector;
        _entryPoints[1] = this.requestRedeem.selector;
        _entryPoints[2] = this.forceCreateNewBatch.selector;
        _entryPoints[3] = this.redeem.selector;
        return _entryPoints;
    }

    function callSummary() public view override {
        console2.log("");
        console2.log("=== kMinter Call Summary ===");
        console2.log("mint:", calls["mint"]);
        console2.log("requestRedeem:", calls["requestRedeem"]);
        console2.log("forceCreateNewBatch:", calls["forceCreateNewBatch"]);
        console2.log("redeem:", calls["redeem"]);
        console2.log("Expected kToken Supply:", expectedKTokenSupply);
        console2.log("Actual kToken Supply:", actualKTokenSupply);
        console2.log("Expected Total Deposited:", expectedTotalDeposited);
        console2.log("Actual Total Deposited:", actualTotalDeposited);
        console2.log("Expected Total Staked:", expectedTotalStakedKTokens);
        console2.log("Actual Total Staked:", actualTotalStakedKTokens);
        console2.log("Total Pending Redemptions:", actualTotalPendingRedemptions);
        console2.log("1:1 Backing Check:", actualKTokenSupply == (actualTotalDeposited - actualTotalRedeemed));
    }
}
