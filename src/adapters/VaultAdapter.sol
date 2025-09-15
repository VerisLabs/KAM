// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import {
    VAULTADAPTER_IS_PAUSED,
    VAULTADAPTER_TRANSFER_FAILED,
    VAULTADAPTER_WRONG_ASSET,
    VAULTADAPTER_WRONG_ROLE,
    VAULTADAPTER_ZERO_ADDRESS,
    VAULTADAPTER_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IVersioned } from "src/interfaces/IVersioned.sol";

import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IVaultAdapter } from "src/interfaces/IVaultAdapter.sol";

import { OptimizedAddressEnumerableSetLib } from "solady/utils/EnumerableSetLib/OptimizedAddressEnumerableSetLib.sol";
import { OptimizedLibCall } from "solady/utils/OptimizedLibCall.sol";

/// @title VaultAdapter
contract VaultAdapter is IVaultAdapter, Initializable, UUPSUpgradeable {
    using SafeTransferLib for address;
    using OptimizedLibCall for address;
    using OptimizedAddressEnumerableSetLib for OptimizedAddressEnumerableSetLib.AddressSet;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Core storage structure for VaultAdapter using ERC-7201 namespaced storage pattern
    /// @dev This structure manages all state for institutional minting and redemption operations.
    /// Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.
    /// @custom:storage-location erc7201:kam.storage.VaultAdapter
    struct VaultAdapterStorage {
        /// @dev Address of the kRegistry singleton that serves as the protocol's configuration hub
        IRegistry registry;
        /// @dev Emergency pause state affecting all protocol operations in inheriting contracts
        bool paused;
        /// @dev Last recorded total assets for vault accounting and performance tracking
        uint256 lastTotalAssets;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.VaultAdapter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant VAULTADAPTER_STORAGE_LOCATION =
        0xf3245d0f4654bfd28a91ebbd673859481bdc20aeda8fc19798f835927d79aa00;

    /// @notice Retrieves the VaultAdapter storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The VaultAdapterStorage struct reference for state modifications
    function _getVaultAdapterStorage() private pure returns (VaultAdapterStorage storage $) {
        assembly {
            $.slot := VAULTADAPTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the VaultAdapter contract
    /// @param registry_ Address of the registry contract
    function initialize(address registry_) external initializer {
        _checkZeroAddress(registry_);
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        $.registry = IRegistry(registry_);
        emit ContractInitialized(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            ROLES MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultAdapter
    function setPaused(bool paused_) external {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        require($.registry.isEmergencyAdmin(msg.sender), VAULTADAPTER_WRONG_ROLE);
        $.paused = paused_;
        emit Paused(paused_);
    }

    /// @inheritdoc IVaultAdapter
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable {
        _checkAdmin(msg.sender);
        _checkZeroAddress(to_);

        if (asset_ == address(0)) {
            // Rescue ETH
            require(amount_ > 0 && amount_ <= address(this).balance, VAULTADAPTER_ZERO_AMOUNT);

            (bool success,) = to_.call{ value: amount_ }("");
            require(success, VAULTADAPTER_TRANSFER_FAILED);

            emit RescuedETH(to_, amount_);
        } else {
            // Rescue ERC20 tokens
            _checkAsset(asset_);
            require(amount_ > 0 && amount_ <= asset_.balanceOf(address(this)), VAULTADAPTER_ZERO_AMOUNT);

            asset_.safeTransfer(to_, amount_);
            emit RescuedAssets(asset_, to_, amount_);
        }
    }

    /*///////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVaultAdapter
    function execute(address target, bytes calldata data, uint256 value) external returns (bytes memory result) {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        IRegistry registry = $.registry;

        require(registry.isManager(msg.sender), VAULTADAPTER_WRONG_ROLE);
        _checkPaused();

        // Extract selector and validate vault-specific permission
        bytes4 functionSig = bytes4(data);
        bytes memory params = data[4:];
        registry.authorizeAdapterCall(target, functionSig, params);

        result = target.callContract(value, data);
        emit Executed(msg.sender, target, data, value, result);
    }

    /// @inheritdoc IVaultAdapter
    function setTotalAssets(uint256 totalAssets_) external {
        _checkAdmin(msg.sender);
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        $.lastTotalAssets = totalAssets_;
    }

    /// @inheritdoc IVaultAdapter
    function totalAssets() external view returns (uint256) {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        return $.lastTotalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                              INTERNAL VIEW
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if caller has admin role
    /// @param user Address to check
    function _checkAdmin(address user) private view {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        require($.registry.isAdmin(user), VAULTADAPTER_WRONG_ROLE);
    }

    /// @notice Ensures the contract is not paused
    function _checkPaused() internal view {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        require(!$.paused, VAULTADAPTER_IS_PAUSED);
    }

    /// @notice Validates that a vault can call a specific selector on a target
    /// @dev This function enforces the new vault-specific permission model where each vault
    /// has granular permissions for specific functions on specific targets. This replaces
    /// the old global allowedTargets approach with better security isolation.
    /// @param target The target contract to be called
    /// @param selector The function selector being called
    function _checkVaultCanCallSelector(address target, bytes4 selector) internal view {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        require($.registry.isAdapterSelectorAllowed(address(this), target, selector));
    }

    /// @notice Reverts if its a zero address
    /// @param addr Address to check
    function _checkZeroAddress(address addr) internal pure {
        require(addr != address(0), VAULTADAPTER_ZERO_ADDRESS);
    }

    /// @notice Reverts if the asset is not supported by the protocol
    /// @param asset Asset address to check
    function _checkAsset(address asset) private view {
        VaultAdapterStorage storage $ = _getVaultAdapterStorage();
        require($.registry.isAsset(asset), VAULTADAPTER_WRONG_ASSET);
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @dev Only callable by ADMIN_ROLE
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override {
        _checkAdmin(msg.sender);
        require(newImplementation != address(0), VAULTADAPTER_ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVersioned
    function contractName() external pure returns (string memory) {
        return "VaultAdapter";
    }

    /// @inheritdoc IVersioned
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
