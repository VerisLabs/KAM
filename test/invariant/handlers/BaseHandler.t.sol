// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Actors } from "../helpers/Actors.sol";

import { AddressSet, LibAddressSet } from "../helpers/AddressSet.sol";
import { CommonBase } from "forge-std/Base.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { Test } from "forge-std/Test.sol";

abstract contract BaseHandler is CommonBase, StdUtils, Test, Actors {
    ////////////////////////////////////////////////////////////////
    ///                      ACTOR MANAGEMENT                    ///
    ////////////////////////////////////////////////////////////////

    constructor(address[] memory _actors) {
        addActors(_actors);
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _sub0(uint256 a, uint256 b) internal pure virtual returns (uint256) {
        unchecked {
            return a - b > a ? 0 : a - b;
        }
    }

    function getEntryPoints() public view virtual returns (bytes4[] memory);
}
