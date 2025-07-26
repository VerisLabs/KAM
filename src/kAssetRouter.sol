// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import { kAssetRouterTypes } from "src/types/kAssetRouterTypes.sol";

import { kBase } from "src/base/kBase.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";

/// @title kAssetRouter
contract kAssetRouter is Initializable, UUPSUpgradeable, kBase, Multicallable {
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

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error InsufficientVirtualBalance();
    error ContractPaused();
    error OnlyStakingVault();

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        uint256 totalPendingDeposits;
        uint256 totalPendingRedeems;
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
        $.totalPendingDeposits += amount;

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

        $.totalPendingRedeems += amount;
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

        // should be when settled
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

        if (asset.balanceOf(address(this)) < requested) {
            _insure(asset, requested);
        }

        if (vault == _getKMinter()) {
            // kMinter settlement: handle institutional deposits and redemptions
            $.vaultBalances[vault][asset] += deposited;

            if (requested > 0) {
                // Deploy batch receiver for this batch
                address batchReceiver = IkStakingVault(vault).getSafeBatchReceiver(batchId);

                // Transfer assets to batch receiver for redemptions
                asset.safeTransfer(batchReceiver, requested);
                $.vaultBalances[vault][asset] -= requested;
            }
        } else {
            // Staking vault settlement
            _settleStakingVault(vault, asset, deposited, requested, totalAssets_);
        }

        // Clear batch balances
        delete $.vaultBatchBalances[vault][batchId];

        // Update totals
        $.totalPendingDeposits = deposited > $.totalPendingDeposits ? 0 : $.totalPendingDeposits - deposited;
        $.totalPendingRedeems = requested > $.totalPendingRedeems ? 0 : $.totalPendingRedeems - requested;

        emit BatchSettled(vault, batchId.toUint32(), totalAssets_);
    }

    /// @notice Settle multiple vaults in parallel
    /// @param vaults Array of vault addresses
    /// @param batchIds Array of batch IDs (one per vault)
    /// @param totalAssets Array of total assets (one per vault)
    function batchSettle(
        address[] calldata vaults,
        uint256[] calldata batchIds,
        uint256[] calldata totalAssets
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRelayer
    {
        uint256 length = vaults.length;
        require(length == batchIds.length && length == totalAssets.length, "Array length mismatch");

        for (uint256 i; i < length;) {
            // Settle each vault individually
            this.settleBatch(vaults[i], batchIds[i], totalAssets[i]);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function to settle staking vault
    function _settleStakingVault(
        address vault,
        address asset,
        uint256 deposited,
        uint256 requested,
        uint256 totalAssets
    )
        internal
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Handle share redemptions
        uint256 requestedShares = $.vaultRequestedShares[vault][totalAssets];
        if (requestedShares > 0) {
            uint256 sharePrice = IkStakingVault(vault).calculateStkTokenPrice(totalAssets);
            uint256 kTokensForShares = requestedShares * sharePrice / 1e18; // TODO: use solady FixedPointMathLic
            requested += kTokensForShares;
            $.vaultRequestedShares[vault][totalAssets] = 0;
        }

        // Calculate net position
        if (deposited > requested) {
            // Net deposit to vault
            uint256 netDeposit = deposited - requested;
            $.vaultBalances[vault][asset] += netDeposit;
            $.vaultBalances[_getKMinter()][asset] -= netDeposit;
        } else if (requested > deposited) {
            // Net withdrawal from vault
            uint256 netWithdrawal = requested - deposited;
            $.vaultBalances[vault][asset] -= netWithdrawal;
            $.vaultBalances[_getKMinter()][asset] += netWithdrawal;
        }

        // Handle yield distribution
        address kToken = _getKTokenForAsset(asset);
        uint256 lastTotalAssets = IkStakingVault(vault).lastTotalAssets();

        if (totalAssets > lastTotalAssets) {
            // Positive yield - mint kTokens to vault
            uint256 profit = totalAssets - lastTotalAssets;
            IkToken(kToken).mint(vault, profit);
            emit YieldDistributed(vault, profit, true);
        } else if (totalAssets < lastTotalAssets) {
            // Negative yield - burn kTokens from vault
            uint256 loss = lastTotalAssets - totalAssets;
            IkToken(kToken).burn(vault, loss);
            emit YieldDistributed(vault, loss, false);
        }

        // Update vault's total assets
        IkStakingVault(vault).updateLastTotalAssets(totalAssets);
    }

    /// @notice Ensure 1:1 peg protection for kTokens
    function _insure(address asset, uint256 amount) internal {
        address kToken = _getKTokenForAsset(asset);
        uint256 totalKTokenSupply = IkToken(kToken).totalSupply();

        // Calculate total backing across all vaults
        uint256 totalBacking = _calculateTotalAssetBacking(asset);

        if (totalBacking < totalKTokenSupply) {
            uint256 shortfall = totalKTokenSupply - totalBacking;

            // TODO: implement adapter Insurance
            // withdraw from adapter
        }
    }

    /// @notice Calculate total asset backing across all vaults
    function _calculateTotalAssetBacking(address asset) internal view returns (uint256 totalBacking) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Add kMinter balance
        totalBacking += $.vaultBalances[_getKMinter()][asset];

        // Add all vault balances
        address[] memory vaults = _registry().getVaultsByAsset(asset);
        for (uint256 i; i < vaults.length;) {
            totalBacking += $.vaultBalances[vaults[i]][asset];
            unchecked {
                ++i;
            }
        }
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
    function getBatchBalances(
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

    /// @notice Get total asset backing across all vaults
    /// @param asset Asset to check
    /// @return Total backing amount
    function getTotalBacking(address asset) external view returns (uint256) {
        return _calculateTotalAssetBacking(asset);
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
