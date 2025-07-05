// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IkDNStaking } from "../../src/interfaces/IkDNStaking.sol";
import { DataTypes } from "../../src/types/DataTypes.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title MockkDNStaking
/// @notice Mock implementation of IkDNStaking for testing kMinter
contract MockkDNStaking is IkDNStaking {
    using SafeTransferLib for address;

    mapping(address => bool) public authorizedMinters;
    mapping(address => uint256) public minterAssetBalances;
    mapping(uint256 => bool) public settledBatches;
    uint256 public nextBatchId = 1;
    address public asset;

    // Mock return values
    uint256 public mockUnaccountedYield = 0;
    uint256 public mockUserSharePrice = 1e6; // 1:1 ratio
    uint256 public mockTotalStakedKTokens = 0;
    uint256 public mockStkTokenPrice = 1e6;

    function setAuthorizedMinter(address minter, bool authorized) external {
        authorizedMinters[minter] = authorized;
    }

    function setBatchSettled(uint256 batchId, bool settled) external {
        settledBatches[batchId] = settled;
    }

    function setMinterAssetBalance(address minter, uint256 balance) external {
        minterAssetBalances[minter] = balance;
    }

    function setAsset(address _asset) external {
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                          MINTER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function requestMinterDeposit(uint256 assetAmount) external payable returns (uint256 batchId) {
        // Transfer assets from sender
        if (asset != address(0)) {
            asset.safeTransferFrom(msg.sender, address(this), assetAmount);
        }

        batchId = nextBatchId++;
        emit MinterDepositRequested(msg.sender, assetAmount, batchId);
        return batchId;
    }

    function requestMinterRedeem(
        uint256 assetAmount,
        address minter,
        address batchReceiver
    )
        external
        payable
        returns (uint256 batchId)
    {
        batchId = nextBatchId++;
        emit MinterRedeemRequested(minter, assetAmount, batchReceiver, batchId);
        return batchId;
    }

    /*//////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function requestStake(uint256 amount) external payable returns (uint256 requestId) {
        requestId = nextBatchId++;
        return requestId;
    }

    function requestUnstake(uint256 stkTokenAmount) external payable returns (uint256 requestId) {
        requestId = nextBatchId++;
        return requestId;
    }

    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable {
        // Mock implementation
    }

    function claimUnstakedAssets(uint256 batchId, uint256 requestIndex) external payable {
        // Mock implementation
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    function settleBatch(uint256 batchId) external {
        settledBatches[batchId] = true;
    }

    function settleStakingBatch(uint256 batchId, uint256 totalKTokensStaked) external {
        settledBatches[batchId] = true;
    }

    function settleUnstakingBatch(
        uint256 batchId,
        uint256 totalStkTokensUnstaked,
        uint256 totalKTokensToReturn,
        uint256 totalYieldToMinter
    )
        external
    {
        settledBatches[batchId] = true;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isAuthorizedMinter(address minter) external view returns (bool) {
        return authorizedMinters[minter];
    }

    function getMinterAssetBalance(address minter) external view returns (uint256) {
        return minterAssetBalances[minter];
    }

    function getMinterPendingNetAmount(address minter) external pure returns (int256) {
        // Mock implementation
        minter; // silence warning
        return 0;
    }

    function isBatchSettled(uint256 batchId) external view returns (bool settled) {
        return settledBatches[batchId];
    }

    function getUnaccountedYield() external view returns (uint256) {
        return mockUnaccountedYield;
    }

    function getUserSharePrice() external view returns (uint256) {
        return mockUserSharePrice;
    }

    function getUnstakingBatch(uint256 batchId) external pure returns (DataTypes.UnstakingBatch memory) {
        // Mock implementation
        batchId; // silence warning
        DataTypes.UnstakingBatch memory batch;
        return batch;
    }

    function getCurrentBatchIds()
        external
        view
        returns (uint256 unifiedBatchId, uint256 stakingBatchId, uint256 unstakingBatchId)
    {
        return (nextBatchId, nextBatchId, nextBatchId);
    }

    function getLastSettledBatchIds()
        external
        view
        returns (uint256 unifiedBatchId, uint256 stakingBatchId, uint256 unstakingBatchId)
    {
        return (nextBatchId - 1, nextBatchId - 1, nextBatchId - 1);
    }

    function getTotalStakedKTokens() external view returns (uint256) {
        return mockTotalStakedKTokens;
    }

    function getStkTokenBalance(address user) external pure returns (uint256) {
        user; // silence warning
        return 0;
    }

    function getClaimedStkTokenBalance(address user) external pure returns (uint256) {
        user; // silence warning
        return 0;
    }

    function getUnclaimedStkTokenBalance(address user) external pure returns (uint256) {
        user; // silence warning
        return 0;
    }

    function getTotalStkTokens() external pure returns (uint256) {
        return 0;
    }

    function getStkTokenPrice() external view returns (uint256) {
        return mockStkTokenPrice;
    }

    function getTotalStkTokenAssets() external pure returns (uint256) {
        return 0;
    }

    function getStkTokenRebaseRatio() external pure returns (uint256) {
        return 1e6; // 1:1 ratio
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function grantMinterRole(address minter) external {
        authorizedMinters[minter] = true;
    }

    function revokeMinterRole(address minter) external {
        authorizedMinters[minter] = false;
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory) {
        return "MockkDNStaking";
    }

    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
