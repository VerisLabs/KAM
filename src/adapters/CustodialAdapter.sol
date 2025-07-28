// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { BaseAdapter } from "src/adapters/BaseAdapter.sol";

/// @title CustodialAdapter
/// @notice Adapter for custodial address integrations (CEX, CEFFU, etc.)
/// @dev Simple adapter that transfers assets to custodial addresses and tracks virtual balances
contract CustodialAdapter is BaseAdapter {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultDestinationUpdated(address indexed vault, address indexed oldAddress, address indexed newAddress);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCustodialAddress();
    error VaultDestinationNotSet();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.CustodialAdapter
    struct CustodialAdapterStorage {
        mapping(address vault => address custodialAddress) vaultDestinations;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.CustodialAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CUSTODIAL_ADAPTER_STORAGE_LOCATION =
        0x6096605776f37a069e5fb3b2282c592b4e41a8f7c82e8665fde33e5acbdbaf00;

    function _getCustodialAdapterStorage() internal pure returns (CustodialAdapterStorage storage $) {
        assembly {
            $.slot := CUSTODIAL_ADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the custodial adapter
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    function initialize(address registry_, address owner_, address admin_) external initializer {
        __BaseAdapter_init(registry_, owner_, admin_, "CustodialAdapter", "1.0.0");
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits assets to custodial address
    /// @param asset The asset to deposit
    /// @param amount The amount to deposit
    /// @param onBehalfOf The vault address this deposit is for
    function _deposit(address asset, uint256 amount, address onBehalfOf) internal override {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        address custodialAddress = $.vaultDestinations[onBehalfOf];
        if (custodialAddress == address(0)) revert VaultDestinationNotSet();

        // Transfer assets to custodial address
        asset.safeTransferFrom(msg.sender, custodialAddress, amount);

        // Update adapter balance tracking
        _adapterDeposit(onBehalfOf, asset, amount);

        emit Deposited(asset, amount, onBehalfOf);
    }

    /// @notice Processes redemption request for custodial assets
    /// @param asset The asset to redeem
    /// @param amount The amount to redeem
    /// @param onBehalfOf The vault address this redemption is for
    /// @dev For custodial adapters, redemption is virtual - actual settlement happens off-chain
    function _redeem(address asset, uint256 amount, address onBehalfOf) internal override {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        address custodialAddress = $.vaultDestinations[onBehalfOf];
        if (custodialAddress == address(0)) revert VaultDestinationNotSet();

        // Update adapter balance tracking
        _adapterRedeem(onBehalfOf, asset, amount);

        emit RedemptionRequested(asset, amount, onBehalfOf);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current total assets across all custodial addresses for this asset
    /// @param asset The asset to query
    /// @return Total assets currently held across all custodial addresses managed by this adapter
    function totalAssets(address asset) external view override returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        // For custodial adapters, we sum adapter balances across all vaults
        // This represents the total assets we're managing for this asset
        uint256 total = 0;

        // Get vaults that use this adapter by checking which vaults have this asset
        address[] memory vaults = _registry().getVaultsByAsset(asset);

        for (uint256 i = 0; i < vaults.length; i++) {
            // Only count if this vault uses this adapter
            if (_registry().getAdapter(vaults[i]) == address(this)) {
                total += this.adapterBalance(vaults[i], asset);
            }
        }

        return total;
    }

    /// @notice Returns estimated total assets (same as totalAssets for custodial)
    /// @param asset The asset to query
    /// @return Estimated total assets (custodial addresses don't generate yield independently)
    function estimatedTotalAssets(address asset) external view override returns (uint256) {
        return this.totalAssets(asset);
    }

    /// @notice Returns the current total assets for a specific vault
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Total assets currently held in custodial address for this vault
    function totalAssetsForVault(address vault, address asset) external view override returns (uint256) {
        // For custodial adapter, the adapter balance equals the total assets
        return this.adapterBalance(vault, asset);
    }

    /// @notice Returns estimated total assets for a specific vault (same as totalAssetsForVault for custodial)
    /// @param vault The vault address
    /// @param asset The asset to query
    /// @return Estimated total assets for this vault
    function estimatedTotalAssetsForVault(address vault, address asset) external view override returns (uint256) {
        // Custodial addresses don't generate yield independently
        return this.totalAssetsForVault(vault, asset);
    }

    /// @notice Returns the custodial address for a given vault
    /// @param vault The vault address
    /// @return The custodial address for the vault
    function getVaultDestination(address vault) external view returns (address) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.vaultDestinations[vault];
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the custodial address for a vault
    /// @param vault The vault address
    /// @param custodialAddress The custodial address for this vault
    function setVaultDestination(address vault, address custodialAddress) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0) || custodialAddress == address(0)) {
            revert InvalidCustodialAddress();
        }

        // Validate vault is registered
        if (!_registry().isVault(vault)) {
            revert InvalidCustodialAddress();
        }

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        address oldAddress = $.vaultDestinations[vault];
        $.vaultDestinations[vault] = custodialAddress;

        emit VaultDestinationUpdated(vault, oldAddress, custodialAddress);
    }

    /// @notice Manual settlement function for reconciling off-chain redemptions
    /// @param asset The asset that was redeemed off-chain
    /// @param amount The amount that was actually redeemed
    /// @param vault The vault that the redemption was for
    /// @dev Called by relayer to confirm off-chain settlements
    function confirmRedemption(address asset, uint256 amount, address vault) external onlyRelayer {
        // Transfer assets from custodial back to kAssetRouter
        // This function assumes custodial has already processed the redemption off-chain
        // and we're just reconciling the on-chain state

        emit RedemptionProcessed(0, amount); // Using 0 as requestId for custodial
    }

    /*//////////////////////////////////////////////////////////////
                          EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency withdrawal from custodial address (if possible)
    /// @param asset Asset to withdraw
    /// @param amount Amount to withdraw
    /// @param to Recipient address
    /// @dev For custodial adapters, this might not be directly callable
    function _emergencyWithdraw(address asset, uint256 amount, address to) internal override {
        // For custodial adapters, emergency withdrawal might need to be coordinated
        // with the custodial service off-chain. This function serves as a flag
        // that emergency withdrawal was requested.

        // Emit event for off-chain monitoring systems
        // Actual withdrawal coordination happens off-chain
        emit RedemptionRequested(asset, amount, to);
    }
}
