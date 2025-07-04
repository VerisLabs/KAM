// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.30;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

import {ECDSA} from "solady/utils/ECDSA.sol";
import {EIP712} from "solady/utils/EIP712.sol";

import {Initializable} from "solady/utils/Initializable.sol";
import {Multicallable} from "solady/utils/Multicallable.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

import {DataTypes} from "src/types/DataTypes.sol";

/// @title kStrategyManager
/// @notice Orchestrates settlement and asset allocation across different strategies
/// @dev Separates strategy logic from kDNStakingVault to reduce contract size
contract kStrategyManager is Initializable, UUPSUpgradeable, OwnableRoles, EIP712, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant SETTLER_ROLE = _ROLE_2;
    uint256 public constant BACKEND_SIGNER_ROLE = _ROLE_3;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice EIP712 type hash for allocation orders
    bytes32 public constant ALLOCATION_ORDER_TYPEHASH = keccak256(
        "AllocationOrder(uint256 totalAmount,Allocation[] allocations,uint256 nonce,uint256 deadline)Allocation(uint8 adapterType,address target,uint256 amount,bytes data)"
    );

    bytes32 public constant ALLOCATION_TYPEHASH =
        keccak256("Allocation(uint8 adapterType,address target,uint256 amount,bytes data)");

    /// @notice Maximum number of allocations per order
    uint256 public constant MAX_ALLOCATIONS = 10;

    /// @notice Default settlement interval
    uint256 public constant DEFAULT_SETTLEMENT_INTERVAL = 1 hours;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kStrategyManager.storage.kStrategyManager
    struct kStrategyManagerStorage {
        address kDNStakingVault;
        address underlyingAsset;
        mapping(address => DataTypes.AdapterConfig) adapterConfigs;
        address[] registeredAdapters;
        mapping(address => uint256) nonces;
        uint256 lastSettlement;
        uint256 settlementInterval;
        bool paused;
        uint256 maxTotalAllocation;
        uint256 currentTotalAllocation;
    }

    // keccak256(abi.encode(uint256(keccak256("kStrategyManager.storage.kStrategyManager")) - 1)) &
    // ~bytes32(uint256(0xff))
    bytes32 private constant KSTRATEGYMANAGER_STORAGE_LOCATION =
        0x2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b00;

    function _getkStrategyManagerStorage() private pure returns (kStrategyManagerStorage storage $) {
        assembly {
            $.slot := KSTRATEGYMANAGER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event SettlementExecuted(uint256 indexed batchId, uint256 totalAmount, uint256 allocationsCount);
    event AllocationExecuted(address indexed target, DataTypes.AdapterType adapterType, uint256 amount);
    event AdapterRegistered(address indexed adapter, DataTypes.AdapterType adapterType, uint256 maxAllocation);
    event AdapterUpdated(address indexed adapter, bool enabled, uint256 maxAllocation);
    event EmergencyWithdrawal(address indexed token, address indexed to, uint256 amount, address indexed admin);
    event SettlementIntervalUpdated(uint256 oldInterval, uint256 newInterval);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error InvalidSignature();
    error SignatureExpired();
    error InvalidNonce();
    error AllocationExceeded();
    error AdapterNotEnabled();
    error SettlementTooEarly();
    error TotalAllocationExceeded();
    error InvalidAllocationSum();
    error TooManyAllocations();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier whenNotPaused() {
        if (_getkStrategyManagerStorage().paused) revert Paused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the kStrategyManager contract
    function initialize(
        address kDNStakingVault_,
        address underlyingAsset_,
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address settler_
    ) external initializer {
        if (kDNStakingVault_ == address(0)) revert ZeroAddress();
        if (underlyingAsset_ == address(0)) revert ZeroAddress();
        if (owner_ == address(0)) revert ZeroAddress();

        // Initialize ownership and roles
        _initializeOwner(owner_);
        _grantRoles(admin_, ADMIN_ROLE);
        _grantRoles(emergencyAdmin_, EMERGENCY_ADMIN_ROLE);
        _grantRoles(settler_, SETTLER_ROLE);

        // EIP712 initialization happens automatically in Solady

        // Initialize storage
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        $.kDNStakingVault = kDNStakingVault_;
        $.underlyingAsset = underlyingAsset_;
        $.settlementInterval = DEFAULT_SETTLEMENT_INTERVAL;
        $.maxTotalAllocation = type(uint256).max; // No limit by default
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Orchestrates batch settlement and asset allocation across multiple strategy adapters
    /// @dev Validates allocation order signature, settles vault batches, and executes asset distribution
    /// @param stakingBatchId Identifier for the staking batch to process
    /// @param unstakingBatchId Identifier for the unstaking batch to process, or 0 to skip
    /// @param order Structured allocation instructions containing targets and amounts
    /// @param signature Cryptographic signature validating the allocation order
    function settleAndAllocate(
        uint256 stakingBatchId,
        uint256 unstakingBatchId,
        DataTypes.AllocationOrder calldata order,
        bytes calldata signature
    ) external nonReentrant whenNotPaused onlyRoles(SETTLER_ROLE) {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        // Check settlement interval
        if (block.timestamp < $.lastSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        // Validate and execute allocation order
        _validateAllocationOrder(order, signature);

        // Settle vault batches first
        _settleVaultBatches(stakingBatchId, unstakingBatchId);

        // Execute allocation strategy
        _executeAllocations(order);

        // Update settlement timestamp
        $.lastSettlement = block.timestamp;

        emit SettlementExecuted(stakingBatchId, order.totalAmount, order.allocations.length);
    }

    /// @notice Processes vault batch settlement without executing any asset allocation
    /// @dev Emergency function that bypasses allocation logic and only updates vault accounting
    function emergencySettle(uint256 stakingBatchId, uint256 unstakingBatchId)
        external
        nonReentrant
        onlyRoles(EMERGENCY_ADMIN_ROLE)
    {
        _settleVaultBatches(stakingBatchId, unstakingBatchId);
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes asset allocation according to signed allocation order
    /// @dev Validates signature and executes distribution across specified strategy adapters
    function executeAllocation(DataTypes.AllocationOrder calldata order, bytes calldata signature)
        external
        nonReentrant
        whenNotPaused
        onlyRoles(ADMIN_ROLE)
    {
        _validateAllocationOrder(order, signature);
        _executeAllocations(order);
    }

    /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get adapter configuration
    function getAdapterConfig(address adapter) external view returns (DataTypes.AdapterConfig memory) {
        return _getkStrategyManagerStorage().adapterConfigs[adapter];
    }

    /// @notice Get current nonce for address
    function getNonce(address account) external view returns (uint256) {
        return _getkStrategyManagerStorage().nonces[account];
    }

    /// @notice Get all registered adapters
    function getRegisteredAdapters() external view returns (address[] memory) {
        return _getkStrategyManagerStorage().registeredAdapters;
    }

    /*//////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new adapter
    function registerAdapter(
        address adapter,
        DataTypes.AdapterType adapterType,
        uint256 maxAllocation,
        address implementation
    ) external onlyRoles(ADMIN_ROLE) {
        if (adapter == address(0)) revert ZeroAddress();
        if (maxAllocation > 10_000) revert AllocationExceeded(); // Max 100%

        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        DataTypes.AdapterConfig storage config = $.adapterConfigs[adapter];
        if (!config.enabled) {
            $.registeredAdapters.push(adapter);
        }

        config.enabled = true;
        config.maxAllocation = maxAllocation;
        config.implementation = implementation;

        emit AdapterRegistered(adapter, adapterType, maxAllocation);
    }

    /// @notice Updates adapter configuration
    function updateAdapter(address adapter, bool enabled, uint256 maxAllocation) external onlyRoles(ADMIN_ROLE) {
        if (maxAllocation > 10_000) revert AllocationExceeded();

        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        DataTypes.AdapterConfig storage config = $.adapterConfigs[adapter];

        if (!config.enabled && enabled) {
            $.registeredAdapters.push(adapter);
        }

        config.enabled = enabled;
        config.maxAllocation = maxAllocation;

        emit AdapterUpdated(adapter, enabled, maxAllocation);
    }

    /// @notice Sets settlement interval
    function setSettlementInterval(uint256 newInterval) external onlyRoles(ADMIN_ROLE) {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        uint256 oldInterval = $.settlementInterval;
        $.settlementInterval = newInterval;
        emit SettlementIntervalUpdated(oldInterval, newInterval);
    }

    /// @notice Emergency pause
    function setPaused(bool paused) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        _getkStrategyManagerStorage().paused = paused;
    }

    /// @notice Emergency withdraws tokens when paused
    /// @param token Token address to withdraw (use address(0) for ETH)
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function emergencyWithdraw(address token, address to, uint256 amount) external onlyRoles(EMERGENCY_ADMIN_ROLE) {
        if (!_getkStrategyManagerStorage().paused) revert("Not paused");
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

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
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates allocation order signature
    function _validateAllocationOrder(DataTypes.AllocationOrder calldata order, bytes calldata signature) internal {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        // Check deadline
        if (block.timestamp > order.deadline) revert SignatureExpired();

        // Check nonce
        address signer = msg.sender;
        if (order.nonce != $.nonces[signer]) revert InvalidNonce();

        // Validate signature
        bytes32 structHash = _hashAllocationOrder(order);
        bytes32 digest = _hashTypedData(structHash);

        address recovered = digest.recover(signature);
        if (!hasAnyRole(recovered, BACKEND_SIGNER_ROLE)) revert InvalidSignature();

        // Increment nonce
        $.nonces[signer]++;

        // Validate allocation logic
        _validateAllocations(order);
    }

    /// @notice Validates allocation parameters
    function _validateAllocations(DataTypes.AllocationOrder calldata order) internal view {
        if (order.allocations.length > MAX_ALLOCATIONS) revert TooManyAllocations();

        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        uint256 totalAllocated = 0;

        for (uint256 i = 0; i < order.allocations.length; i++) {
            DataTypes.Allocation calldata allocation = order.allocations[i];

            // Check adapter is enabled
            if (!$.adapterConfigs[allocation.target].enabled) revert AdapterNotEnabled();

            // Check allocation limits
            DataTypes.AdapterConfig storage config = $.adapterConfigs[allocation.target];
            uint256 newAllocation = config.currentAllocation + allocation.amount;
            uint256 maxAllowed = ($.currentTotalAllocation * config.maxAllocation) / 10_000;

            if (newAllocation > maxAllowed) revert AllocationExceeded();

            totalAllocated += allocation.amount;
        }

        // Check total allocation matches order
        if (totalAllocated != order.totalAmount) revert InvalidAllocationSum();

        // Check global allocation limit
        if ($.currentTotalAllocation + order.totalAmount > $.maxTotalAllocation) {
            revert TotalAllocationExceeded();
        }
    }

    /// @notice Executes the allocation strategy
    function _executeAllocations(DataTypes.AllocationOrder calldata order) internal {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        for (uint256 i = 0; i < order.allocations.length; i++) {
            DataTypes.Allocation calldata allocation = order.allocations[i];

            // Update tracking
            $.adapterConfigs[allocation.target].currentAllocation += allocation.amount;
            $.currentTotalAllocation += allocation.amount;

            // Execute allocation based on type
            _executeAllocation(allocation);

            emit AllocationExecuted(allocation.target, allocation.adapterType, allocation.amount);
        }
    }

    /// @notice Executes individual allocation
    function _executeAllocation(DataTypes.Allocation calldata allocation) internal {
        if (allocation.adapterType == DataTypes.AdapterType.CUSTODIAL_WALLET) {
            // Direct transfer to custodial wallet
            _getkStrategyManagerStorage().underlyingAsset.safeTransfer(allocation.target, allocation.amount);
        } else if (allocation.adapterType == DataTypes.AdapterType.ERC7540_VAULT) {
            // ERC7540 async vault deposit
            _executeERC7540Deposit(allocation);
        } else if (allocation.adapterType == DataTypes.AdapterType.LENDING_PROTOCOL) {
            // Onchain lending protocol
            _executeLendingDeposit(allocation);
        }
    }

    /// @notice Executes ERC7540 vault deposit
    function _executeERC7540Deposit(DataTypes.Allocation calldata allocation) internal {
        // ERC7540 async vault integration
        // This would call requestDeposit on the ERC7540 vault
        address vault = allocation.target;
        uint256 amount = allocation.amount;

        // Approve and request deposit
        _getkStrategyManagerStorage().underlyingAsset.safeApprove(vault, amount);

        // Call ERC7540 requestDeposit function
        (bool success,) = vault.call(
            abi.encodeWithSignature(
                "requestDeposit(uint256,address,address,bytes)", amount, address(this), address(this), allocation.data
            )
        );
        require(success, "ERC7540 deposit failed");
    }

    /// @notice Executes lending protocol deposit
    function _executeLendingDeposit(DataTypes.Allocation calldata allocation) internal {
        // Generic lending protocol integration
        address protocol = allocation.target;
        uint256 amount = allocation.amount;

        _getkStrategyManagerStorage().underlyingAsset.safeApprove(protocol, amount);

        // Call deposit function (would be protocol-specific)
        (bool success,) = protocol.call(abi.encodeWithSignature("deposit(uint256,address)", amount, address(this)));
        require(success, "Lending deposit failed");
    }

    /// @notice Settles vault batches
    function _settleVaultBatches(uint256 stakingBatchId, uint256 unstakingBatchId) internal {
        address vault = _getkStrategyManagerStorage().kDNStakingVault;

        // Settle staking batch
        if (stakingBatchId > 0) {
            (bool success,) = vault.call(abi.encodeWithSignature("settleStakingBatch(uint256)", stakingBatchId));
            require(success, "Staking settlement failed");
        }

        // Settle unstaking batch
        if (unstakingBatchId > 0) {
            (bool success,) = vault.call(abi.encodeWithSignature("settleUnstakingBatch(uint256)", unstakingBatchId));
            require(success, "Unstaking settlement failed");
        }
    }

    /// @notice Hashes allocation order for EIP712
    function _hashAllocationOrder(DataTypes.AllocationOrder calldata order) internal pure returns (bytes32) {
        bytes32[] memory allocationHashes = new bytes32[](order.allocations.length);

        for (uint256 i = 0; i < order.allocations.length; i++) {
            allocationHashes[i] = keccak256(
                abi.encode(
                    ALLOCATION_TYPEHASH,
                    order.allocations[i].adapterType,
                    order.allocations[i].target,
                    order.allocations[i].amount,
                    keccak256(order.allocations[i].data)
                )
            );
        }

        return keccak256(
            abi.encode(
                ALLOCATION_ORDER_TYPEHASH,
                order.totalAmount,
                keccak256(abi.encodePacked(allocationHashes)),
                order.nonce,
                order.deadline
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                          EIP712 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the EIP712 domain name
    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("kStrategyManager", "1");
    }

    /*//////////////////////////////////////////////////////////////
                          UPGRADE AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address newImplementation) internal view override onlyRoles(ADMIN_ROLE) {
        if (newImplementation == address(0)) revert ZeroAddress();
    }

    /*//////////////////////////////////////////////////////////////
                          CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory) {
        return "kStrategyManager";
    }

    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
