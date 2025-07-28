// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IAdapter
/// @notice Interface for protocol adapters that manage external strategy integrations
/// @dev All adapters must implement this interface for kAssetRouter integration
interface IAdapter {
    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event RedemptionRequested(address indexed asset, uint256 amount, address indexed onBehalfOf);
    event RedemptionProcessed(uint256 indexed requestId, uint256 assets);
    event AdapterBalanceUpdated(address indexed vault, address indexed asset, uint256 newBalance);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAsset();
    error InvalidAmount();
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets to external strategy on behalf of a vault
    /// @param asset The asset to deposit
    /// @param amount The amount to deposit
    /// @param onBehalfOf The vault address this deposit is for
    function deposit(address asset, uint256 amount, address onBehalfOf) external;

    /// @notice Redeems assets from external strategy on behalf of a vault
    /// @param asset The asset to redeem
    /// @param amount The amount to redeem
    /// @param onBehalfOf The vault address this redemption is for
    function redeem(address asset, uint256 amount, address onBehalfOf) external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current total assets in the external strategy
    /// @param asset The asset to query
    /// @return Total assets currently deployed in strategy
    function totalAssets(address asset) external view returns (uint256);

    /// @notice Returns estimated total assets including pending yield
    /// @param asset The asset to query
    /// @return Estimated total assets including unrealized gains
    function estimatedTotalAssets(address asset) external view returns (uint256);

    /// @notice Returns the current total assets for a specific vault
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Total assets currently deployed for this vault
    function totalAssetsForVault(address vault, address asset) external view returns (uint256);

    /// @notice Returns estimated total assets for a specific vault including pending yield
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Estimated total assets including unrealized gains for this vault
    function estimatedTotalAssetsForVault(address vault, address asset) external view returns (uint256);

    /// @notice Returns the adapter balance for a specific vault
    /// @param vault The vault address
    /// @param asset The asset address
    /// @return Adapter balance for the vault
    function adapterBalance(address vault, address asset) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                          METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns whether this adapter is registered
    /// @return True if adapter is registered and active
    function registered() external view returns (bool);

    /// @notice Returns the adapter's name for identification
    /// @return Human readable adapter name
    function name() external view returns (string memory);

    /// @notice Returns the adapter's version
    /// @return Version string
    function version() external view returns (string memory);
}
