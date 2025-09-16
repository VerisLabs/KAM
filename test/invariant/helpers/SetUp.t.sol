// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kMinterHandler } from "../handlers/kMinterHandler.t.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { DeploymentBaseTest } from "test/utils/DeploymentBaseTest.sol";

contract SetUp is StdInvariant, DeploymentBaseTest {
    kMinterHandler public minterHandler;

    function setUp() public override {
        super.setUp();
        _setUpkMinterHandler();
    }

    function _setUpkMinterHandler() internal {
        address[] memory _actors = new address[](4);
        _actors[0] = address(users.institution);
        _actors[1] = address(users.institution2);
        _actors[2] = address(users.institution3);
        _actors[3] = address(users.institution4);
        minterHandler = new kMinterHandler(address(minter), address(assetRouter), getUSDC(), address(kUSD), _actors);
        targetContract(address(minterHandler));
        bytes4[] memory selectors = minterHandler.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(minterHandler), selectors: selectors }));
        vm.label(address(minterHandler), "kMinterHandler");
    }
}
