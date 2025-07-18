// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { Initializable } from "solady/utils/Initializable.sol";

import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

/// @title kSiloContract
/// @notice Secure intermediary for all external strategy returns using unified asset management
/// @dev EXTERNAL ASSET FLOW: All external sources route assets through kSilo for unified management:
///      1. CUSTODIAL: Custodial addresses can ONLY transfer tokens (USDC/WBTC) directly to this contract.
///         They cannot call any functions - they only do: USDC.transfer(siloAddress, amount)
///      2. METAVAULT: MetaVault redemptions route assets directly to kSilo via redeem() calls
///      The kStrategyManager then validates balances and redistributes funds to kBatchReceivers for user redemptions.
///
/// @dev UNIFIED ARCHITECTURE:
///      1. External sources (custodial wallets, MetaVaults) send USDC/WBTC to kSilo
///      2. kSilo accumulates all external assets and validates balances before transfers
///      3. kStrategyManager calls transferToDestination() to send funds to kBatchReceivers
///      4. Users redeem from kBatchReceivers during settlement
///
/// @dev SECURITY: Only kStrategyManager can redistribute funds. All transfers validate sufficient balance
///      using asset.balanceOf(address(this)) before executing transfers.
contract kSiloContract is Initializable, UUPSUpgradeable, OwnableRoles, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant STRATEGY_MANAGER_ROLE = _ROLE_2;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kSiloContract.storage.kSiloContract
    struct kSiloStorage {
        bool isPaused;
        address underlyingAsset;
        address strategyManager;
        uint256 totalDistributed;
    }

    // keccak256(abi.encode(uint256(keccak256("kSiloContract.storage.kSiloContract")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KSILO_STORAGE_LOCATION = 0x3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c00;

    function _getkSiloStorage() private pure returns (kSiloStorage storage $) {
        assembly {
            $.slot := KSILO_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetDistribution(
        bytes32 indexed operationId, address indexed destination, uint256 amount, string distributionType
    );
    event StrategyManagerUpdated(address indexed oldManager, address indexed newManager);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidOperation();
    error InsufficientBalance();
    error ContractNotPaused();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (_getkSiloStorage().isPaused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kSiloContract
    /// @param underlyingAsset_ The underlying asset address (USDC/WBTC)
    /// @param strategyManager_ The kStrategyManager address
    /// @param owner_ Owner address
    /// @param admin_ Admin address
    /// @param emergencyAdmin_ Emergency admin address
    function initialize(
        address underlyingAsset_,
        address strategyManager_,
        address owner_,
        address admin_,
        address emergencyAdmin_
    )
        external
        initializer
    {
        if (underlyingAsset_ == address(0)) revert ZeroAddress();
        if (strategyManager_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();
        if (admin_ == address(0)) revert ZeroAddress();
        if (emergencyAdmin_ == address(0)) revert ZeroAddress();

        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(strategyManager_, STRATEGY_MANAGER_ROLE);

        kSiloStorage storage $ = _getkSiloStorage();
        $.underlyingAsset = underlyingAsset_;
        $.strategyManager = strategyManager_;
        $.isPaused = false;
        $.totalDistributed = 0;
    }

    /*//////////////////////////////////////////////////////////////
                        DISTRIBUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers assets to destination (only kStrategyManager)
    /// @param destination The destination address (kBatchReceiver, vault, etc.)
    /// @param amount Amount to transfer
    /// @param operationId Associated operation ID
    /// @param distributionType Type of distribution ("redemption", "rebalancing", etc.)
    function transferToDestination(
        address destination,
        uint256 amount,
        bytes32 operationId,
        string calldata distributionType
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(STRATEGY_MANAGER_ROLE)
    {
        kSiloStorage storage $ = _getkSiloStorage();

        if (destination == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 availableBalance = $.underlyingAsset.balanceOf(address(this));
        if (availableBalance < amount) revert InsufficientBalance();

        // Transfer assets to destination
        $.underlyingAsset.safeTransfer(destination, amount);

        $.totalDistributed += amount;

        emit AssetDistribution(operationId, destination, amount, distributionType);
    }

    /// @notice Batch transfer to multiple destinations
    /// @param destinations Array of destination addresses
    /// @param amounts Array of amounts to transfer
    /// @param operationIds Array of operation IDs
    /// @param distributionType Type of distribution
    function batchTransferToDestinations(
        address[] calldata destinations,
        uint256[] calldata amounts,
        bytes32[] calldata operationIds,
        string calldata distributionType
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyRoles(STRATEGY_MANAGER_ROLE)
    {
        if (destinations.length != amounts.length || amounts.length != operationIds.length) {
            revert InvalidOperation();
        }

        kSiloStorage storage $ = _getkSiloStorage();
        uint256 totalAmount = 0;

        // Calculate total amount needed
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        uint256 availableBalance = $.underlyingAsset.balanceOf(address(this));
        if (availableBalance < totalAmount) revert InsufficientBalance();

        // Execute transfers
        uint256 length = destinations.length;
        uint256 totalDistributed = $.totalDistributed;
        for (uint256 i; i < length;) {
            if (destinations[i] == address(0)) revert ZeroAddress();
            if (amounts[i] == 0) continue;

            $.underlyingAsset.safeTransfer(destinations[i], amounts[i]);
            totalDistributed += amounts[i];

            emit AssetDistribution(operationIds[i], destinations[i], amounts[i], distributionType);

            unchecked {
                ++i;
            }
        }

        $.totalDistributed = totalDistributed;
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get total distributed amounts and current balance
    /// @return totalDistributed Total amount distributed to destinations
    /// @return currentBalance Current balance in the silo
    function getTotalAmounts() external view returns (uint256 totalDistributed, uint256 currentBalance) {
        kSiloStorage storage $ = _getkSiloStorage();
        totalDistributed = $.totalDistributed;
        currentBalance = $.underlyingAsset.balanceOf(address(this));
    }

    /// @notice Get underlying asset address
    /// @return asset The underlying asset address
    function asset() external view returns (address) {
        return _getkSiloStorage().underlyingAsset;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Update strategy manager address
    /// @param newStrategyManager New strategy manager address
    function setStrategyManager(address newStrategyManager) external onlyRoles(ADMIN_ROLE) {
        if (newStrategyManager == address(0)) revert ZeroAddress();

        kSiloStorage storage $ = _getkSiloStorage();
        address oldManager = $.strategyManager;

        // Remove role from old manager
        _removeRoles(oldManager, STRATEGY_MANAGER_ROLE);

        // Grant role to new manager
        _grantRoles(newStrategyManager, STRATEGY_MANAGER_ROLE);

        $.strategyManager = newStrategyManager;

        emit StrategyManagerUpdated(oldManager, newStrategyManager);
    }

    /// @notice Set pause state
    /// @param isPaused Whether to pause the contract
    function setPaused(bool isPaused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _getkSiloStorage().isPaused = isPaused;
    }

    /// @notice Emergency withdrawal function
    /// @param token Token to withdraw (use address(0) for ETH)
    /// @param to Destination address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        kSiloStorage storage $ = _getkSiloStorage();
        if (!$.isPaused) revert ContractNotPaused();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        if (token == address(0)) {
            to.safeTransferETH(amount);
        } else {
            token.safeTransfer(to, amount);
        }

        emit EmergencyWithdrawal(token, to, amount, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize contract upgrade
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
        return "kSiloContract";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    /// @notice Accepts ETH transfers
    receive() external payable { }
}
