// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "kam/test/invariant/helpers/SetUp.t.sol";

contract kStakingVaultInvariants is SetUp {
    function setUp() public override {
        _setUp();
        _setUpkStakingVaultHandlerAlpha();
        _setUpInstitutionalMint();
        _setUpVaultFees(alphaVault);
    }

    function invariant_kStakingVaultTotalAssets() public view {
        vaultHandlerAlpha.INVARIANT_A_TOTAL_ASSETS();
    }

    function invariant_kStakingVaultAdapterBalance() public view {
        vaultHandlerAlpha.INVARIANT_B_ADAPTER_BALANCE();
    }

    function invariant_kStakingVaultAdapterTotalAssets() public view {
        vaultHandlerAlpha.INVARIANT_C_ADAPTER_TOTAL_ASSETS();
    }

    function invariant_kStakingVaultSharePrice() public view {
        vaultHandlerAlpha.INVARIANT_D_SHARE_PRICE();
    }

    function invariant_kStakingVaultTotalNetAssets() public view {
        vaultHandlerAlpha.INVARIANT_E_TOTAL_NET_ASSETS();
    }

    function invariant_kStakingVaultSupply() public view {
        vaultHandlerAlpha.INVARIANT_F_SUPPLY();
    }
}
