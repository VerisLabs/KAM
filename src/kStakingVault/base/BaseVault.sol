// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC20 } from "solady/tokens/ERC20.sol";

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";

import { OptimizedReentrancyGuardTransient } from "src/abstracts/OptimizedReentrancyGuardTransient.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IVaultFees } from "src/interfaces/modules/IVaultFees.sol";
import { BaseVaultTypes } from "src/kStakingVault/types/BaseVaultTypes.sol";

/// @title BaseVault
/// @notice Base contract for all modules
/// @dev Provides shared storage, roles, and common functionality
abstract contract BaseVault is ERC20, OptimizedReentrancyGuardTransient {
    using FixedPointMathLib for uint256;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;
    using SafeTransferLib for address;

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
    event Initialized(address registry, string name, string symbol, uint8 decimals, address asset);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
    bytes32 internal constant K_MINTER = keccak256("K_MINTER");

    uint256 internal constant DECIMALS_MASK = 0xFF;
    uint256 internal constant DECIMALS_SHIFT = 0;
    uint256 internal constant HURDLE_RATE_MASK = 0xFFFF;
    uint256 internal constant HURDLE_RATE_SHIFT = 8;
    uint256 internal constant PERFORMANCE_FEE_MASK = 0xFFFF;
    uint256 internal constant PERFORMANCE_FEE_SHIFT = 24;
    uint256 internal constant MANAGEMENT_FEE_MASK = 0xFFFF;
    uint256 internal constant MANAGEMENT_FEE_SHIFT = 40;
    uint256 internal constant INITIALIZED_MASK = 0x1;
    uint256 internal constant INITIALIZED_SHIFT = 56;
    uint256 internal constant PAUSED_MASK = 0x1;
    uint256 internal constant PAUSED_SHIFT = 57;
    uint256 internal constant IS_HARD_HURDLE_RATE_MASK = 0x1;
    uint256 internal constant IS_HARD_HURDLE_RATE_SHIFT = 58;
    uint256 internal constant LAST_FEES_CHARGED_MANAGEMENT_MASK = 0xFFFFFFFFFFFFFFFF;
    uint256 internal constant LAST_FEES_CHARGED_MANAGEMENT_SHIFT = 59;
    uint256 internal constant LAST_FEES_CHARGED_PERFORMANCE_MASK = 0xFFFFFFFFFFFFFFFF;
    uint256 internal constant LAST_FEES_CHARGED_PERFORMANCE_SHIFT = 123;

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidRegistry();
    error NotInitialized();
    error ContractNotFound(bytes32 identifier);
    error ZeroAmount();
    error AmountBelowDustThreshold();
    error Closed();
    error Settled();
    error RequestNotFound();
    error RequestNotEligible();
    error InvalidVault();
    error IsPaused();
    error AlreadyInit();
    error WrongRole();
    error WrongAsset();
    error TransferFailed();
    error NotClosed();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201.kam.storage.BaseVault
    struct BaseVaultStorage {
        // 1
        uint256 config; // decimals, hurdle rate, performance fee, management fee, initialized, paused,
            // isHardHurdleRate, lastFeesChargedManagement, lastFeesChargedPerformance
        // 2
        uint128 sharePriceWatermark;
        uint128 totalPendingStake;
        // 3
        uint256 currentBatch;
        // 4
        bytes32 currentBatchId;
        // 5
        address registry;
        // 6
        address receiverImplementation;
        // 7
        address underlyingAsset;
        // 8
        address kToken;
        // 9
        string name;
        // 10
        string symbol;
        mapping(bytes32 => BaseVaultTypes.BatchInfo) batches;
        mapping(bytes32 => BaseVaultTypes.StakeRequest) stakeRequests;
        mapping(bytes32 => BaseVaultTypes.UnstakeRequest) unstakeRequests;
        mapping(address => OptimizedBytes32EnumerableSetLib.Bytes32Set) userRequests;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.BaseVault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant MODULE_BASE_STORAGE_LOCATION =
        0x50bc60b877273d55cac3903fd4818902e5fd7aa256278ee2dc6b212f256c0b00;

    /// @notice Returns the base vault storage struct using ERC-7201 pattern
    /// @return $ Storage reference for base vault state variables
    function _getBaseVaultStorage() internal pure returns (BaseVaultStorage storage $) {
        assembly {
            $.slot := MODULE_BASE_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                          CONFIG GETTERS/SETTERS
    //////////////////////////////////////////////////////////////*/

    function _getDecimals(BaseVaultStorage storage $) internal view returns (uint8) {
        return uint8(($.config >> DECIMALS_SHIFT) & DECIMALS_MASK);
    }

    function _setDecimals(BaseVaultStorage storage $, uint8 value) internal {
        $.config = ($.config & ~(DECIMALS_MASK << DECIMALS_SHIFT)) | (uint256(value) << DECIMALS_SHIFT);
    }

    function _getHurdleRate(BaseVaultStorage storage $) internal view returns (uint16) {
        return uint16(($.config >> HURDLE_RATE_SHIFT) & HURDLE_RATE_MASK);
    }

    function _setHurdleRate(BaseVaultStorage storage $, uint16 value) internal {
        $.config = ($.config & ~(HURDLE_RATE_MASK << HURDLE_RATE_SHIFT)) | (uint256(value) << HURDLE_RATE_SHIFT);
    }

    function _getPerformanceFee(BaseVaultStorage storage $) internal view returns (uint16) {
        return uint16(($.config >> PERFORMANCE_FEE_SHIFT) & PERFORMANCE_FEE_MASK);
    }

    function _setPerformanceFee(BaseVaultStorage storage $, uint16 value) internal {
        $.config =
            ($.config & ~(PERFORMANCE_FEE_MASK << PERFORMANCE_FEE_SHIFT)) | (uint256(value) << PERFORMANCE_FEE_SHIFT);
    }

    function _getManagementFee(BaseVaultStorage storage $) internal view returns (uint16) {
        return uint16(($.config >> MANAGEMENT_FEE_SHIFT) & MANAGEMENT_FEE_MASK);
    }

    function _setManagementFee(BaseVaultStorage storage $, uint16 value) internal {
        $.config =
            ($.config & ~(MANAGEMENT_FEE_MASK << MANAGEMENT_FEE_SHIFT)) | (uint256(value) << MANAGEMENT_FEE_SHIFT);
    }

    function _getInitialized(BaseVaultStorage storage $) internal view returns (bool) {
        return (($.config >> INITIALIZED_SHIFT) & INITIALIZED_MASK) != 0;
    }

    function _setInitialized(BaseVaultStorage storage $, bool value) internal {
        $.config = ($.config & ~(INITIALIZED_MASK << INITIALIZED_SHIFT)) | (uint256(value ? 1 : 0) << INITIALIZED_SHIFT);
    }

    function _getPaused(BaseVaultStorage storage $) internal view returns (bool) {
        return (($.config >> PAUSED_SHIFT) & PAUSED_MASK) != 0;
    }

    function _setPaused(BaseVaultStorage storage $, bool value) internal {
        $.config = ($.config & ~(PAUSED_MASK << PAUSED_SHIFT)) | (uint256(value ? 1 : 0) << PAUSED_SHIFT);
    }

    function _getIsHardHurdleRate(BaseVaultStorage storage $) internal view returns (bool) {
        return (($.config >> IS_HARD_HURDLE_RATE_SHIFT) & IS_HARD_HURDLE_RATE_MASK) != 0;
    }

    function _setIsHardHurdleRate(BaseVaultStorage storage $, bool value) internal {
        $.config = ($.config & ~(IS_HARD_HURDLE_RATE_MASK << IS_HARD_HURDLE_RATE_SHIFT))
            | (uint256(value ? 1 : 0) << IS_HARD_HURDLE_RATE_SHIFT);
    }

    function _getLastFeesChargedManagement(BaseVaultStorage storage $) internal view returns (uint64) {
        return uint64(($.config >> LAST_FEES_CHARGED_MANAGEMENT_SHIFT) & LAST_FEES_CHARGED_MANAGEMENT_MASK);
    }

    function _setLastFeesChargedManagement(BaseVaultStorage storage $, uint64 value) internal {
        $.config = ($.config & ~(LAST_FEES_CHARGED_MANAGEMENT_MASK << LAST_FEES_CHARGED_MANAGEMENT_SHIFT))
            | (uint256(value) << LAST_FEES_CHARGED_MANAGEMENT_SHIFT);
    }

    function _getLastFeesChargedPerformance(BaseVaultStorage storage $) internal view returns (uint64) {
        return uint64(($.config >> LAST_FEES_CHARGED_PERFORMANCE_SHIFT) & LAST_FEES_CHARGED_PERFORMANCE_MASK);
    }

    function _setLastFeesChargedPerformance(BaseVaultStorage storage $, uint64 value) internal {
        $.config = ($.config & ~(LAST_FEES_CHARGED_PERFORMANCE_MASK << LAST_FEES_CHARGED_PERFORMANCE_SHIFT))
            | (uint256(value) << LAST_FEES_CHARGED_PERFORMANCE_SHIFT);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the base contract with registry and pause state
    /// @param registry_ Address of the kRegistry contract
    /// @param paused_ Initial pause state
    /// @dev Can only be called once during initialization
    function __BaseVault_init(address registry_, bool paused_) internal {
        BaseVaultStorage storage $ = _getBaseVaultStorage();

        if (_getInitialized($)) revert AlreadyInit();
        if (registry_ == address(0)) revert InvalidRegistry();

        $.registry = registry_;
        _setPaused($, paused_);
        _setInitialized($, true);
        _setLastFeesChargedManagement($, uint64(block.timestamp));
        _setLastFeesChargedPerformance($, uint64(block.timestamp));
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY GETTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the registry contract interface
    /// @return IkRegistry interface for registry interaction
    /// @dev Internal helper for typed registry access
    function _registry() internal view returns (IkRegistry) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (!_getInitialized($)) revert NotInitialized();
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

    /// @notice Returns the vault shares token name
    /// @return Token name
    function name() public view override returns (string memory) {
        return _getBaseVaultStorage().name;
    }

    /// @notice Returns the vault shares token symbol
    /// @return Token symbol
    function symbol() public view override returns (string memory) {
        return _getBaseVaultStorage().symbol;
    }

    /// @return Token decimals
    function decimals() public view override returns (uint8) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _getDecimals($);
    }

    /*//////////////////////////////////////////////////////////////
                            PAUSE 
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function _setPaused(bool paused_) internal {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (!_getInitialized($)) revert NotInitialized();
        _setPaused($, paused_);
        emit Paused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                                MATH HELPERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Converts shares to assets
    /// @param shares Amount of shares to convert
    /// @return assets Amount of assets
    function _convertToAssets(uint256 shares) internal view returns (uint256 assets) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return shares;
        return shares.fullMulDiv(_totalNetAssets(), totalSupply_);
    }

    /// @notice Converts assets to shares
    /// @param assets Amount of assets to convert
    /// @return shares Amount of shares
    function _convertToShares(uint256 assets) internal view returns (uint256 shares) {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return assets;
        return assets.fullMulDiv(totalSupply_, _totalNetAssets());
    }

    /// @notice Calculates share price for stkToken
    /// @return sharePrice Price per stkToken in underlying asset terms (18 decimals)
    function _netSharePrice() internal view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _convertToAssets(10 ** _getDecimals($));
    }

    function _sharePrice() internal view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        uint256 shares = 10 ** _getDecimals($);
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) return shares;
        return shares.fullMulDiv(_totalAssets(), totalSupply_);
    }

    /// @notice Returns the total assets in the vault
    /// @return totalAssets Total assets in the vault
    function _totalAssets() internal view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return $.kToken.balanceOf(address(this)) - $.totalPendingStake;
    }

    /// @notice Returns the total net assets in the vault
    /// @return totalNetAssets Total net assets in the vault
    function _totalNetAssets() internal view returns (uint256) {
        return _totalAssets() - _accumulatedFees();
    }

    /// @notice Calculates accumulated fees
    /// @return accumulatedFees Accumulated fees
    function _accumulatedFees() internal view returns (uint256) {
        (,, uint256 totalFees) = IVaultFees(address(this)).computeLastBatchFees();
        return totalFees;
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

    /// @notice Checks if an address is a relayer
    /// @return Whether the address is a relayer
    function _isRelayer(address user) internal view returns (bool) {
        return _registry().isRelayer(user);
    }

    /// @notice Checks if an address is a institution
    /// @return Whether the address is a institution
    function _isPaused() internal view returns (bool) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (!_getInitialized($)) revert NotInitialized();
        return _getPaused($);
    }

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _isKAssetRouter(address kAssetRouter_) internal view returns (bool) {
        bool isTrue;
        address _kAssetRouter = _registry().getContractById(K_ASSET_ROUTER);
        if (_kAssetRouter == kAssetRouter_) isTrue = true;
        return isTrue;
    }

    /// @notice Checks if an asset is registered
    /// @param asset The asset address to check
    /// @return Whether the asset is registered
    function _isAsset(address asset) internal view returns (bool) {
        return _registry().isAsset(asset);
    }
}
