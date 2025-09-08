// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedReentrancyGuardTransient } from "src/abstracts/OptimizedReentrancyGuardTransient.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";

import {
    ADAPTER_ALREADY_INITIALIZED,
    ADAPTER_INVALID_REGISTRY,
    ADAPTER_TRANSFER_FAILED,
    ADAPTER_WRONG_ASSET,
    ADAPTER_WRONG_ROLE,
    ADAPTER_ZERO_ADDRESS,
    ADAPTER_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/// @title BaseAdapter
/// @notice Foundation contract providing essential shared functionality for all protocol adapter implementations
/// @dev This abstract contract serves as the base layer for adapter pattern implementations that integrate external
/// yield strategies (CEX, DeFi protocols, custodial solutions) with the KAM protocol. Key responsibilities include:
/// (1) Registry integration to maintain protocol-wide configuration consistency and access control, (2) Asset rescue
/// mechanisms to recover stuck funds while protecting protocol assets from unauthorized extraction, (3) Standardized
/// initialization patterns ensuring proper setup across all adapter types, (4) Version tracking for upgrade management
/// and compatibility checks, (5) Role-based access control validation through registry lookups. Adapters enable the
/// protocol to generate yield from diverse sources while maintaining a unified interface for the kAssetRouter. Each
/// adapter implementation (CustodialAdapter, AaveAdapter, etc.) extends this base to handle strategy-specific logic
/// while inheriting critical safety features and protocol integration. The ERC-7201 storage pattern prevents collisions
/// during upgrades and enables safe composition with other base contracts.
contract BaseAdapter is OptimizedReentrancyGuardTransient {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when ERC20 tokens are rescued from the adapter to prevent permanent loss
    /// @dev Rescue mechanism restricted to non-protocol assets to protect user funds. Typically recovers
    /// accidentally sent tokens or airdrops that would otherwise be locked in the adapter contract.
    /// @param asset The ERC20 token address being rescued (must not be a registered protocol asset)
    /// @param to The recipient address receiving the rescued tokens
    /// @param amount The quantity of tokens rescued
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);

    /// @notice Emitted when native ETH is rescued from the adapter contract
    /// @dev Separate from ERC20 rescue due to different transfer mechanisms. Prevents ETH from being
    /// permanently locked if sent to the adapter accidentally.
    /// @param to The recipient address receiving the rescued ETH
    /// @param amount The quantity of ETH rescued in wei
    event RescuedETH(address indexed to, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registry lookup key for the kAssetRouter singleton contract
    /// @dev Used to retrieve and validate the kAssetRouter address from registry. Only kAssetRouter
    /// can trigger adapter deposits/redemptions, ensuring centralized control over asset flows.
    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.BaseAdapter
    /// @dev Storage struct following ERC-7201 namespaced storage pattern for upgrade safety.
    /// Prevents storage collisions when adapters inherit from multiple base contracts.
    struct BaseAdapterStorage {
        /// @dev Address of the kRegistry singleton for protocol configuration
        address registry;
        /// @dev Initialization flag preventing reinitialization attacks
        bool initialized;
        /// @dev Human-readable adapter name for identification (e.g., "AaveV3Adapter")
        string name;
        /// @dev Semantic version string for upgrade tracking (e.g., "1.0.0")
        string version;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.BaseAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant BASE_ADAPTER_STORAGE_LOCATION =
        0x5547882c17743d50a538cd94a34f6308d65f7005fe26b376dcedda44d3aab800;

    /// @dev Returns the base adapter storage pointer
    function _getBaseAdapterStorage() internal pure returns (BaseAdapterStorage storage $) {
        assembly {
            $.slot := BASE_ADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base adapter with registry integration and metadata
    /// @dev This internal initialization establishes the foundation for all adapter implementations. The process:
    /// (1) Validates initialization hasn't occurred to prevent reinitialization in proxy patterns, (2) Ensures
    /// registry address is valid since all access control depends on it, (3) Sets adapter metadata for tracking
    /// and identification, (4) Marks initialization complete. Must be called by inheriting adapter contracts
    /// during their initialization phase to establish proper protocol integration. The internal visibility
    /// ensures only inheriting contracts can initialize, preventing external manipulation.
    /// @param registry_ The kRegistry contract address for protocol configuration and access control
    /// @param name_ Human-readable adapter identifier (e.g., "CustodialAdapter", "AaveV3Adapter")
    /// @param version_ Semantic version string for upgrade management (e.g., "1.0.0")
    function __BaseAdapter_init(address registry_, string memory name_, string memory version_) internal {
        // Initialize adapter storage
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();

        require(!$.initialized, ADAPTER_ALREADY_INITIALIZED);
        require(registry_ != address(0), ADAPTER_INVALID_REGISTRY);

        $.registry = registry_;
        $.initialized = true;
        $.name = name_;
        $.version = version_;
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract address
    /// @return The kRegistry contract address
    /// @dev Reverts if contract not initialized
    function registry() external view returns (address) {
        return address(_registry());
    }

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    function _registry() internal view returns (IkRegistry) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return IkRegistry($.registry);
    }

    /*//////////////////////////////////////////////////////////////
                                RESCUER
    //////////////////////////////////////////////////////////////*/

    /// @notice Rescues accidentally sent assets preventing permanent loss in the adapter
    /// @dev Critical safety mechanism for recovering tokens or ETH stuck in the adapter through user error
    /// or airdrops. The rescue process: (1) Validates admin authorization to prevent unauthorized extraction,
    /// (2) Ensures recipient address validity to prevent burning funds, (3) For ETH (asset_=address(0)):
    /// validates balance and uses low-level call for transfer, (4) For ERC20: critically verifies the token
    /// is NOT a registered protocol asset to protect user deposits, then validates balance and uses
    /// SafeTransferLib. Protocol assets are blocked to prevent admin abuse and maintain user trust. This
    /// function is essential for adapter contracts that may receive unexpected transfers.
    /// @param asset_ The asset to rescue (address(0) for ETH, token address for ERC20)
    /// @param to_ The recipient address for rescued assets (cannot be zero address)
    /// @param amount_ The quantity to rescue (must not exceed available balance)
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable {
        require(_isAdmin(msg.sender), ADAPTER_WRONG_ROLE);
        require(to_ != address(0), ADAPTER_ZERO_ADDRESS);

        if (asset_ == address(0)) {
            // Rescue ETH
            require(amount_ > 0 && amount_ <= address(this).balance, ADAPTER_ZERO_AMOUNT);

            (bool success,) = to_.call{ value: amount_ }("");
            require(success, ADAPTER_TRANSFER_FAILED);

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            require(!_isAsset(asset_), ADAPTER_WRONG_ASSET);
            require(amount_ > 0 && amount_ <= asset_.balanceOf(address(this)), ADAPTER_ZERO_AMOUNT);

            asset_.safeTransfer(to_, amount_);
            emit RescuedAssets(asset_, to_, amount_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the adapter's name
    /// @return Human readable adapter name
    function name() external view returns (string memory) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.name;
    }

    /// @notice Returns the adapter's version
    /// @return Version string
    function version() external view returns (string memory) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.version;
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an address has admin role for adapter management
    /// @dev Admins can rescue assets and configure adapter parameters. Access control through registry.
    /// @param user The address to check for admin privileges
    /// @return Whether the address is registered as an admin
    function _isAdmin(address user) internal view returns (bool) {
        return _registry().isAdmin(user);
    }

    /// @notice Checks if an address is the kAssetRouter contract
    /// @dev Only kAssetRouter can trigger deposits/redemptions in adapters, ensuring centralized control
    /// over asset flows between vaults and external strategies. Critical for maintaining protocol integrity.
    /// @param user The address to validate against kAssetRouter
    /// @return Whether the address is the registered kAssetRouter
    function _isKAssetRouter(address user) internal view returns (bool) {
        bool isTrue;
        address _kAssetRouter = _registry().getContractById(K_ASSET_ROUTER);
        if (_kAssetRouter == user) isTrue = true;
        return isTrue;
    }

    /// @notice Checks if an asset is registered in the protocol
    /// @dev Registered assets (USDC, WBTC, etc.) cannot be rescued to protect user deposits.
    /// This distinction ensures protocol assets remain under vault control.
    /// @param asset The asset address to check
    /// @return Whether the asset is a registered protocol asset
    function _isAsset(address asset) internal view returns (bool) {
        return _registry().isAsset(asset);
    }
}
