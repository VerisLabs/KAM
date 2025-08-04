// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";

import { BaseModule } from "src/kStakingVault/modules/BaseModule.sol";
import { MultiFacetProxy } from "src/kStakingVault/modules/MultiFacetProxy.sol";
import { BaseModuleTypes } from "src/kStakingVault/types/BaseModuleTypes.sol";

// Using imported IkAssetRouter interface

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is Initializable, UUPSUpgradeable, BaseModule, MultiFacetProxy {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint128;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
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
        __BaseModule_init(registry_, owner_, admin_, paused_);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);

        // Initialize storage with optimized packing
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        $.name = name_;
        $.symbol = symbol_;
        $.decimals = decimals_;
        $.underlyingAsset = asset_;
        $.dustAmount = dustAmount_.toUint96();
        $.kToken = _registry().assetToKToken(asset_);

        emit Initialized(registry_, owner_, admin_);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param to Address to receive the stkTokens
    /// @param kTokensAmount Amount of kTokens to stake
    /// @return requestId Request ID for this staking request
    function requestStake(
        address to,
        uint96 kTokensAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if (kTokensAmount == 0) revert ZeroAmount();
        if ($.kToken.balanceOf(msg.sender) < kTokensAmount) revert InsufficientBalance();
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
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].push(requestId);

        $.kToken.safeTransferFrom(msg.sender, address(this), kTokensAmount);

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            _getKMinter(), address(this), $.underlyingAsset, kTokensAmount, batchId
        );

        emit StakeRequestCreated(bytes32(requestId), msg.sender, $.kToken, kTokensAmount, to, batchId);

        return requestId;
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(
        address to,
        uint96 stkTokenAmount
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
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].push(requestId);

        _transfer(msg.sender, address(this), stkTokenAmount);

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPush(address(this), stkTokenAmount, batchId);

        emit UnstakeRequestCreated(bytes32(requestId), msg.sender, stkTokenAmount, to, batchId);

        return requestId;
    }

    /// @notice Cancels a staking request
    /// @param requestId Request ID to cancel
    function cancelStakeRequest(uint256 requestId) external {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        BaseModuleTypes.StakeRequest storage request = $.stakeRequests[requestId];

        if (msg.sender != request.user) revert Unauthorized();
        if (request.id == 0) revert RequestNotFound();
        if (request.status != uint8(BaseModuleTypes.RequestStatus.PENDING)) revert RequestNotEligible();

        request.status = uint8(BaseModuleTypes.RequestStatus.CANCELLED);

        address vault = _getDNVaultByAsset($.underlyingAsset);
        if ($.batches[request.batchId].isClosed) revert Closed();
        if ($.batches[request.batchId].isSettled) revert Settled();

        IkAssetRouter(_getKAssetRouter()).kAssetTransfer(
            address(this), _getKMinter(), $.underlyingAsset, request.kTokenAmount, request.batchId
        );

        $.kToken.safeTransfer(request.user, request.kTokenAmount);

        emit StakeRequestCancelled(bytes32(requestId));
    }

    /// @notice Cancels an unstaking request
    /// @param requestId Request ID to cancel
    function cancelUnstakeRequest(uint256 requestId) external payable nonReentrant whenNotPaused {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        BaseModuleTypes.UnstakeRequest storage request = $.unstakeRequests[requestId];

        if (msg.sender != request.user) revert Unauthorized();
        if (request.id == 0) revert RequestNotFound();
        if (request.status != uint8(BaseModuleTypes.RequestStatus.PENDING)) revert RequestNotEligible();

        request.status = uint8(BaseModuleTypes.RequestStatus.CANCELLED);

        address vault = _getDNVaultByAsset($.underlyingAsset);
        if ($.batches[request.batchId].isClosed) revert Closed();
        if ($.batches[request.batchId].isSettled) revert Settled();

        IkAssetRouter(_getKAssetRouter()).kSharesRequestPull(address(this), request.stkTokenAmount, request.batchId);

        _transfer(address(this), request.user, request.stkTokenAmount);

        emit UnstakeRequestCancelled(bytes32(requestId));
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
                            PAUSE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the pause state of the contract
    /// @param paused_ New pause state
    /// @dev Only callable internally by inheriting contracts
    function setPaused(bool paused_) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _setPaused(paused_);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTIFACET PROXY OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Override addFunction with proper access control from BaseModule
    /// @param selector The function selector to add
    /// @param implementation The implementation contract address
    /// @param forceOverride If true, allows overwriting existing mappings
    function addFunction(
        bytes4 selector,
        address implementation,
        bool forceOverride
    )
        public
        override
        onlyRoles(ADMIN_ROLE)
    {
        super.addFunction(selector, implementation, forceOverride);
    }

    /// @notice Override addFunctions with proper access control
    /// @param selectors Array of function selectors to add
    /// @param implementation The implementation contract address
    /// @param forceOverride If true, allows overwriting existing mappings
    function addFunctions(
        bytes4[] calldata selectors,
        address implementation,
        bool forceOverride
    )
        public
        override
        onlyRoles(ADMIN_ROLE)
    {
        super.addFunctions(selectors, implementation, forceOverride);
    }

    /// @notice Override removeFunction with proper access control
    /// @param selector The function selector to remove
    function removeFunction(bytes4 selector) public override onlyRoles(ADMIN_ROLE) {
        super.removeFunction(selector);
    }

    /// @notice Override removeFunctions with proper access control
    /// @param selectors Array of function selectors to remove
    function removeFunctions(bytes4[] calldata selectors) public override onlyRoles(ADMIN_ROLE) {
        super.removeFunctions(selectors);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        return _sharePrice();
    }

    /// @notice Returns the current total assets from adapter (real-time)
    /// @return Total assets currently deployed in strategies
    function totalAssets() external view returns (uint256) {
        return _totalAssets();
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
        uint256 batchId = $.currentBatchId;
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
        return _getBaseModuleStorage().batches[batchId].batchReceiver;
    }

    function getSafeBatchReceiver(uint256 batchId) external view returns (address) {
        BaseModuleStorage storage $ = _getBaseModuleStorage();
        if ($.batches[batchId].isSettled) revert Settled();
        return $.batches[batchId].batchReceiver;
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize upgrade (only owner can upgrade)
    /// @dev This allows upgrading the main contract while keeping modules separate
    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

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
