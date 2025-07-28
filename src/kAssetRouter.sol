// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import { kAssetRouterTypes } from "src/types/kAssetRouterTypes.sol";

import { kBase } from "src/base/kBase.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

import { kBatchReceiver } from "src/kBatchReceiver.sol";

/// @title kAssetRouter
contract kAssetRouter is Initializable, UUPSUpgradeable, kBase, Multicallable {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint128;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address indexed registry, address indexed owner, address admin, bool paused);
    event AssetsPushed(address indexed from, uint256 amount);
    event AssetsRequestPulled(address indexed vault, address indexed asset, uint256 amount);
    event AssetsTransfered(
        address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount
    );
    event SharesRequested(address indexed vault, uint32 batchId, uint256 amount);
    event SharesSettled(
        address[] vaults, uint32 batchId, uint256 totalRequestedShares, uint256[] totalAssets, uint256 sharePrice
    );
    event BatchSettled(address indexed vault, uint32 indexed batchId, uint256 totalAssets);
    event PegProtectionActivated(address indexed vault, uint256 shortfall);
    event PegProtectionExecuted(address indexed sourceVault, address indexed targetVault, uint256 amount);
    event YieldDistributed(address indexed vault, uint256 yield, bool isProfit);
    event Deposited(address indexed vault, address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error InsufficientVirtualBalance();
    error ContractPaused();
    error OnlyStakingVault();
    error InvalidTotalAssets();

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        mapping(address => mapping(uint256 => kAssetRouterTypes.Balances)) vaultBatchBalances; // vault => batchId =>
            // pending amounts
        mapping(address => mapping(address => uint256)) vaultBalances; // vault => asset => balance
        mapping(address => mapping(uint256 => uint256)) vaultRequestedShares; // vault => batchId => balance
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
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

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
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Push assets from kMinter to designated DN vault
    /// @param _asset The asset being deposited
    /// @param amount Amount of assets being pushed
    /// @param batchId The batch ID from the DN vault
    function kAssetPush(
        address _asset,
        uint256 amount,
        uint256 batchId
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

        // Transfer assets from minter to router
        _asset.safeTransferFrom(kMinter, address(this), amount);

        $.vaultBatchBalances[kMinter][batchId].deposited += amount.toUint128();

        emit AssetsPushed(kMinter, amount);
    }

    /// @notice Request to pull assets for kMinter redemptions
    /// @param _asset The asset to redeem
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kAssetRequestPull(
        address _asset,
        uint256 amount,
        uint256 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyKMinter
    {
        if (amount == 0) revert ZeroAmount();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        address kMinter = msg.sender;
        if ($.vaultBalances[kMinter][_asset] < amount) revert InsufficientVirtualBalance();

        $.vaultBatchBalances[kMinter][batchId].requested += amount.toUint128();

        // Set batch receiver for the vault
        IkStakingVault(_getDNVaultByAsset(_asset)).deployBatchReceiver(batchId);

        emit AssetsRequestPulled(kMinter, _asset, amount);
    }

    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        uint256 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyStakingVault
    {
        if (amount == 0) revert ZeroAmount();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if ($.vaultBalances[sourceVault][_asset] < amount) revert InsufficientVirtualBalance();
        // Update batch tracking for settlement
        $.vaultBatchBalances[sourceVault][batchId].requested += amount.toUint128();
        $.vaultBatchBalances[targetVault][batchId].deposited += amount.toUint128();

        emit AssetsTransfered(sourceVault, targetVault, _asset, amount);
    }

    function kSharesRequestPull(
        address sourceVault,
        uint256 amount,
        uint256 batchId
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

        emit SharesRequested(sourceVault, batchId.toUint32(), amount);
    }

    /// @notice Settle a single vault's batch
    /// @param vault Vault address to settle
    /// @param batchId Batch ID to settle
    /// @param totalAssets_ Current total assets in the vault
    function settleBatch(
        address vault,
        uint256 batchId,
        uint256 totalAssets_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRelayer
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        address asset = _getVaultAsset(vault);

        uint256 deposited = $.vaultBatchBalances[vault][batchId].deposited;
        uint256 requested = $.vaultBatchBalances[vault][batchId].requested;

        $.vaultBalances[vault][asset] += deposited;
        if (requested > 0) {
            $.vaultBalances[vault][asset] -= requested;
        }

        if (vault == _getKMinter()) {
            // kMinter settlement: handle institutional deposits and redemptions
            if (requested > 0) {
                // Deploy batch receiver for this batch
                address batchReceiver = IkStakingVault(vault).getSafeBatchReceiver(batchId);
                // Transfer assets to batch receiver for redemptions
                asset.safeTransfer(batchReceiver, requested);
            }

            if (deposited > requested) {
                address dnVault = _getDNVaultByAsset(asset);
                uint256 netted = deposited - requested;
                address adapter = _registry().getAdapter(vault);
                if (dnVault != address(0)) {
                    // deposit into adapter
                    // MetavaultAdapter.deposit(asset, netted, vault);
                    IAdapter(adapter).deposit(asset, netted, vault);
                }

                emit Deposited(vault, asset, netted);
            }
        } else {
            // Staking vault settlement
            // Update virtual balances immediately for cross-vault transfers
            _settleStakingVault(vault, asset, batchId, deposited, requested, totalAssets_);
        }

        // Clear batch balances
        delete $.vaultBatchBalances[vault][batchId];
        delete $.vaultRequestedShares[vault][batchId];

        emit BatchSettled(vault, batchId.toUint32(), totalAssets_);
    }

    /// @notice Internal function to settle staking vault
    function _settleStakingVault(
        address vault,
        address asset,
        uint256 batchId,
        uint256 deposited,
        uint256 requested,
        uint256 totalAssets
    )
        internal
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        uint256 requestedShares = $.vaultRequestedShares[vault][batchId];
        if (requestedShares > 0) {
            uint256 sharePrice = IkStakingVault(vault).calculateStkTokenPrice(totalAssets);
            uint256 kTokensForShares = requestedShares.mulWad(sharePrice);
            requested += kTokensForShares;
            $.vaultRequestedShares[vault][batchId] = 0;
        }

        // Handle yield distribution
        address kToken = _getKTokenForAsset(asset);
        uint256 lastTotalAssets = IkStakingVault(vault).lastTotalAssets();

        _handleYield(vault, asset, totalAssets, lastTotalAssets, kToken);

        if (deposited > requested) {
            uint256 netted = deposited - requested;
            address adapter = _registry().getAdapter(vault);
            IAdapter(adapter).deposit(asset, netted, vault);

            emit Deposited(vault, asset, deposited);
        }

        // Update vault's total assets
        IkStakingVault(vault).updateLastTotalAssets(totalAssets);
    }

    function _handleYield(
        address vault,
        address asset,
        uint256 totalAssets,
        uint256 lastTotalAssets,
        address kToken
    )
        internal
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        if (totalAssets > lastTotalAssets) {
            // Positive yield - mint kTokens to vault
            uint256 profit = totalAssets - lastTotalAssets;
            $.vaultBalances[vault][asset] += profit;
            IkToken(kToken).mint(vault, profit);
            emit YieldDistributed(vault, profit, true);
        } else if (totalAssets < lastTotalAssets) {
            // Negative yield - burn kTokens from vault
            uint256 loss = lastTotalAssets - totalAssets;
            $.vaultBalances[vault][asset] -= loss;
            IkToken(kToken).burn(vault, loss);
            emit YieldDistributed(vault, loss, false);
        }
    }

    /// @notice In case of not enough funds for kTokens, pull from insurance
    function _insure(address asset, uint256 requested) internal {
        // TODO: Implement insurance
        // call insurance adapter to pull from insurance
    }

    /// @notice Get current batch ID for a vault
    function _getCurrentBatchId(address vault) internal view returns (uint256) {
        return IkStakingVault(vault).getBatchId();
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

    /// @notice Get virtual asset balance for a specific vault and asset
    /// @param _vault The vault to query (kMinter, kDNVault, kSVault)
    /// @param _asset The asset to query (USDC, WBTC, etc.)
    /// @return Virtual asset balance for the vault
    function getBalanceOf(address _vault, address _asset) external view returns (uint256) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.vaultBalances[_vault][_asset];
    }

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool) {
        return _getBaseStorage().paused;
    }

    /// @notice Get batch balances for a vault
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return deposited Amount deposited in this batch
    /// @return requested Amount requested in this batch
    function getBatchIdBalances(
        address vault,
        uint256 batchId
    )
        external
        view
        returns (uint256 deposited, uint256 requested)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        kAssetRouterTypes.Balances memory balances = $.vaultBatchBalances[vault][batchId];
        return (balances.deposited, balances.requested);
    }

    /// @notice Get requested shares for a vault batch
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return Requested shares amount
    function getRequestedShares(address vault, uint256 batchId) external view returns (uint256) {
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
}
