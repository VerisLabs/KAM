// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "test/invariant/helpers/SetUp.t.sol";

contract kStakingVaultInvariants is SetUp {
    function setUp() public override {
        _setUp();
        _setUpkStakingVaultHandlerAlpha();
        _setUpInstitutionalMint();
        _setUpVaultFees(alphaVault);
    }

    function invariant_kStakingVaultTotalAssets() public {
        vaultHandler.INVARIANT_A_TOTAL_ASSETS();
    }

    function invariant_kStakingVaultAdapterBalance() public {
        vaultHandler.INVARIANT_B_ADAPTER_BALANCE();
    }

    function invariant_kStakingVaultSharePrice() public {
        vaultHandler.INVARIANT_C_SHARE_PRICE();
    }

    function invariant_kStakingVaultTotalNetAssets() public {
        vaultHandler.INVARIANT_D_TOTAL_NET_ASSETS();
    }
}
