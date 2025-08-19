// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Defender, ApprovalProcessResponse} from "openzeppelin-foundry-upgrades/src/Defender.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";


contract DefenderScript is Script {
    function setUp() public {}

    function _deployWithDefender(string memory contractName, bytes memory initData) internal {
        ApprovalProcessResponse memory upgradeApprovalProcess = Defender.getUpgradeApprovalProcess();

        if (upgradeApprovalProcess.via == address(0)) {
            revert(
                string.concat(
                    "Upgrade approval process with id ",
                    upgradeApprovalProcess.approvalProcessId,
                    " has no assigned address"
                )
            );
        }

        Options memory opts;
        opts.defender.useDefenderDeploy = true;

        address proxy =
            Upgrades.deployUUPSProxy(string.concat(contractName, ".sol"), initData, opts);

        console.log("Deployed proxy to address", proxy);
    }
}