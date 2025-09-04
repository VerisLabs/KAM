// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedReentrancyGuardTransient } from "src/abstracts/OptimizedReentrancyGuardTransient.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";

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
} from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";

/// @title kBase
/// @notice Base contract providing common functionality for all KAM protocol contracts
/// @dev Includes registry integration, role management, pause functionality, and helper methods
contract kBase is OptimizedReentrancyGuardTransient {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the pause state is changed
    /// @param paused_ New pause state
    event Paused(bool paused_);
    /// @notice Emitted when assets are rescued from the contract
    /// @param asset_ The asset rescued
    /// @param to_ The recipient of the rescued assets
    /// @param amount_ The amount of assets rescued
    event RescuedAssets(address indexed asset_, address indexed to_, uint256 amount_);
    /// @notice Emitted when ETH is rescued from the contract
    /// @param to_ The recipient of the rescued ETH
    /// @param amount_ The amount of ETH rescued
    event RescuedETH(address indexed to_, uint256 amount_);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice kMinter key
    bytes32 internal constant K_MINTER = keccak256("K_MINTER");
    /// @notice kAssetRouter key
    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");

    /*//////////////////////////////////////////////////////////////
                        STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kBase
    struct kBaseStorage {
        address registry;
        bool initialized;
        bool paused;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kBase")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KBASE_STORAGE_LOCATION = 0xe91688684975c4d7d54a65dd96da5d4dcbb54b8971c046d5351d3c111e43a800;

    /*//////////////////////////////////////////////////////////////
                              STORAGE GETTER
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns the kBase storage pointer
    function _getBaseStorage() internal pure returns (kBaseStorage storage $) {
        assembly {
            $.slot := KBASE_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base contract with registry and pause state
    /// @param registry_ Address of the kRegistry contract
    /// @dev Can only be called once during initialization
    function __kBase_init(address registry_) internal {
        kBaseStorage storage $ = _getBaseStorage();

        require(!$.initialized, KBASE_ALREADY_INITIALIZED);
        require(registry_ != address(0), KBASE_INVALID_REGISTRY);

        $.registry = registry_;
        $.paused = false;
        $.initialized = true;
    }

    /*//////////////////////////////////////////////////////////////
                          ROLES FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function setPaused(bool paused_) external {
        require(_isEmergencyAdmin(msg.sender), KBASE_WRONG_ROLE);
        kBaseStorage storage $ = _getBaseStorage();
        require($.initialized, KBASE_NOT_INITIALIZED);
        $.paused = paused_;
        emit Paused(paused_);
    }

    /// @notice rescues locked assets (ETH or ERC20) in the contract
    /// @param asset_ the asset to rescue (use address(0) for ETH)
    /// @param to_ the address that will receive the assets
    /// @param amount_ the amount to rescue
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
    /// @dev Internal helper for typed registry access
    function _registry() internal view returns (IkRegistry) {
        kBaseStorage storage $ = _getBaseStorage();
        require($.initialized, KBASE_NOT_INITIALIZED);
        return IkRegistry($.registry);
    }

    /*//////////////////////////////////////////////////////////////
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
        vault = _registry().getVaultByAssetAndType(asset, uint8(IkRegistry.VaultType.DN));
        require(vault != address(0), KBASE_INVALID_VAULT);
    }

    /*//////////////////////////////////////////////////////////////
                            VALIDATORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an address is a admin
    /// @return Whether the address is a admin
    function _isAdmin(address user) internal view returns (bool) {
        return _registry().isAdmin(user);
    }

    /// @notice Checks if an address is a emergencyAdmin
    /// @return Whether the address is a emergencyAdmin
    function _isEmergencyAdmin(address user) internal view returns (bool) {
        return _registry().isEmergencyAdmin(user);
    }

    /// @notice Checks if an address is a guardian
    /// @return Whether the address is a guardian
    function _isGuardian(address user) internal view returns (bool) {
        return _registry().isGuardian(user);
    }

    /// @notice Checks if an address is a relayer
    /// @return Whether the address is a relayer
    function _isRelayer(address user) internal view returns (bool) {
        return _registry().isRelayer(user);
    }

    /// @notice Checks if an address is a institution
    /// @return Whether the address is a institution
    function _isInstitution(address user) internal view returns (bool) {
        return _registry().isInstitution(user);
    }

    /// @notice Checks if an address is a institution
    /// @return Whether the address is a institution
    function _isPaused() internal view returns (bool) {
        kBaseStorage storage $ = _getBaseStorage();
        require($.initialized, KBASE_NOT_INITIALIZED);
        return $.paused;
    }

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _isKMinter(address user) internal view returns (bool) {
        bool isTrue;
        address _kminter = _registry().getContractById(K_MINTER);
        if (_kminter == user) isTrue = true;
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
