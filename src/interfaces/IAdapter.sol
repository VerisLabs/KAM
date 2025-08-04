// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title IAdapter
/// @notice Interface for protocol adapters that manage external strategy integrations
/// @dev All adapters must implement this interface for kAssetRouter integration
interface IAdapter {
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

    /// @notice Processes a pending redemption
    /// @param requestId The request ID to process
    function processRedemption(uint256 requestId) external;

    /// @notice Sets the total assets for a given vault
    /// @param vault The vault address
    /// @param asset The asset address
    /// @param totalAssets_ The total assets to set
    function setTotalAssets(address vault, address asset, uint256 totalAssets_) external;

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current total assets in the external strategy
    /// @param vault The vault to query
    /// @param asset The asset to query
    /// @return Total assets currently deployed in strategy
    function totalAssets(address vault, address asset) external view returns (uint256);

    /// @notice Returns the pending redemption for a request ID
    /// @param requestId The request ID to query
    /// @return vault The vault address
    /// @return asset The asset address
    /// @return shares The number of shares being redeemed
    /// @return processed Whether the redemption has been processed
    function getPendingRedemption(uint256 requestId)
        external
        view
        returns (address vault, address asset, uint256 shares, bool processed);

    /// @notice Returns the pending redemptions for a vault
    /// @param vault The vault address
    /// @return Pending redemptions for the vault   
    function getPendingRedemptions(address vault) external view returns (uint256[] memory);

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
