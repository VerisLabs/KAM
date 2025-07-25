// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import { kAssetRouterTypes } from "src/types/kAssetRouterTypes.sol";

import { kBase } from "src/base/kBase.sol";
import { IkBatch } from "src/interfaces/IkBatch.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kAssetRouter
contract kAssetRouter is Initializable, UUPSUpgradeable, kBase, Multicallable {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address indexed registry, address indexed owner, address admin, bool paused);
    event AssetsPushed(address indexed from, address indexed vault, uint256 amount);
    event AssetsRequestPulled(address indexed vault, address indexed asset, uint256 amount);
    event AssetsTransfered(
        address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount
    );
    event SharesRequested(address indexed vault, uint32 batchId, uint256 amount);
    event SharesSettled(
        address[] vaults, uint32 batchId, uint256 totalRequestedShares, uint256[] totalAssets, uint256 sharePrice
    );
    event PegProtectionActivated(address indexed vault, uint256 shortfall);
    event YieldDistributed(address indexed vault, uint256 yield, bool isProfit);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAmount();
    error BatchSettled();
    error BatchClosed();
    error InsufficientVirtualBalance();
    error ContractPaused();
    error OnlyStakingVault();
    error VaultNotInBatch();

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

    /// @notice Push assets from kMinter with virtual balance update for target vault
    /// @param targetVault The vault that should receive the virtual balance credit
    /// @param amount Amount of assets being pushed
    function kAssetPush(
        address targetVault,
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

        // Transfer assets from minter to router
        _asset.safeTransferFrom(msg.sender, address(this), amount);

        $.vaultBatchBalances[targetVault][batchId].deposited += amount;
        $.totalPendingDeposits += amount;

        emit AssetsPushed(msg.sender, targetVault, amount);
    }

    function kAssetRequestPull(
        address targetVault,
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

        if ($.vaultBalances[targetVault][_asset] < amount) revert InsufficientVirtualBalance();

        $.totalPendingRedeems += amount;
        $.vaultBatchBalances[targetVault][batchId].requested += amount;

        emit AssetsRequestPulled(targetVault, _asset, amount);
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
        $.vaultBatchBalances[sourceVault][batchId].requested += amount;
        $.vaultBatchBalances[targetVault][batchId].deposited += amount;

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

    function kSettleShares(
        address[] calldata vaults,
        uint256[] calldata totalAssets,
        uint256 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRelayer
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if (IkBatch(_getKBatch()).isBatchSettled(batchId)) revert BatchSettled();

        uint256 length = vaults.length;
        uint256 totalRequestedShares;
        uint256 sharePrice;
        uint256 kTokens;
        address kMinter = _getKMinter();
        address kBatch = _getKBatch();
        IkBatch batch = IkBatch(kBatch);

        for (uint256 i; i < length;) {
            if (batch.isVaultInBatch(batchId, vaults[i])) {
                totalRequestedShares = $.vaultRequestedShares[vaults[i]][batchId];

                if (totalRequestedShares > 0) {
                    kTokens = totalRequestedShares * IkStakingVault(vaults[i]).calculateStkTokenPrice(totalAssets[i]);
                    $.totalPendingRedeems -= kTokens;
                    $.vaultRequestedShares[vaults[i]][batchId] = 0;
                    $.vaultBatchBalances[vaults[i]][batchId].requested -= kTokens;
                }

                if (vaults[i] == kMinter) {
                    $.vaultBatchBalances[vaults[i]][batchId].deposited += kTokens;
                } else {
                    // Deposit into kMinter
                    // kMinter should be last
                    // maybe every vault will deposit into kMinter
                    $.vaultBatchBalances[kMinter][batchId].deposited += kTokens;
                }
            }
            unchecked {
                ++i;
            }
        }

        emit SharesSettled(vaults, batchId.toUint32(), totalRequestedShares, totalAssets, sharePrice);
    }

    /// @notice Settle assets for a batch
    /// @param vaults Array of vault addresses
    /// @param totalAssets Array of total assets
    /// @param batchId Batch ID
    function kSettleAssets(
        address[] calldata vaults,
        uint256[] calldata totalAssets,
        uint256 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRelayer
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if (IkBatch(_getKBatch()).isBatchSettled(batchId)) revert BatchSettled();
        if (IkBatch(_getKBatch()).isBatchClosed(batchId)) revert BatchClosed();

        uint256 length = vaults.length;

        for (uint256 i; i < length;) {
            address vault = vaults[i];
            if (!IkBatch(_getKBatch()).isVaultInBatch(batchId, vault)) revert VaultNotInBatch();
            address asset = _getVaultAsset(vault);

            uint256 deposited = $.vaultBatchBalances[vault][batchId].deposited;
            uint256 requested = $.vaultBatchBalances[vault][batchId].requested;
            if (vault == _getKMinter()) {
                // kMinter case:
                // deposited = assets pushed from institutions (already in router)
                // requested = assets needed for redemptions
                // Just update accounting - assets already here
                $.vaultBalances[vault][asset] += deposited;
                if (requested > 0) {
                    // Send to BatchReceiver for institutional redemptions
                    address batchReceiver = IkBatch(_getKBatch()).getBatchReceiver(batchId);
                    asset.safeTransfer(batchReceiver, requested);
                    $.vaultBalances[vault][asset] -= requested;
                }
                // kMinter case - ensure 1:1 peg protection
                uint256 kMinterTotalAssets = $.vaultBalances[vault][asset];
                address kToken = IkStakingVault(vault).kToken();
                uint256 totalKTokenSupply = IkToken(kToken).totalSupply();
                if (kMinterTotalAssets < totalKTokenSupply) {
                    // Shortfall - need insurance fund to maintain peg
                    uint256 shortfall = totalKTokenSupply - kMinterTotalAssets;
                    // TODO: Pull from insurance fund adapter
                    // IInsuranceFund($.insuranceFund).withdraw(asset, shortfall);
                    // $.vaultBalances[vault][asset] += shortfall;
                    emit PegProtectionActivated(vault, shortfall);
                } else if (kMinterTotalAssets > totalKTokenSupply) {
                    // Excess profit - mint kTokens to kDNStakingVault as yield
                    uint256 profit = kMinterTotalAssets - totalKTokenSupply;
                    // TODO: Mint to kDNVault
                    // IkToken(kToken).mint(, profit);
                    emit YieldDistributed(vault, profit, true);
                }
            } else {
                // Other vaults: Calculate net position
                if (deposited > requested) {
                    // Net deposit to vault
                    uint256 netDeposit = deposited - requested;
                    // Push assets to vault/adapter
                    // TODO: Deposit vault Adapter
                    // Update accounting
                    $.vaultBalances[vault][asset] += netDeposit;
                    // Deduct from source (usually kMinter's balance)
                    $.vaultBalances[_getKMinter()][asset] -= netDeposit;
                } else if (requested > deposited) {
                    // Net withdrawal from vault
                    uint256 netWithdrawal = requested - deposited;
                    // Vault should have sent assets back to router already
                    // Push assets to vault/adapter
                    // TODO: Deposit into kDNVault Adapter
                    // Update accounting
                    $.vaultBalances[vault][asset] -= netWithdrawal;
                    // Credit back to kMinter
                    $.vaultBalances[_getKMinter()][asset] += netWithdrawal;
                }
                address kToken = IkStakingVault(vault).kToken();
                uint256 lastTotalAssets = IkStakingVault(vault).lastTotalAssets();
                if (totalAssets[i] > lastTotalAssets) {
                    // Positive yield - mint kTokens to vault
                    uint256 profit = totalAssets[i] - lastTotalAssets;
                    IkToken(kToken).mint(vault, profit);
                    emit YieldDistributed(vault, profit, true);
                } else {
                    // Negative yield - burn kTokens from vault
                    uint256 loss = lastTotalAssets - totalAssets[i];
                    IkToken(kToken).burn(vault, loss);
                    emit YieldDistributed(vault, loss, false);
                }
            }
            // Update vault's total assets
            // TODO: ORACLE?? VALIDATE if Custodial reflects the balance at settlement time
            IkStakingVault(vault).updateLastTotalAssets(totalAssets[i]);
            unchecked {
                ++i;
            }
        }

        // Clear pending totals
        $.totalPendingDeposits = 0;
        $.totalPendingRedeems = 0;

        // Mark batch as settled
        IkBatch(_getKBatch()).settleBatch(batchId);
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
