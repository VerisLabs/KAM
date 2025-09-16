// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "test/invariant/helpers/SetUp.t.sol";

contract KAMIntegrationInvariants is SetUp {
    function invariant_kMinterLockedAssets() public {
        minterHandler.INVARIANT_TOTAL_LOCKED_ASSETS();
    }
}
