// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { kBase } from "src/base/kBase.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kAssetRouter
contract kAssetRouter is IkAssetRouter, Initializable, UUPSUpgradeable, kBase, Multicallable {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint128;

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
        mapping(address => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kAssetRouter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
        0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;

    function _getkAssetRouterStorage() private pure returns (kAssetRouterStorage storage $) {
        assembly {
            $.slot := KASSETROUTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (_getBaseStorage().paused) revert ContractPaused();
        _;
    }

    modifier onlyStakingVault() {
        if (!_isVault(msg.sender)) revert OnlyStakingVault();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the kAssetRouter with asset and admin configuration
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Address of the owner
    /// @param admin_ Address of the admin
    /// @param paused_ Initial pause state
    function initialize(address registry_, address owner_, address admin_, bool paused_) external initializer {
        __kBase_init(registry_, owner_, admin_, paused_);

        emit Initialized(registry_, owner_, admin_, paused_);
    }

    /*//////////////////////////////////////////////////////////////
                            kMINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Push assets from kMinter to designated DN vault
    /// @param _asset The asset being deposited
    /// @param amount Amount of assets being pushed
    /// @param batchId The batch ID from the DN vault
    function kAssetPush(
        address _asset,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyKMinter
    {
        if (amount == 0) revert ZeroAmount();
        address kMinter = msg.sender;

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        $.vaultBatchBalances[kMinter][batchId].deposited += amount.toUint128();

        emit AssetsPushed(kMinter, amount);
    }

    /// @notice Request to pull assets for kMinter redemptions
    /// @param _asset The asset to redeem
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kAssetRequestPull(
        address _asset,
        address _vault,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyKMinter
    {
        if (amount == 0) revert ZeroAmount();
        address kMinter = msg.sender;
        address vault = _getDNVaultByAsset(_asset);
        if (_balance(vault) < amount) revert InsufficientVirtualBalance();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.vaultBatchBalances[kMinter][batchId].requested += amount.toUint128();

        // Set batch receiver for the vault
        address batchReceiver = IkStakingVault(_vault).createBatchReceiver(batchId);
        if (batchReceiver == address(0)) revert ZeroAddress();

        emit AssetsRequestPulled(kMinter, _asset, batchReceiver, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            kSTAKING VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer assets between kStakingVaults
    /// @param sourceVault The vault to transfer assets from
    /// @param targetVault The vault to transfer assets to
    /// @param _asset The asset to transfer
    /// @param amount Amount of assets to transfer
    /// @param batchId The batch ID for this transfer
    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyStakingVault
    {
        if (amount == 0) revert ZeroAmount();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if (_balance(sourceVault) < amount) revert InsufficientVirtualBalance();
        // Update batch tracking for settlement
        $.vaultBatchBalances[sourceVault][batchId].requested += amount.toUint128();
        $.vaultBatchBalances[sourceVault][batchId].deposited -= amount.toUint128();
        $.vaultBatchBalances[targetVault][batchId].deposited += amount.toUint128();

        emit AssetsTransfered(sourceVault, targetVault, _asset, amount);
    }

    /// @notice Request to pull shares for kStakingVault redemptions
    /// @param sourceVault The vault to redeem shares from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kSharesRequestPush(
        address sourceVault,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyStakingVault
    {
        if (amount == 0) revert ZeroAmount();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        $.vaultRequestedShares[sourceVault][batchId] += amount;

        emit SharesRequestedPushed(sourceVault, batchId, amount);
    }

    /// @notice Request to pull shares for kStakingVault redemptions
    /// @param sourceVault The vault to redeem shares from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kSharesRequestPull(
        address sourceVault,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyStakingVault
    {
        if (amount == 0) revert ZeroAmount();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        $.vaultRequestedShares[sourceVault][batchId] -= amount;

        emit SharesRequestedPulled(sourceVault, batchId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settle a single vault's batch
    /// @param vault Vault address to settle
    /// @param batchId Batch ID to settle
    /// @param totalAssets_ total assets in the vault with Deposited and Requested and Shares
    /// @param netted netted amount in current batch
    /// @param yield yield in current batch
    /// @param profit whether the batch is profitable
    function settleBatch(
        address asset,
        address vault,
        bytes32 batchId,
        uint256 totalAssets_,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRelayer
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        address kToken = _getKTokenForAsset(asset);
        bool isKMinter; // for event Deposited
        uint256 requested = $.vaultBatchBalances[vault][batchId].requested;

        // Clear batch balances
        delete $.vaultBatchBalances[vault][batchId];
        delete $.vaultRequestedShares[vault][batchId];

        // kMinter settlement
        if (vault == _getKMinter()) {
            // kMinter settlement: handle institutional deposits and redemptions
            isKMinter = true;

            vault = _getDNVaultByAsset(asset);
            if (requested > 0) {
                // Transfer assets to batch receiver for redemptions
                address receiver = IkStakingVault(vault).getSafeBatchReceiver(batchId);
                if (receiver == address(0)) revert ZeroAddress();
                asset.safeTransfer(receiver, requested);
            }
        } else {
            // kMinter yield is sent to insuranceFund, cannot be minted.
            // peg will be positive till excess withdrawn and sent to insuranceFund.
            // Insurance fund is managed by the backend
            if (profit) {
                IkToken(kToken).mint(vault, yield);
                emit YieldDistributed(vault, yield, true);
            } else {
                IkToken(kToken).burn(vault, yield);
                emit YieldDistributed(vault, yield, false);
            }
        }

        address[] memory adapters = _registry().getAdapters(vault);
        // at some point we will have multiple adapters for a vault
        // for now we just use the first one
        if (adapters[0] == address(0)) revert ZeroAddress();
        IAdapter adapter = IAdapter(adapters[0]);

        if (netted > 0) {
            adapter.deposit(asset, netted, vault);
            emit Deposited(vault, asset, netted, isKMinter);
        }

        // Update vault's total assets
        if (_registry().getVaultType(vault) > 0) {
            adapter.setTotalAssets(vault, asset, totalAssets_);
        }

        emit BatchSettled(vault, batchId, totalAssets_);
    }

    /*////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set contract pause state
    /// @param paused New pause state
    function setPaused(bool paused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _setPaused(paused);
        emit Paused(paused);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice gets the virtual balance of a vault
    /// @param vault the vault address
    /// @return balance the balance of the vault in all adapters.
    function _balance(address vault) internal view returns (uint256 balance) {
        address[] memory assets = _getVaultAssets(vault);
        address[] memory adapters = _registry().getAdapters(vault);
        uint256 length = adapters.length;
        for (uint256 i; i < length;) {
            IAdapter adapter = IAdapter(adapters[i]);
            // For now, assume single asset per vault (use first asset)
            balance += adapter.totalAssets(vault, assets[0]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool) {
        return _getBaseStorage().paused;
    }

    /// @notice Gets the DN vault address for a given asset
    /// @param asset The asset address
    /// @return vault The corresponding DN vault address
    /// @dev Reverts if asset not supported
    function getDNVaultByAsset(address asset) external view returns (address vault) {
        vault = _registry().getVaultByAssetAndType(asset, uint8(IkRegistry.VaultType.DN));
        if (vault == address(0)) revert InvalidVault(vault);
    }

    /// @notice Get batch balances for a vault
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return deposited Amount deposited in this batch
    /// @return requested Amount requested in this batch
    function getBatchIdBalances(
        address vault,
        bytes32 batchId
    )
        external
        view
        returns (uint256 deposited, uint256 requested)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        Balances memory balances = $.vaultBatchBalances[vault][batchId];
        return (balances.deposited, balances.requested);
    }

    /// @notice Get requested shares for a vault batch
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return Requested shares amount
    function getRequestedShares(address vault, bytes32 batchId) external view returns (uint256) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.vaultRequestedShares[vault][batchId];
    }

    /*//////////////////////////////////////////////////////////////
                          UPGRADE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize contract upgrade
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive ETH (for gas refunds, etc.)
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kAssetRouter";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
