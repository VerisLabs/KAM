// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";
import { kToken } from "src/kToken.sol";

contract DeployKToken is DefenderScript {
    function run(address owner, address admin, address emergencyAdmin, uint8 decimals) public {
        address minter = vm.envAddress("KMINTER_ADDRESS");
        address deployment = _deployWithDefender(
            "kToken", abi.encodeWithSelector(kToken.initialize.selector, owner, admin, emergencyAdmin, minter, decimals)
        );
    }
}
