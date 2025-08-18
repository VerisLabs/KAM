// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IDNVault {
    function deposit(address to, uint256 amount) external payable;
    function requestRedeem() external payable;
    function redeem() external payable;
}
