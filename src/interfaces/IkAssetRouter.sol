// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Interface for kAssetRouter for asset routing and settlement
interface IkAssetRouter {
    /*/////////////////////////////////////////////////////////////// 
                                STRUCTS
    ///////////////////////////////////////////////////////////////*/

    struct Balances {
        uint128 requested;
        uint128 deposited;
    }

    struct VaultSettlementProposal {
        address asset;
        address vault;
        bytes32 batchId;
        uint256 totalAssets;
        uint256 netted;
        uint256 yield;
        bool profit;
        uint256 executeAfter;
        bool executed;
        bool cancelled;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ContractInitialized(address indexed registry);
    event AssetsPushed(address indexed from, uint256 amount);
    event AssetsRequestPulled(
        address indexed vault, address indexed asset, address indexed batchReceiver, uint256 amount
    );
    event AssetsTransfered(
        address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount
    );
    event SharesRequestedPushed(address indexed vault, bytes32 indexed batchId, uint256 amount);
    event SharesRequestedPulled(address indexed vault, bytes32 indexed batchId, uint256 amount);
    event SharesSettled(
        address[] vaults,
        bytes32 indexed batchId,
        uint256 totalRequestedShares,
        uint256[] totalAssets,
        uint256 sharePrice
    );
    event BatchSettled(address indexed vault, bytes32 indexed batchId, uint256 totalAssets);
    event PegProtectionActivated(address indexed vault, uint256 shortfall);
    event PegProtectionExecuted(address indexed sourceVault, address indexed targetVault, uint256 amount);
    event YieldDistributed(address indexed vault, uint256 yield, bool isProfit);
    event Deposited(address indexed vault, address indexed asset, uint256 amount, bool isKMinter);

    // Timelock events
    event SettlementProposed(
        bytes32 indexed proposalId,
        address indexed vault,
        bytes32 indexed batchId,
        uint256 totalAssets,
        uint256 netted,
        uint256 yield,
        bool profit,
        uint256 executeAfter
    );
    event SettlementExecuted(
        bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId, address executor
    );
    event SettlementCancelled(bytes32 indexed proposalId, address indexed vault, bytes32 indexed batchId);
    event SettlementUpdated(
        bytes32 indexed proposalId, uint256 totalAssets, uint256 netted, uint256 yield, bool profit
    );
    event SettlementCooldownUpdated(uint256 oldCooldown, uint256 newCooldown);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientVirtualBalance();
    error ContractPaused();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalCancelled();
    error CooldownNotPassed();
    error InvalidCooldown();
    error ProposalAlreadyExists();

    /*//////////////////////////////////////////////////////////////
                            KMINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Push assets from kMinter to designated DN vault
    /// @param _asset The asset being deposited
    /// @param amount Amount of assets being pushed
    /// @param batchId The batch ID from the DN vault
    function kAssetPush(address _asset, uint256 amount, bytes32 batchId) external payable;

    /// @notice Request to pull assets for kMinter redemptions
    /// @param _asset The asset to redeem
    /// @param _vault The vault to pull from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kAssetRequestPull(address _asset, address _vault, uint256 amount, bytes32 batchId) external payable;

    /*//////////////////////////////////////////////////////////////
                        KSTAKING VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer assets between kStakingVaults
    /// @param sourceVault The vault to transfer assets from
    /// @param targetVault The vault to transfer assets to
    /// @param _asset The asset to transfer
    /// @param amount Amount of assets to transfer
    /// @param batchId The batch ID for this transfer
    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable;

    /// @notice Request to push shares for kStakingVault operations
    /// @param sourceVault The vault to push shares from
    /// @param amount Amount of shares to push
    /// @param batchId The batch ID for this operation
    function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable;

    /// @notice Request to pull shares for kStakingVault operations
    /// @param sourceVault The vault to pull shares from
    /// @param amount Amount of shares to pull
    /// @param batchId The batch ID for this operation
    function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable;

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Propose a settlement for a vault's batch
    /// @param asset Asset address
    /// @param vault Vault address to settle
    /// @param batchId Batch ID to settle
    /// @param totalAssets Total assets in the vault
    /// @param netted Netted amount in current batch
    /// @param yield Yield in current batch
    /// @param profit Whether the batch is profitable
    /// @return proposalId The unique identifier for this proposal
    function proposeSettleBatch(
        address asset,
        address vault,
        bytes32 batchId,
        uint256 totalAssets,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        external
        payable
        returns (bytes32 proposalId);

    /// @notice Execute a settlement proposal after cooldown period
    /// @param proposalId The proposal ID to execute
    function executeSettleBatch(bytes32 proposalId) external;

    /// @notice Cancel a settlement proposal before execution
    /// @param proposalId The proposal ID to cancel
    function cancelProposal(bytes32 proposalId) external;

    /// @notice Update a settlement proposal before execution
    /// @param proposalId The proposal ID to update
    /// @param totalAssets New total assets value
    /// @param netted New netted amount
    /// @param yield New yield amount
    /// @param profit New profit status
    function updateProposal(
        bytes32 proposalId,
        uint256 totalAssets,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        external;

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set contract pause state
    /// @param paused New pause state
    function setPaused(bool paused) external;

    /// @notice Set the cooldown period for settlement proposals
    /// @param cooldown New cooldown period in seconds
    function setSettlementCooldown(uint256 cooldown) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the DN vault address for a given asset
    /// @param asset The asset address
    /// @return vault The corresponding DN vault address
    function getDNVaultByAsset(address asset) external view returns (address vault);

    /// @notice Get batch balances for a vault
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return deposited Amount deposited in this batch
    /// @return requested Amount requested in this batch
    function getBatchIdBalances(
        address vault,
        bytes32 batchId
    )
        external
        view
        returns (uint256 deposited, uint256 requested);

    /// @notice Get requested shares for a vault batch
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return Requested shares amount
    function getRequestedShares(address vault, bytes32 batchId) external view returns (uint256);

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool);

    /// @notice Get details of a settlement proposal
    /// @param proposalId The proposal ID
    /// @return proposal The settlement proposal details
    function getSettlementProposal(bytes32 proposalId)
        external
        view
        returns (VaultSettlementProposal memory proposal);

    /// @notice Check if a proposal can be executed
    /// @param proposalId The proposal ID
    /// @return canExecute Whether the proposal can be executed
    /// @return reason Reason if cannot execute
    function canExecuteProposal(bytes32 proposalId) external view returns (bool canExecute, string memory reason);

    /// @notice Get the current settlement cooldown period
    /// @return cooldown The cooldown period in seconds
    function getSettlementCooldown() external view returns (uint256 cooldown);

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory);

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory);
}
