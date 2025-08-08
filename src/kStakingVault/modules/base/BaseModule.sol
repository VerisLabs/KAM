// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { ERC20 } from "solady/tokens/ERC20.sol";

import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkToken } from "src/interfaces/IkToken.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

/// @title BaseModule
/// @notice Base contract for all modules
/// @dev Provides shared storage, roles, and common functionality
contract BaseModule is OwnableRoles, ERC20, ReentrancyGuardTransient, Extsload {
    using FixedPointMathLib for uint256;
    using EnumerableSetLib for EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event StakeRequestCreated(
        bytes32 indexed requestId,
        address indexed user,
        address indexed kToken,
        uint256 amount,
        address recipient,
        bytes32 batchId
    );
    event StakeRequestRedeemed(bytes32 indexed requestId);
    event StakeRequestCancelled(bytes32 indexed requestId);
    event UnstakeRequestCreated(
        bytes32 indexed requestId, address indexed user, uint256 amount, address recipient, bytes32 batchId
    );
    event UnstakeRequestCancelled(bytes32 indexed requestId);
    event Paused(bool paused);
    event Initialized(address registry, address owner, address admin);
    event TotalAssetsUpdated(uint256 oldTotalAssets, uint256 newTotalAssets);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ONE_HUNDRED_PERCENT = 10_000;

    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
    bytes32 internal constant K_MINTER = keccak256("K_MINTER");

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidRegistry();
    error NotInitialized();
    error ContractNotFound(bytes32 identifier);
    error OnlyKAssetRouter();
    error OnlyRelayer();
    error ZeroAmount();
    error AmountBelowDustThreshold();
    error ContractPaused();
    error Closed();
    error Settled();
    error RequestNotFound();
    error RequestNotEligible();
    error InvalidVault();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201.kam.storage.BaseModule
    struct BaseModuleStorage {
        uint256 currentBatch;
        bytes32 currentBatchId;
        uint256 lastTotalAssets;
        uint256 sharePriceWatermark;
        uint256 lastFeesCharged;
        address registry;
        address receiverImplementation;
        uint96 dustAmount;
        address underlyingAsset;
        uint256 requestCounter;
        address kToken;
        uint8 decimals;
        bool initialized;
        bool paused;
        string name;
        string symbol;
        uint16 performanceFee;
        uint16 managementFee;
        address feeReceiver;
        mapping(bytes32 => BaseModuleTypes.BatchInfo) batches;
        mapping(bytes32 => BaseModuleTypes.StakeRequest) stakeRequests;
        mapping(bytes32 => BaseModuleTypes.UnstakeRequest) unstakeRequests;
        mapping(address => EnumerableSetLib.Bytes32Set) userRequests;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.BaseModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant MODULE_BASE_STORAGE_LOCATION =
        0x50bc60b877273d55cac3903fd4818902e5fd7aa256278ee2dc6b212f256c0b00;

    /// @notice Returns the base vault storage struct using ERC-7201 pattern
    /// @return $ Storage reference for base vault state variables
    function _getBaseModuleStorage() internal pure returns (BaseModuleStorage storage $) {
        assembly {
            $.slot := MODULE_BASE_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base contract with registry and pause state
    /// @param registry_ Address of the kRegistry contract
    /// @param paused_ Initial pause state
    /// @dev Can only be called once during initialization
    function __BaseModule_init(
        address registry_,
        address owner_,
        address admin_,
        address feeReceiver_,
        bool paused_
    )
        internal
    {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        if ($.initialized) revert AlreadyInitialized();
        if (registry_ == address(0)) revert InvalidRegistry();

        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();

        $.registry = registry_;
        $.paused = paused_;
        $.feeReceiver = feeReceiver_;
        $.initialized = true;

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract address
    /// @return The kRegistry contract address
    /// @dev Reverts if contract not initialized
    function registry() external view returns (address) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (!$.initialized) revert NotInitialized();
        return $.registry;
    }

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    /// @dev Internal helper for typed registry access
    function _registry() internal view returns (IkRegistry) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (!$.initialized) revert NotInitialized();
        return IkRegistry($.registry);
    }

    /*//////////////////////////////////////////////////////////////
                          GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _getKMinter() internal view returns (address minter) {
        minter = _registry().getContractById(K_MINTER);
        if (minter == address(0)) revert ContractNotFound(K_MINTER);
    }

    /// @notice Gets the kAssetRouter singleton contract address
    /// @return router The kAssetRouter contract address
    /// @dev Reverts if kAssetRouter not set in registry
    function _getKAssetRouter() internal view returns (address router) {
        router = _registry().getContractById(K_ASSET_ROUTER);
        if (router == address(0)) revert ContractNotFound(K_ASSET_ROUTER);
    }

    /// @notice Gets the DN vault address for a given asset
    /// @param asset_ The asset address
    /// @return vault The corresponding DN vault address
    /// @dev Reverts if asset not supported
    function _getDNVaultByAsset(address asset_) internal view returns (address vault) {
        vault = _registry().getVaultByAssetAndType(asset_, uint8(IkRegistry.VaultType.DN));
        if (vault == address(0)) revert InvalidVault();
    }

    /// @notice Checks if an account has relayer role
    /// @param account The account to check
    /// @return Whether the account has relayer role
    function _getRelayer(address account) internal view returns (bool) {
        return _registry().isRelayer(account);
    }

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
        return _getBaseModuleStorage().kToken;
    }

    /// @notice Returns the underlying asset address
    /// @return Asset address
    function underlyingAsset() external view returns (address) {
        return _getBaseModuleStorage().underlyingAsset;
    }

    /// @notice Returns the vault shares token name
    /// @return Token name
    function name() public view override returns (string memory) {
        return _getBaseModuleStorage().name;
    }

    /// @notice Returns the vault shares token symbol
    /// @return Token symbol
    function symbol() public view override returns (string memory) {
        return _getBaseModuleStorage().symbol;
    }

    /// @notice Returns the vault shares token decimals
    /// @return Token decimals
    function decimals() public view override returns (uint8) {
        return uint8(_getBaseModuleStorage().decimals);
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE 
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function _setPaused(bool paused_) internal {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (!$.initialized) revert NotInitialized();
        $.paused = paused_;
        emit Paused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                                MATH HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates stkToken price with safety checks
    /// @dev Standard price calculation used across settlement modules
    /// @return price Price per stkToken in underlying asset terms (18 decimals)
    function _calculateStkTokenPrice() internal view returns (uint256 price) {
        return _convertToAssets(10 ** _getBaseModuleStorage().decimals);
    }

    /// @notice Converts shares to assets
    /// @param shares Amount of shares to convert
    /// @return assets Amount of assets
    function _convertToAssets(uint256 shares) internal view returns (uint256 assets) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return shares;
        return shares.fullMulDiv(totalSupply_, _totalAssets());
    }

    /// @notice Converts assets to shares
    /// @param assets Amount of assets to convert
    /// @return shares Amount of shares
    function _convertToShares(uint256 assets) internal view returns (uint256 shares) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return assets;
        return assets.fullMulDiv(_totalAssets(), totalSupply_);
    }

    /// @notice Calculates stkTokens to mint for given kToken amount
    /// @dev Used in staking settlement operations
    /// @param kTokenAmount Amount of kTokens being staked
    /// @param stkTokenPrice Current stkToken price
    /// @return stkTokens Amount of stkTokens to mint
    function _calculateStkTokensToMint(
        uint256 kTokenAmount,
        uint256 stkTokenPrice
    )
        internal
        pure
        returns (uint256 stkTokens)
    {
        return kTokenAmount.divWad(stkTokenPrice);
    }

    /// @notice Calculates asset value for given stkToken amount
    /// @dev Used in unstaking settlement operations
    /// @param stkTokenAmount Amount of stkTokens being unstaked
    /// @param stkTokenPrice Current stkToken price
    /// @return assetValue Equivalent asset value
    function _calculateAssetValue(
        uint256 stkTokenAmount,
        uint256 stkTokenPrice
    )
        internal
        pure
        returns (uint256 assetValue)
    {
        return stkTokenAmount.mulWad(stkTokenPrice);
    }

    /// @notice Calculates share price for stkToken
    /// @return sharePrice Price per stkToken in underlying asset terms (18 decimals)
    function _sharePrice() internal view returns (uint256) {
        return _calculateStkTokenPrice();
    }

    /// @notice Returns the total assets in the vault
    /// @return totalAssets Total assets in the vault
    function _totalAssets() internal view returns (uint256) {
        return IkToken(_getBaseModuleStorage().underlyingAsset).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict function execution when contract is paused
    /// @dev Reverts with Paused() if isPaused is true
    modifier whenNotPaused() virtual {
        if (_getBaseModuleStorage().paused) revert ContractPaused();
        _;
    }

    /// @notice Restricts function access to the kAssetRouter contract
    modifier onlyKAssetRouter() {
        if (msg.sender != _getKAssetRouter()) revert OnlyKAssetRouter();
        _;
    }

    /// @notice Restricts function access to the relayer
    /// @dev Only callable internally by inheriting contracts
    modifier onlyRelayer() {
        if (!_getRelayer(msg.sender)) revert OnlyRelayer();
        _;
    }
}
