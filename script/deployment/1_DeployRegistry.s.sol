// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";
import { kRegistry } from "src/kRegistry.sol";

contract DeployRegistryScript is DefenderScript {
    function run(address owner, address admin, address relayer) public {
        address deployment = _deployWithDefender(
            "kRegistry", abi.encodeWithSelector(kRegistry.initialize.selector, owner, admin, relayer)
        );
    }
}
