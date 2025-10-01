// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "kam/test/invariant/helpers/SetUp.t.sol";

contract kMinterInvariants is SetUp {
    function setUp() public override {
        _setUp();
        _setUpkMinterHandler();
    }

    function invariant_kMinterLockedAssets() public {
        minterHandler.INVARIANT_A_TOTAL_LOCKED_ASSETS();
    }

    function invariant_kMinterAdapterBalance() public {
        minterHandler.INVARIANT_B_ADAPTER_BALANCE();
    }

    function invariant_kMinterAdapterTotalAssets() public {
        minterHandler.INVARIANT_C_ADAPTER_TOTAL_ASSETS();
    }
}
