// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { LibString } from "solady/utils/LibString.sol";

import { DeploymentManager } from "./DeploymentManager.sol";
import { ApprovalProcessResponse, Defender } from "openzeppelin-foundry-upgrades/src/Defender.sol";
import { Options, Upgrades } from "openzeppelin-foundry-upgrades/src/Upgrades.sol";

contract DefenderScript is Script, DeploymentManager {
    using LibString for string;
    using LibString for address;

    function setUp() public { }

    function _deployWithDefender(string memory contractName, bytes memory initData) internal returns (address) {
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

        address proxy = Upgrades.deployUUPSProxy(contractName.concat(".sol"), initData, opts);

        console.log("Deployed proxy for ", contractName.concat(" at : ").concat(proxy.toHexString()));

        // Auto-write contract address to deployment JSON
        writeContractAddress(contractName, proxy);

        return proxy;
    }
}
