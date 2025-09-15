// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IModule {
    function selectors() external view returns (bytes4[] memory);
}
