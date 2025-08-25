// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseVaultTest, DeploymentBaseTest } from "../utils/BaseVaultTest.sol";
import { USDC_MAINNET, _1_USDC } from "../utils/Constants.sol";

import { console } from "forge-std/console.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { BaseVaultModuleTypes } from "src/kStakingVault/types/BaseVaultModuleTypes.sol";

/// @title kStakingVaultFlowsTest
/// @notice Tests for fee mechanics in kStakingVault
/// @dev Focuses on fee calculations and asset conversions
contract kStakingVaultFlowsTest is BaseVaultTest {
    using FixedPointMathLib for uint256;
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
