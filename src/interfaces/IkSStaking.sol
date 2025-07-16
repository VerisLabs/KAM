// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "src/types/DataTypes.sol";

/// @title IkSStaking
/// @notice Interface for kSStakingVault that manages strategy-based staking operations
/// @dev Matches kSStakingVault implementation
interface IkSStaking {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user requests to stake kTokens in the strategy vault
    /// @dev Indicates a new staking request has been added to the current batch
    event KTokenStakingRequested(address indexed user, uint256 kTokenAmount, uint256 indexed batchId);

    /// @notice Emitted when kTokens have been successfully staked and shares issued
    /// @dev Indicates completion of the staking process after batch settlement
    event KTokenStaked(address indexed user, uint256 kTokenAmount, uint256 shares, uint256 indexed batchId);

    /// @notice Emitted when shares have been successfully unstaked back to kTokens
    /// @dev Indicates completion of the unstaking process with asset recovery
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);

    /// @notice Emitted when assets are requested from the kDNStakingVault for strategy allocation
    /// @dev Indicates asset flow from delta-neutral vault to strategy vault
    event AssetsRequestedFromDN(uint256 amount, uint256 indexed batchId);

    /// @notice Emitted when assets are returned to the kDNStakingVault from strategy operations
    /// @dev Indicates asset flow back from strategy vault to delta-neutral vault
    event AssetsReturnedToDN(uint256 amount, uint256 indexed batchId);

    /*//////////////////////////////////////////////////////////////
                        USER STAKING OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initiates a request to stake kTokens in the strategy vault for yield generation
    /// @dev Transfers kTokens from user and adds request to current staking batch
    /// @param amount Amount of kTokens to stake in the strategy vault
    /// @return requestId Unique identifier for tracking this staking request
    function requestStake(uint256 amount) external payable returns (uint256 requestId);

    /// @notice Initiates a request to unstake stkTokens back to underlying assets
    /// @dev Escrows stkTokens and adds request to current unstaking batch
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Unique identifier for tracking this unstaking request
    function requestUnstake(uint256 stkTokenAmount) external payable returns (uint256 requestId);

    /// @notice Claims strategy vault shares after a staking batch has been settled
    /// @dev Transfers vault shares to user, completing the staking process
    /// @param batchId The identifier of the settled staking batch
    /// @param requestIndex The index of the user's request within the batch
    function claimStakedShares(uint256 batchId, uint256 requestIndex) external payable;

    /// @notice Claims underlying assets after an unstaking batch has been settled
    /// @dev Transfers assets to user, completing the unstaking process
    /// @param batchId The identifier of the settled unstaking batch
    /// @param requestIndex The index of the user's request within the batch
    function claimUnstakedAssets(uint256 batchId, uint256 requestIndex) external payable;

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Settles a staking batch by allocating assets to strategy destinations
    /// @dev Processes all staking requests in the batch and allocates assets to strategies
    /// @param batchId The identifier of the staking batch to settle
    /// @param totalKTokensStaked Total amount of kTokens being staked in this batch
    /// @param destinations Array of strategy addresses to receive allocated assets
    /// @param amounts Array of amounts to allocate to each destination
    function settleStakingBatch(
        uint256 batchId,
        uint256 totalKTokensStaked,
        address[] calldata destinations,
        uint256[] calldata amounts
    )
        external;

    /// @notice Settles an unstaking batch by retrieving assets from strategy sources
    /// @dev Processes all unstaking requests in the batch and retrieves assets from strategies
    /// @param batchId The identifier of the unstaking batch to settle
    /// @param totalStkTokensUnstaked Total amount of stkTokens being unstaked in this batch
    /// @param sources Array of strategy addresses to retrieve assets from
    /// @param amounts Array of amounts to retrieve from each source
    function settleUnstakingBatch(
        uint256 batchId,
        uint256 totalStkTokensUnstaked,
        address[] calldata sources,
        uint256[] calldata amounts
    )
        external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the total assets under management in the strategy vault
    /// @return The total amount of underlying assets in the vault
    function getTotalVaultAssets() external view returns (uint256);

    /// @notice Returns the total assets belonging to users in the strategy vault
    /// @return The total amount of user assets including accumulated yield
    function getTotalUserAssets() external view returns (uint256);

    /// @notice Returns the address of the connected kDNStakingVault
    /// @return The address of the delta-neutral staking vault
    function getKDNVault() external view returns (address);

    /// @notice Returns the current batch identifiers for staking and unstaking operations
    /// @return stakingBatchId The current staking batch identifier
    /// @return unstakingBatchId The current unstaking batch identifier
    function getCurrentBatchIds() external view returns (uint256 stakingBatchId, uint256 unstakingBatchId);

    /// @notice Returns the last settled batch identifiers for staking and unstaking operations
    /// @return stakingBatchId The last settled staking batch identifier
    /// @return unstakingBatchId The last settled unstaking batch identifier
    function getLastSettledBatchIds() external view returns (uint256 stakingBatchId, uint256 unstakingBatchId);

    /// @notice Returns the total amount of kTokens currently staked in strategies
    /// @return The total amount of kTokens allocated to strategy operations
    function getTotalStakedKTokens() external view returns (uint256);

    /// @notice Returns the strategy vault share balance for a specific user
    /// @param user The address of the user to query
    /// @return The amount of strategy vault shares owned by the user
    function getStkTokenBalance(address user) external view returns (uint256);

    /// @notice Returns the claimed stkToken balance for a specific user
    /// @param user The address of the user to query
    /// @return The amount of stkTokens claimed by the user from settled batches
    function getClaimedStkTokenBalance(address user) external view returns (uint256);

    /// @notice Returns the total supply of stkTokens issued by the strategy vault
    /// @return The total amount of stkTokens in circulation
    function getTotalStkTokens() external view returns (uint256);

    /// @notice Returns the current price of stkTokens in terms of underlying assets
    /// @return The price of stkTokens scaled to the appropriate precision
    function getStkTokenPrice() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the address of the connected kDNStakingVault
    /// @dev Only callable by addresses with ADMIN_ROLE
    /// @param kDNVault The address of the new delta-neutral staking vault
    function setKDNVault(address kDNVault) external;

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
