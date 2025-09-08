// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";

import {
    KBATCHRECEIVER_ALREADY_INITIALIZED,
    KBATCHRECEIVER_INVALID_BATCH_ID,
    KBATCHRECEIVER_ONLY_KMINTER,
    KBATCHRECEIVER_TRANSFER_FAILED,
    KBATCHRECEIVER_WRONG_ASSET,
    KBATCHRECEIVER_ZERO_ADDRESS,
    KBATCHRECEIVER_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IkBatchReceiver } from "src/interfaces/IkBatchReceiver.sol";

/// @title kBatchReceiver
/// @notice Minimal proxy contract implementation for isolated batch asset distribution in the KAM protocol
/// @dev This contract implements the minimal proxy pattern where each batch redemption gets its own dedicated
/// receiver instance for secure and efficient asset distribution. The implementation provides several key features:
/// (1) Minimal Proxy Pattern: Uses EIP-1167 minimal proxy deployment to reduce gas costs per batch while maintaining
/// full isolation between different settlement periods, (2) Batch Isolation: Each receiver handles exactly one batch,
/// preventing cross-contamination and simplifying accounting, (3) Access Control: Only the originating kMinter can
/// interact with receivers, ensuring strict security throughout the distribution process, (4) Asset Distribution:
/// Manages the final step of redemption where settled assets flow from kMinter to individual users, (5) Emergency
/// Recovery: Provides safety mechanisms for accidentally sent tokens while protecting settlement assets.
///
/// Technical Implementation Notes:
/// - Uses immutable kMinter reference set at construction for gas efficiency
/// - Implements strict batch ID validation to prevent operational errors
/// - Supports both ERC20 and native ETH rescue operations
/// - Emits comprehensive events for off-chain tracking and reconciliation
contract kBatchReceiver is IkBatchReceiver {
    using SafeTransferLib for address;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the kMinter contract authorized to interact with this receiver
    /// @dev Immutable reference set at construction time for gas efficiency and security. This address
    /// has exclusive permission to call pullAssets() and rescueAssets(), ensuring only the originating
    /// kMinter can manage asset distribution for this specific batch. The immutable nature prevents
    /// modification and reduces gas costs for access control checks.
    address public immutable kMinter;

    /// @notice Address of the underlying asset contract this receiver will distribute
    /// @dev Set during initialization to specify which token type (USDC, WBTC, etc.) this receiver
    /// manages. Must match the asset type that was originally deposited and requested for redemption
    /// in the associated batch. Used for asset transfer operations and rescue validation.
    address public asset;

    /// @notice Unique batch identifier linking this receiver to a specific redemption batch
    /// @dev Set during initialization to establish the connection between this receiver and the batch
    /// of redemption requests it serves. Used for validation in pullAssets() to ensure operations
    /// are performed on the correct batch, preventing cross-contamination between settlement periods.
    bytes32 public batchId;

    /// @notice Initialization state flag preventing duplicate configuration
    /// @dev Boolean flag that prevents re-initialization after the receiver has been configured.
    /// Set to true during the initialize() call to ensure batch parameters can only be set once,
    /// maintaining the integrity of the receiver's purpose and preventing operational errors.
    bool public isInitialised;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys a new kBatchReceiver with immutable kMinter authorization
    /// @dev Constructor for minimal proxy implementation that establishes the sole authorized caller.
    /// The kMinter address is set as immutable during deployment to ensure gas efficiency and prevent
    /// unauthorized modifications. This constructor is called once per batch receiver deployment,
    /// establishing the security foundation for all subsequent operations. The address validation
    /// ensures no receiver can be deployed with invalid authorization.
    /// @param _kMinter Address of the kMinter contract that will have exclusive interaction rights
    constructor(address _kMinter) {
        _checkAddressNotZero(_kMinter);
        kMinter = _kMinter;
    }

    /// @notice Configures the receiver with batch-specific parameters after deployment
    /// @dev Post-deployment initialization that links this receiver to a specific batch and asset type.
    /// This two-step deployment pattern (constructor + initialize) enables efficient minimal proxy usage
    /// where the implementation is deployed once and initialization customizes each instance. The function:
    /// (1) prevents duplicate initialization with isInitialised flag, (2) validates asset address,
    /// (3) stores batch parameters for operational use, (4) emits initialization event for tracking.
    /// Only callable once per receiver instance to maintain batch isolation integrity.
    /// @param _batchId The unique batch identifier this receiver will serve
    /// @param _asset Address of the underlying asset contract (USDC, WBTC, etc.) to distribute
    function initialize(bytes32 _batchId, address _asset) external {
        require(!isInitialised, KBATCHRECEIVER_ALREADY_INITIALIZED);
        _checkAddressNotZero(_asset);

        isInitialised = true;
        batchId = _batchId;
        asset = _asset;

        emit BatchReceiverInitialized(kMinter, batchId, asset);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkBatchReceiver
    function pullAssets(address receiver, uint256 amount, bytes32 _batchId) external {
        _checkMinter(msg.sender);
        require(_batchId == batchId, KBATCHRECEIVER_INVALID_BATCH_ID);
        _checkAmountNotZero(amount);
        _checkAddressNotZero(receiver);

        asset.safeTransfer(receiver, amount);
        emit PulledAssets(receiver, asset, amount);
    }

    /// @inheritdoc IkBatchReceiver
    function rescueAssets(address asset_) external payable {
        address sender = msg.sender;
        _checkMinter(sender);

        if (asset_ == address(0)) {
            // Rescue ETH
            uint256 balance = address(this).balance;
            _checkAmountNotZero(balance);

            (bool success,) = sender.call{ value: balance }("");
            require(success, KBATCHRECEIVER_TRANSFER_FAILED);

            emit RescuedETH(sender, balance);
        } else {
            // Rescue ERC20 tokens
            require(asset_ != asset, KBATCHRECEIVER_WRONG_ASSET);

            uint256 balance = asset_.balanceOf(address(this));
            _checkAmountNotZero(balance);

            asset_.safeTransfer(sender, balance);
            emit RescuedAssets(asset_, sender, balance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Only callable by kMinter
    function _checkMinter(address minter) private view {
        require(minter == kMinter, KBATCHRECEIVER_ONLY_KMINTER);
    }

    /// @dev Checks address is not zero
    function _checkAddressNotZero(address address_) private pure {
        require(address_ != address(0), KBATCHRECEIVER_ZERO_ADDRESS);
    }

    /// @dev Checks amount is not zero
    function _checkAmountNotZero(uint256 amount) private pure {
        require(amount != 0, KBATCHRECEIVER_ZERO_AMOUNT);
    }
}
