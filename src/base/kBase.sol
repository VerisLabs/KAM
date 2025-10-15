// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedReentrancyGuardTransient } from "solady/utils/OptimizedReentrancyGuardTransient.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import {
    KBASE_ALREADY_INITIALIZED,
    KBASE_ASSET_NOT_SUPPORTED,
    KBASE_CONTRACT_NOT_FOUND,
    KBASE_INVALID_REGISTRY,
    KBASE_INVALID_VAULT,
    KBASE_NOT_INITIALIZED,
    KBASE_TRANSFER_FAILED,
    KBASE_WRONG_ASSET,
    KBASE_WRONG_ROLE,
    KBASE_ZERO_ADDRESS,
    KBASE_ZERO_AMOUNT
} from "kam/src/errors/Errors.sol";
import { IRegistry } from "kam/src/interfaces/IRegistry.sol";
import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";

/// @title kBase
/// @notice Foundation contract providing essential shared functionality and registry integration for all KAM protocol
/// contracts
/// @dev This abstract contract serves as the architectural foundation for the entire KAM protocol, establishing
/// critical patterns and utilities that ensure consistency across all protocol components. Key responsibilities
/// include: (1) Registry integration through a singleton pattern that enables dynamic protocol configuration and
/// contract discovery, (2) Role-based access control validation that enforces protocol governance permissions,
/// (3) Emergency pause functionality for protocol-wide risk mitigation during critical events, (4) Asset rescue
/// mechanisms to recover stuck funds while protecting protocol assets, (5) Vault and asset validation to ensure
/// only registered components interact, (6) Batch processing coordination through ID management and receiver tracking.
/// The contract employs ERC-7201 namespaced storage to prevent storage collisions during upgrades and enable safe
/// inheritance patterns. All inheriting contracts (kMinter, kAssetRouter, etc.) leverage these utilities to maintain
/// protocol integrity, reduce code duplication, and ensure consistent security checks across the ecosystem. The
/// registry serves as the single source of truth for protocol configuration, making the system highly modular and
/// upgradeable.
contract kBase is OptimizedReentrancyGuardTransient {
    using SafeTransferLib for address;

    /* //////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the emergency pause state is toggled for protocol-wide risk mitigation
    /// @dev This event signals a critical protocol state change that affects all inheriting contracts.
    /// When paused=true, protocol operations are halted to prevent potential exploits or manage emergencies.
    /// Only emergency admins can trigger this, providing rapid response capability during security incidents.
    /// @param paused_ The new pause state (true = operations halted, false = normal operation)
    event Paused(bool paused_);

    /// @notice Emitted when ERC20 tokens are rescued from the contract to prevent permanent loss
    /// @dev This rescue mechanism is restricted to non-protocol assets only - registered assets (USDC, WBTC, etc.)
    /// cannot be rescued to protect user funds and maintain protocol integrity. Typically used to recover
    /// accidentally sent tokens or airdrops. Only admin role can execute rescues as a security measure.
    /// @param asset_ The ERC20 token address being rescued (must not be a registered protocol asset)
    /// @param to_ The recipient address receiving the rescued tokens (cannot be zero address)
    /// @param amount_ The quantity of tokens rescued (must not exceed contract balance)
    event RescuedAssets(address indexed asset_, address indexed to_, uint256 amount_);

    /// @notice Emitted when native ETH is rescued from the contract to recover stuck funds
    /// @dev ETH rescue is separate from ERC20 rescue due to different transfer mechanisms. This prevents
    /// ETH from being permanently locked if sent to the contract accidentally. Uses low-level call for
    /// ETH transfer with proper success checking. Only admin role authorized for security.
    /// @param to_ The recipient address receiving the rescued ETH (cannot be zero address)
    /// @param amount_ The quantity of ETH rescued in wei (must not exceed contract balance)
    event RescuedETH(address indexed to_, uint256 amount_);

    /* //////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registry lookup key for the kMinter singleton contract
    /// @dev This hash is used to retrieve the kMinter address from the registry's contract mapping.
    /// kMinter handles institutional minting/redemption flows, so many contracts need to identify it
    /// for access control and routing decisions. The hash ensures consistent lookups across the protocol.
    bytes32 internal constant K_MINTER = keccak256("K_MINTER");

    /// @notice Registry lookup key for the kAssetRouter singleton contract
    /// @dev This hash is used to retrieve the kAssetRouter address from the registry's contract mapping.
    /// kAssetRouter coordinates all asset movements and settlements, making it a critical dependency
    /// for vaults and other protocol components. The hash-based lookup enables dynamic upgrades.
    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /* //////////////////////////////////////////////////////////////
                        STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kBase
    /// @dev Storage struct following ERC-7201 namespaced storage pattern to prevent collisions during upgrades.
    /// This pattern ensures that storage layout remains consistent across proxy upgrades and prevents
    /// accidental overwriting when contracts inherit from multiple base contracts. The namespace
    /// "kam.storage.kBase" uniquely identifies this storage area within the contract's storage space.
    struct kBaseStorage {
        /// @dev Address of the kRegistry singleton that serves as the protocol's configuration hub
        address registry;
        /// @dev Initialization flag preventing multiple initialization calls (reentrancy protection)
        bool initialized;
        /// @dev Emergency pause state affecting all protocol operations in inheriting contracts
        bool paused;
    }

    /// @dev ERC-7201 storage location calculated as: keccak256(abi.encode(uint256(keccak256("kam.storage.kBase")) - 1))
    /// & ~bytes32(uint256(0xff))
    /// This specific slot is chosen to avoid any possible collision with standard storage layouts while maintaining
    /// deterministic addressing. The calculation ensures the storage location is unique to this namespace and won't
    /// conflict with other inherited contracts or future upgrades. The 0xff mask ensures proper alignment.
    bytes32 private constant KBASE_STORAGE_LOCATION =
        0xe91688684975c4d7d54a65dd96da5d4dcbb54b8971c046d5351d3c111e43a800;

    /* //////////////////////////////////////////////////////////////
                              STORAGE GETTER
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the kBase storage pointer using ERC-7201 namespaced storage pattern
    /// @return $ Storage pointer to the kBaseStorage struct at the designated storage location
    /// This function uses inline assembly to directly set the storage pointer to our namespaced location,
    /// ensuring efficient access to storage variables while maintaining upgrade safety. The pure modifier
    /// is used because we're only returning a storage pointer, not reading storage values.
    function _getBaseStorage() internal pure returns (kBaseStorage storage $) {
        assembly {
            $.slot := KBASE_STORAGE_LOCATION
        }
    }

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base contract with registry integration and default operational state
    /// @dev This internal initialization function establishes the foundational connection between any inheriting
    /// contract and the protocol's registry system. The initialization process: (1) Validates that initialization
    /// hasn't occurred to prevent reinitialization attacks in proxy patterns, (2) Ensures registry address is valid
    /// since the registry is critical for all protocol operations, (3) Sets the contract to unpaused state enabling
    /// normal operations, (4) Marks initialization complete to prevent future calls. This function MUST be called
    /// by all inheriting contracts during their initialization phase to establish proper protocol integration.
    /// The internal visibility ensures only inheriting contracts can initialize, preventing external manipulation.
    /// @param registry_ The kRegistry contract address that serves as the protocol's configuration and discovery hub
    function __kBase_init(address registry_) internal {
        kBaseStorage storage $ = _getBaseStorage();

        require(!$.initialized, KBASE_ALREADY_INITIALIZED);
        require(registry_ != address(0), KBASE_INVALID_REGISTRY);

        $.registry = registry_;
        $.paused = false;
        $.initialized = true;
    }

    /* //////////////////////////////////////////////////////////////
                          ROLES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Toggles the emergency pause state affecting all protocol operations in this contract
    /// @dev This function provides critical risk management capability by allowing emergency admins to halt
    /// contract operations during security incidents or market anomalies. The pause mechanism: (1) Affects all
    /// state-changing operations in inheriting contracts that check _isPaused(), (2) Does not affect view/pure
    /// functions ensuring protocol state remains readable, (3) Enables rapid response to potential exploits by
    /// halting operations protocol-wide, (4) Requires emergency admin role ensuring only authorized governance
    /// can trigger pauses. Inheriting contracts should check _isPaused() modifier in critical functions to
    /// respect the pause state. The external visibility with role check prevents unauthorized pause manipulation.
    /// @param paused_ The desired pause state (true = halt operations, false = resume normal operation)
    function setPaused(bool paused_) external {
        require(_isEmergencyAdmin(msg.sender), KBASE_WRONG_ROLE);
        kBaseStorage storage $ = _getBaseStorage();
        require($.initialized, KBASE_NOT_INITIALIZED);
        $.paused = paused_;
        emit Paused(paused_);
    }

    /// @notice Rescues accidentally sent assets (ETH or ERC20 tokens) preventing permanent loss of funds
    /// @dev This function implements a critical safety mechanism for recovering tokens or ETH that become stuck
    /// in the contract through user error or airdrops. The rescue process: (1) Validates admin authorization to
    /// prevent unauthorized fund extraction, (2) Ensures recipient address is valid to prevent burning funds,
    /// (3) For ETH rescue (asset_=address(0)): validates balance sufficiency and uses low-level call for transfer,
    /// (4) For ERC20 rescue: critically checks the token is NOT a registered protocol asset (USDC, WBTC, etc.) to
    /// protect user deposits and protocol integrity, then validates balance and uses SafeTransferLib for secure
    /// transfer. The distinction between ETH and ERC20 handling accounts for their different transfer mechanisms.
    /// Protocol assets are explicitly blocked from rescue to prevent admin abuse and maintain user trust.
    /// @param asset_ The asset to rescue (use address(0) for native ETH, otherwise ERC20 token address)
    /// @param to_ The recipient address that will receive the rescued assets (cannot be zero address)
    /// @param amount_ The quantity to rescue (must not exceed available balance)
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable {
        require(_isAdmin(msg.sender), KBASE_WRONG_ROLE);
        require(to_ != address(0), KBASE_ZERO_ADDRESS);

        if (asset_ == address(0)) {
            // Rescue ETH
            require(amount_ > 0 && amount_ <= address(this).balance, KBASE_ZERO_AMOUNT);

            (bool success,) = to_.call{ value: amount_ }("");
            require(success, KBASE_TRANSFER_FAILED);

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            require(!_isAsset(asset_), KBASE_WRONG_ASSET);
            require(amount_ > 0 && amount_ <= asset_.balanceOf(address(this)), KBASE_ZERO_AMOUNT);

            asset_.safeTransfer(to_, amount_);
            emit RescuedAssets(asset_, to_, amount_);
        }
    }

    /* //////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract address
    /// @return The kRegistry contract address
    /// @dev Reverts if contract not initialized
    function registry() external view returns (address) {
        return address(_registry());
    }

    /// @notice Returns the registry contract interface
    /// @return IRegistry interface for registry interaction
    /// @dev Internal helper for typed registry access
    function _registry() internal view returns (IRegistry) {
        kBaseStorage storage $ = _getBaseStorage();
        require($.initialized, KBASE_NOT_INITIALIZED);
        return IRegistry($.registry);
    }

    /* //////////////////////////////////////////////////////////////
                          GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the current batch ID for a given vault
    /// @param vault The vault address
    /// @return batchId The current batch ID
    /// @dev Reverts if vault not registered
    function _getBatchId(address vault) internal view returns (bytes32 batchId) {
        return IkStakingVault(vault).getBatchId();
    }

    /// @notice Gets the current batch receiver for a given batchId
    /// @param vault_ The vault address
    /// @param batchId_ The batch ID
    /// @return batchReceiver The address of the batchReceiver where tokens will be sent
    /// @dev Reverts if vault not registered
    function _getBatchReceiver(address vault_, bytes32 batchId_) internal view returns (address batchReceiver) {
        batchReceiver = IkStakingVault(vault_).getBatchReceiver(batchId_);
        require(batchReceiver != address(0), KBASE_ZERO_ADDRESS);
    }

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _getKMinter() internal view returns (address minter) {
        minter = _registry().getContractById(K_MINTER);
        require(minter != address(0), KBASE_CONTRACT_NOT_FOUND);
    }

    /// @notice Gets the kAssetRouter singleton contract address
    /// @return router The kAssetRouter contract address
    /// @dev Reverts if kAssetRouter not set in registry
    function _getKAssetRouter() internal view returns (address router) {
        router = _registry().getContractById(K_ASSET_ROUTER);
        require(router != address(0), KBASE_CONTRACT_NOT_FOUND);
    }

    /// @notice Gets the kToken address for a given asset
    /// @param asset The underlying asset address
    /// @return kToken The corresponding kToken address
    /// @dev Reverts if asset not supported
    function _getKTokenForAsset(address asset) internal view returns (address kToken) {
        kToken = _registry().assetToKToken(asset);
        require(kToken != address(0), KBASE_ASSET_NOT_SUPPORTED);
    }

    /// @notice Gets the asset managed by a vault
    /// @param vault The vault address
    /// @return assets The asset address managed by the vault
    /// @dev Reverts if vault not registered
    function _getVaultAssets(address vault) internal view returns (address[] memory assets) {
        assets = _registry().getVaultAssets(vault);
        require(assets.length > 0, KBASE_INVALID_VAULT);
    }

    /// @notice Gets the DN vault address for a given asset
    /// @param asset The asset address
    /// @return vault The corresponding DN vault address
    /// @dev Reverts if asset not supported
    function _getDNVaultByAsset(address asset) internal view returns (address vault) {
        vault = _registry().getVaultByAssetAndType(asset, uint8(IRegistry.VaultType.DN));
        require(vault != address(0), KBASE_INVALID_VAULT);
    }

    /* //////////////////////////////////////////////////////////////
                            VALIDATORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an address has admin role in the protocol governance
    /// @dev Admins can execute critical functions like asset rescue and protocol configuration changes.
    /// This validation is used throughout inheriting contracts to enforce permission boundaries.
    /// @param user The address to check for admin privileges
    /// @return Whether the address is registered as an admin in the registry
    function _isAdmin(address user) internal view returns (bool) {
        return _registry().isAdmin(user);
    }

    /// @notice Checks if an address has emergency admin role for critical protocol interventions
    /// @dev Emergency admins can pause/unpause contracts during security incidents or market anomalies.
    /// This elevated role enables rapid response to threats while limiting scope to emergency functions only.
    /// @param user The address to check for emergency admin privileges
    /// @return Whether the address is registered as an emergency admin in the registry
    function _isEmergencyAdmin(address user) internal view returns (bool) {
        return _registry().isEmergencyAdmin(user);
    }

    /// @notice Checks if an address has guardian role for protocol monitoring and verification
    /// @dev Guardians verify settlement proposals and can cancel incorrect settlements during cooldown periods.
    /// This role provides an additional security layer for yield distribution accuracy.
    /// @param user The address to check for guardian privileges
    /// @return Whether the address is registered as a guardian in the registry
    function _isGuardian(address user) internal view returns (bool) {
        return _registry().isGuardian(user);
    }

    /// @notice Checks if an address has relayer role for automated protocol operations
    /// @dev Relayers execute batched operations and trigger settlements on behalf of users to optimize gas costs.
    /// This role enables automation while maintaining security through limited permissions.
    /// @param user The address to check for relayer privileges
    /// @return Whether the address is registered as a relayer in the registry
    function _isRelayer(address user) internal view returns (bool) {
        return _registry().isRelayer(user);
    }

    /// @notice Checks if an address is registered as an institutional user
    /// @dev Institutions have special privileges in kMinter for large-scale minting and redemption operations.
    /// This distinction enables optimized flows for high-volume users while maintaining retail accessibility.
    /// @param user The address to check for institutional status
    /// @return Whether the address is registered as an institution in the registry
    function _isInstitution(address user) internal view returns (bool) {
        return _registry().isInstitution(user);
    }

    /// @notice Checks if the contract is currently in emergency pause state
    /// @dev Used by inheriting contracts to halt operations during emergencies. When paused, state-changing
    /// functions should revert while view functions remain accessible for protocol monitoring.
    /// @return Whether the contract is currently paused
    function _isPaused() internal view returns (bool) {
        kBaseStorage storage $ = _getBaseStorage();
        require($.initialized, KBASE_NOT_INITIALIZED);
        return $.paused;
    }

    /// @notice Checks if an address is the kMinter contract
    /// @dev Validates if the caller is the protocol's kMinter singleton for access control in vault operations.
    /// Used to ensure only kMinter can trigger institutional deposit and redemption flows.
    /// @param vault The address to check against kMinter
    /// @return Whether the address is the registered kMinter contract
    function _isKMinter(address vault) internal view returns (bool) {
        bool isTrue;
        address _kminter = _registry().getContractById(K_MINTER);
        if (_kminter == vault) isTrue = true;
        return isTrue;
    }

    /// @notice Checks if an address is a registered vault
    /// @param vault The address to check
    /// @return Whether the address is a registered vault
    function _isVault(address vault) internal view returns (bool) {
        return _registry().isVault(vault);
    }

    /// @notice Checks if an asset is registered
    /// @param asset The asset address to check
    /// @return Whether the asset is registered
    function _isAsset(address asset) internal view returns (bool) {
        return _registry().isAsset(asset);
    }
}
