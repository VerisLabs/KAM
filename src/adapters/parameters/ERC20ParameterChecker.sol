// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC20 } from "solady/tokens/ERC20.sol";
import { PARAMETERCHECKER_NOT_ALLOWED } from "src/errors/Errors.sol";
import { IRegistry } from "src/interfaces/IRegistry.sol";
import { IParametersChecker } from "src/interfaces/modules/IAdapterGuardian.sol";

/// @title ERC20ParameterChecker
/// @notice A contract that checks parameters for ERC20 token operations
/// @dev Implements IParametersChecker to authorize adapter calls for ERC20 tokens
contract ERC20ParameterChecker is IParametersChecker {
    /// @notice The registry contract reference
    IRegistry public immutable registry;

    /// @notice Mapping of allowed receivers for each token
    mapping(address token => mapping(address receiver => bool)) private _allowedReceivers;

    /// @notice Mapping of allowed sources for each token
    mapping(address token => mapping(address source => bool)) private _allowedSources;

    /// @notice Mapping of allowed spenders for each token
    mapping(address token => mapping(address spender => bool)) private _allowedSpenders;

    /// @notice Maximum amount allowed for a single transfer per token
    mapping(address token => uint256 maxSingleTransfer) private _maxSingleTransfer;

    /// @notice Emitted when a receiver's allowance status is updated
    /// @param token The token address
    /// @param receiver The receiver address
    /// @param allowed Whether the receiver is allowed
    event ReceiverStatusUpdated(address indexed token, address indexed receiver, bool allowed);

    /// @notice Emitted when a source's allowance status is updated
    /// @param token The token address
    /// @param source The source address
    /// @param allowed Whether the source is allowed
    event SourceStatusUpdated(address indexed token, address indexed source, bool allowed);

    /// @notice Emitted when a spender's allowance status is updated
    /// @param token The token address
    /// @param spender The spender address
    /// @param allowed Whether the spender is allowed
    event SpenderStatusUpdated(address indexed token, address indexed spender, bool allowed);

    /// @notice Emitted when the max single transfer amount is updated
    /// @param token The token address
    /// @param maxAmount The maximum amount allowed
    event MaxSingleTransferUpdated(address indexed token, uint256 maxAmount);

    /// @notice Constructs the ERC20ParameterChecker
    /// @param _registry The address of the registry contract
    constructor(address _registry) {
        registry = IRegistry(_registry);
    }

    /// @notice Sets whether a receiver is allowed for a specific token
    /// @param token The token address
    /// @param receiver The receiver address
    /// @param allowed Whether the receiver is allowed
    function setAllowedReceiver(address token, address receiver, bool allowed) external {
        _checkAdmin(msg.sender);
        _allowedReceivers[token][receiver] = allowed;
        emit ReceiverStatusUpdated(token, receiver, allowed);
    }

    /// @notice Sets whether a source is allowed for a specific token
    /// @param token The token address
    /// @param source The source address
    /// @param allowed Whether the source is allowed
    function setAllowedSource(address token, address source, bool allowed) external {
        _checkAdmin(msg.sender);
        _allowedSources[token][source] = allowed;
        emit SourceStatusUpdated(token, source, allowed);
    }

    /// @notice Sets whether a spender is allowed for a specific token
    /// @param token The token address
    /// @param spender The spender address
    /// @param allowed Whether the spender is allowed
    function setAllowedSpender(address token, address spender, bool allowed) external {
        _checkAdmin(msg.sender);
        _allowedSpenders[token][spender] = allowed;
        emit SpenderStatusUpdated(token, spender, allowed);
    }

    /// @notice Sets the maximum amount allowed for a single transfer
    /// @param token The token address
    /// @param max The maximum amount
    function setMaxSingleTransfer(address token, uint256 max) external {
        _checkAdmin(msg.sender);
        _maxSingleTransfer[token] = max;
        emit MaxSingleTransferUpdated(token, max);
    }

    /// @notice Authorizes an adapter call based on parameters
    /// @param adapter The adapter address
    /// @param token The token address
    /// @param selector The function selector
    /// @param params The encoded function parameters
    /// @return Whether the call is authorized
    function authorizeAdapterCall(
        address adapter,
        address token,
        bytes4 selector,
        bytes calldata params
    )
        external
        view
        returns (bool)
    {
        if (!registry.isAsset(token)) return false;

        if (selector == ERC20.transfer.selector) {
            (address to, uint256 amount) = abi.decode(params, (address, uint256));
            if (amount > maxSingleTransfer(token)) return false;
            if (!isAllowedReceiver(token, to)) return false;
            return true;
        } else if (selector == ERC20.transferFrom.selector) {
            (address from, address to, uint256 amount) = abi.decode(params, (address, address, uint256));
            if (amount > maxSingleTransfer(token)) return false;
            if (!isAllowedReceiver(token, to)) return false;
            if (!isAllowedSource(token, from)) return false;
            return true;
        } else if (selector == ERC20.approve.selector) {
            (address spender,) = abi.decode(params, (address, uint256));
            if (!isAllowedSpender(token, spender)) return false;
            return true;
        } else {
            return false;
        }
    }

    /// @notice Checks if a receiver is allowed for a specific token
    /// @param token The token address
    /// @param receiver The receiver address
    /// @return Whether the receiver is allowed
    function isAllowedReceiver(address token, address receiver) public view returns (bool) {
        return _allowedReceivers[token][receiver];
    }

    /// @notice Checks if a source is allowed for a specific token
    /// @param token The token address
    /// @param source The source address
    /// @return Whether the source is allowed
    function isAllowedSource(address token, address source) public view returns (bool) {
        return _allowedSources[token][source];
    }

    /// @notice Checks if a spender is allowed for a specific token
    /// @param token The token address
    /// @param spender The spender address
    /// @return Whether the spender is allowed
    function isAllowedSpender(address token, address spender) public view returns (bool) {
        return _allowedSpenders[token][spender];
    }

    /// @notice Gets the maximum amount allowed for a single transfer
    /// @param token The token address
    /// @return The maximum amount
    function maxSingleTransfer(address token) public view returns (uint256) {
        return _maxSingleTransfer[token];
    }

    /// @notice Checks if the caller is an admin
    /// @param admin The address to check
    /// @dev Reverts if the address is not an admin
    function _checkAdmin(address admin) private view {
        require(registry.isAdmin(admin), PARAMETERCHECKER_NOT_ALLOWED);
    }
}
