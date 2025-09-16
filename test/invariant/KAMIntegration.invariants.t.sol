// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "test/invariant/helpers/SetUp.t.sol";

contract KAMIntegrationInvariants is SetUp {
    function invariant_kMinterLockedAssets() public {
        minterHandler.INVARIANT_TOTAL_LOCKED_ASSETS();
    }

    function invariant_kMinterAdapterBalance() public {
        minterHandler.INVARIANT_ADAPTER_BALANCE();
    }

    // function invariant_kMinterTotalNetted() public {
    //     minterHandler.INVARIANT_TOTAL_NETTED();
    // }
}
