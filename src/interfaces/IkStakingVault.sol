// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IkStakingVault
/// @notice Interface for kStakingVault that manages minter operations and user staking
/// @dev Matches kStakingVault implementation
interface IkStakingVault {
    /*//////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function requestStake(uint256 amount) external payable returns (uint256 requestId);
    function requestUnstake(uint256 stkTokenAmount) external payable returns (uint256 requestId);
    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable;
    function claimUnstakedAssets(uint256 batchId, uint256 requestIndex) external payable;
    function updateLastTotalAssets(uint256 totalAssets) external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function asset() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function calculateStkTokenPrice(uint256 totalAssets) external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);
    function kToken() external view returns (address);
    function getBatchId() external view returns (uint256);
    function isBatchClosed() external view returns (bool);
    function isBatchSettled() external view returns (bool);
    function getBatchInfo() external view returns (uint256 batchId, bool isClosed, bool isSettled);
    function sharePrice() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
