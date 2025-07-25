// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";

import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { ModuleBaseTypes } from "src/kStakingVault/types/ModuleBaseTypes.sol";

/// @title BaseModule
/// @notice Base contract for all modules
/// @dev Provides shared storage, roles, and common functionality
abstract contract BaseModule is OwnableRoles, ReentrancyGuardTransient {
    using FixedPointMathLib for uint256;

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
        uint256 batchId
    );
    event StakeRequestRedeemed(bytes32 indexed requestId);
    event StakeRequestCancelled(bytes32 indexed requestId);
    event UnstakeRequestCreated(
        bytes32 indexed requestId, address indexed user, uint256 amount, address recipient, uint256 batchId
    );
    event Paused(bool paused);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant PRECISION = 1e18;
    uint256 public constant ONE_HUNDRED_PERCENT = 10_000;

    bytes32 internal constant K_ASSET_ROUTER = keccak256("K_ASSET_ROUTER");
    bytes32 internal constant K_BATCH = keccak256("K_BATCH");
    bytes32 internal constant K_MINTER = keccak256("K_MINTER");

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error InvalidRegistry();
    error NotInitialized();
    error ContractNotFound(bytes32 identifier);
    error AssetNotSupported(address asset);
    error InvalidVault(address vault);
    error OnlyKAssetRouter();
    error OnlyKBatch();
    error ZeroAmount();
    error AmountBelowDustThreshold();
    error ContractPaused();

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201.kam.storage.BaseModule
    struct BaseModuleStorage {
        bool initialized;
        bool paused;
        uint256 requestCounter;
        uint256 lastTotalAssets;
        uint128 dustAmount;
        uint8 decimals;
        address underlyingAsset;
        address registry;
        string name;
        string symbol;
        mapping(uint256 => ModuleBaseTypes.StakeRequest) stakeRequests;
        mapping(uint256 => ModuleBaseTypes.UnstakeRequest) unstakeRequests;
        mapping(address => uint256[]) userRequests;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.BaseModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant MODULE_BASE_STORAGE_LOCATION =
        0x7ab139db2b2a77f463059682bb9762784f22bc1cb9ca9b84dadf2770b5cfb600;

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
    function __ModuleBase_init(address registry_, address owner_, address admin_, bool paused_) internal {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        if ($.initialized) revert AlreadyInitialized();
        if (registry_ == address(0)) revert InvalidRegistry();

        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();

        $.registry = registry_;
        $.paused = paused_;
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
    function registry() public view returns (address) {
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
                          SINGLETON GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the kMinter singleton contract address
    /// @return minter The kMinter contract address
    /// @dev Reverts if kMinter not set in registry
    function _getKMinter() internal view returns (address minter) {
        minter = _registry().getSingletonContract(K_MINTER);
        if (minter == address(0)) revert ContractNotFound(K_MINTER);
    }

    /// @notice Gets the kBatch singleton contract address
    /// @return batch The kBatch contract address
    /// @dev Reverts if kBatch not set in registry
    function _getKBatch() internal view returns (address batch) {
        batch = _registry().getSingletonContract(K_BATCH);
        if (batch == address(0)) revert ContractNotFound(K_BATCH);
    }

    /// @notice Gets the kAssetRouter singleton contract address
    /// @return router The kAssetRouter contract address
    /// @dev Reverts if kAssetRouter not set in registry
    function _getKAssetRouter() internal view returns (address router) {
        router = _registry().getSingletonContract(K_ASSET_ROUTER);
        if (router == address(0)) revert ContractNotFound(K_ASSET_ROUTER);
    }

    /*//////////////////////////////////////////////////////////////
                          ASSET HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the kToken address for a given asset
    /// @param asset The underlying asset address
    /// @return kToken The corresponding kToken address
    /// @dev Reverts if asset not supported
    function _getKTokenForAsset(address asset) internal view returns (address kToken) {
        kToken = _registry().assetToKToken(asset);
        if (kToken == address(0)) revert AssetNotSupported(asset);
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
    /// @param totalAssets Total underlying assets backing stkTokens
    /// @param totalSupply Total stkToken supply
    /// @return price Price per stkToken in underlying asset terms (18 decimals)
    function _calculateStkTokenPrice(uint256 totalAssets, uint256 totalSupply) internal pure returns (uint256 price) {
        return totalSupply == 0 ? PRECISION : totalAssets.divWad(totalSupply);
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

    /// @notice Restricts function access to the kBatch contract
    modifier onlyKBatch() {
        if (msg.sender != _getKBatch()) revert OnlyKBatch();
        _;
    }
}
