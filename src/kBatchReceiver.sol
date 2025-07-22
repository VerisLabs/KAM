// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title kBatchReceiver
/// @notice Receives assets by batch to be redeemed by kMinter users
contract kBatchReceiver {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable kMinterUSD;
    address public immutable kMinterBTC;
    address public immutable USDC;
    address public immutable WBTC;
    uint256 public immutable batchId;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event UserReceivedAssets(address indexed receiver, address indexed asset, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error OnlyKMinter();
    error InvalidBatchId();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyKMinterUSD() {
        if (msg.sender != kMinterUSD) revert OnlyKMinter();
        _;
    }

    modifier onlyKMinterBTC() {
        if (msg.sender != kMinterBTC) revert OnlyKMinter();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _kMinterUSD, address _kMinterBTC, uint256 _batchId, address _USDC, address _WBTC) {
        if (_kMinterUSD == address(0) || _kMinterBTC == address(0)) revert ZeroAddress();
        kMinterUSD = _kMinterUSD;
        kMinterBTC = _kMinterBTC;
        batchId = _batchId;
        USDC = _USDC;
        WBTC = _WBTC;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function receiveAssets(address receiver, address asset, uint256 amount, uint256 _batchId) external {
        if (_batchId != batchId) revert InvalidBatchId();
        asset.safeTransferFrom(msg.sender, receiver, amount);
        emit UserReceivedAssets(receiver, asset, amount);
    }
}
