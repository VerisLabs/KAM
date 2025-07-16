// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "src/types/DataTypes.sol";

/// @title IkMinter
/// @notice Interface for institutional minting and redemption manager for kTokens
/// @dev Defines the standard interface for kMinter implementations with batch settlement
interface IkMinter {
    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates new kTokens by accepting underlying asset deposits in a 1:1 ratio
    /// @dev Validates request parameters, transfers assets, deposits to vault, and mints tokens
    /// @param request Structured data containing deposit amount, beneficiary address, and unique nonce
    function mint(DataTypes.MintRequest calldata request) external payable;

    /// @notice Initiates a redemption request for converting kTokens back to underlying assets
    /// @dev Burns kTokens immediately and queues request for batch settlement
    /// @param request Structured data containing amount, user, and recipient addresses
    /// @return requestId Unique identifier for tracking this redemption request
    function requestRedeem(DataTypes.RedeemRequest calldata request) external payable returns (bytes32 requestId);

    /// @notice Completes a redemption request after batch settlement has occurred
    /// @dev Transfers assets from BatchReceiver to user, marks request as processed
    /// @param requestId The unique identifier of the redemption request to process
    function redeem(bytes32 requestId) external payable;

    /// @notice Cancels a pending redemption request before settlement
    /// @dev Returns kTokens to user and removes request from batch, only available before settlement
    /// @param requestId The unique identifier of the redemption request to cancel
    function cancelRequest(bytes32 requestId) external payable;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset address used for minting and redemption
    /// @return The address of the underlying asset contract
    function asset() external view returns (address);

    /// @notice Returns the kToken contract address managed by this minter
    /// @return The address of the kToken contract
    function kToken() external view returns (address);

    /// @notice Returns the kDNStaking vault address used for asset management
    /// @return The address of the kDNStaking vault contract
    function kDNStaking() external view returns (address);

    /// @notice Checks if this minter is authorized to interact with the kDNStaking vault
    /// @return True if authorized, false otherwise
    function isAuthorizedMinter() external view returns (bool);

    /// @notice Returns the BatchReceiver contract address for a specific batch
    /// @param batchId The identifier of the redemption batch
    /// @return The address of the BatchReceiver contract for the specified batch
    function getBatchReceiver(uint256 batchId) external view returns (address);

    /// @notice Checks if a specific nonce has been used in a previous request
    /// @param nonce The nonce value to check
    /// @return True if the nonce has been used, false otherwise
    function isNonceUsed(uint256 nonce) external view returns (bool);

    /// @notice Returns comprehensive information about a specific redemption batch
    /// @param batchId The identifier of the redemption batch
    /// @return Structured data containing batch details including timing and amounts
    function getBatchInfo(uint256 batchId) external view returns (DataTypes.BatchInfo memory);

    /// @notice Returns detailed information about a specific redemption request
    /// @param requestId The unique identifier of the redemption request
    /// @return Structured data containing request details including user and amount
    function getRedemptionRequest(bytes32 requestId) external view returns (DataTypes.RedemptionRequest memory);

    /// @notice Returns all redemption request IDs associated with a specific user
    /// @param user The address of the user to query
    /// @return Array of request identifiers belonging to the specified user
    function getUserRequests(address user) external view returns (bytes32[] memory);

    /// @notice Returns the total amount of assets pending redemption across all batches
    /// @return The total amount of assets awaiting settlement
    function getTotalPendingRedemptions() external view returns (uint256);

    /// @notice Returns the total amount of assets in a specific redemption batch
    /// @param batchId The identifier of the redemption batch
    /// @return The total amount of assets in the specified batch
    function getBatchTotalAmount(uint256 batchId) external view returns (uint256);

    /// @notice Checks if a redemption request is eligible for completion
    /// @param requestId The unique identifier of the redemption request
    /// @return eligible True if the request can be redeemed, false otherwise
    /// @return reason Human-readable explanation of the eligibility status
    function isEligibleForRedeem(bytes32 requestId) external view returns (bool eligible, string memory reason);

    /// @notice Returns the kDNStaking batch ID associated with a redemption request
    /// @param requestId The unique identifier of the redemption request
    /// @return The kDNStaking batch identifier for the specified request
    function getRequestKDNBatchId(bytes32 requestId) external view returns (uint256);

    /// @notice Returns the BatchReceiver address associated with a redemption request
    /// @param requestId The unique identifier of the redemption request
    /// @return The address of the BatchReceiver handling the specified request
    function getRequestBatchReceiver(bytes32 requestId) external view returns (address);

    /// @notice Returns comprehensive information about the current active batch
    /// @return batchId The identifier of the current batch
    /// @return startTime The timestamp when the current batch started
    /// @return cutoffTime The timestamp when new requests are no longer accepted
    /// @return settlementTime The timestamp when settlement will occur
    /// @return totalAmount The total amount of assets in the current batch
    function getCurrentBatchInfo()
        external
        view
        returns (uint256 batchId, uint256 startTime, uint256 cutoffTime, uint256 settlementTime, uint256 totalAmount);

    /// @notice Returns the total value of assets under management by this minter
    /// @return The total value locked in underlying assets
    function getTotalValueLocked() external view returns (uint256);

    /// @notice Returns the cumulative amount of assets deposited through this minter
    /// @return The total amount of assets deposited since inception
    function getTotalDeposited() external view returns (uint256);

    /// @notice Returns the cumulative amount of assets redeemed through this minter
    /// @return The total amount of assets redeemed since inception
    function getTotalRedeemed() external view returns (uint256);

    /// @notice Returns the total supply of kTokens managed by this minter
    /// @return The total supply of kTokens
    function getTotalKTokenSupply() external view returns (uint256);

    /// @notice Checks if the current batch has passed its cutoff time for new requests
    /// @return True if the cutoff time has passed, false otherwise
    function isCurrentBatchPastCutoff() external view returns (bool);

    /// @notice Returns the next scheduled settlement time
    /// @return The timestamp of the next settlement operation
    function getNextSettlementTime() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @dev Only callable by addresses with EMERGENCY_ADMIN_ROLE
    /// @param _isPaused True to pause the contract, false to unpause
    function setPaused(bool _isPaused) external;

    /// @notice Updates the kDNStaking vault address used for asset management
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param newStaking The address of the new kDNStaking vault contract
    function setKDNStaking(address newStaking) external;

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants administrative privileges to an address
    /// @dev Only callable by the contract owner
    /// @param admin The address to grant admin role to
    function grantAdminRole(address admin) external;

    /// @notice Revokes administrative privileges from an address
    /// @dev Only callable by the contract owner
    /// @param admin The address to revoke admin role from
    function revokeAdminRole(address admin) external;

    /// @notice Grants emergency administrative privileges to an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param emergency The address to grant emergency admin role to
    function grantEmergencyRole(address emergency) external;

    /// @notice Revokes emergency administrative privileges from an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param emergency The address to revoke emergency admin role from
    function revokeEmergencyRole(address emergency) external;

    /// @notice Grants institutional privileges to an address for minting and redemption
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param institution The address to grant institution role to
    function grantInstitutionRole(address institution) external;

    /// @notice Revokes institutional privileges from an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param institution The address to revoke institution role from
    function revokeInstitutionRole(address institution) external;

    /// @notice Grants settlement privileges to an address for batch processing
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param settler The address to grant settler role to
    function grantSettlerRole(address settler) external;

    /// @notice Revokes settlement privileges from an address
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param settler The address to revoke settler role from
    function revokeSettlerRole(address settler) external;

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the name identifier for this contract type
    /// @return The contract name as a string
    function contractName() external pure returns (string memory);

    /// @notice Returns the version identifier for this contract
    /// @return The contract version as a string
    function contractVersion() external pure returns (string memory);
}
