// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

import { Multicallable } from "solady/utils/Multicallable.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";

import { MultiFacetProxy } from "src/modules/MultiFacetProxy.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title kDNStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kDNStakingVault is
    Initializable,
    UUPSUpgradeable,
    ERC20,
    ModuleBase,
    Multicallable,
    MultiFacetProxy,
    Extsload
{
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    // Roles, storage, and constants inherited from ModuleBase

    // Metadata constants to save gas (instead of storage)
    string private constant DEFAULT_NAME = "KAM DN Staking Vault";
    string private constant DEFAULT_SYMBOL = "kToken";

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event PauseState(bool isPaused);
    event MinterDepositRequested(address indexed minter, uint256 assetAmount, uint256 indexed batchId);
    event MinterRedeemRequested(
        address indexed minter, uint256 assetAmount, address batchReceiver, uint256 indexed batchId
    );
    event KTokenStakingRequested(
        address indexed user, address indexed minter, uint256 kTokenAmount, uint256 indexed batchId
    );
    event ShareUnstakingRequested(address indexed user, uint256 shares, uint256 indexed batchId);
    event KTokenUnstaked(address indexed user, uint256 shares, uint256 kTokenAmount);
    event KTokenStaked(address indexed user, uint256 kTokenAmount, uint256 shares, uint256 indexed batchId);
    event MinterDeposited(address indexed minter, uint256 assets);
    event MinterWithdrawn(address indexed minter, address indexed receiver, uint256 assets);
    event StkTokensIssued(address indexed user, uint256 stkTokenAmount);
    event StkTokensRedeemed(address indexed user, uint256 stkTokenAmount, uint256 kTokenAmount);
    event SharesTransferredToUser(address indexed user, address indexed fromMinter, uint256 shares);
    event Initialized(
        string name,
        string symbol,
        uint8 decimals,
        address asset,
        address kToken,
        address owner,
        address admin,
        address emergencyAdmin,
        address settler,
        address strategyManager
    );

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    // Shared errors inherited from ModuleBase
    error InvalidBatchReceiver();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() MultiFacetProxy(ADMIN_ROLE) {
        _disableInitializers();
    }

    /// @notice Initializes the kDNStakingVault contract (stack optimized)
    /// @dev Phase 1: Core initialization without strings to avoid stack too deep
    /// @param asset_ Underlying asset address
    /// @param kToken_ kToken address
    /// @param owner_ Owner address
    /// @param admin_ Admin address
    /// @param emergencyAdmin_ Emergency admin address
    /// @param settler_ Settler address
    /// @param strategyManager_ Strategy manager address
    /// @param decimals_ Token decimals
    function initialize(
        address asset_,
        address kToken_,
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address settler_,
        address strategyManager_,
        uint8 decimals_
    )
        external
        initializer
    {
        if (asset_ == address(0)) revert ZeroAddress();
        if (kToken_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();
        if (settler_ == address(0)) revert ZeroAddress();
        if (strategyManager_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(settler_, SETTLER_ROLE);
        _grantRoles(strategyManager_, STRATEGY_MANAGER_ROLE);

        // Initialize storage with optimized packing
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        $.underlyingAsset = asset_;
        $.kToken = kToken_;
        $.strategyManager = strategyManager_;
        $.varianceRecipient = owner_;

        // Pack configuration values efficiently
        $.dustAmount = _safeToUint128(DEFAULT_DUST_AMOUNT);
        $.settlementInterval = _safeToUint64(DEFAULT_SETTLEMENT_INTERVAL);
        $.decimals = _safeToUint32(decimals_);
        $.isPaused = false;

        // Initialize batch IDs (start at 1) - packed efficiently
        $.currentBatchId = 1;
        $.currentStakingBatchId = 1;
        $.currentUnstakingBatchId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Requests deposit from authorized minter with exact asset amount
    /// @param assetAmount Exact amount of assets to deposit
    /// @return batchId Batch ID for this request
    function requestMinterDeposit(uint256 assetAmount)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(MINTER_ROLE)
        returns (uint256 batchId)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (assetAmount == 0) revert ZeroAmount();

        // Get current batch
        batchId = $.currentBatchId;
        DataTypes.Batch storage batch = $.batches[batchId];

        // Update state
        batch.depositAmounts[msg.sender] += assetAmount;
        batch.totalDeposits += assetAmount;
        $.minterPendingNetAmounts[msg.sender] += int256(assetAmount);

        // Track minter if first operation in batch
        if (!batch.hasMinterOperation[msg.sender]) {
            batch.hasMinterOperation[msg.sender] = true;
            batch.minters.push(msg.sender);
        }

        $.underlyingAsset.safeTransferFrom(msg.sender, address(this), assetAmount);

        emit MinterDepositRequested(msg.sender, assetAmount, batchId);
    }

    /// @notice Requests redemption from authorized minter with exact asset amount
    /// @param assetAmount Exact amount of assets to redeem
    /// @param minter Minter address for tracking
    /// @param batchReceiver BatchReceiver to send assets to
    /// @return batchId Batch ID for this request
    function requestMinterRedeem(
        uint256 assetAmount,
        address minter,
        address batchReceiver
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(MINTER_ROLE)
        returns (uint256 batchId)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (assetAmount == 0) revert ZeroAmount();
        if (batchReceiver == address(0)) revert InvalidBatchReceiver();

        // Get current batch
        batchId = $.currentBatchId;
        DataTypes.Batch storage batch = $.batches[batchId];

        // Add to batch redeems
        batch.redeemAmounts[minter] += assetAmount;
        batch.totalRedeems += assetAmount;
        batch.batchReceivers[minter] = batchReceiver;

        // Update minter's net pending (negative for redeems)
        $.minterPendingNetAmounts[minter] -= int256(assetAmount);

        // Track minter if first operation in batch
        if (!batch.hasMinterOperation[minter]) {
            batch.hasMinterOperation[minter] = true;
            batch.minters.push(minter);
        }

        emit MinterRedeemRequested(minter, assetAmount, batchReceiver, batchId);
    }

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param amount Amount of kTokens to stake
    /// @return requestId Request ID for this staking request
    function requestStake(uint256 amount) external payable nonReentrant whenNotPaused returns (uint256 requestId) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (amount == 0) revert ZeroAmount();
        if (amount < $.dustAmount) revert("Amount below dust threshold");

        // Get current staking batch
        uint256 batchId = $.currentStakingBatchId;
        DataTypes.StakingBatch storage batch = $.stakingBatches[batchId];

        $.totalStakedKTokens += _safeToUint128(amount);

        // Add to batch (stkToken amount calculated at settlement)
        batch.requests.push(
            DataTypes.StakingRequest({
                user: msg.sender,
                kTokenAmount: _safeToUint96(amount),
                stkTokenAmount: 0, // Will be calculated at settlement with real pricing
                requestTimestamp: _safeToUint64(block.timestamp),
                claimed: false
            })
        );

        batch.totalKTokens += amount;
        requestId = batch.requests.length - 1; // Request index as ID

        $.kToken.safeTransferFrom(msg.sender, address(this), amount);

        emit KTokenStakingRequested(msg.sender, address(0), amount, batchId);
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(uint256 stkTokenAmount)
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (stkTokenAmount == 0) revert ZeroAmount();

        // Check available stkTokens using ERC20 balance
        uint256 totalAvailable = balanceOf(msg.sender);
        if (totalAvailable < stkTokenAmount) revert InsufficientShares();

        // Transfer stkTokens to vault for safe handling during settlement process
        _transfer(msg.sender, address(this), stkTokenAmount);

        // Get current unstaking batch
        uint256 batchId = $.currentUnstakingBatchId;
        DataTypes.UnstakingBatch storage batch = $.unstakingBatches[batchId];

        // Add to batch (amounts calculated at settlement)
        batch.requests.push(
            DataTypes.UnstakingRequest({
                user: msg.sender,
                stkTokenAmount: _safeToUint96(stkTokenAmount),
                requestTimestamp: _safeToUint64(block.timestamp),
                claimed: false
            })
        );

        batch.totalStkTokens += stkTokenAmount;
        requestId = batch.requests.length - 1; // Request index as ID

        emit ShareUnstakingRequested(msg.sender, stkTokenAmount, batchId);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if address is authorized minter
    function isAuthorizedMinter(address minter) external view returns (bool) {
        return hasAnyRole(minter, MINTER_ROLE);
    }

    /// @notice Check if a unified batch is settled
    /// @param batchId The batch ID to check
    /// @return settled Whether the batch is settled
    function isBatchSettled(uint256 batchId) external view returns (bool settled) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return batchId <= $.lastSettledBatchId;
    }

    /// @notice Get total vault assets (vault balance only - StrategyManager handles external assets)
    function getTotalVaultAssets() public view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        // Return kToken balance only (underlyingAsset for vault is kToken, not USDC)
        return $.underlyingAsset.balanceOf(address(this));
    }

    /// @notice Returns total user assets including automatic yield
    /// @return Total user assets including unaccounted yield
    function getTotalUserAssets() external view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        uint256 userAssets = $.userTotalAssets; // Cache storage read
        uint256 totalVaultBalance = getTotalVaultAssets();
        uint256 accountedAssets = $.totalMinterAssets + userAssets;

        // Return total user assets including unaccounted yield
        // This ensures user shares appreciate with vault yield automatically
        return totalVaultBalance > accountedAssets ? userAssets + (totalVaultBalance - accountedAssets) : userAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
        return _getkDNStakingVaultStorage().underlyingAsset;
    }

    /// @notice Returns the vault shares token name
    /// @return Token name
    function name() public pure override returns (string memory) {
        return DEFAULT_NAME;
    }

    /// @notice Returns the vault shares token symbol
    /// @return Token symbol
    function symbol() public pure override returns (string memory) {
        return DEFAULT_SYMBOL;
    }

    /// @notice Returns the vault shares token decimals
    /// @return Token decimals
    function decimals() public view override returns (uint8) {
        return uint8(_getkDNStakingVaultStorage().decimals);
    }

    /// @notice Get user's stkToken balance (alias for balanceOf)
    /// @param user User address
    /// @return User's stkToken balance
    function getStkTokenBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    /// @notice Get user's claimed stkToken balance (same as total balance in new model)
    /// @param user User address
    /// @return User's claimed stkToken balance
    function getClaimedStkTokenBalance(address user) external view returns (uint256) {
        return balanceOf(user);
    }

    /// @notice Get total stkTokens in circulation
    /// @return Total stkToken supply
    function getTotalStkTokens() external view returns (uint256) {
        return totalSupply();
    }

    /// @notice Get current stkToken price
    /// @return Current price in terms of assets per stkToken
    function getStkTokenPrice() external view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.totalStkTokenSupply == 0 ? PRECISION : ($.totalStkTokenAssets * PRECISION) / $.totalStkTokenSupply;
    }

    /// @notice Get minter's asset balance (for 1:1 guarantee validation)
    /// @param minter Minter address
    /// @return Minter's tracked asset balance
    function getMinterAssetBalance(address minter) external view returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.minterAssetBalances[minter];
    }

    /*//////////////////////////////////////////////////////////////
                        ERC20 OVERRIDES FOR DUAL ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns total supply of user shares (not including minter accounting)
    /// @dev Overrides ERC20 to provide user-only share accounting
    function totalSupply() public view override returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return uint256($.userTotalSupply);
    }

    /// @notice Returns user's stkToken balance
    /// @dev Overrides ERC20 to provide user share balance
    function balanceOf(address account) public view override returns (uint256) {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();
        return $.userShareBalances[account];
    }

    /// @notice Override internal mint to update our dual accounting
    /// @dev Updates userTotalSupply and userShareBalances
    function _mint(address to, uint256 value) internal override {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        $.userTotalSupply += _safeToUint128(value);
        $.userShareBalances[to] += value;

        emit Transfer(address(0), to, value);
    }

    /// @notice Override internal burn to update our dual accounting
    /// @dev Updates userTotalSupply and userShareBalances
    function _burn(address from, uint256 value) internal override {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        $.userShareBalances[from] -= value;
        $.userTotalSupply -= _safeToUint128(value);

        emit Transfer(from, address(0), value);
    }

    /// @notice Override internal transfer to update our dual accounting
    /// @dev Updates userShareBalances for both from and to
    function _transfer(address from, address to, uint256 value) internal override {
        kDNStakingVaultStorage storage $ = _getkDNStakingVaultStorage();

        if (from == address(0)) {
            // This is a mint
            _mint(to, value);
            return;
        }

        if (to == address(0)) {
            // This is a burn
            _burn(from, value);
            return;
        }

        // Regular transfer
        $.userShareBalances[from] -= value;
        $.userShareBalances[to] += value;

        emit Transfer(from, to, value);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Grants admin role to address
    /// @param admin Address to grant role to
    function grantAdminRole(address admin) external onlyOwner {
        _grantRoles(admin, ADMIN_ROLE);
    }

    /// @notice Revokes admin role from address
    /// @param admin Address to revoke role from
    function revokeAdminRole(address admin) external onlyOwner {
        _removeRoles(admin, ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTIFACET PROXY OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Override MultiFacetProxy addFunction to use main contract's role system
    /// @param selector The function selector to add
    /// @param implementation The implementation contract address
    /// @param forceOverride If true, allows overwriting existing mappings
    function addFunction(
        bytes4 selector,
        address implementation,
        bool forceOverride
    )
        public
        override
        onlyRoles(ADMIN_ROLE)
    {
        // Use direct mapping access instead of parent to bypass proxy admin role check
        if (!forceOverride) {
            if (selectorToImplementation[selector] != address(0)) revert("Selector already mapped");
        }
        selectorToImplementation[selector] = implementation;
    }

    /// @notice Override MultiFacetProxy addFunctions to use main contract's role system
    /// @param selectors Array of function selectors to add
    /// @param implementation The implementation contract address
    /// @param forceOverride If true, allows overwriting existing mappings
    function addFunctions(bytes4[] calldata selectors, address implementation, bool forceOverride) public override {
        uint256 length = selectors.length;
        for (uint256 i; i < length;) {
            addFunction(selectors[i], implementation, forceOverride);

            unchecked {
                i++;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner { }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kDNStakingVault";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts ETH transfers
    receive() external payable { }
}
