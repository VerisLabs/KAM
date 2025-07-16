/// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IMetaVault {
    function balanceOf(address) external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function asset() external view returns (address);

    function totalAssets() external view returns (uint256 assets);

    function totalSupply() external view returns (uint256 assets);

    function convertToAssets(uint256) external view returns (uint256);

    function convertToShares(uint256) external view returns (uint256);

    function convertToSuperPositions(uint256 superformId, uint256 assets) external view returns (uint256);

    function totalWithdrawableAssets() external view returns (uint256 assets);

    function totalLocalAssets() external view returns (uint256 assets);

    function totalXChainAssets() external view returns (uint256 assets);

    function sharePrice() external view returns (uint256);

    function totalIdle() external view returns (uint256 assets);

    function totalDebt() external view returns (uint256 assets);

    function totalDeposits() external view returns (uint256 assets);

    function lastReport() external view returns (uint256);

    function requestDeposit(uint256 assets, address controller, address owner) external returns (uint256 requestId);

    function deposit(uint256 assets, address to) external returns (uint256 shares);

    function deposit(uint256 assets, address to, address controller) external returns (uint256 shares);

    function requestRedeem(uint256 shares, address controller, address owner) external returns (uint256 requestId);

    function redeem(uint256 shares, address receiver, address controller) external returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address controller) external returns (uint256 shares);

    function pendingRedeemRequest(address) external view returns (uint256);

    function claimableRedeemRequest(address) external view returns (uint256);

    function pendingProcessedShares(address) external view returns (uint256);

    function claimableDepositRequest(address) external view returns (uint256);
}
