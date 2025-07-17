// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { ECDSA } from "solady/utils/ECDSA.sol";
import { EIP712 } from "solady/utils/EIP712.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IkDNStaking } from "src/interfaces/IkDNStaking.sol";
import { IkSStaking } from "src/interfaces/IkSStaking.sol";
import { kSiloContract } from "src/kSiloContract.sol";
import { DataTypes } from "src/types/DataTypes.sol";

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
    uint256 public constant DEFAULT_SETTLEMENT_INTERVAL = 8 hours;

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kStrategyManager.storage.kStrategyManager
    struct kStrategyManagerStorage {
        address kDNStakingVault;
        address kSStakingVault;
        address underlyingAsset;
        address kSiloContract;
        address kMinter;
        mapping(address => DataTypes.AdapterConfig) adapterConfigs;
        address[] registeredAdapters;
        mapping(address => uint256) nonces;
        uint256 lastSettlement;
        uint256 settlementInterval;
        bool paused;
        uint256 maxTotalAllocation;
        uint256 currentTotalAllocation;
        mapping(uint256 => SettlementOperation) settlementOperations;
        uint256 settlementCounter;
    }

    struct SettlementOperation {
        uint256 operationId;
        uint256 totalStrategyAssets;
        uint256 totalDeployedAssets;
        address[] destinations;
        uint256[] amounts;
        bytes32[] batchReceiverIds;
        bool validated;
        bool executed;
        uint256 timestamp;
        string operationType;
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
    event SettlementValidated(uint256 indexed operationId, uint256 totalStrategyAssets, uint256 totalDeployedAssets);
    event SiloTransferExecuted(bytes32 indexed operationId, address indexed destination, uint256 amount);
    event AsyncOperationTracked(bytes32 indexed operationId, address indexed metavault, uint256 amount);
    event StrategyAssetsMismatch(uint256 totalStrategyAssets, uint256 totalDeployedAssets, uint256 difference);
    event kSiloContractUpdated(address indexed oldSilo, address indexed newSilo);

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
    error InsufficientStrategyAssets();
    error SettlementNotValidated();
    error SettlementAlreadyExecuted();
    error SiloContractNotSet();
    error InvalidSettlementOperation();
    error VaultNotSet();
    error SettlementFailed();
    error UseVaultSpecificEmergencySettlementFunctions();
    error ContractNotPaused();

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
        address kSStakingVault_,
        address underlyingAsset_,
        address kSiloContract_,
        address kMinter_,
        address owner_,
        address admin_,
        address emergencyAdmin_,
        address settler_
    )
        external
        initializer
    {
        if (kDNStakingVault_ == address(0)) revert ZeroAddress();
        if (underlyingAsset_ == address(0)) revert ZeroAddress();
        if (kSiloContract_ == address(0)) revert ZeroAddress();
        if (kMinter_ == address(0)) revert ZeroAddress();
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
        $.kSStakingVault = kSStakingVault_;
        $.underlyingAsset = underlyingAsset_;
        $.kSiloContract = kSiloContract_;
        $.kMinter = kMinter_;
        $.settlementInterval = DEFAULT_SETTLEMENT_INTERVAL;
        $.maxTotalAllocation = type(uint256).max; // No limit by default
        $.settlementCounter = 0;
    }

    /*//////////////////////////////////////////////////////////////
                          SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates settlement operation ensuring withdrawals > deposits
    /// @param totalStrategyAssets Total amount of assets currently held by strategies
    /// @param totalDeployedAssets Total amount originally deployed to strategies
    /// @param destinations Array of destination addresses (kBatchReceivers)
    /// @param amounts Array of amounts to transfer to each destination
    /// @param batchReceiverIds Array of batch receiver IDs for tracking
    /// @param operationType Type of settlement operation
    /// @return operationId Unique identifier for this settlement operation
    function validateSettlement(
        uint256 totalStrategyAssets,
        uint256 totalDeployedAssets,
        address[] calldata destinations,
        uint256[] calldata amounts,
        bytes32[] calldata batchReceiverIds,
        string calldata operationType
    )
        external
        onlyRoles(SETTLER_ROLE)
        whenNotPaused
        returns (uint256 operationId)
    {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        // Validate withdrawals > deposits (key requirement)
        if (totalStrategyAssets <= totalDeployedAssets) {
            revert InsufficientStrategyAssets();
        }

        // Validate arrays match
        if (destinations.length != amounts.length || amounts.length != batchReceiverIds.length) {
            revert InvalidSettlementOperation();
        }

        // Generate operation ID
        operationId = ++$.settlementCounter;

        // Store settlement operation
        $.settlementOperations[operationId] = SettlementOperation({
            operationId: operationId,
            totalStrategyAssets: totalStrategyAssets,
            totalDeployedAssets: totalDeployedAssets,
            destinations: destinations,
            amounts: amounts,
            batchReceiverIds: batchReceiverIds,
            validated: true,
            executed: false,
            timestamp: block.timestamp,
            operationType: operationType
        });

        emit SettlementValidated(operationId, totalStrategyAssets, totalDeployedAssets);

        // Log mismatch for monitoring
        uint256 difference = totalStrategyAssets - totalDeployedAssets;
        emit StrategyAssetsMismatch(totalStrategyAssets, totalDeployedAssets, difference);

        return operationId;
    }

    /// @notice Executes validated settlement by transferring from Silo to destinations
    /// @param operationId Settlement operation ID to execute
    function executeSettlement(uint256 operationId) external onlyRoles(SETTLER_ROLE) whenNotPaused {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        if ($.kSiloContract == address(0)) revert SiloContractNotSet();

        // Direct lookup using operationId as key
        SettlementOperation storage operation = $.settlementOperations[operationId];

        // Validate operation exists
        if (operation.operationId == 0) revert SettlementNotValidated();
        if (!operation.validated) revert SettlementNotValidated();
        if (operation.executed) revert SettlementAlreadyExecuted();

        // Execute transfers from Silo to destinations
        for (uint256 i = 0; i < operation.destinations.length; i++) {
            if (operation.amounts[i] > 0) {
                kSiloContract(payable($.kSiloContract)).transferToDestination(
                    operation.destinations[i],
                    operation.amounts[i],
                    operation.batchReceiverIds[i],
                    operation.operationType
                );

                emit SiloTransferExecuted(
                    operation.batchReceiverIds[i], operation.destinations[i], operation.amounts[i]
                );
            }
        }

        // Mark as executed
        operation.executed = true;
    }

    /// @notice Orchestrates multi-phase settlement across the entire protocol
    /// @dev Implements proper settlement ordering: Institutional → User Staking → Strategy Deployment
    /// @param params Struct containing all settlement and allocation parameters
    /// @param order Structured allocation instructions containing targets and amounts
    /// @param signature Cryptographic signature validating the allocation order
    function settleAndAllocate(
        DataTypes.SettlementParams calldata params,
        DataTypes.AllocationOrder calldata order,
        bytes calldata signature
    )
        external
        nonReentrant
        whenNotPaused
        onlyRoles(SETTLER_ROLE)
    {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        // Check settlement interval
        if (block.timestamp < $.lastSettlement + $.settlementInterval) {
            revert SettlementTooEarly();
        }

        // Validate allocation order signature
        _validateAllocationOrder(order, signature);

        // PHASE 1: Institutional Settlement (kMinter → kDNStakingVault)
        // Note: Institutional settlements are handled by kMinter.settleBatch() externally
        // This ensures institutions get priority liquidity access

        // PHASE 2: User Staking Settlement (kDNStakingVault → kSStakingVault)
        // Handle kDNStakingVault settlements (both staking and unstaking)
        if (params.stakingBatchId > 0 && params.totalKTokensStaked > 0) {
            // Validate kDNStakingVault is set
            if ($.kDNStakingVault == address(0)) revert VaultNotSet();

            // kDNStakingVault staking settlement (now unified interface with optional destinations/amounts)
            try IkDNStaking($.kDNStakingVault).settleStakingBatch(
                params.stakingBatchId,
                params.totalKTokensStaked,
                params.stakingDestinations, // Forward destinations for unified interface
                params.stakingAmounts // Forward amounts for unified interface
            ) {
                // Settlement successful
            } catch {
                revert SettlementFailed();
            }
        }

        // PHASE 3: User Unstaking Settlement (kSStakingVault → kMinter)
        if (params.unstakingBatchId > 0 && params.totalStkTokensUnstaked > 0) {
            // Validate kSStakingVault is set
            if ($.kSStakingVault == address(0)) revert VaultNotSet();

            // kSStakingVault unstaking settlement (now unified interface with optional sources/amounts)
            try IkSStaking($.kSStakingVault).settleUnstakingBatch(
                params.unstakingBatchId,
                params.totalStkTokensUnstaked,
                params.unstakingSources, // Forward sources for unified interface
                params.unstakingAmounts // Forward amounts for unified interface
            ) {
                // Settlement successful
            } catch {
                revert SettlementFailed();
            }
        }

        // PHASE 4: Strategy Deployment (Execute allocation strategy)
        // Each vault deploys to its strategy-specific destinations with MetaVault-first priority
        _executeAllocation(order);

        // Update settlement timestamp
        $.lastSettlement = block.timestamp;

        emit SettlementExecuted(params.stakingBatchId, order.totalAmount, order.allocations.length);
    }

    /// @notice Processes vault batch settlement without executing any asset allocation
    /// @dev Emergency function that bypasses allocation logic and only updates vault accounting
    /// @notice Emergency settlement function (deprecated)
    /// @dev Emergency settlements are now handled directly by individual vaults
    /// @dev This function remains for compatibility but should not be used
    function emergencySettle(
        uint256 stakingBatchId,
        uint256 unstakingBatchId,
        uint256 totalKTokensStaked,
        uint256 totalStkTokensUnstaked,
        uint256 totalKTokensToReturn,
        uint256 totalYieldToMinter
    )
        external
        nonReentrant
        onlyRoles(EMERGENCY_ADMIN_ROLE)
    {
        // Emergency settlements are now handled directly by vaults
        // This function is deprecated but kept for interface compatibility
        revert UseVaultSpecificEmergencySettlementFunctions();
    }

    /*//////////////////////////////////////////////////////////////
                          CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Processes asset allocation according to signed allocation order
    /// @dev Validates signature and executes distribution across specified strategy adapters
    function executeAllocation(
        DataTypes.AllocationOrder calldata order,
        bytes calldata signature
    )
        external
        nonReentrant
        whenNotPaused
        onlyRoles(ADMIN_ROLE)
    {
        _validateAllocationOrder(order, signature);
        _executeAllocation(order);
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

    /// @notice Get settlement operation details
    /// @param operationId Settlement operation ID
    /// @return operation The settlement operation details
    function getSettlementOperation(uint256 operationId) external view returns (SettlementOperation memory operation) {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        // Direct lookup using operationId as key
        return $.settlementOperations[operationId];
    }

    /// @notice Get kSiloContractAddress
    function kSiloContractAddress() external view returns (address) {
        return _getkStrategyManagerStorage().kSiloContract;
    }

    /// @notice Get settlement counter
    function settlementCounter() external view returns (uint256) {
        return _getkStrategyManagerStorage().settlementCounter;
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
    )
        external
        onlyRoles(ADMIN_ROLE)
    {
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

    /// @notice Updates kSiloContract address
    /// @param newSiloContract New kSiloContract address
    function setkSiloContract(address newSiloContract) external onlyRoles(ADMIN_ROLE) {
        if (newSiloContract == address(0)) revert ZeroAddress();
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        address oldSilo = $.kSiloContract;
        $.kSiloContract = newSiloContract;
        emit kSiloContractUpdated(oldSilo, newSiloContract);
    }

    /// @notice Updates kSStakingVault address
    /// @param newkSStakingVault New kSStakingVault address
    function setkSStakingVault(address newkSStakingVault) external onlyRoles(ADMIN_ROLE) {
        if (newkSStakingVault == address(0)) revert ZeroAddress();
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        $.kSStakingVault = newkSStakingVault;
    }

    /// @notice Updates kMinter address
    /// @param newkMinter New kMinter address
    function setkMinter(address newkMinter) external onlyRoles(ADMIN_ROLE) {
        if (newkMinter == address(0)) revert ZeroAddress();
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();
        $.kMinter = newkMinter;
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
        if (!_getkStrategyManagerStorage().paused) revert ContractNotPaused();
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

        uint256 length = order.allocations.length;
        DataTypes.Allocation calldata allocation;
        DataTypes.AdapterConfig storage config;
        uint256 newAllocation;
        uint256 maxAllowed;

        for (uint256 i; i < length;) {
            allocation = order.allocations[i];

            // Check adapter is enabled
            if (!$.adapterConfigs[allocation.target].enabled) revert AdapterNotEnabled();

            // Check allocation limits
            config = $.adapterConfigs[allocation.target];
            newAllocation = config.currentAllocation + allocation.amount;
            maxAllowed = ($.currentTotalAllocation * config.maxAllocation) / 10_000;

            if (newAllocation > maxAllowed) revert AllocationExceeded();

            totalAllocated += allocation.amount;

            unchecked {
                i++;
            }
        }

        // Check total allocation matches order
        if (totalAllocated != order.totalAmount) revert InvalidAllocationSum();

        // Check global allocation limit
        if ($.currentTotalAllocation + order.totalAmount > $.maxTotalAllocation) {
            revert TotalAllocationExceeded();
        }
    }

    /// @notice Internal function to execute allocation orders
    /// @param order The allocation order to execute
    function _executeAllocation(DataTypes.AllocationOrder calldata order) internal {
        kStrategyManagerStorage storage $ = _getkStrategyManagerStorage();

        // Execute each allocation in the order
        uint256 length = order.allocations.length;
        for (uint256 i; i < length;) {
            DataTypes.Allocation calldata allocation = order.allocations[i];

            // Execute allocation based on adapter type
            DataTypes.AdapterConfig storage adapterConfig = $.adapterConfigs[allocation.target];
            if (!adapterConfig.enabled || adapterConfig.implementation == address(0)) revert AdapterNotEnabled();

            // Call the adapter to execute the allocation
            (bool success,) = adapterConfig.implementation.call(
                abi.encodeWithSignature(
                    "executeAllocation(address,uint256,bytes)", allocation.target, allocation.amount, allocation.data
                )
            );

            if (!success) {
                // Handle failed allocation
                revert AllocationExceeded();
            }

            // Emit event for each allocation
            emit AllocationExecuted(allocation.target, allocation.adapterType, allocation.amount);

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Hashes allocation order for EIP712
    function _hashAllocationOrder(DataTypes.AllocationOrder calldata order) internal pure returns (bytes32) {
        bytes32[] memory allocationHashes = new bytes32[](order.allocations.length);

        uint256 length = order.allocations.length;
        DataTypes.Allocation calldata allocation;

        for (uint256 i; i < length;) {
            allocation = order.allocations[i];

            allocationHashes[i] = keccak256(
                abi.encode(
                    ALLOCATION_TYPEHASH,
                    order.allocations[i].adapterType,
                    order.allocations[i].target,
                    order.allocations[i].amount,
                    keccak256(order.allocations[i].data)
                )
            );

            unchecked {
                i++;
            }
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
