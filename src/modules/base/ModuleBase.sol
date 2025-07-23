// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { ReentrancyGuardTransient } from "solady/utils/ReentrancyGuardTransient.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { ModuleBaseTypes } from "src/types/ModuleBaseTypes.sol";

/// @title ModuleBase
/// @notice Base contract for all modules
/// @dev Provides shared storage, roles, and common functionality
abstract contract ModuleBase is OwnableRoles, ReentrancyGuardTransient {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

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

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant MINTER_ROLE = _ROLE_2;
    uint256 public constant SETTLER_ROLE = _ROLE_3;
    uint256 public constant VAULT_ROLE = _ROLE_4;
    uint256 public constant ASSET_ROUTER_ROLE = _ROLE_5;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant PRECISION = 1e18;
    uint256 public constant ONE_HUNDRED_PERCENT = 10_000;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:BaseVault.storage.BaseVault
    struct BaseVaultStorage {
        bool isPaused;
        uint256 requestCounter;
        uint256 lastTotalAssets;
        uint256 userTotalSupply;
        uint128 dustAmount;
        uint64 settlementInterval;
        uint8 decimals;
        address kMinter;
        address kAssetRouter;
        address kBatch;
        address kToken;
        address underlyingAsset;
        address strategyManager;
        address varianceRecipient;
        address kReceiver;
        mapping(address => uint256) userShareBalances;
        mapping(uint256 => ModuleBaseTypes.StakeRequest) stakeRequests;
        mapping(uint256 => ModuleBaseTypes.UnstakeRequest) unstakeRequests;
        mapping(address => uint256[]) userRequests;
    }

    bytes32 internal constant BASE_VAULT_STORAGE_LOCATION =
        0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00;

    /// @notice Returns the base vault storage struct using ERC-7201 pattern
    /// @return $ Storage reference for base vault state variables
    function _getBaseVaultStorage() internal pure returns (BaseVaultStorage storage $) {
        assembly {
            $.slot := BASE_VAULT_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error AmountBelowDustThreshold();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict function execution when contract is paused
    /// @dev Reverts with Paused() if isPaused is true
    modifier whenNotPaused() virtual {
        if (_getBaseVaultStorage().isPaused) revert Paused();
        _;
    }

    /// @notice Checks if an asset is registered
    /// @param asset Asset address
    /// @return True if asset is registered
    function _isRegisteredAsset(address asset) internal view returns (bool) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return IkAssetRouter($.kAssetRouter).isRegisteredAsset(asset);
    }

    /*//////////////////////////////////////////////////////////////
                      MATHEMATICAL HELPERS
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
}
