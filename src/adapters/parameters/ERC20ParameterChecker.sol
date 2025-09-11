/// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IAdapterGuardian, IParametersChecker } from "src/interfaces/modules/IAdapterGuardian.sol";
import {ERC20} from "src/vendor/ERC20.sol";

contract ERC20ParameterChecker is IParametersChecker {

    

    function authorizeAdapterCall(
        address adapter,
        address target,
        bytes4 selector,
        bytes calldata params
    )
        external
        view
        returns (bool) {

        }

}