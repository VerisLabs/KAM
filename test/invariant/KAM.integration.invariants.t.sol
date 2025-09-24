// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SetUp } from "test/invariant/helpers/SetUp.t.sol";

contract IntegrationInvariants is SetUp {
    function setUp() public override {
        useMinter = true;
        _setUp();
        _setUpkMinterHandler();
        _setUpInstitutionalMint();
        _setUpkStakingVaultHandlerDeltaNeutral();
        _setUpkStakingVaultHandlerAlpha();
        _setUpkStakingVaultHandlerBeta();
        _setUpVaultFees(dnVault);
        _setUpVaultFees(alphaVault);
        _setUpVaultFees(betaVault);
    }

    function invariant_INTEGRATION_kMinterLockedAssets() public {
        minterHandler.INVARIANT_A_TOTAL_LOCKED_ASSETS();
    }

    function invariant_INTEGRATION_kMinterAdapterBalance() public {
        minterHandler.INVARIANT_B_ADAPTER_BALANCE();
    }

    function invariant_INTEGRATION_kMinterAdapterTotalAssets() public {
        minterHandler.INVARIANT_C_ADAPTER_TOTAL_ASSETS();
    }

    function invariant_INTEGRATION_kStakingVaultTotalAssets() public {
        vaultHandlerDeltaNeutral.INVARIANT_A_TOTAL_ASSETS();
        vaultHandlerAlpha.INVARIANT_A_TOTAL_ASSETS();
        vaultHandlerBeta.INVARIANT_A_TOTAL_ASSETS();
    }

    function invariant_INTEGRATION_kStakingVaultAdapterBalance() public {
        vaultHandlerDeltaNeutral.INVARIANT_B_ADAPTER_BALANCE();
        vaultHandlerAlpha.INVARIANT_B_ADAPTER_BALANCE();
        vaultHandlerBeta.INVARIANT_B_ADAPTER_BALANCE();
    }

    function invariant_INTEGRATION_kStakingVaultAdapterTotalAssets() public {
        vaultHandlerDeltaNeutral.INVARIANT_C_ADAPTER_TOTAL_ASSETS();
        vaultHandlerAlpha.INVARIANT_C_ADAPTER_TOTAL_ASSETS();
        vaultHandlerBeta.INVARIANT_C_ADAPTER_TOTAL_ASSETS();
    }

    function invariant_INTEGRATION_kStakingVaultSharePrice() public {
        vaultHandlerDeltaNeutral.INVARIANT_D_SHARE_PRICE();
        vaultHandlerAlpha.INVARIANT_D_SHARE_PRICE();
        vaultHandlerBeta.INVARIANT_D_SHARE_PRICE();
    }

    function invariant_INTEGRATION_kStakingVaultTotalNetAssets() public {
        vaultHandlerDeltaNeutral.INVARIANT_E_TOTAL_NET_ASSETS();
        vaultHandlerAlpha.INVARIANT_E_TOTAL_NET_ASSETS();
        vaultHandlerBeta.INVARIANT_E_TOTAL_NET_ASSETS();
    }

    function invariant_INTEGRATION_kStakingVaultSupply() public {
        vaultHandlerDeltaNeutral.INVARIANT_F_SUPPLY();
        vaultHandlerAlpha.INVARIANT_F_SUPPLY();
        vaultHandlerBeta.INVARIANT_F_SUPPLY();
    }
}
