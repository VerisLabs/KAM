/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IERC7540 {
    function balanceOf(address) external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function asset() external view returns (address);

    function totalAssets() external view returns (uint256 assets);

    function totalSupply() external view returns (uint256 assets);

    function convertToAssets(uint256) external view returns (uint256);

    function convertToShares(uint256) external view returns (uint256);

    function setOperator(address, bool) external;

    function isOperator(address, address) external view returns (bool);

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);

    function deposit(uint256 assets, address to) external returns (uint256 shares);

    function deposit(uint256 assets, address to, address controller) external returns (uint256 shares);

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    function pendingRedeemRequest(address) external view returns (uint256);

    function claimableRedeemRequest(address) external view returns (uint256);

    function pendingProcessedShares(address) external view returns (uint256);

    function pendingDepositRequest(address) external view returns (uint256);

    function claimableDepositRequest(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);

    function lastRedeem(address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function allowance(address, address) external view returns (uint256);
}
