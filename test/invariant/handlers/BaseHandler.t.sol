// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { CommonBase } from "forge-std/Base.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

abstract contract BaseHandler is CommonBase, StdUtils {
    mapping(bytes32 => uint256) public calls;

    ////////////////////////////////////////////////////////////////
    ///                      ACTOR MANAGEMENT                    ///
    ////////////////////////////////////////////////////////////////

    address internal currentActor;
    address[] internal actors;

    modifier createActor() {
        currentActor = msg.sender;
        _;
    }

    modifier useActor(uint256 actorIndexSeed) {
        currentActor = actors.length == 0 ? msg.sender : actors[bound(actorIndexSeed, 0, actors.length - 1)];
        _;
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    ////////////////////////////////////////////////////////////////
    ///                      HELPERS                             ///
    ////////////////////////////////////////////////////////////////

    function _sub0(uint256 a, uint256 b) internal pure virtual returns (uint256) {
        unchecked {
            return a - b > a ? 0 : a - b;
        }
    }

    function callSummary() public view virtual;

    function getEntryPoints() public view virtual returns (bytes4[] memory);
}
