// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Initializable } from "src/vendor/Initializable.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";

import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import {
    CUSTODIAL_INVALID_CUSTODIAL_ADDRESS,
    CUSTODIAL_TRANSFER_FAILED,
    CUSTODIAL_VAULT_DESTINATION_NOT_SET,
    CUSTODIAL_WRONG_ASSET,
    CUSTODIAL_WRONG_ROLE,
    CUSTODIAL_ZERO_ADDRESS,
    CUSTODIAL_ZERO_AMOUNT
} from "src/errors/Errors.sol";

/// @title CustodialAdapter
/// @notice Specialized adapter enabling yield generation through custodial services like CEX staking and institutional
/// platforms
/// @dev This adapter implements the bridge between KAM protocol vaults and external custodial yield sources
/// (centralized
/// exchanges, CEFFU, institutional staking providers). Key functionality includes: (1) Virtual balance tracking that
/// maintains on-chain accounting while assets are held off-chain, (2) Configurable custodial destinations per vault
/// allowing flexible routing to different providers, (3) Two-phase deposit/redemption flow where deposits are tracked
/// virtually and actual transfers happen through manual processes, (4) Total assets management for accurate yield
/// calculation during settlements, (5) Request ID system for tracking redemption operations. The adapter operates on
/// a trust-minimized model where admin-controlled totalAssets updates reflect off-chain yields, which are then
/// distributed
/// through the settlement process. This design enables institutional-grade yield opportunities while maintaining the
/// protocol's unified settlement and distribution mechanisms. The virtual balance system ensures accurate accounting
/// even when assets are temporarily off-chain for yield generation.
contract CustodialAdapter is BaseAdapter, Initializable, UUPSUpgradeable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a vault's custodial destination address is configured or updated
    /// @dev Custodial addresses represent off-chain destinations (CEX wallets, institutional accounts) where
    /// assets are sent for yield generation. Each vault can have its own destination for segregation.
    /// @param vault The vault address whose custodial destination is being updated
    /// @param oldAddress The previous custodial address (address(0) if first configuration)
    /// @param newAddress The new custodial address for this vault's assets
    event VaultDestinationUpdated(address indexed vault, address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when total assets are updated to reflect off-chain yields or losses
    /// @dev This update mechanism allows the protocol to account for yields generated in custodial accounts.
    /// The kAssetRouter uses these values during settlement to calculate and distribute yields.
    /// @param vault The vault address whose total assets are being updated
    /// @param totalAssets The new total asset value including any yields or losses
    event TotalAssetsUpdated(address indexed vault, uint256 totalAssets);

    /// @notice Emitted when assets are virtually deposited for custodial yield generation
    /// @dev Marks the virtual accounting update when kAssetRouter routes assets to this adapter.
    /// Actual transfer to custodial address happens separately through manual processes.
    /// @param asset The underlying asset being deposited (USDC, WBTC, etc.)
    /// @param amount The quantity of assets being virtually deposited
    /// @param onBehalfOf The vault address that owns these deposited assets
    event Deposited(address indexed asset, uint256 amount, address indexed onBehalfOf);

    /// @notice Emitted when redemption is requested from custodial holdings
    /// @dev Initiates the redemption process by updating virtual balances. Actual asset return
    /// from custodial address happens through manual processes coordinated off-chain.
    /// @param asset The underlying asset being redeemed
    /// @param amount The quantity requested for redemption
    /// @param onBehalfOf The vault requesting the redemption
    event RedemptionRequested(address indexed asset, uint256 amount, address indexed onBehalfOf);

    /// @notice Emitted when a redemption is processed
    /// @param requestId The request ID
    /// @param assets The amount of assets processed
    event RedemptionProcessed(uint256 indexed requestId, uint256 assets);

    /// @notice Emitted when the adapter balance is updated
    /// @param vault The vault address
    /// @param asset The asset address
    /// @param newBalance The new balance
    event AdapterBalanceUpdated(address indexed vault, address indexed asset, uint256 newBalance);

    /// @notice Emitted when the adapter is initialized
    /// @param registry The registry address
    event Initialised(address indexed registry);

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.CustodialAdapter
    /// @dev Storage layout using ERC-7201 pattern for upgrade safety and collision prevention
    struct CustodialAdapterStorage {
        /// @dev Incrementing ID for tracking redemption requests
        uint256 nextRequestId;
        /// @dev Virtual balance tracking per vault per asset (actual assets may be off-chain)
        mapping(address vault => mapping(address asset => uint256 balance)) balanceOf;
        /// @dev Total assets including yields for settlement calculations
        mapping(address vault => mapping(address asset => uint256 totalAssets)) totalAssets;
        /// @dev Maps each vault to its designated custodial address for asset transfers
        mapping(address vault => address custodialAddress) vaultDestinations;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.CustodialAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CUSTODIAL_ADAPTER_STORAGE_LOCATION =
        0x6096605776f37a069e5fb3b2282c592b4e41a8f7c82e8665fde33e5acbdbaf00;

    /// @dev Returns the custodial adapter storage pointer
    function _getCustodialAdapterStorage() internal pure returns (CustodialAdapterStorage storage $) {
        assembly {
            $.slot := CUSTODIAL_ADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Empty constructor to ensure clean initialization state
    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the CustodialAdapter with registry integration and request tracking
    /// @dev Initialization process: (1) Calls BaseAdapter initialization for registry setup and metadata,
    /// (2) Initializes request ID counter for redemption tracking, (3) Emits initialization event for
    /// monitoring. The adapter starts with no vault destinations configured - these must be set by admin
    /// before deposits can occur. Uses OpenZeppelin's initializer modifier for reentrancy protection.
    /// @param registry_ The kRegistry contract address for protocol configuration and access control
    function initialize(address registry_) external initializer {
        __BaseAdapter_init(registry_, "CustodialAdapter", "1.0.0");

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        $.nextRequestId = 1;

        emit Initialised(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Virtually deposits assets for custodial yield generation while maintaining on-chain accounting
    /// @dev This function handles the on-chain accounting when assets are routed to custodial services. Process:
    /// (1) Validates caller is kAssetRouter ensuring centralized control over deposits, (2) Validates parameters
    /// to prevent zero deposits or invalid addresses, (3) Checks vault has configured custodial destination,
    /// (4) Verifies adapter has received the assets from kAssetRouter, (5) Updates virtual balance tracking
    /// for accurate accounting. Note: This doesn't transfer to custodial address - that happens through separate
    /// manual processes. The virtual tracking ensures the protocol knows asset locations even when off-chain.
    /// This two-phase approach enables yield generation through custodial services while maintaining protocol
    /// accounting integrity for settlements.
    /// @param asset The underlying asset being deposited (must be protocol-registered)
    /// @param amount The quantity being virtually deposited (must be non-zero)
    /// @param onBehalfOf The vault that owns these assets for yield attribution
    function deposit(address asset, uint256 amount, address onBehalfOf) external {
        _lockReentrant();
        require(_isKAssetRouter(msg.sender), CUSTODIAL_WRONG_ROLE);
        require(asset != address(0), CUSTODIAL_WRONG_ASSET);
        require(amount != 0, CUSTODIAL_ZERO_AMOUNT);
        require(onBehalfOf != address(0), CUSTODIAL_WRONG_ASSET);

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        address custodialAddress = $.vaultDestinations[onBehalfOf];
        require(custodialAddress != address(0), CUSTODIAL_VAULT_DESTINATION_NOT_SET);

        // Validate if the assets are available
        require(asset.balanceOf(address(this)) >= amount, CUSTODIAL_TRANSFER_FAILED);

        // Update adapter balance tracking
        $.balanceOf[onBehalfOf][asset] += amount;

        emit Deposited(asset, amount, onBehalfOf);

        _unlockReentrant();
    }

    /// @notice Virtually redeems assets from custodial holdings by updating on-chain accounting
    /// @dev Handles the accounting for asset redemptions from custodial services. Process: (1) Validates
    /// caller is kAssetRouter for centralized control, (2) Validates parameters preventing invalid redemptions,
    /// (3) Checks vault has configured destination ensuring proper setup, (4) Decrements virtual balance
    /// reflecting the redemption request. Like deposits, actual asset return from custodial address happens
    /// through manual processes. The virtual balance update ensures accurate protocol accounting during the
    /// redemption period. This function is virtual allowing specialized implementations to add custom logic
    /// while maintaining base redemption accounting.
    /// @param asset The underlying asset being redeemed
    /// @param amount The quantity to redeem (must not exceed virtual balance)
    /// @param onBehalfOf The vault requesting redemption of its assets
    function redeem(address asset, uint256 amount, address onBehalfOf) external virtual {
        _lockReentrant();
        require(_isKAssetRouter(msg.sender), CUSTODIAL_WRONG_ROLE);
        require(asset != address(0), CUSTODIAL_WRONG_ASSET);
        require(amount != 0, CUSTODIAL_ZERO_AMOUNT);
        require(onBehalfOf != address(0), CUSTODIAL_WRONG_ASSET);

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();

        address custodialAddress = $.vaultDestinations[onBehalfOf];
        require(custodialAddress != address(0), CUSTODIAL_VAULT_DESTINATION_NOT_SET);

        // Update adapter balance tracking
        $.balanceOf[onBehalfOf][asset] -= amount;

        emit RedemptionRequested(asset, amount, onBehalfOf);

        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current total assets across all custodial addresses for this asset
    /// @param vault The vault to query
    /// @return Total assets currently held across all custodial addresses managed by this adapter
    function totalEstimatedAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        address custodialAddress = $.vaultDestinations[vault];
        return asset.balanceOf(custodialAddress);
    }

    /// @notice Returns the total assets in storage for a given vault
    /// @param vault The vault address
    /// @return Total assets currently held in storage for this vault
    function totalVirtualAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.balanceOf[vault][asset];
    }

    /// @notice Returns the total assets for a given vault and asset
    /// @param vault The vault address
    /// @return Total assets currently held for this vault and asset
    function totalAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.totalAssets[vault][asset];
    }

    /// @notice Returns the last total assets for a given vault and asset
    /// @param vault The vault address
    /// @param asset The asset address
    /// @return The last total assets for the vault and asset
    function getLastTotalAssets(address vault, address asset) external view returns (uint256) {
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        return $.totalAssets[vault][asset];
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

    /// @notice Configures the custodial destination address for a specific vault's assets
    /// @dev Admin function to map vaults to their custodial service providers. Process: (1) Validates admin
    /// authorization for security, (2) Ensures both addresses are valid preventing misconfiguration,
    /// (3) Validates vault is registered in protocol ensuring only authorized vaults use custodial services,
    /// (4) Updates mapping and emits event for tracking. Each vault can have a unique destination enabling
    /// diversification across custodial providers. Must be configured before deposits can occur.
    /// @param vault The vault address to configure custodial destination for
    /// @param custodialAddress The off-chain custodial address (CEX wallet, institutional account)
    function setVaultDestination(address vault, address custodialAddress) external {
        require(_isAdmin(msg.sender), CUSTODIAL_WRONG_ROLE);
        require(vault != address(0) && custodialAddress != address(0), CUSTODIAL_INVALID_CUSTODIAL_ADDRESS);

        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        address oldAddress = $.vaultDestinations[vault];
        $.vaultDestinations[vault] = custodialAddress;

        // Validate vault is registered
        require(_registry().isVault(vault), CUSTODIAL_INVALID_CUSTODIAL_ADDRESS);

        emit VaultDestinationUpdated(vault, oldAddress, custodialAddress);
    }

    /// @notice Updates total assets to reflect off-chain yields for settlement calculations
    /// @dev Critical function for yield distribution - allows kAssetRouter to update asset values based on
    /// off-chain performance. Process: (1) Validates caller is kAssetRouter ensuring only settlement process
    /// can update, (2) Sets new total reflecting yields or losses from custodial services, (3) Emits event
    /// for tracking. The difference between previous and new totalAssets represents yield to be distributed
    /// during settlement. This trust-minimized approach requires careful monitoring but enables access to
    /// institutional yield opportunities not available on-chain.
    /// @param vault The vault whose assets are being updated
    /// @param asset The specific asset being updated
    /// @param totalAssets_ The new total value including any yields or losses
    function setTotalAssets(address vault, address asset, uint256 totalAssets_) external {
        require(_isKAssetRouter(msg.sender), CUSTODIAL_WRONG_ROLE);
        CustodialAdapterStorage storage $ = _getCustodialAdapterStorage();
        $.totalAssets[vault][asset] = totalAssets_;

        emit TotalAssetsUpdated(vault, totalAssets_);
    }

    /*//////////////////////////////////////////////////////////////
                          UPGRADE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades through UUPS pattern with admin validation
    /// @dev Security-critical function controlling adapter upgrades. Only admin can authorize ensuring
    /// governance control over adapter evolution. Validates new implementation address preventing
    /// accidental upgrades to zero address. Part of UUPS upgrade pattern for gas-efficient upgrades.
    /// @param newImplementation The new adapter implementation contract address
    function _authorizeUpgrade(address newImplementation) internal view override {
        require(_isAdmin(msg.sender), CUSTODIAL_WRONG_ROLE);
        require(newImplementation != address(0), CUSTODIAL_ZERO_ADDRESS);
    }
}
