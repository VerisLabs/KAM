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

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address indexed registry, address indexed owner, address admin, bool paused);
    event AssetsPushed(address indexed from, uint256 amount);
    event AssetsRequestPulled(
        address indexed vault, address indexed asset, address indexed batchReceiver, uint256 amount
    );
    event AssetsTransfered(
        address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount
    );
    event SharesRequestedPushed(address indexed vault, uint256 batchId, uint256 amount);
    event SharesRequestedPulled(address indexed vault, uint256 batchId, uint256 amount);
    event SharesSettled(
        address[] vaults, uint256 batchId, uint256 totalRequestedShares, uint256[] totalAssets, uint256 sharePrice
    );
    event BatchSettled(address indexed vault, uint256 indexed batchId, uint256 totalAssets);
    event PegProtectionActivated(address indexed vault, uint256 shortfall);
    event PegProtectionExecuted(address indexed sourceVault, address indexed targetVault, uint256 amount);
    event YieldDistributed(address indexed vault, uint256 yield, bool isProfit);
    event Deposited(address indexed vault, address indexed asset, uint256 amount, bool isKMinter);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error InsufficientVirtualBalance();
    error ContractPaused();
    error OnlyStakingVault();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Push assets from kMinter to designated DN vault
    /// @param _asset The asset being deposited
    /// @param amount Amount of assets being pushed
    /// @param batchId The batch ID from the DN vault
    function kAssetPush(address _asset, uint256 amount, uint256 batchId) external payable;
    function kAssetRequestPull(address _asset, address _vault, uint256 amount, uint256 batchId) external payable;
    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        uint256 batchId
    )
        external
        payable;
    function kSharesRequestPush(address sourceVault, uint256 amount, uint256 batchId) external payable;
    function kSharesRequestPull(address sourceVault, uint256 amount, uint256 batchId) external payable;
    function settleBatch(
        address asset,
        address vault,
        uint256 batchId,
        uint256 totalAssets,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        external
        payable;
    function setPaused(bool paused) external;

    function getBalanceOf(address _vault, address _asset) external view returns (uint256);
    function getBatchIdBalances(
        address vault,
        uint256 batchId
    )
        external
        view
        returns (uint256 deposited, uint256 requested);
    function getRequestedShares(address vault, uint256 batchId) external view returns (uint256);
    function isPaused() external view returns (bool);
}
