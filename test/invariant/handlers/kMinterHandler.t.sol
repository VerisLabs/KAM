// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Bytes32Set, LibBytes32Set } from "../helpers/Bytes32Set.sol";
import { BaseHandler } from "./BaseHandler.t.sol";
import { console2 } from "forge-std/console2.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";

contract kMinterHandler is BaseHandler {
    using SafeTransferLib for address;
    using LibBytes32Set for Bytes32Set;

    ////////////////////////////////////////////////////////////////
    ///                      GHOST VARS                          ///
    ////////////////////////////////////////////////////////////////

    uint256 expectedTotalLockedAssets;
    uint256 actualTotalLockedAssets;
    IkMinter minter;
    IkAssetRouter assetRouter;
    address token;
    address kToken;
    mapping(address actor => Bytes32Set pendingRequestIds) actorRequests;

    constructor(
        address _minter,
        address _assetRouter,
        address _token,
        address _kToken,
        address[] memory _actors
    )
        BaseHandler(_actors)
    {
        minter = IkMinter(_minter);
        assetRouter = IkAssetRouter(_assetRouter);
        token = _token;
        kToken = _kToken;
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////
    function getEntryPoints() public pure override returns (bytes4[] memory) {
        bytes4[] memory _entryPoints = new bytes4[](3);
        _entryPoints[0] = this.mint.selector;
        _entryPoints[1] = this.requestBurn.selector;
        _entryPoints[2] = this.burn.selector;
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
            minter.mint(token, currentActor, amount);
            vm.stopPrank();
            return;
        }
        bytes32 requestId = minter.requestBurn(token, currentActor, amount);
        vm.stopPrank();
        actorRequests[currentActor].add(requestId);
        actualTotalLockedAssets = minter.getTotalLockedAssets(token);
    }

    function burn(uint256 actorSeed, uint256 requestSeedIndex) public useActor(actorSeed) {
        vm.startPrank(currentActor);
        if (actorRequests[currentActor].count() == 0) {
            vm.stopPrank();
            return;
        }
        bytes32 requestId = actorRequests[currentActor].rand(requestSeedIndex);
        uint256 amount = minter.getBurnRequest(requestId).amount;
        minter.burn(requestId);
        vm.stopPrank();
        expectedTotalLockedAssets -= amount;
        actualTotalLockedAssets = minter.getTotalLockedAssets(token);
    }

    ////////////////////////////////////////////////////////////////
    ///                      INVARIANTS                          ///
    ////////////////////////////////////////////////////////////////
    function INVARIANT_TOTAL_LOCKED_ASSETS() public view {
        assertEq(actualTotalLockedAssets, expectedTotalLockedAssets);
    }
}
