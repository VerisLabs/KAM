// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title DataTypes
/// @notice Library containing all data structures used in the protocol
library DataTypes {
    /*//////////////////////////////////////////////////////////////
                        ENUMS
    //////////////////////////////////////////////////////////////*/

    enum RedemptionStatus {
        PENDING,
        REDEEMED,
        CANCELLED
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct InitParams {
        address kToken;
        address underlyingAsset;
        address owner;
        address admin;
        address emergencyAdmin;
        address institution;
        address settler;
        address manager;
        uint256 settlementInterval;
    }

    struct kTokenInitParams {
        uint8 decimals;
        address owner;
        address admin;
        address emergencyAdmin;
        address minter;
    }

    struct kDNStakingVaultInitParams {
        uint8 decimals;
        address asset;
        address kToken;
        address owner;
        address admin;
        address emergencyAdmin;
        address settler;
        address strategyManager;
    }

    struct MintRequest {
        uint256 amount;
        address beneficiary;
    }

    struct RedeemRequest {
        uint256 amount;
        address user;
        address recipient;
    }

    struct RedemptionRequest {
        bytes32 id;
        address user;
        uint96 amount;
        address recipient;
        address batchReceiver;
        uint64 requestTimestamp;
        RedemptionStatus status;
    }

    struct BatchInfo {
        uint256 startTime;
        uint256 cutoffTime;
        uint256 settlementTime;
        bool isClosed;
        uint256 totalAmount;
        address batchReceiver;
    }

    /*//////////////////////////////////////////////////////////////
                    KDNSTAKING VAULT STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Batch {
        uint256 totalDeposits;
        uint256 totalRedeems;
        uint256 netDeposits;
        uint256 netRedeems;
        uint256 sharesCreated;
        uint256 sharesBurned;
        address[] minters;
        mapping(address => uint256) depositAmounts;
        mapping(address => uint256) redeemAmounts;
        mapping(address => address) batchReceivers;
        mapping(address => bool) hasMinterOperation;
        bool settled;
    }

    struct StakingRequest {
        address user;
        uint96 kTokenAmount;
        uint96 stkTokenAmount;
        uint64 requestTimestamp;
        bool claimed;
    }

    struct StakingBatch {
        StakingRequest[] requests;
        uint256 stkTokenPrice;
        uint256 totalKTokens;
        uint256 totalStkTokens;
        uint256 totalStkTokensClaimed;
        uint256 totalAssetsFromMinter;
        bool settled;
    }

    struct UnstakingRequest {
        address user;
        uint96 stkTokenAmount;
        uint64 requestTimestamp;
        bool claimed;
    }

    struct UnstakingBatch {
        UnstakingRequest[] requests;
        uint256 stkTokenPrice;
        uint256 totalStkTokens;
        uint256 totalKTokensToReturn;
        uint256 totalYieldToMinter;
        uint256 totalKTokensClaimed;
        uint256 originalKTokenRatio; // Ratio of original kTokens to stkTokens (scaled by PRECISION)
        bool settled;
    }

    struct AdapterConfig {
        bool enabled;
        uint256 maxAllocation;
        uint256 currentAllocation;
        address implementation;
    }

    /*//////////////////////////////////////////////////////////////
                    KSTRATEGY MANAGER STRUCTS
    //////////////////////////////////////////////////////////////*/

    enum AdapterType {
        CUSTODIAL_WALLET,
        ERC7540_VAULT,
        LENDING_PROTOCOL
    }

    struct Allocation {
        AdapterType adapterType;
        address target;
        uint256 amount;
        bytes data;
    }

    struct AllocationOrder {
        uint256 totalAmount;
        Allocation[] allocations;
        uint256 nonce;
        uint256 deadline;
    }
}
