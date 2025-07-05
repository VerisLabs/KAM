// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "src/types/DataTypes.sol";

/// @title IkDNStaking
/// @notice Interface for kDNStakingVault that manages minter operations and user staking
/// @dev Matches kDNStakingVault implementation
interface IkDNStaking {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event MinterDepositRequested(address indexed minter, uint256 assetAmount, uint256 indexed batchId);
    event MinterRedeemRequested(
        address indexed minter, uint256 assetAmount, address batchReceiver, uint256 indexed batchId
    );
    event KTokenStakingRequested(
        address indexed user, address indexed minter, uint256 kTokenAmount, uint256 indexed batchId
    );
    event KTokenStaked(address indexed user, uint256 kTokenAmount, uint256 shares, uint256 indexed batchId);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);

    /*//////////////////////////////////////////////////////////////
                          MINTER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function requestMinterDeposit(uint256 assetAmount) external payable returns (uint256 batchId);
    function requestMinterRedeem(
        uint256 assetAmount,
        address minter,
        address batchReceiver
    )
        external
        payable
        returns (uint256 batchId);

    /*//////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function requestStake(uint256 amount) external payable returns (uint256 requestId);
    function requestUnstake(uint256 stkTokenAmount) external payable returns (uint256 requestId);
    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable;
    function claimUnstakedAssets(uint256 batchId, uint256 requestIndex) external payable;

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    function settleBatch(uint256 batchId) external;
    function settleStakingBatch(uint256 batchId, uint256 totalKTokensStaked) external;
    function settleUnstakingBatch(
        uint256 batchId,
        uint256 totalStkTokensUnstaked,
        uint256 totalKTokensToReturn,
        uint256 totalYieldToMinter
    )
        external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isAuthorizedMinter(address minter) external view returns (bool);
    function getMinterAssetBalance(address minter) external view returns (uint256);
    function getMinterPendingNetAmount(address minter) external view returns (int256);
    function isBatchSettled(uint256 batchId) external view returns (bool settled);
    function getUnaccountedYield() external view returns (uint256);
    function getUserSharePrice() external view returns (uint256);
    function getUnstakingBatch(uint256 batchId) external view returns (DataTypes.UnstakingBatch memory);
    function getCurrentBatchIds()
        external
        view
        returns (uint256 unifiedBatchId, uint256 stakingBatchId, uint256 unstakingBatchId);
    function getLastSettledBatchIds()
        external
        view
        returns (uint256 unifiedBatchId, uint256 stakingBatchId, uint256 unstakingBatchId);
    function getTotalStakedKTokens() external view returns (uint256);
    function getStkTokenBalance(address user) external view returns (uint256);
    function getClaimedStkTokenBalance(address user) external view returns (uint256);
    function getUnclaimedStkTokenBalance(address user) external view returns (uint256);
    function getTotalStkTokens() external view returns (uint256);
    function getStkTokenPrice() external view returns (uint256);
    function getTotalStkTokenAssets() external view returns (uint256);
    function getStkTokenRebaseRatio() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function grantMinterRole(address minter) external;
    function revokeMinterRole(address minter) external;

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
