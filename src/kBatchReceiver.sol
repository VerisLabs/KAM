// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.30;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @title kBatchReceiver
/// @notice Minimal receiver contract for batch redemptions
/// @dev Deployed as minimal proxy clones for each redemption batch
contract kBatchReceiver {
    using SafeTransferLib for address;

    address private immutable _IMPLEMENTATION;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public kMinter;
    address public asset;
    uint256 public batchId;
    uint256 public totalReceived;
    bool public initialized;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address indexed kMinter, address indexed asset, uint256 indexed batchId);
    event AssetsReceived(uint256 indexed amount);
    event WithdrawnForRedemption(address indexed recipient, uint256 indexed amount);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed caller);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyKMinter();
    error OnlyAuthorized();
    error AlreadyInitialized();
    error NotInitialized();
    error InvalidAddress();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets implementation address for proxy detection
    constructor() {
        _IMPLEMENTATION = address(this);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the batch receiver proxy
    /// @param _kMinter kMinter address
    /// @param _asset Asset address
    /// @param _batchId Batch ID
    function initialize(address _kMinter, address _asset, uint256 _batchId) external {
        if (initialized) revert AlreadyInitialized();
        if (_kMinter == address(0)) revert InvalidAddress();
        if (_asset == address(0)) revert InvalidAddress();

        kMinter = _kMinter;
        asset = _asset;
        batchId = _batchId;
        initialized = true;

        emit Initialized(kMinter, asset, batchId);
    }

    /// @notice Receives assets from kDNStaking
    /// @param amount Amount of assets to receive
    function receiveAssets(uint256 amount) external {
        if (!initialized) revert NotInitialized();
        if (msg.sender != kMinter && msg.sender != address(this)) revert OnlyAuthorized();
        asset.safeTransferFrom(msg.sender, address(this), amount);
        unchecked {
            totalReceived += amount;
        }

        emit AssetsReceived(amount);
    }

    /// @notice Withdraws assets for redemption
    /// @param recipient Recipient address
    /// @param amount Amount to withdraw
    function withdrawForRedemption(address recipient, uint256 amount) external {
        if (!initialized) revert NotInitialized();
        if (msg.sender != kMinter) revert OnlyKMinter();
        asset.safeTransfer(recipient, amount);

        emit WithdrawnForRedemption(recipient, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency withdrawal of tokens sent by mistake
    /// @dev Can only be called by kMinter (which should have proper authorization)
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external {
        if (!initialized) revert NotInitialized();
        if (msg.sender != kMinter) revert OnlyKMinter();
        if (to == address(0)) revert InvalidAddress();

        if (token == address(0)) {
            // Withdraw ETH
            to.safeTransferETH(amount);
        } else {
            // Withdraw ERC20 token
            token.safeTransfer(to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    function contractName() external pure returns (string memory) {
        return "kBatchReceiver";
    }

    /// @notice Returns the contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
