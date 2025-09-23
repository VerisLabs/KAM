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

    IkMinter kMinter_minter;
    IkAssetRouter kMinter_assetRouter;
    IVaultAdapter kMinter_adapter;
    address kMinter_token;
    address kMinter_kToken;
    address kMinter_relayer;
    uint256 kMinter_lastFeesChargedManagement;
    uint256 kMinter_lastFeesChargedPerformance;
    mapping(address actor => Bytes32Set pendingRequestIds) kMinter_actorRequests;
    Bytes32Set kMinter_pendingUnsettledBatches;
    Bytes32Set kMinter_pendingSettlementProposals;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARS                          ///
    ////////////////////////////////////////////////////////////////

    int256 public kMinter_nettedInBatch;
    int256 public kMinter_totalNetted;
    uint256 public kMinter_expectedTotalLockedAssets;
    uint256 public kMinter_actualTotalLockedAssets;
    uint256 public kMinter_expectedAdapterBalance;
    uint256 public kMinter_actualAdapterBalance;

    constructor(
        address _minter,
        address _assetRouter,
        address _adapter,
        address _token,
        address _kToken,
        address _relayer,
        address[] memory _minterActors
    )
        BaseHandler(_minterActors)
    {
        kMinter_minter = IkMinter(_minter);
        kMinter_assetRouter = IkAssetRouter(_assetRouter);
        kMinter_adapter = IVaultAdapter(_adapter);
        kMinter_token = _token;
        kMinter_kToken = _kToken;
        kMinter_relayer = _relayer;
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////
    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](5);
        _entryPoints[0] = this.kMinter_mint.selector;
        _entryPoints[1] = this.kMinter_requestBurn.selector;
        _entryPoints[2] = this.kMinter_burn.selector;
        _entryPoints[3] = this.kMinter_proposeSettlement.selector;
        _entryPoints[4] = this.kMinter_executeSettlement.selector;
        return _entryPoints;
    }

    function kMinter_mint(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        amount = bound(amount, 0, kMinter_token.balanceOf(currentActor));
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        kMinter_token.safeApprove(address(kMinter_minter), amount);
        kMinter_minter.mint(kMinter_token, currentActor, amount);
        vm.stopPrank();
        kMinter_expectedTotalLockedAssets += amount;
        kMinter_actualTotalLockedAssets = kMinter_minter.getTotalLockedAssets(kMinter_token);
        kMinter_actualAdapterBalance = kMinter_assetRouter.virtualBalance(address(kMinter_minter), kMinter_token);
        kMinter_nettedInBatch += int256(amount);
        kMinter_totalNetted += int256(amount);
    }

    function kMinter_requestBurn(uint256 actorSeed, uint256 amount) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        amount = bound(amount, 0, kMinter_kToken.balanceOf(currentActor));
        if (amount == 0) {
            vm.stopPrank();
            return;
        }
        kMinter_kToken.safeApprove(address(kMinter_minter), amount);
        if (kMinter_assetRouter.virtualBalance(address(kMinter_minter), kMinter_token) < amount) {
            vm.expectRevert();
            kMinter_minter.requestBurn(kMinter_token, currentActor, amount);
            vm.stopPrank();
            return;
        }
        bytes32 requestId = kMinter_minter.requestBurn(kMinter_token, currentActor, amount);
        vm.stopPrank();
        kMinter_actorRequests[currentActor].add(requestId);
        kMinter_actualTotalLockedAssets = kMinter_minter.getTotalLockedAssets(kMinter_token);
        kMinter_actualAdapterBalance = kMinter_assetRouter.virtualBalance(address(kMinter_minter), kMinter_token);
        kMinter_nettedInBatch -= int256(amount);
        kMinter_totalNetted -= int256(amount);
    }

    function kMinter_burn(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (kMinter_actorRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = kMinter_actorRequests[currentActor].rand(requestSeedIndex);
        kMinter_actorRequests[currentActor].remove(requestId);
        uint256 amount = kMinter_minter.getBurnRequest(requestId).amount;
        address batchReceiver = kMinter_minter.getBatchReceiver(kMinter_minter.getBurnRequest(requestId).batchId);
        if (kMinter_token.balanceOf(batchReceiver) == 0) {
            vm.expectRevert();
            kMinter_minter.burn(requestId);
            vm.stopPrank();
            return;
        }
        kMinter_minter.burn(requestId);
        vm.stopPrank();
        kMinter_expectedTotalLockedAssets -= amount;
        kMinter_actualTotalLockedAssets = kMinter_minter.getTotalLockedAssets(kMinter_token);
        kMinter_actualAdapterBalance = kMinter_assetRouter.virtualBalance(address(kMinter_minter), kMinter_token);
    }

    function kMinter_proposeSettlement() public {
        vm.startPrank(kMinter_relayer);
        bytes32 batchId = kMinter_minter.getBatchId(kMinter_token);
        if (kMinter_pendingUnsettledBatches.count() != 0) {
            vm.stopPrank();
            return;
        }
        uint256 newTotalAssets = uint256(int256(kMinter_expectedAdapterBalance) + kMinter_nettedInBatch);
        if (batchId == bytes32(0)) {
            vm.stopPrank();
            return;
        }
        if (kMinter_pendingUnsettledBatches.contains(batchId)) {
            vm.stopPrank();
            return;
        }
        kMinter_minter.closeBatch(batchId, true);
        vm.expectEmit(false, true, true, true);
        emit IkAssetRouter.SettlementProposed(
            bytes32(0),
            address(kMinter_minter),
            batchId,
            newTotalAssets,
            kMinter_nettedInBatch,
            0,
            block.timestamp + kMinter_assetRouter.getSettlementCooldown(),
            0,
            0
        );
        bytes32 proposalId = kMinter_assetRouter.proposeSettleBatch(
            kMinter_token, address(kMinter_minter), batchId, newTotalAssets, 0, 0
        );
        vm.stopPrank();
        kMinter_pendingSettlementProposals.add(proposalId);
        kMinter_pendingUnsettledBatches.add(batchId);
        IkAssetRouter.VaultSettlementProposal memory proposal = kMinter_assetRouter.getSettlementProposal(proposalId);
        assertEq(proposal.batchId, batchId);
        assertEq(proposal.asset, kMinter_token);
        assertEq(proposal.vault, address(kMinter_minter));
        assertEq(proposal.totalAssets, newTotalAssets);
        assertEq(proposal.netted, kMinter_nettedInBatch);
        assertEq(proposal.yield, 0);
        assertEq(proposal.executeAfter, block.timestamp + kMinter_assetRouter.getSettlementCooldown());
        kMinter_nettedInBatch = 0;
    }

    function kMinter_executeSettlement() public {
        vm.startPrank(kMinter_relayer);
        if (kMinter_pendingSettlementProposals.count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 proposalId = kMinter_pendingSettlementProposals.at(0);
        IkAssetRouter.VaultSettlementProposal memory proposal = kMinter_assetRouter.getSettlementProposal(proposalId);
        int256 netted = proposal.netted;
        address[] memory targets = new address[](1);
        bytes[] memory data = new bytes[](1);
        uint256[] memory values = new uint256[](1);
        targets[0] = address(kMinter_token);
        data[0] = abi.encodeWithSignature("transfer(address,uint256)", address(kMinter_assetRouter), uint256(-netted));
        values[0] = 0;
        if (netted < 0) {
            kMinter_adapter.execute(targets, data, values);
        }
        kMinter_assetRouter.executeSettleBatch(proposalId);
        vm.stopPrank();
        kMinter_pendingSettlementProposals.remove(proposalId);
        kMinter_pendingUnsettledBatches.remove(proposal.batchId);
        kMinter_expectedAdapterBalance = proposal.totalAssets;
        kMinter_actualAdapterBalance = kMinter_assetRouter.virtualBalance(address(kMinter_minter), kMinter_token);
    }

    ////////////////////////////////////////////////////////////////
    ///                      SETTER FUNCTIONS                    ///
    ////////////////////////////////////////////////////////////////

    // Contract reference setters
    function set_kMinter_minter(address _minter) public {
        kMinter_minter = IkMinter(_minter);
    }

    function set_kMinter_assetRouter(address _assetRouter) public {
        kMinter_assetRouter = IkAssetRouter(_assetRouter);
    }

    function set_kMinter_adapter(address _adapter) public {
        kMinter_adapter = IVaultAdapter(_adapter);
    }

    // Address setters
    function set_kMinter_token(address _token) public {
        kMinter_token = _token;
    }

    function set_kMinter_kToken(address _kToken) public {
        kMinter_kToken = _kToken;
    }

    function set_kMinter_relayer(address _relayer) public {
        kMinter_relayer = _relayer;
    }

    // Value setters
    function set_kMinter_lastFeesChargedManagement(uint256 _value) public {
        kMinter_lastFeesChargedManagement = _value;
    }

    function set_kMinter_lastFeesChargedPerformance(uint256 _value) public {
        kMinter_lastFeesChargedPerformance = _value;
    }

    // Ghost var setters
    function set_kMinter_nettedInBatch(int256 _value) public {
        kMinter_nettedInBatch = _value;
    }

    function set_kMinter_totalNetted(int256 _value) public {
        kMinter_totalNetted = _value;
    }

    function set_kMinter_expectedTotalLockedAssets(uint256 _value) public {
        kMinter_expectedTotalLockedAssets = _value;
    }

    function set_kMinter_actualTotalLockedAssets(uint256 _value) public {
        kMinter_actualTotalLockedAssets = _value;
    }

    function set_kMinter_expectedAdapterBalance(uint256 _value) public {
        kMinter_expectedAdapterBalance = _value;
    }

    function set_kMinter_actualAdapterBalance(uint256 _value) public {
        kMinter_actualAdapterBalance = _value;
    }

    // Set operations for sets
    function add_kMinter_actorRequest(address _actor, bytes32 _requestId) public {
        kMinter_actorRequests[_actor].add(_requestId);
    }

    function remove_kMinter_actorRequest(address _actor, bytes32 _requestId) public {
        kMinter_actorRequests[_actor].remove(_requestId);
    }

    function add_kMinter_pendingUnsettledBatch(bytes32 _batchId) public {
        kMinter_pendingUnsettledBatches.add(_batchId);
    }

    function remove_kMinter_pendingUnsettledBatch(bytes32 _batchId) public {
        kMinter_pendingUnsettledBatches.remove(_batchId);
    }

    function add_kMinter_pendingSettlementProposal(bytes32 _proposalId) public {
        kMinter_pendingSettlementProposals.add(_proposalId);
    }

    function remove_kMinter_pendingSettlementProposal(bytes32 _proposalId) public {
        kMinter_pendingSettlementProposals.remove(_proposalId);
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////
    function INVARIANT_A_TOTAL_LOCKED_ASSETS() public view {
        assertEq(kMinter_actualTotalLockedAssets, kMinter_expectedTotalLockedAssets, "kMinter locked assets");
    }

    function INVARIANT_B_ADAPTER_BALANCE() public view {
        assertEq(kMinter_actualAdapterBalance, kMinter_expectedAdapterBalance, "kMinter adapter balance");
    }

    function INVARIANT_C_TOTAL_NETTED() public view {
        if (kMinter_pendingSettlementProposals.count() == 0) {
            assertEq(kMinter_actualAdapterBalance, uint256(kMinter_totalNetted), "kMinter total netted");
        }
    }
}
