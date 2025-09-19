// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Bytes32Set, LibBytes32Set } from "../helpers/Bytes32Set.sol";
import { AddressSet, BaseHandler, LibAddressSet } from "./BaseHandler.t.sol";
import { console2 } from "forge-std/console2.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IVaultAdapter } from "src/interfaces/IVaultAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

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
    Bytes32Set pendingUnsettledBatches;
    Bytes32Set pendingSettlementProposals;

    int256 nettedInBatch;
    int256 totalNetted;
    int256 totalYield;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARS                          ///
    ////////////////////////////////////////////////////////////////

    uint256 expectedTotalAssets;
    uint256 actualTotalAssets;
    uint256 expectedAdapterBalance;
    uint256 actualAdapterBalance;

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
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////
    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](8);
        _entryPoints[0] = this.claimStakedShares.selector;
        _entryPoints[1] = this.requestStake.selector;
        _entryPoints[2] = this.claimUnstakedAssets.selector;
        _entryPoints[3] = this.requestUnstake.selector;
        _entryPoints[4] = this.proposeSettlement.selector;
        _entryPoints[5] = this.executeSettlement.selector;
        _entryPoints[6] = this.gain.selector;
        _entryPoints[7] = this.lose.selector;
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
        nettedInBatch += int256(amount);
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
        totalYield += int256(amount);
    }

    function lose(uint256 amount) public {
        amount = bound(
            amount,
            0,
            totalYield < 0 ? actualTotalAssets - uint256(-totalYield) : actualTotalAssets + uint256(totalYield)
        );
        if (amount == 0) return;
        totalYield -= int256(amount);
    }

    function claimStakedShares(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (actorStakeRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = actorStakeRequests[currentActor].rand(requestSeedIndex);
        vault.claimStakedShares(requestId);
        actorStakeRequests[currentActor].remove(requestId);
        vm.stopPrank();
    }

    function requestUnstake(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        amount = bound(amount, 0, kToken.balanceOf(currentActor));
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = vault.requestUnstake(currentActor, amount);
        actorUnstakeRequests[currentActor].add(requestId);
        vm.stopPrank();
    }

    function claimUnstakedAssets(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (actorUnstakeRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = actorUnstakeRequests[currentActor].rand(requestSeedIndex);
        vault.claimUnstakedAssets(requestId);
        actorUnstakeRequests[currentActor].remove(requestId);
        vm.stopPrank();
    }

    function proposeSettlement() public {
        vm.startPrank(relayer);
        bytes32 batchId = vault.getBatchId();
        if (pendingUnsettledBatches.count() != 0) {
            vm.stopPrank();
            return;
        }
        uint256 newTotalAssets = uint256(int256(expectedAdapterBalance) + nettedInBatch + totalYield);
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
            nettedInBatch,
            0,
            block.timestamp + assetRouter.getSettlementCooldown(),
            0,
            0
        );
        bytes32 proposalId = assetRouter.proposeSettleBatch(token, address(vault), batchId, newTotalAssets, 0, 0);
        vm.stopPrank();
        pendingSettlementProposals.add(proposalId);
        pendingUnsettledBatches.add(batchId);
        IkAssetRouter.VaultSettlementProposal memory proposal = assetRouter.getSettlementProposal(proposalId);
        assertEq(proposal.batchId, batchId);
        assertEq(proposal.asset, token);
        assertEq(proposal.vault, address(vault));
        assertEq(proposal.totalAssets, newTotalAssets);
        assertEq(proposal.netted, nettedInBatch);
        assertEq(proposal.yield, 0);
        assertEq(proposal.executeAfter, block.timestamp + assetRouter.getSettlementCooldown());
        nettedInBatch = 0;
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
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////
}
