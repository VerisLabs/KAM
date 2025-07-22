// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

import { Multicallable } from "solady/utils/Multicallable.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { Extsload } from "src/abstracts/Extsload.sol";

import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkBatch } from "src/interfaces/IkBatch.sol";
import { IkToken } from "src/interfaces/IkToken.sol";
import { MultiFacetProxy } from "src/modules/MultiFacetProxy.sol";
import { ModuleBase } from "src/modules/base/ModuleBase.sol";
import { ModuleBaseTypes } from "src/types/ModuleBaseTypes.sol";

// Using imported IkAssetRouter interface

/// @title kStakingVault
/// @notice Pure ERC20 vault with dual accounting for minter and user pools
/// @dev Implements automatic yield distribution from minter to user pools with modular architecture
contract kStakingVault is
    Initializable,
    UUPSUpgradeable,
    ERC20,
    ModuleBase,
    Multicallable,
    MultiFacetProxy,
    Extsload
{
    using SafeTransferLib for address;
    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string private constant DEFAULT_NAME = "KAM Delta Neutral Staking Vault";
    string private constant DEFAULT_SYMBOL = "kToken";

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
    /// @param kToken_ kToken address
    /// @param owner_ Owner address
    /// @param admin_ Admin address
    /// @param emergencyAdmin_ Emergency admin address
    /// @param settler_ Settler address
    /// @param kBatch_ Batch contract address
    /// @param kAssetRouter_ Asset router address
    /// @param decimals_ Token decimals
    /// @param dustAmount_ Minimum amount threshold
    function initialize(
        address asset_,
        address kToken_,
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address settler_,
        address kBatch_,
        address kAssetRouter_,
        uint8 decimals_,
        uint128 dustAmount_
    )
        external
        initializer
    {
        if (asset_ == address(0)) revert ZeroAddress();
        if (kToken_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();
        if (settler_ == address(0)) revert ZeroAddress();
        if (kAssetRouter_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(settler_, SETTLER_ROLE);

        // Initialize storage with optimized packing
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.underlyingAsset = asset_;
        $.kToken = kToken_;
        $.kBatch = kBatch_;
        $.kAssetRouter = kAssetRouter_;
        $.dustAmount = dustAmount_;
        $.decimals = decimals_;
        $.isPaused = false;
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Request to stake kTokens for stkTokens (rebase token)
    /// @param recipient Address to receive the stkTokens
    /// @param kTokensAmount Amount of kTokens to stake
    /// @param minStkTokens Minimum stkTokens to receive
    /// @return requestId Request ID for this staking request
    function requestStake(
        address recipient,
        uint96 kTokensAmount,
        uint96 minStkTokens
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (kTokensAmount == 0) revert ZeroAmount();
        if (IkToken($.kToken).balanceOf(msg.sender) < kTokensAmount) revert InsufficientBalance();
        if (kTokensAmount < $.dustAmount) revert AmountBelowDustThreshold();

        uint256 batchId = IkBatch($.kBatch).batchToUse();
        //IkBatch($.kBatch).updateBatchInfo(batchId, $.underlyingAsset, int256(amount));

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, kTokensAmount, block.timestamp);

        // Create staking request
        $.stakeRequests[requestId] = ModuleBaseTypes.StakeRequest({
            id: requestId,
            user: msg.sender,
            recipient: recipient,
            kTokenAmount: kTokensAmount,
            minStkTokens: minStkTokens,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: ModuleBaseTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].push(requestId);

        IkAssetRouter($.kAssetRouter).kAssetTransfer(
            $.kMinter, address(this), $.underlyingAsset, kTokensAmount, batchId
        );

        $.kToken.safeTransferFrom(msg.sender, address(this), kTokensAmount);

        emit StakeRequestCreated(bytes32(requestId), msg.sender, $.kToken, kTokensAmount, recipient, batchId);

        return requestId;
    }

    /// @notice Request to unstake stkTokens for kTokens + yield
    /// @dev Works with both claimed and unclaimed stkTokens (can unstake immediately after settlement)
    /// @param stkTokenAmount Amount of stkTokens to unstake
    /// @return requestId Request ID for this unstaking request
    function requestUnstake(
        address recipient,
        uint96 stkTokenAmount,
        uint96 minKTokens
    )
        external
        payable
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        if (stkTokenAmount == 0) revert ZeroAmount();
        if (balanceOf(msg.sender) < stkTokenAmount) revert InsufficientBalance();
        if (stkTokenAmount < $.dustAmount) revert AmountBelowDustThreshold();

        uint256 batchId = IkBatch($.kBatch).batchToUse();

        // Generate request ID
        requestId = _createStakeRequestId(msg.sender, stkTokenAmount, block.timestamp);

        // Create unstaking request
        $.unstakeRequests[requestId] = ModuleBaseTypes.UnstakeRequest({
            id: requestId,
            user: msg.sender,
            recipient: recipient,
            stkTokenAmount: stkTokenAmount,
            minKTokens: minKTokens,
            requestTimestamp: SafeCastLib.toUint64(block.timestamp),
            status: ModuleBaseTypes.RequestStatus.PENDING,
            batchId: batchId
        });

        // Add to user requests tracking
        $.userRequests[msg.sender].push(requestId);

        IkAssetRouter($.kAssetRouter).kSharesRequestPull(address(this), stkTokenAmount, batchId);

        _transfer(msg.sender, address(this), stkTokenAmount);

        emit StakeRequestCreated(bytes32(requestId), msg.sender, $.kToken, stkTokenAmount, recipient, batchId);

        return requestId;
    }

    /*//////////////////////////////////////////////////////////////
                            ASSET ROUTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the last total assets for the vault
    /// @param totalAssets Total assets in the vault
    function updateLastTotalAssets(uint256 totalAssets) external onlyRoles(ASSET_ROUTER_ROLE) {
        _getBaseVaultStorage().lastTotalAssets = totalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createStakeRequestId(address user, uint256 amount, uint256 timestamp) internal returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        $.requestCounter++;
        return uint256(keccak256(abi.encode(address(this), user, amount, timestamp, $.requestCounter)));
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the underlying asset address (for compatibility)
    /// @return Asset address
    function asset() external view returns (address) {
        return _getBaseVaultStorage().underlyingAsset;
    }

    /// @notice Returns the vault shares token name
    /// @return Token name
    function name() public pure override returns (string memory) {
        return DEFAULT_NAME;
    }

    /// @notice Returns the vault shares token symbol
    /// @return Token symbol
    function symbol() public pure override returns (string memory) {
        return DEFAULT_SYMBOL;
    }

    /// @notice Returns the vault shares token decimals
    /// @return Token decimals
    function decimals() public view override returns (uint8) {
        return uint8(_getBaseVaultStorage().decimals);
    }

    /// @notice Calculates stkToken price with safety checks
    /// @dev Standard price calculation used across settlement modules
    /// @param totalAssets Total underlying assets backing stkTokens
    /// @return price Price per stkToken in underlying asset terms (18 decimals)
    function calculateStkTokenPrice(uint256 totalAssets) external view returns (uint256) {
        return _calculateStkTokenPrice(totalAssets, totalSupply());
    }

    function sharePrice() external view returns (uint256) {
        BaseVaultStorage storage $ = _getBaseVaultStorage();
        return _calculateStkTokenPrice($.lastTotalAssets, totalSupply());
    }

    function lastTotalAssets() external view returns (uint256) {
        return _getBaseVaultStorage().lastTotalAssets;
    }

    function kToken() external view returns (address) {
        return _getBaseVaultStorage().kToken;
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
