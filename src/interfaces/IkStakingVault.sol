// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IVaultBatch } from "./modules/IVaultBatch.sol";
import { IVaultClaim } from "./modules/IVaultClaim.sol";
import { IVaultFees } from "./modules/IVaultFees.sol";

/// @title IkStakingVault
/// @notice Interface for kStakingVault that manages minter operations and user staking
/// @dev Matches kStakingVault implementation
interface IkStakingVault is IVaultBatch, IVaultClaim, IVaultFees {
    /*//////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function requestStake(address to, uint256 kTokensAmount) external payable returns (bytes32 requestId);
    function requestUnstake(address to, uint256 stkTokenAmount) external payable returns (bytes32 requestId);
    function updateLastTotalAssets(uint256 totalAssets) external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function asset() external view returns (address);
    function totalSupply() external view returns (uint256);
    function underlyingAsset() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function calculateStkTokenPrice(uint256 totalAssets) external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalNetAssets() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function lastTotalAssets() external view returns (uint256);
    function kToken() external view returns (address);
    function getBatchId() external view returns (bytes32);
    function getSafeBatchId() external view returns (bytes32);
    function getSafeBatchReceiver(bytes32 batchId) external view returns (address);
    function isBatchClosed() external view returns (bool);
    function isBatchSettled() external view returns (bool);
    function getBatchIdInfo()
        external
        view
        returns (bytes32 batchId, address batchReceiver, bool isClosed, bool isSettled);
    function getBatchReceiver(bytes32 batchId) external view returns (address);
    function getBatchIdReceiver(bytes32 batchId) external view returns (address);
    function sharePrice() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
