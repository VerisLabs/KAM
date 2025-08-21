// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.20;

import { DefenderScript } from "../utils/DefenderScript.s.sol";
import { kAssetRouter } from "src/kAssetRouter.sol";

contract DeployAssetRouterScript is DefenderScript {
    function run(address owner, address admin, bool paused) public {
        address registry = vm.envAddress("KREGISTRY_ADDRESS");
        address deployment = _deployWithDefender(
            "kAssetRouter", abi.encodeWithSelector(kAssetRouter.initialize.selector, registry, owner, admin, paused)
        );
    }
}
