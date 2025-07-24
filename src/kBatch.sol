// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { EnumerableSetLib } from "solady/utils/EnumerableSetLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { kBase } from "src/base/kBase.sol";
import { kBatchReceiver } from "src/kBatchReceiver.sol";
import { kBatchTypes } from "src/types/kBatchTypes.sol";

/// @title kBatch
/// @notice Manages time-based batch processing for the KAM protocol
/// @dev Handles batch creation, settlement, and receiver deployment for efficient asset processing
contract kBatch is Initializable, UUPSUpgradeable, kBase {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kBatch
    struct kBatchStorage {
        uint256 currentBatchId;
        uint256 requestCounter;
        mapping(uint256 => kBatchTypes.BatchInfo) batches;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kBatch")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant kBATCH_STORAGE_LOCATION =
        0x927302f3b232a88db1c43475f2c58bc64b14d8218127eff98b943b1494942100;

    /// @notice Returns the storage pointer for the kBatch contract
    /// @return $ The storage pointer
    function _getkBatchStorage() private pure returns (kBatchStorage storage $) {
        assembly {
            $.slot := kBATCH_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address registry, address owner, address admin, bool paused);
    event BatchCreated(uint256 indexed batchId);
    event BatchReceiverDeployed(uint256 indexed batchId, address indexed receiver);
    event BatchSettled(uint256 indexed batchId);
    event BatchClosed(uint256 indexed batchId);
    event VaultPushed(address indexed vault, address indexed asset, uint256 indexed batchId);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Closed();
    error Settled();
    error OnlyContracts();
    error VaultAlreadyPushed();
    error AssetAlreadyPushed();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyContracts() {
        if (!_isSingletonContract(msg.sender) && !_isVault(msg.sender)) revert OnlyContracts();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kBatch contract
    /// @param registry_ Address of the kRegistry contract
    /// @param owner_ Contract owner address
    /// @param admin_ Admin role recipient
    /// @param paused_ Initial pause state
    /// @dev Creates the first batch upon initialization
    function initialize(address registry_, address owner_, address admin_, bool paused_) external initializer {
        __kBase_init(registry_, owner_, admin_, paused_);

        _newBatch();

        emit Initialized(registry_, owner_, admin_, paused_);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch for processing requests
    /// @return The new batch ID
    /// @dev Only callable by RELAYER_ROLE, typically called at batch intervals
    function createNewBatch() external onlyRelayer returns (uint256) {
        return _newBatch();
    }

    /// @notice Closes a batch to prevent new requests
    /// @param _batchId The batch ID to close
    /// @dev Only callable by RELAYER_ROLE, typically called at cutoff time
    function closeBatch(uint256 _batchId) external onlyRelayer {
        kBatchStorage storage $ = _getkBatchStorage();
        if ($.batches[_batchId].isClosed) revert Closed();
        $.batches[_batchId].isClosed = true;

        emit BatchClosed(_batchId);
    }

    /// @notice Marks a batch as settled
    /// @param _batchId The batch ID to settle
    /// @dev Only callable by kMinter, indicates assets have been distributed
    function settleBatch(uint256 _batchId) external onlyKMinter {
        kBatchStorage storage $ = _getkBatchStorage();
        if ($.batches[_batchId].isSettled) revert Settled();
        $.batches[_batchId].isSettled = true;

        emit BatchSettled(_batchId);
    }

    /// @notice Deploys BatchReceiver for specific batch
    /// @param _batchId Batch ID to deploy receiver for
    /// @dev Only callable by kMinter
    function deployBatchReceiver(uint256 _batchId) external onlyKMinter returns (address) {
        kBatchStorage storage $ = _getkBatchStorage();

        address receiver = $.batches[_batchId].batchReceiver;
        if (receiver != address(0)) return receiver;

        receiver = address(
            new kBatchReceiver(
                _registry().getSingletonContract(K_MINTER),
                _batchId,
                _registry().getSingletonAsset("USDC"),
                _registry().getSingletonAsset("WBTC")
            )
        );

        $.batches[_batchId].batchReceiver = receiver;

        emit BatchReceiverDeployed(_batchId, receiver);

        return receiver;
    }

    /// @notice Pushes a vault to a batch
    /// @param _batchId The batch ID to push the vault to
    /// @dev Only callable by contracts or vaults
    function pushVault(uint256 _batchId) external onlyContracts {
        kBatchStorage storage $ = _getkBatchStorage();
        if ($.batches[_batchId].vaults.contains(msg.sender)) revert VaultAlreadyPushed();
        $.batches[_batchId].vaults.add(msg.sender);
        address _asset = _getVaultAsset(msg.sender);
        if ($.batches[_batchId].assets.contains(_asset)) revert AssetAlreadyPushed();
        $.batches[_batchId].assets.add(_asset);

        emit VaultPushed(msg.sender, _asset, _batchId);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new batch
    /// @return The new batch ID
    /// @dev Creates a new batch and returns its ID
    function _newBatch() internal returns (uint256) {
        kBatchStorage storage $ = _getkBatchStorage();
        uint256 newBatchId = ++$.currentBatchId;

        kBatchTypes.BatchInfo storage batch = $.batches[newBatchId];
        batch.batchId = newBatchId;
        batch.batchReceiver = address(0);
        batch.isClosed = false;
        batch.isSettled = false;

        emit BatchCreated(newBatchId);

        return newBatchId;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the current active batch ID
    /// @return The current batch ID accepting new requests
    function getCurrentBatchId() external view returns (uint256) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.currentBatchId;
    }

    /// @notice Checks if a batch has been closed
    /// @param _batchId The batch ID to check
    /// @return Whether the batch is closed to new requests
    function isBatchClosed(uint256 _batchId) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].isClosed;
    }

    /// @notice Checks if a batch has been settled
    /// @param _batchId The batch ID to check
    /// @return Whether the batch is settled
    function isBatchSettled(uint256 _batchId) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].isSettled;
    }

    /// @notice Gets comprehensive information about a batch
    /// @param _batchId The batch ID to query
    /// @return batchId The batch identifier
    /// @return batchReceiver The deployed receiver contract address (if any)
    /// @return isClosed Whether the batch is closed to new requests
    /// @return isSettled Whether the batch has been settled
    /// @return vaults The vaults in the batch
    function getBatchInfo(uint256 _batchId)
        external
        view
        returns (uint256 batchId, address batchReceiver, bool isClosed, bool isSettled, address[] memory vaults)
    {
        kBatchStorage storage $ = _getkBatchStorage();
        return (
            $.batches[_batchId].batchId,
            $.batches[_batchId].batchReceiver,
            $.batches[_batchId].isClosed,
            $.batches[_batchId].isSettled,
            $.batches[_batchId].vaults.values()
        );
    }

    /// @notice Gets the batch receiver contract address for a batch
    /// @param _batchId The batch ID to query
    /// @return The batch receiver contract address (zero if not deployed)
    function getBatchReceiver(uint256 _batchId) external view returns (address) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].batchReceiver;
    }

    /// @notice Gets the vaults in a batch
    /// @param _batchId The batch ID to query
    /// @return The vaults in the batch
    function getBatchVaults(uint256 _batchId) external view returns (address[] memory) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].vaults.values();
    }

    /// @notice Checks if a vault is in a batch
    /// @param _batchId The batch ID to check
    /// @param _vault The vault to check
    /// @return Whether the vault is in the batch
    function isVaultInBatch(uint256 _batchId, address _vault) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].vaults.contains(_vault);
    }

    /// @notice Gets the assets in a batch
    /// @param _batchId The batch ID to query
    /// @return The assets in the batch
    function getBatchAssets(uint256 _batchId) external view returns (address[] memory) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].assets.values();
    }

    /// @notice Checks if an asset is in a batch
    /// @param _batchId The batch ID to check
    /// @param _asset The asset to check
    /// @return Whether the asset is in the batch
    function isAssetInBatch(uint256 _batchId, address _asset) external view returns (bool) {
        kBatchStorage storage $ = _getkBatchStorage();
        return $.batches[_batchId].assets.contains(_asset);
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorizes contract upgrades
    /// @dev Only callable by ADMIN_ROLE
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kBatch";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
