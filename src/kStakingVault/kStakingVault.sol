// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";
import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
import { MultiFacetProxy } from "src/kStakingVault/modules/MultiFacetProxy.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

// Using imported IkAssetRouter interface

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is Initializable, UUPSUpgradeable, ERC20, BaseModule, MultiFacetProxy {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint128;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() MultiFacetProxy(ADMIN_ROLE) {
        _disableInitializers();
    }

    /// @notice Initializes the kStakingVault contract (stack optimized)
    /// @dev Phase 1: Core initialization without strings to avoid stack too deep
    /// @param asset_ Underlying asset address
    /// @param owner_ Owner address
    /// @param admin_ Admin address
    /// @param emergencyAdmin_ Emergency admin address
    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param decimals_ Token decimals
    /// @param dustAmount_ Minimum amount threshold
    /// @param paused_ Initial pause state
    function initialize(
        address registry_,
        address owner_,
        address admin_,
        bool paused_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint128 dustAmount_,
        address emergencyAdmin_,
        address asset_
    )
        external
        initializer
    {
        if (asset_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        __ModuleBase_init(registry_, owner_, admin_, paused_);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);

        // Initialize storage with optimized packing
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        $.name = name_;
        $.symbol = symbol_;
        $.decimals = decimals_;
        $.underlyingAsset = asset_;
        $.dustAmount = dustAmount_.toUint96();
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param to Address to receive the stkTokens
    /// @param kTokensAmount Amount of kTokens to stake
    /// @param minStkTokens Minimum stkTokens to receive
    /// @return requestId Request ID for this staking request
    function requestStake(
        address to,
        uint96 kTokensAmount,
        uint96 minStkTokens
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (kTokensAmount == 0) revert ZeroAmount();
        address kToken = _getKTokenForAsset($.underlyingAsset);
        if (IkToken(kToken).balanceOf(msg.sender) < kTokensAmount) revert InsufficientBalance();
        if (kTokensAmount < $.dustAmount) revert AmountBelowDustThreshold();

        uint256 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, kTokensAmount, block.timestamp);

        // Create staking request
        $.stakeRequests[requestId] = BaseModuleTypes.StakeRequest({
            id: requestId,
            user: msg.sender,
            kTokenAmount: kTokensAmount,
            recipient: to,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: uint8(BaseModuleTypes.RequestStatus.PENDING),
            minStkTokens: minStkTokens,
            batchId: SafeCastLib.toUint32(batchId)
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].push(requestId);

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            _getKMinter(), address(this), $.underlyingAsset, kTokensAmount, batchId
        );

        kToken.safeTransferFrom(msg.sender, address(this), kTokensAmount);

        emit StakeRequestCreated(bytes32(requestId), msg.sender, kToken, kTokensAmount, to, batchId.toUint32());

        return requestId;
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(
        address to,
        uint96 stkTokenAmount,
        uint96 minKTokens
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (stkTokenAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < stkTokenAmount) revert InsufficientBalance();
        if (stkTokenAmount < $.dustAmount) revert AmountBelowDustThreshold();

        uint256 batchId = $.currentBatchId;

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, stkTokenAmount, block.timestamp);

        // Create unstaking request
        $.unstakeRequests[requestId] = BaseModuleTypes.UnstakeRequest({
            id: requestId,
            user: msg.sender,
            stkTokenAmount: stkTokenAmount,
            recipient: to,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: uint8(BaseModuleTypes.RequestStatus.PENDING),
            minKTokens: minKTokens,
            batchId: SafeCastLib.toUint32(batchId)
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].push(requestId);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPull(address(this), stkTokenAmount, batchId);

        _transfer(msg.sender, address(this), stkTokenAmount);

        emit UnstakeRequestCreated(bytes32(requestId), msg.sender, stkTokenAmount, to, batchId.toUint32());

        return requestId;
    }

    /*//////////////////////////////////////////////////////////////
                            ASSET ROUTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the last total assets for the vault
    /// @param totalAssets_ Total assets in the vault
    function updateLastTotalAssets(uint256 totalAssets_) external onlyKAssetRouter {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint256 oldTotalAssets = $.lastTotalAssets;
        $.lastTotalAssets = totalAssets_;
        emit TotalAssetsUpdated(oldTotalAssets, totalAssets_);
    }

    function mintStkTokens(address to, uint256 amount) external {
        if (msg.sender != address(this)) revert OnlyKAssetRouter();
        _mint(to, amount);
    }

    function burnStkTokens(address from, uint256 amount) external {
        if (msg.sender != address(this)) revert OnlyKAssetRouter();
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) internal returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        $.requestCounter = (uint256($.requestCounter) + 1).toUint64();
        return uint256(keccak256(abi.encode(address(this), user, amount, timestamp, $.requestCounter)));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
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

    /// @notice Calculates stkToken price with safety checks
    /// @dev Standard price calculation used across settlement modules
    /// @param totalAssets_ Total underlying assets backing stkTokens
    /// @return price Price per stkToken in underlying asset terms (18 decimals)
    function calculateStkTokenPrice(uint256 totalAssets_) external view returns (uint256) {
        return _calculateStkTokenPrice(totalAssets_, totalSupply());
    }

    /// @notice Calculates the price of stkTokens in underlying asset terms
    /// @dev Uses the last total assets and total supply to calculate the price
    /// @return price Price per stkToken in underlying asset terms (18 decimals)
    function sharePrice() external view returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        return _calculateStkTokenPrice($.lastTotalAssets, totalSupply());
    }

    /// @notice Returns the last total assets for the vault
    /// @return Total assets
    function lastTotalAssets() external view returns (uint256) {
        return _getBaseModuleStorage().lastTotalAssets;
    }

    /// @notice Returns the current total assets from adapter (real-time)
    /// @return Total assets currently deployed in strategies
    function totalAssets() external view returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        // Get adapter from registry for this specific vault
        address adapter = _registry().getAdapter(address(this));

        if (adapter != address(0) && _registry().isAdapterRegistered(adapter)) {
            return IAdapter(adapter).totalAssets($.underlyingAsset);
        }

        // Fallback to stored value if no adapter
        return $.lastTotalAssets;
    }

    /// @notice Returns estimated total assets including pending yield
    /// @return Estimated total assets with unrealized gains
    function estimatedTotalAssets() external view returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();

        // Get adapter from registry for this specific vault
        address adapter = _registry().getAdapter(address(this));

        if (adapter != address(0) && _registry().isAdapterRegistered(adapter)) {
            return IAdapter(adapter).estimatedTotalAssets($.underlyingAsset);
        }

        // Fallback to stored value if no adapter
        return $.lastTotalAssets;
    }

    /// @notice Returns the kToken address for the vault
    /// @return kToken address
    function getKToken() external view returns (address) {
        return _getKTokenForAsset(_getBaseModuleStorage().underlyingAsset);
    }

    /// @notice Returns the current batch ID
    /// @return Batch ID
    function getBatchId() external view returns (uint256) {
        return _getBaseModuleStorage().currentBatchId;
    }

    /// @notice Returns the safe batch ID
    /// @return Batch ID
    function getSafeBatchId() external view returns (uint256) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint32 batchId = $.currentBatchId;
        if ($.batches[batchId].isClosed) revert Closed();
        if ($.batches[batchId].isSettled) revert Settled();
        return batchId;
    }

    /// @notice Returns whether the current batch is closed
    /// @return Whether the current batch is closed
    function isBatchClosed() external view returns (bool) {
        return _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isClosed;
    }

    /// @notice Returns whether the current batch is settled
    /// @return Whether the current batch is settled
    function isBatchSettled() external view returns (bool) {
        return _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isSettled;
    }

    /// @notice Returns the current batch ID, whether it is closed, and whether it is settled
    /// @return batchId Current batch ID
    /// @return batchReceiver Current batch receiver
    /// @return isClosed Whether the current batch is closed
    /// @return isSettled Whether the current batch is settled
    function getBatchInfo()
        external
        view
        returns (uint256 batchId, address batchReceiver, bool isClosed, bool isSettled)
    {
        return (
            _getBaseModuleStorage().currentBatchId,
            _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].batchReceiver,
            _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isClosed,
            _getBaseModuleStorage().batches[_getBaseModuleStorage().currentBatchId].isSettled
        );
    }

    /// @notice Returns the batch receiver for the current batch
    /// @return Batch receiver
    function getBatchReceiver(uint256 batchId) external view returns (address) {
        return _getBaseModuleStorage().batches[batchId.toUint32()].batchReceiver;
    }

    function getSafeBatchReceiver(uint256 batchId) external view returns (address) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        uint32 batchId32 = batchId.toUint32();
        if ($.batches[batchId32].isSettled) revert Settled();
        return $.batches[batchId32].batchReceiver;
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner { }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts ETH transfers
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kStakingVault";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
