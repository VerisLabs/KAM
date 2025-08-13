// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { ERC7540 } from "../vendor/ERC7540.sol";
import { FixedPointMathLib as Math } from "solady/utils/FixedPointMathLib.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";


/// @title MockMetaVault Contract for MetaVault Modules
/// @author Unlockd
/// @notice Base storage contract containing all shared state variables and helper functions for MetaVault modules
/// @dev Implements role-based access control and core vault functionality
contract MockMetaVault is ERC7540, OwnableRoles {

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           CONSTANTS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Maximum size of the withdrawal queue
    uint256 public constant WITHDRAWAL_QUEUE_SIZE = 30;

    /// @notice Number of seconds in a year, used for APY calculations
    uint256 public constant SECS_PER_YEAR = 31_556_952;

    /// @notice Maximum basis points (100%)
    uint256 public constant MAX_BPS = 10_000;

    /// @notice Role identifier for admin privileges
    uint256 public constant ADMIN_ROLE = _ROLE_0;

    /// @notice Role identifier for emergency admin privileges
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;

    /// @notice Role identifier for oracle privileges
    uint256 public constant ORACLE_ROLE = _ROLE_2;

    /// @notice Role identifier for manager privileges
    uint256 public constant MANAGER_ROLE = _ROLE_3;

    /// @notice Role identifier for relayer privileges
    uint256 public constant RELAYER_ROLE = _ROLE_4;

    /// @notice Chain ID of the current network
    uint64 public THIS_CHAIN_ID;

    /// @notice Number of supported chains
    uint256 public constant N_CHAINS = 7;

    /// @dev Maximum fee that can be set (100% = 10000 basis points)
    uint16 constant MAX_FEE = 10_000;

    /// @dev Maximum time that can be set (48 hours)
    uint256 public MAX_TIME = 172_800;

    /// @notice Nonce slot seed
    uint256 internal constant _NONCES_SLOT_SEED = 0x38377508;

    /// @notice mapping from address to the average share price of their deposits
    mapping(address => uint256 averageEntryPrice) public positions;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           STORAGE                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Asset decimals
    uint8 _decimals;
    /// @notice Underlying asset
    address internal _asset;
    /// @notice ERC20 name
    string internal _name;
    /// @notice ERC20 symbol
    string internal _symbol;


    constructor(address asset_, string memory name_, string memory symbol_) {
        _asset = asset_;
        _name = name_;
        _symbol = symbol_;
        // Try to get asset decimals, fallback to default if unsuccessful
        (bool success, uint8 result) = _tryGetAssetDecimals(asset_);
        _decimals = success ? result : _DEFAULT_UNDERLYING_DECIMALS;
        _initializeOwner(msg.sender);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       HELPR FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Private helper to substract a - b or return 0 if it underflows
    function _sub0(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return a - b > a ? 0 : a - b;
        }
    }


    /// @dev Private helper to return `x + 1` without the overflow check.
    /// Used for computing the denominator input to `FixedPointMathLib.fullMulDiv(a, b, x + 1)`.
    /// When `x == type(uint).max`, we get `x + 1 == 0` (mod 2**256 - 1),
    /// and `FixedPointMathLib.fullMulDiv` will revert as the denominator is zero.
    function _inc_(uint256 x) internal pure returns (uint256) {
        unchecked {
            return x + 1;
        }
    }

    /// @dev Private helper to return if either value is zero.
    function _eitherIsZero_(uint256 a, uint256 b) internal pure returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := or(iszero(a), iszero(b))
        }
    }

    /// @notice the number of decimals of the underlying token
    function _underlyingDecimals() internal view override returns (uint8) {
        return _decimals;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONTEXT GETTERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function name() public view override returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token.
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the estimate price of 1 vault share
    function sharePrice() public view returns (uint256) {
        return convertToAssets(10 ** decimals());
    }

    /// @notice Returns the address of the underlying asset.
    function asset() public view override returns (address) {
        return _asset;
    }
}