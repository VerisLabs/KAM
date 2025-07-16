// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { IMetaVault } from "src/interfaces/IMetaVault.sol";

/// @title MockMetaVault
/// @notice Mock implementation of IMetaVault for testing
contract MockMetaVault is IMetaVault {
    using SafeTransferLib for address;

    address public override asset;
    uint256 public override totalSupply;
    uint256 public override totalAssets;
    mapping(address => uint256) public override balanceOf;

    constructor(address _asset) {
        asset = _asset;
    }

    function name() external pure override returns (string memory) {
        return "Mock MetaVault";
    }

    function symbol() external pure override returns (string memory) {
        return "MOCK";
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }

    function convertToAssets(uint256 shares) external view override returns (uint256) {
        return totalSupply == 0 ? shares : (shares * totalAssets) / totalSupply;
    }

    function convertToShares(uint256 assets) external view override returns (uint256) {
        return totalSupply == 0 ? assets : (assets * totalSupply) / totalAssets;
    }

    function convertToSuperPositions(uint256, uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function totalWithdrawableAssets() external view override returns (uint256) {
        return totalAssets;
    }

    function totalLocalAssets() external view override returns (uint256) {
        return totalAssets;
    }

    function totalXChainAssets() external pure override returns (uint256) {
        return 0;
    }

    function sharePrice() external view override returns (uint256) {
        return totalSupply == 0 ? 1e18 : (totalAssets * 1e18) / totalSupply;
    }

    function totalIdle() external view override returns (uint256) {
        return totalAssets;
    }

    function totalDebt() external pure override returns (uint256) {
        return 0;
    }

    function totalDeposits() external view override returns (uint256) {
        return totalAssets;
    }

    function lastReport() external view override returns (uint256) {
        return block.timestamp;
    }

    function requestDeposit(uint256, address, address) external pure override returns (uint256) {
        return 1;
    }

    function deposit(uint256 assets, address to) external override returns (uint256 shares) {
        return _deposit(assets, to, msg.sender);
    }

    function deposit(uint256 assets, address to, address) external override returns (uint256 shares) {
        return _deposit(assets, to, msg.sender);
    }

    function _deposit(uint256 assets, address to, address controller) internal returns (uint256 shares) {
        if (!(assets > 0)) revert AssetsMustBeGreaterThanZero();

        // Transfer assets from sender to this contract
        asset.safeTransferFrom(controller, address(this), assets);

        // Calculate shares to mint
        shares = totalSupply == 0 ? assets : (assets * totalSupply) / totalAssets;

        // Update state
        totalSupply += shares;
        totalAssets += assets;
        balanceOf[to] += shares;

        return shares;
    }

    function requestRedeem(uint256, address, address) external pure override returns (uint256) {
        return 1;
    }

    function redeem(uint256 shares, address receiver, address controller) external override returns (uint256 assets) {
        if (!(shares > 0)) revert SharesMustBeGreaterThanZero();
        if (!(balanceOf[controller] >= shares)) revert InsufficientBalance();

        // Calculate assets to return
        assets = (shares * totalAssets) / totalSupply;

        // Update state
        totalSupply -= shares;
        totalAssets -= assets;
        balanceOf[controller] -= shares;

        // Transfer assets to receiver
        asset.safeTransfer(receiver, assets);

        return assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    )
        external
        override
        returns (uint256 shares)
    {
        if (!(assets > 0)) revert AssetsMustBeGreaterThanZero();

        // Calculate shares to burn
        shares = (assets * totalSupply) / totalAssets;
        if (!(balanceOf[controller] >= shares)) revert InsufficientBalance();

        // Update state
        totalSupply -= shares;
        totalAssets -= assets;
        balanceOf[controller] -= shares;

        // Transfer assets to receiver
        asset.safeTransfer(receiver, assets);

        return shares;
    }

    function pendingRedeemRequest(address) external pure override returns (uint256) {
        return 0;
    }

    function claimableRedeemRequest(address) external pure override returns (uint256) {
        return 0;
    }

    function pendingProcessedShares(address) external pure override returns (uint256) {
        return 0;
    }

    function claimableDepositRequest(address) external pure override returns (uint256) {
        return 0;
    }

    // Helper function to mint tokens directly for testing
    function mint(address to, uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        totalAssets += amount;
        totalSupply += amount;
        balanceOf[to] += amount;
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error AssetsMustBeGreaterThanZero();
    error SharesMustBeGreaterThanZero();
    error InsufficientBalance();
}
