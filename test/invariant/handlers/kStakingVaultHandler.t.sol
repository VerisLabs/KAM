// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Bytes32Set, LibBytes32Set } from "../helpers/Bytes32Set.sol";
import { AddressSet, BaseHandler, LibAddressSet } from "./BaseHandler.t.sol";
import { console2 } from "forge-std/console2.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IVaultAdapter } from "src/interfaces/IVaultAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

contract kStakingVaultHandler is BaseHandler {
    using SafeTransferLib for address;
    using LibBytes32Set for Bytes32Set;
    using LibAddressSet for AddressSet;

    IkStakingVault vault;
    AddressSet minterActors;
    IkAssetRouter assetRouter;
    IVaultAdapter vaultAdapter;
    IVaultAdapter minterAdapter;
    address token;
    address kToken;
    address relayer;
    uint256 lastFeesChargedManagement;
    uint256 lastFeesChargedPerformance;
    mapping(address actor => Bytes32Set pendingRequestIds) actorStakeRequests;
    mapping(address actor => Bytes32Set pendingRequestIds) actorUnstakeRequests;
    mapping(bytes32 batchId => int256 netted) nettedInBatch;
    mapping(bytes32 batchId => int256 yieldInBatch) totalYieldInBatch;
    mapping(bytes32 batchId => uint256 chargedManagement) chargedManagementInBatch;
    mapping(bytes32 batchId => uint256 chargedPerformance) chargedPerformanceInBatch;
    mapping(bytes32 batchId => uint256 pendingStake) pendingStakeInBatch;
    Bytes32Set pendingUnsettledBatches;
    Bytes32Set pendingSettlementProposals;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARS                          ///
    ////////////////////////////////////////////////////////////////

    uint256 expectedTotalAssets;
    uint256 actualTotalAssets;
    uint256 expectedAdapterBalance;
    uint256 actualAdapterBalance;
    uint256 expectedSupply;
    uint256 actualSupply;

    constructor(
        address _vault,
        address _assetRouter,
        address _vaultAdapter,
        address _minterAdapter,
        address _token,
        address _kToken,
        address _relayer,
        address[] memory _minterActors,
        address[] memory _vaultActors
    )
        BaseHandler(_vaultActors)
    {
        for (uint256 i = 0; i < _minterActors.length; i++) {
            minterActors.add(_minterActors[i]);
        }
        vault = IkStakingVault(_vault);
        assetRouter = IkAssetRouter(_assetRouter);
        vaultAdapter = IVaultAdapter(_vaultAdapter);
        minterAdapter = IVaultAdapter(_minterAdapter);
        token = _token;
        kToken = _kToken;
        relayer = _relayer;
        lastFeesChargedManagement = 1; // initial timestamp
        lastFeesChargedPerformance = 1;
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////
    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](10);
        _entryPoints[0] = this.claimStakedShares.selector;
        _entryPoints[1] = this.requestStake.selector;
        _entryPoints[2] = this.claimUnstakedAssets.selector;
        _entryPoints[3] = this.requestUnstake.selector;
        _entryPoints[4] = this.proposeSettlement.selector;
        _entryPoints[5] = this.executeSettlement.selector;
        _entryPoints[6] = this.gain.selector;
        _entryPoints[7] = this.lose.selector;
        _entryPoints[8] = this.advanceTime.selector;
        _entryPoints[9] = this.chargeFees.selector;
        return _entryPoints;
    }

    function requestStake(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        amount = buyToInstitution(actorSeed, currentActor, amount);
        vm.startPrank(currentActor);
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        kToken.safeApprove(address(vault), amount);
        bytes32 requestId = vault.requestStake(currentActor, amount);
        actorStakeRequests[currentActor].add(requestId);
        nettedInBatch[vault.getBatchId()] += int256(amount);
        pendingStakeInBatch[vault.getBatchId()] += amount;
        expectedTotalAssets = actualTotalAssets;
        vm.stopPrank();
    }

    function buyToInstitution(uint256 actorSeed, address currentActor, uint256 amount) internal returns (uint256) {
        address institution = minterActors.rand(actorSeed);
        uint256 kTokenBalance = kToken.balanceOf(institution);
        amount = bound(amount, 0, kTokenBalance);
        if (kTokenBalance == 0) {
            return 0;
        }
        vm.prank(institution);
        kToken.safeTransfer(currentActor, amount);
        return amount;
    }

    function gain(uint256 amount) public {
        amount = bound(amount, 0, actualTotalAssets);
        if (amount == 0) return;
        totalYieldInBatch[vault.getBatchId()] += int256(amount);
        expectedTotalAssets = actualTotalAssets;
    }

    function advanceTime(uint256 amount) public {
        amount = bound(amount, 0, 30 days);
        vm.warp(block.timestamp + amount);
    }

    function chargeFees(bool management, bool performance) public {
        (uint256 managementFee, uint256 performanceFee, uint256 totalFees) = vault.computeLastBatchFees();
        if (management) {
            chargedManagementInBatch[vault.getBatchId()] += managementFee;
        }
        if (performance) {
            chargedPerformanceInBatch[vault.getBatchId()] += performanceFee;
        }
        lastFeesChargedManagement = block.timestamp;
        lastFeesChargedPerformance = block.timestamp;
        expectedTotalAssets = actualTotalAssets;
    }

    function lose(uint256 amount) public {
        amount = bound(
            amount,
            0,
            totalYieldInBatch[vault.getBatchId()] < 0
                ? actualTotalAssets - uint256(-totalYieldInBatch[vault.getBatchId()])
                : actualTotalAssets + uint256(totalYieldInBatch[vault.getBatchId()])
        );
        if (amount == 0) return;
        totalYieldInBatch[vault.getBatchId()] -= int256(amount);
        expectedTotalAssets = actualTotalAssets;
    }

    function claimStakedShares(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (actorStakeRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = actorStakeRequests[currentActor].rand(requestSeedIndex);
        BaseVaultTypes.StakeRequest memory stakeRequest = vault.getStakeRequest(requestId);
        bytes32 batchId = stakeRequest.batchId;
        (address batchReceiver, bool isClosed, bool isSettled, uint256 sharePrice, uint256 netSharePrice) =
            vault.getBatchIdInfo(batchId);
        if (!isSettled) {
            vm.expectRevert();
            vault.claimStakedShares(requestId);
            vm.stopPrank();
            return;
        } else {
            vault.claimStakedShares(requestId);
            actorStakeRequests[currentActor].remove(requestId);
            pendingStakeInBatch[batchId] -= stakeRequest.kTokenAmount;
        }
        expectedTotalAssets += stakeRequest.kTokenAmount;
        actualTotalAssets = vault.totalAssets();
        vm.stopPrank();
    }

    function requestUnstake(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        amount = bound(amount, 0, kToken.balanceOf(currentActor));
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        nettedInBatch[vault.getBatchId()] += int256(amount);
        bytes32 requestId = vault.requestUnstake(currentActor, amount);
        actorUnstakeRequests[currentActor].add(requestId);
        expectedTotalAssets = actualTotalAssets;
        vm.stopPrank();
    }

    function claimUnstakedAssets(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (actorUnstakeRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = actorUnstakeRequests[currentActor].rand(requestSeedIndex);
        BaseVaultTypes.UnstakeRequest memory unstakeRequest = vault.getUnstakeRequest(requestId);
        bytes32 batchId = unstakeRequest.batchId;
        (address batchReceiver, bool isClosed, bool isSettled, uint256 sharePrice, uint256 netSharePrice) =
            vault.getBatchIdInfo(batchId);
        if (!isSettled) {
            vm.expectRevert();
            vault.claimUnstakedAssets(requestId);
            return;
        } else {
            vault.claimUnstakedAssets(requestId);
            actorUnstakeRequests[currentActor].remove(requestId);
        }
        expectedTotalAssets += (unstakeRequest.stkTokenAmount * sharePrice / 1e6);
        actualTotalAssets = vault.totalAssets();

        vm.stopPrank();
    }

    function proposeSettlement() public {
        bytes32 batchId = vault.getBatchId();
        int256 netted = nettedInBatch[batchId];
        uint256 chargedManagement = chargedManagementInBatch[batchId];
        uint256 chargedPerformance = chargedPerformanceInBatch[batchId];
        int256 yieldAmount = totalYieldInBatch[batchId] - int256(chargedPerformance) - int256(chargedManagement);
        uint256 lastFeesChargedPerformance_ = vault.lastFeesChargedPerformance();
        uint256 lastFeesChargedManagement_ = vault.lastFeesChargedManagement();

        if (lastFeesChargedPerformance_ == lastFeesChargedPerformance) {
            lastFeesChargedPerformance_ = 0;
        } else {
            lastFeesChargedPerformance_ = lastFeesChargedPerformance;
        }

        if (lastFeesChargedManagement_ == lastFeesChargedManagement) {
            lastFeesChargedManagement_ = 0;
        } else {
            lastFeesChargedManagement_ = lastFeesChargedManagement;
        }

        vm.startPrank(relayer);
        if (pendingUnsettledBatches.count() != 0) {
            vm.stopPrank();
            return;
        }
        uint256 newTotalAssets =
            uint256(int256(expectedAdapterBalance) + netted + yieldAmount);
        if (batchId == bytes32(0)) {
            vm.stopPrank();
            return;
        }
        if (pendingUnsettledBatches.contains(batchId)) {
            vm.stopPrank();
            return;
        }
        vault.closeBatch(batchId, true);
        vm.expectEmit(false, true, true, true);
        emit IkAssetRouter.SettlementProposed(
            bytes32(0),
            address(vault),
            batchId,
            newTotalAssets,
            netted,
            yieldAmount,
            block.timestamp + assetRouter.getSettlementCooldown(),
            uint64(lastFeesChargedPerformance_),
            uint64(lastFeesChargedManagement_)
        );
        bytes32 proposalId = assetRouter.proposeSettleBatch(
            token,
            address(vault),
            batchId,
            newTotalAssets,
            uint64(lastFeesChargedPerformance_),
            uint64(lastFeesChargedManagement_)
        );
        vm.stopPrank();
        pendingSettlementProposals.add(proposalId);
        pendingUnsettledBatches.add(batchId);
        IkAssetRouter.VaultSettlementProposal memory proposal = assetRouter.getSettlementProposal(proposalId);
        assertEq(proposal.batchId, batchId, "Proposal batchId mismatch");
        assertEq(proposal.asset, token, "Proposal asset mismatch");
        assertEq(proposal.vault, address(vault), "Proposal vault mismatch");
        assertEq(proposal.totalAssets, newTotalAssets, "Proposal totalAssets mismatch");
        assertEq(proposal.netted, netted, "Proposal netted mismatch");
        assertEq(proposal.yield, yieldAmount, "Proposal yield mismatch");
        assertEq(proposal.executeAfter, block.timestamp + assetRouter.getSettlementCooldown(), "Proposal executeAfter mismatch");
        expectedTotalAssets = actualTotalAssets;
    }

    function executeSettlement() public {
        vm.startPrank(relayer);
        if (pendingSettlementProposals.count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 proposalId = pendingSettlementProposals.at(0);
        IkAssetRouter.VaultSettlementProposal memory proposal = assetRouter.getSettlementProposal(proposalId);
        int256 netted = proposal.netted;
        assetRouter.executeSettleBatch(proposalId);
        vm.stopPrank();
        pendingSettlementProposals.remove(proposalId);
        pendingUnsettledBatches.remove(proposal.batchId);
        expectedAdapterBalance = proposal.totalAssets;
        actualAdapterBalance = assetRouter.virtualBalance(address(vault), token);
        expectedTotalAssets = uint256(
            int256(actualTotalAssets) + netted + proposal.yield - int256(pendingStakeInBatch[proposal.batchId])
        );
        actualTotalAssets = vault.totalAssets();
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////
    function INVARIANT_A_TOTAL_ASSETS() public {
        assertEq(vault.totalAssets(), expectedTotalAssets);
    }
}
