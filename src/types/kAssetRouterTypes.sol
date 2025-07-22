// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title kAssetRouterTypes
/// @notice Library containing all data structures used in the kAssetRouter contract
/// @dev Defines standardized data types for cross-contract communication and storage
library kAssetRouterTypes {
    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialization parameters for kMinter contract deployment
    /// @dev Contains all required addresses and configuration for minter setup
    struct InitParams {
        address kToken; // Address of the kToken contract to manage
        address underlyingAsset; // Address of the underlying asset (USDC/WBTC)
        address owner; // Contract owner with ultimate authority
        address admin; // Administrator with operational privileges
        address emergencyAdmin; // Emergency administrator for pause/unpause
        address institution; // Initial institutional user address
        address kBatch; // Address of the kBatch contract
        address kAssetRouter; // Address of the kAssetRouter for push model
    }

    struct Balances {
        uint256 requested;
        uint256 deposited;
    }
}
