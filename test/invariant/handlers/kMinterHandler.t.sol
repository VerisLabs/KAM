// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Bytes32Set, LibBytes32Set } from "../helpers/Bytes32Set.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { console2 } from "forge-std/console2.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IVaultAdapter } from "src/interfaces/IVaultAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";

contract kMinterHandler is BaseHandler {
    using SafeTransferLib for address;
    using LibBytes32Set for Bytes32Set;

    IkMinter minter;
    IkAssetRouter assetRouter;
    IVaultAdapter adapter;
    address token;
    address kToken;
    address relayer;
    uint256 lastFeesChargedManagement;
    uint256 lastFeesChargedPerformance;
    mapping(address actor => Bytes32Set pendingRequestIds) actorRequests;
    Bytes32Set pendingUnsettledBatches;
    Bytes32Set pendingSettlementProposals;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARS                          ///
    ////////////////////////////////////////////////////////////////

    int256 nettedInBatch;
    int256 totalNetted;
    uint256 expectedTotalLockedAssets;
    uint256 actualTotalLockedAssets;
    uint256 expectedAdapterBalance;
    uint256 actualAdapterBalance;

    constructor(
        address _minter,
        address _assetRouter,
        address _adapter,
        address _token,
        address _kToken,
        address _relayer,
        address[] memory _actors
    )
        BaseHandler(_actors)
    {
        minter = IkMinter(_minter);
        assetRouter = IkAssetRouter(_assetRouter);
        adapter = IVaultAdapter(_adapter);
        token = _token;
        kToken = _kToken;
        relayer = _relayer;
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////
    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](5);
        _entryPoints[0] = this.mint.selector;
        _entryPoints[1] = this.requestBurn.selector;
        _entryPoints[2] = this.burn.selector;
        _entryPoints[3] = this.proposeSettlement.selector;
        _entryPoints[4] = this.executeSettlement.selector;
        return _entryPoints;
    }

    function mint(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        amount = bound(amount, 0, token.balanceOf(currentActor));
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        token.safeApprove(address(minter), amount);
        minter.mint(token, currentActor, amount);
        vm.stopPrank();
        expectedTotalLockedAssets += amount;
        actualTotalLockedAssets = minter.getTotalLockedAssets(token);
        actualAdapterBalance = assetRouter.virtualBalance(address(minter), token);
        nettedInBatch += int256(amount);
        totalNetted += int256(amount);
    }

    function requestBurn(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        amount = bound(amount, 0, kToken.balanceOf(currentActor));
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        kToken.safeApprove(address(minter), amount);
        if (assetRouter.virtualBalance(address(minter), token) < amount) {
            vm.expectRevert();
            minter.requestBurn(token, currentActor, amount);
            vm.stopPrank();
            return;
        }
        bytes32 requestId = minter.requestBurn(token, currentActor, amount);
        vm.stopPrank();
        actorRequests[currentActor].add(requestId);
        actualTotalLockedAssets = minter.getTotalLockedAssets(token);
        actualAdapterBalance = assetRouter.virtualBalance(address(minter), token);
        nettedInBatch -= int256(amount);
        totalNetted -= int256(amount);
    }

    function burn(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (actorRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = actorRequests[currentActor].rand(requestSeedIndex);
        actorRequests[currentActor].remove(requestId);
        uint256 amount = minter.getBurnRequest(requestId).amount;
        address batchReceiver = minter.getBatchReceiver(minter.getBurnRequest(requestId).batchId);
        if (token.balanceOf(batchReceiver) == 0) {
            vm.expectRevert();
            minter.burn(requestId);
            vm.stopPrank();
            return;
        }
        minter.burn(requestId);
        vm.stopPrank();
        expectedTotalLockedAssets -= amount;
        actualTotalLockedAssets = minter.getTotalLockedAssets(token);
        actualAdapterBalance = assetRouter.virtualBalance(address(minter), token);
    }

    function proposeSettlement() public {
        vm.startPrank(relayer);
        bytes32 batchId = minter.getBatchId(token);
        if(  pendingUnsettledBatches.count() != 0) {
            vm.stopPrank();
            return;
        }
        uint256 newTotalAssets = uint256(int256(expectedAdapterBalance) + nettedInBatch);
        if (batchId == bytes32(0)) {
            vm.stopPrank();
            return;
        }
        if(pendingUnsettledBatches.contains(batchId)) {
            vm.stopPrank();
            return;
        }
        minter.closeBatch(batchId, true);
        vm.expectEmit(false, true, true, true);
        emit IkAssetRouter.SettlementProposed(
            bytes32(0),
            address(minter),
            batchId,
            newTotalAssets,
            nettedInBatch,
            0,
            block.timestamp + assetRouter.getSettlementCooldown(),
            0,
            0
        );
        bytes32 proposalId = assetRouter.proposeSettleBatch(token, address(minter), batchId, newTotalAssets, 0, 0);
        vm.stopPrank();
        pendingSettlementProposals.add(proposalId);
        pendingUnsettledBatches.add(batchId);
        IkAssetRouter.VaultSettlementProposal memory proposal = assetRouter.getSettlementProposal(proposalId);
        assertEq(proposal.batchId, batchId);
        assertEq(proposal.asset, token);
        assertEq(proposal.vault, address(minter));
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
        if (netted < 0) {
            adapter.execute(
                address(token),
                abi.encodeWithSignature("transfer(address,uint256)", address(assetRouter), uint256(-netted)),
                0
            );
        }
        assetRouter.executeSettleBatch(proposalId);
        vm.stopPrank();
        pendingSettlementProposals.remove(proposalId);
        pendingUnsettledBatches.remove(proposal.batchId);
        expectedAdapterBalance = proposal.totalAssets;
        actualAdapterBalance = assetRouter.virtualBalance(address(minter), token);
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////
    function INVARIANT_TOTAL_LOCKED_ASSETS() public view {
        assertEq(actualTotalLockedAssets, expectedTotalLockedAssets, "kMinter locked assets");
    }

    function INVARIANT_ADAPTER_BALANCE() public view {
        assertEq(actualAdapterBalance, expectedAdapterBalance, "kMinter adapter balance");
    }

    function INVARIANT_TOTAL_NETTED() public view {
        if (pendingSettlementProposals.count() == 0) {
            assertEq(actualAdapterBalance, uint256(totalNetted), "kMinter total netted");
        }
    }
}
