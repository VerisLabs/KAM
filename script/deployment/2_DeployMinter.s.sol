// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";
import { kMinter } from "src/kMinter.sol";

contract DeployMinterScript is DefenderScript {
    function run(address owner, address admin, address emergencyAdmin) public {
        address registry = vm.envAddress("KREGISTRY_ADDRESS");
        address deployment = _deployWithDefender(
            "kMinter", abi.encodeWithSelector(kMinter.initialize.selector, registry, owner, admin, emergencyAdmin)
        );
    }
}
