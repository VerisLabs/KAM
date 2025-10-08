// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";

import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";

contract kStakingVaultFlowsTest is BaseVaultTest {
    using OptimizedFixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        DeploymentBaseTest.setUp();

        // Use Alpha vault for testing
        vault = IkStakingVault(address(alphaVault));

        BaseVaultTest.setUp();
    }
}
