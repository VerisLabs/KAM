// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {DataTypes} from "src/types/DataTypes.sol";

interface IkMinter {
    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mint(DataTypes.MintRequest calldata request) external payable;
    function requestRedeem(DataTypes.RedeemRequest calldata request) external payable returns (bytes32 requestId);
    function redeem(bytes32 requestId) external payable;
    function cancelRequest(bytes32 requestId) external payable;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function asset() external view returns (address);
    function kToken() external view returns (address);
    function kDNStaking() external view returns (address);
    function isAuthorizedMinter() external view returns (bool);
    function getBatchReceiver(uint256 batchId) external view returns (address);
    function isNonceUsed(uint256 nonce) external view returns (bool);
    function getBatchInfo(uint256 batchId) external view returns (DataTypes.BatchInfo memory);
    function getRedemptionRequest(bytes32 requestId) external view returns (DataTypes.RedemptionRequest memory);
    function getUserRequests(address user) external view returns (bytes32[] memory);
    function getTotalPendingRedemptions() external view returns (uint256);
    function getBatchTotalAmount(uint256 batchId) external view returns (uint256);
    function isEligibleForRedeem(bytes32 requestId) external view returns (bool eligible, string memory reason);
    function getRequestKDNBatchId(bytes32 requestId) external view returns (uint256);
    function getRequestBatchReceiver(bytes32 requestId) external view returns (address);
    function getCurrentBatchInfo()
        external
        view
        returns (uint256 batchId, uint256 startTime, uint256 cutoffTime, uint256 settlementTime, uint256 totalAmount);
    function getTotalValueLocked() external view returns (uint256);
    function getTotalDeposited() external view returns (uint256);
    function getTotalRedeemed() external view returns (uint256);
    function getTotalKTokenSupply() external view returns (uint256);
    function isCurrentBatchPastCutoff() external view returns (bool);
    function getNextSettlementTime() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setPaused(bool _isPaused) external;
    function setKDNStaking(address newStaking) external;

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantAdminRole(address admin) external;
    function revokeAdminRole(address admin) external;
    function grantEmergencyRole(address emergency) external;
    function revokeEmergencyRole(address emergency) external;
    function grantInstitutionRole(address institution) external;
    function revokeInstitutionRole(address institution) external;
    function grantSettlerRole(address settler) external;
    function revokeSettlerRole(address settler) external;

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
