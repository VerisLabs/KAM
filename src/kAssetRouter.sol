// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";
import { kAssetRouterTypes } from "src/types/kAssetRouterTypes.sol";

import { IkBatch } from "src/interfaces/IkBatch.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kAssetRouter
contract kAssetRouter is Initializable, UUPSUpgradeable, OwnableRoles, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant ADMIN_ROLE = _ROLE_0;
    uint256 internal constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 internal constant MANAGER_ROLE = _ROLE_2;
    uint256 internal constant MINTER_ROLE = _ROLE_3;
    uint256 internal constant VAULT_ROLE = _ROLE_4;
    uint256 internal constant ADAPTER_ROLE = _ROLE_5;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetsPushed(address indexed from, address indexed vault, uint256 amount);
    event AssetsRequestPulled(address indexed vault, address indexed asset, uint256 amount);
    event AssetsTransfered(
        address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount
    );
    event SharesRequested(address indexed vault, uint256 batchId, uint256 amount);
    event VirtualBalanceUpdated(address indexed vault, uint256 previousBalance, uint256 newBalance);
    event AssetsRoutedToBatch(address indexed batchReceiver, uint256 amount);
    event VirtualBalanceTransfer(address indexed fromVault, address indexed toVault, uint256 amount);
    event VirtualBalanceLossRealized(address indexed vault, address indexed assetToken, uint256 lossAmount);
    event StrategyReturnProcessed(
        address indexed vault, address indexed assetToken, uint256 deployedAmount, uint256 returnedAmount, uint256 loss
    );
    event StrategyDeploymentProcessed(address indexed vault, address indexed assetToken, uint256 amount);
    event kTransfered(address indexed sourceVault, address indexed targetVault, address indexed asset, uint256 amount);
    event RequestPulled(address indexed vault, address indexed asset, uint256 amount);
    event SharesSettled(
        address[] vaults, uint256 batchId, uint256 totalRequestedShares, uint256[] totalAssets, uint256 sharePrice
    );
    event AssetsSettled(address[] vaults, uint256 batchId);
    event PegProtectionActivated(address indexed vault, uint256 shortfall);
    event YieldDistributed(address indexed vault, uint256 yield, bool isProfit);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAmount();
    error VaultNotRegistered();
    error AssetNotRegistered();
    error AssetAlreadyRegistered();
    error ZeroAddress();
    error BatchVaultsLengthMismatch();
    error BatchSettled();
    error InsufficientVirtualBalance();

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        bool isPaused;
        address[] assets;
        address[] vaults;
        address kMinter;
        address kBatch;
        address kDNVault;
        uint256 totalPendingDeposits;
        uint256 totalPendingRedeems;
        uint256 peggedBalance;
        mapping(address => mapping(uint256 => kAssetRouterTypes.Balances)) vaultBatchBalances; // vault => batchId =>
            // pending amounts
        mapping(address => mapping(address => uint256)) vaultBalances; // vault => asset => balance
        mapping(address => mapping(uint256 => uint256)) vaultRequestedShares; // vault => batchId => balance
        mapping(address => bool) registeredVaults; // vault => is registered
        mapping(address => bool) registeredAssets; // asset => is registered
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
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        if ($.isPaused) revert Paused();
        _;
    }

    modifier onlyRegisteredVault(address _vault) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        if (!$.registeredVaults[_vault]) revert VaultNotRegistered();
        _;
    }

    modifier onlyRegisteredAsset(address _asset) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        if (!$.registeredAssets[_asset]) revert AssetNotRegistered();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the kAssetRouter with asset and admin configuration
    /// @param asset_ Initial asset to register
    /// @param admin_ Admin address for role management
    /// @param kMinter_ kMinter contract address
    /// @param kBatch_ kBatch contract address
    function initialize(address asset_, address admin_, address kMinter_, address kBatch_) external initializer {
        if (admin_ == address(0)) revert ZeroAddress();
        if (kMinter_ == address(0)) revert ZeroAddress();
        if (kBatch_ == address(0)) revert ZeroAddress();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.kMinter = kMinter_;
        $.kBatch = kBatch_;

        _registerAsset(asset_);

        _initializeOwner(admin_);
        _grantRoles(admin_, ADMIN_ROLE);
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
        onlyRoles(MINTER_ROLE)
        onlyRegisteredVault(targetVault)
        onlyRegisteredAsset(_asset)
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
        onlyRoles(VAULT_ROLE)
        onlyRegisteredVault(targetVault)
        onlyRegisteredAsset(_asset)
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
        onlyRoles(VAULT_ROLE)
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
        onlyRoles(VAULT_ROLE)
    {
        if (amount == 0) revert ZeroAmount();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        $.vaultRequestedShares[sourceVault][batchId] += amount;

        emit SharesRequested(sourceVault, batchId, amount);
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
        onlyRoles(VAULT_ROLE)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if (IkBatch($.kBatch).isBatchSettled(batchId)) revert BatchSettled();

        address[] memory batchVaults = IkBatch($.kBatch).getBatchVaults(batchId);
        if (batchVaults.length != vaults.length) revert BatchVaultsLengthMismatch();

        uint256 length = batchVaults.length;
        uint256 totalRequestedShares;
        uint256 sharePrice;
        uint256 kTokens;

        for (uint256 i; i < length;) {
            if (batchVaults[i] == vaults[i]) {
                totalRequestedShares = $.vaultRequestedShares[vaults[i]][batchId];

                if (totalRequestedShares > 0) {
                    kTokens = totalRequestedShares * IkStakingVault(vaults[i]).calculateStkTokenPrice(totalAssets[i]);
                    $.totalPendingRedeems -= kTokens;
                    $.vaultRequestedShares[vaults[i]][batchId] = 0;
                    $.vaultBatchBalances[vaults[i]][batchId].requested -= kTokens;
                }

                if (vaults[i] == $.kMinter) {
                    $.vaultBatchBalances[vaults[i]][batchId].deposited += kTokens;
                } else {
                    // Deposit into kMinter
                    // kMinter should be last
                    // maybe every vault will deposit into kMinter
                    $.vaultBatchBalances[$.kMinter][batchId].deposited += kTokens;
                }
            }
            unchecked {
                ++i;
            }
        }

        emit SharesSettled(vaults, batchId, totalRequestedShares, totalAssets, sharePrice);
    }

    function kSettleAssets(
        address[] calldata vaults,
        uint256[] calldata totalAssets,
        uint256 batchId
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(VAULT_ROLE)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if (IkBatch($.kBatch).isBatchSettled(batchId)) revert BatchSettled();

        address[] memory batchVaults = IkBatch($.kBatch).getBatchVaults(batchId);
        if (batchVaults.length != vaults.length) revert BatchVaultsLengthMismatch();

        uint256 length = batchVaults.length;

        for (uint256 i; i < length;) {
            if (batchVaults[i] == vaults[i]) {
                address vault = vaults[i];
                address asset = IkBatch($.kBatch).getAssetInVaultBatch(batchId, vault);

                uint256 deposited = $.vaultBatchBalances[vault][batchId].deposited;
                uint256 requested = $.vaultBatchBalances[vault][batchId].requested;

                if (vault == $.kMinter) {
                    // kMinter case:
                    // deposited = assets pushed from institutions (already in router)
                    // requested = assets needed for redemptions

                    // Just update accounting - assets already here
                    $.vaultBalances[vault][asset] += deposited;

                    if (requested > 0) {
                        // Send to BatchReceiver for institutional redemptions
                        address batchReceiver = IkBatch($.kBatch).getBatchReceiver(batchId);
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
                        $.vaultBalances[$.kMinter][asset] -= netDeposit;
                    } else if (requested > deposited) {
                        // Net withdrawal from vault
                        uint256 netWithdrawal = requested - deposited;

                        // Vault should have sent assets back to router already
                        // Push assets to vault/adapter
                        // TODO: Deposit into kDNVault Adapter

                        // Update accounting
                        $.vaultBalances[vault][asset] -= netWithdrawal;
                        // Credit back to kMinter
                        $.vaultBalances[$.kMinter][asset] += netWithdrawal;
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
            }

            unchecked {
                ++i;
            }
        }

        // Clear pending totals
        $.totalPendingDeposits = 0;
        $.totalPendingRedeems = 0;

        // Mark batch as settled
        IkBatch($.kBatch).settleBatch(batchId);
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function registerAsset(address _asset) external onlyRoles(ADMIN_ROLE) {
        _registerAsset(_asset);
    }

    function registerVault(address _vault) external onlyRoles(ADMIN_ROLE) {
        _registerVault(_vault);
    }

    /// @notice Grant minter role to address (typically kMinter)
    /// @param minter The address to grant minter role
    function grantMinterRole(address minter) external onlyRoles(ADMIN_ROLE) {
        if (minter == address(0)) revert ZeroAddress();
        _grantRoles(minter, MINTER_ROLE);
    }

    /// @notice Grant vault role to address (typically vault contracts)
    /// @param vault The address to grant vault role
    function grantVaultRole(address vault) external onlyRoles(ADMIN_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        _grantRoles(vault, VAULT_ROLE);
    }

    /// @notice Grant strategy manager role
    /// @param manager Address to grant role to
    function grantStrategyManagerRole(address manager) external onlyRoles(ADMIN_ROLE) {
        if (manager == address(0)) revert ZeroAddress();
        _grantRoles(manager, MANAGER_ROLE);
    }

    /// @notice Set contract pause state
    /// @param paused New pause state
    function setPaused(bool paused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.isPaused = paused;
    }

    /// @notice Set kDNVault address (for circular dependency resolution)
    /// @param kDNVault_ kDNStakingVault contract address
    function setKDNVault(address kDNVault_) external onlyRoles(ADMIN_ROLE) {
        if (kDNVault_ == address(0)) revert ZeroAddress();
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.kDNVault = kDNVault_;
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

    /// @notice Check if an asset is registered
    /// @param _asset The asset address to check
    /// @return True if the asset is registered
    function isRegisteredAsset(address _asset) external view returns (bool) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.registeredAssets[_asset];
    }

    /// @notice Check if a vault is registered
    /// @param _vault The vault address to check
    /// @return True if the vault is registered
    function isRegisteredVault(address _vault) external view returns (bool) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.registeredVaults[_vault];
    }

    /// @notice Get all registered vaults
    /// @return Array of registered vault addresses
    function getRegisteredVaults() external view returns (address[] memory) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.vaults;
    }

    /// @notice Get all registered assets
    /// @return Array of registered asset addresses
    function getRegisteredAssets() external view returns (address[] memory) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.assets;
    }

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.isPaused;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register an asset for virtual balance tracking
    /// @param _asset The asset address to register
    function _registerAsset(address _asset) internal {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        if ($.registeredAssets[_asset]) revert AssetAlreadyRegistered();
        $.registeredAssets[_asset] = true;
        $.assets.push(_asset);
    }

    /// @notice Register a vault for virtual balance tracking
    /// @param vault The vault address to register
    function _registerVault(address vault) internal {
        if (vault == address(0)) revert ZeroAddress();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        if (!$.registeredVaults[vault]) {
            $.registeredVaults[vault] = true;
            $.vaults.push(vault);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          UPGRADE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize contract upgrade
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(ADMIN_ROLE) {
        // Authorization handled by modifier
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive ETH (for gas refunds, etc.)
    receive() external payable { }
}
