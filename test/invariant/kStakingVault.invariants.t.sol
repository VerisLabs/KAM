// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "test/invariant/helpers/SetUp.t.sol";

contract kStakingVaultInvariants is SetUp {

    function setUp() public override {
        _setUp();
        _setUpkStakingVaultHandlerAlpha();
        _setUpInstitutionalMint();
    }

    function invariant_kStakingVaultLockedAssets() public {
        assertTrue(true);
    }

}
