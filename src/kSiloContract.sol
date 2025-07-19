// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

import { ECDSA } from "solady/utils/ECDSA.sol";
import { EIP712 } from "solady/utils/EIP712.sol";
import { Initializable } from "solady/utils/Initializable.sol";

import { Multicallable } from "solady/utils/Multicallable.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { IInsuranceStrategy } from "src/interfaces/IInsuranceStrategy.sol";

/// @title kSiloContract
/// @notice Secure intermediary for all external strategy returns and insurance fund management
/// @dev EXTERNAL ASSET FLOW: All external sources route assets through kSilo for unified management:
///      1. CUSTODIAL: Custodial addresses can ONLY transfer tokens (USDC/WBTC) directly to this contract.
///         They cannot call any functions - they only do: USDC.transfer(siloAddress, amount)
///      2. METAVAULT: MetaVault redemptions route assets directly to kSilo via redeem() calls
///      The kStrategyManager then validates balances and redistributes funds to kBatchReceivers for user redemptions.
///
/// @dev INSURANCE FUND MANAGEMENT: kSilo manages insurance funds through backend-signed orders:
///      1. Backend accumulates insurance funds from protocol profits
///      2. Backend signs deployment orders to invest insurance funds in yield strategies
///      3. Backend signs withdrawal orders to source coverage funds during losses
///      4. Pluggable strategy system allows integration with different yield strategies
///
/// @dev UNIFIED ARCHITECTURE:
///      1. External sources (custodial wallets, MetaVaults) send USDC/WBTC to kSilo
///      2. kSilo accumulates all external assets and validates balances before transfers
///      3. kStrategyManager calls transferToDestination() to send funds to kBatchReceivers
///      4. Users redeem from kBatchReceivers during settlement
///      5. Backend manages insurance fund deployment through signed orders
///
/// @dev SECURITY: Only kStrategyManager can redistribute funds. All transfers validate sufficient balance
///      using asset.balanceOf(address(this)) before executing transfers.
contract kSiloContract is Initializable, UUPSUpgradeable, OwnableRoles, EIP712, ReentrancyGuard, Multicallable {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant ADMIN_ROLE = _ROLE_0;
    uint256 public constant EMERGENCY_ADMIN_ROLE = _ROLE_1;
    uint256 public constant STRATEGY_MANAGER_ROLE = _ROLE_2;
    uint256 public constant BACKEND_SIGNER_ROLE = _ROLE_3;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice EIP712 type hash for insurance operations
    bytes32 public constant INSURANCE_OPERATION_TYPEHASH = keccak256(
        "InsuranceOperation(bytes32 strategyId,uint256 amount,bytes data,uint256 nonce,uint256 deadline,bool isDeployment)"
    );

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kSiloContract.storage.kSiloContract
    struct kSiloStorage {
        bool isPaused;
        address underlyingAsset;
        address strategyManager;
        uint256 totalDistributed;
        // Insurance fund management
        uint256 insuranceBalance;
        uint256 totalInsuranceDeposited;
        uint256 totalInsuranceWithdrawn;
        mapping(bytes32 => address) insuranceStrategies; // strategyId => strategy address
        mapping(bytes32 => uint256) deployedToStrategy; // strategyId => amount deployed
        mapping(address => uint256) nonces; // signer => nonce for replay protection
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

    // Insurance fund events
    event InsuranceAmountSet(uint256 oldAmount, uint256 newAmount, address indexed admin);
    event InsuranceStrategyRegistered(bytes32 indexed strategyId, address indexed strategy, string strategyName);
    event InsuranceStrategyUnregistered(bytes32 indexed strategyId, address indexed strategy);
    event InsuranceFundsDeployed(bytes32 indexed strategyId, uint256 amount, bytes data, bytes result);
    event InsuranceFundsWithdrawn(bytes32 indexed strategyId, uint256 amount, bytes data, bytes result);
    event InsuranceBalanceUpdated(uint256 oldBalance, uint256 newBalance, string reason);

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Paused();
    error ZeroAddress();
    error ZeroAmount();
    error InvalidOperation();
    error InsufficientBalance();
    error ContractNotPaused();

    // Insurance fund errors
    error InvalidSignature();
    error SignatureExpired();
    error InvalidNonce();
    error StrategyNotRegistered();
    error StrategyAlreadyRegistered();
    error InsufficientInsuranceBalance();
    error InvalidStrategyId();
    error InsuranceOperationFailed();

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
        $.insuranceBalance = 0;
        $.totalInsuranceDeposited = 0;
        $.totalInsuranceWithdrawn = 0;
    }

    /*//////////////////////////////////////////////////////////////
                        DISTRIBUTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        uint256 totalAmount = _getTotalAmount(amounts);
        uint256 availableBalance = $.underlyingAsset.balanceOf(address(this));
        if (availableBalance < totalAmount) revert InsufficientBalance();

        uint256 length = destinations.length;

        // Execute transfers
        for (uint256 i; i < length;) {
            if (amounts[i] > 0) {
                _transferToDestination(destinations[i], amounts[i], operationIds[i], distributionType);
            }

            unchecked {
                ++i;
            }
        }

        // totalDistributed is updated in _transferToDestination
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

    /// @notice Get insurance fund information
    /// @return insuranceBalance Current insurance balance
    /// @return totalDeposited Total insurance funds deposited
    /// @return totalWithdrawn Total insurance funds withdrawn
    function getInsuranceInfo()
        external
        view
        returns (uint256 insuranceBalance, uint256 totalDeposited, uint256 totalWithdrawn)
    {
        kSiloStorage storage $ = _getkSiloStorage();
        insuranceBalance = $.insuranceBalance;
        totalDeposited = $.totalInsuranceDeposited;
        totalWithdrawn = $.totalInsuranceWithdrawn;
    }

    /// @notice Get deployed amount for a strategy
    /// @param strategyId The strategy identifier
    /// @return deployed Amount deployed to the strategy
    function getDeployedToStrategy(bytes32 strategyId) external view returns (uint256 deployed) {
        return _getkSiloStorage().deployedToStrategy[strategyId];
    }

    /// @notice Get insurance strategy address for a strategy
    /// @param strategyId The strategy identifier
    /// @return strategy Address of the insurance strategy
    function getInsuranceStrategy(bytes32 strategyId) external view returns (address strategy) {
        return _getkSiloStorage().insuranceStrategies[strategyId];
    }

    /// @notice Get nonce for an address
    /// @param account The account address
    /// @return nonce Current nonce
    function getNonce(address account) external view returns (uint256 nonce) {
        return _getkSiloStorage().nonces[account];
    }

    /// @notice Get total available funds including insurance
    /// @return totalAvailable Total funds available for settlement
    function getTotalAvailableForSettlement() external view returns (uint256 totalAvailable) {
        kSiloStorage storage $ = _getkSiloStorage();
        return $.underlyingAsset.balanceOf(address(this)) + $.insuranceBalance;
    }

    /*//////////////////////////////////////////////////////////////
                      INSURANCE FUND MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the insurance fund amount (admin only)
    /// @param amount New insurance fund amount
    function setInsuranceAmount(uint256 amount) external onlyRoles(ADMIN_ROLE) {
        kSiloStorage storage $ = _getkSiloStorage();
        uint256 oldAmount = $.insuranceBalance;
        $.insuranceBalance = amount;

        emit InsuranceAmountSet(oldAmount, amount, msg.sender);
        emit InsuranceBalanceUpdated(oldAmount, amount, "Admin set insurance amount");
    }

    /// @notice Grants backend signer role to an address (admin only)
    /// @param signer Address to grant backend signer role to
    function grantBackendSignerRole(address signer) external onlyRoles(ADMIN_ROLE) {
        if (signer == address(0)) revert ZeroAddress();
        _grantRoles(signer, BACKEND_SIGNER_ROLE);
    }

    /// @notice Registers an insurance strategy for a strategy
    /// @param strategyId Unique identifier for the strategy
    /// @param strategy Address of the insurance strategy contract
    function registerInsuranceStrategy(bytes32 strategyId, address strategy) external onlyRoles(ADMIN_ROLE) {
        if (strategy == address(0)) revert ZeroAddress();
        if (strategyId == bytes32(0)) revert InvalidStrategyId();

        kSiloStorage storage $ = _getkSiloStorage();
        if ($.insuranceStrategies[strategyId] != address(0)) revert StrategyAlreadyRegistered();

        $.insuranceStrategies[strategyId] = strategy;

        string memory strategyName = IInsuranceStrategy(strategy).getStrategyName();
        emit InsuranceStrategyRegistered(strategyId, strategy, strategyName);
    }

    /// @notice Unregisters an insurance strategy for a strategy
    /// @param strategyId Unique identifier for the strategy
    function unregisterInsuranceStrategy(bytes32 strategyId) external onlyRoles(ADMIN_ROLE) {
        kSiloStorage storage $ = _getkSiloStorage();
        address strategy = $.insuranceStrategies[strategyId];
        if (strategy == address(0)) revert StrategyNotRegistered();

        delete $.insuranceStrategies[strategyId];

        emit InsuranceStrategyUnregistered(strategyId, strategy);
    }

    /// @notice Executes insurance fund deployment with backend signature
    /// @param strategyId Strategy identifier
    /// @param amount Amount to deploy
    /// @param data Strategy-specific data
    /// @param nonce Nonce for replay protection
    /// @param deadline Signature deadline
    /// @param signature Backend signature
    function executeInsuranceDeployment(
        bytes32 strategyId,
        uint256 amount,
        bytes calldata data,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    )
        external
        nonReentrant
        whenNotPaused
    {
        _validateInsuranceSignature(strategyId, amount, data, nonce, deadline, true, signature);
        _deployInsuranceFunds(strategyId, amount, data);
    }

    /// @notice Executes insurance fund withdrawal with backend signature
    /// @param strategyId Strategy identifier
    /// @param amount Amount to withdraw
    /// @param data Strategy-specific data
    /// @param nonce Nonce for replay protection
    /// @param deadline Signature deadline
    /// @param signature Backend signature
    function executeInsuranceWithdrawal(
        bytes32 strategyId,
        uint256 amount,
        bytes calldata data,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    )
        external
        nonReentrant
        whenNotPaused
    {
        _validateInsuranceSignature(strategyId, amount, data, nonce, deadline, false, signature);
        _withdrawInsuranceFunds(strategyId, amount, data);
    }

    /// @notice Emergency withdrawal of insurance funds (admin only)
    /// @param strategyId Strategy identifier
    /// @param amount Amount to withdraw
    /// @param data Strategy-specific data
    function emergencyWithdrawInsurance(
        bytes32 strategyId,
        uint256 amount,
        bytes calldata data
    )
        external
        onlyRoles(EMERGENCY_ADMIN_ROLE)
    {
        kSiloStorage storage $ = _getkSiloStorage();
        if (!$.isPaused) revert ContractNotPaused();

        _withdrawInsuranceFunds(strategyId, amount, data);
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
                      INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get total amount
    /// @param amounts Array of amounts
    /// @return totalAmount Total amount
    function _getTotalAmount(uint256[] calldata amounts) internal pure returns (uint256 totalAmount) {
        uint256 length = amounts.length;
        for (uint256 i; i < length;) {
            totalAmount += amounts[i];
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Transfers assets to destination
    /// @param destination The destination address (kBatchReceiver, vault, etc.)
    /// @param amount Amount to transfer
    /// @param operationId Associated operation ID
    /// @param distributionType Type of distribution ("redemption", "rebalancing", etc.)
    function _transferToDestination(
        address destination,
        uint256 amount,
        bytes32 operationId,
        string calldata distributionType
    )
        internal
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

    /// @notice Validates insurance operation signature
    function _validateInsuranceSignature(
        bytes32 strategyId,
        uint256 amount,
        bytes calldata data,
        uint256 nonce,
        uint256 deadline,
        bool isDeployment,
        bytes calldata signature
    )
        internal
    {
        if (block.timestamp > deadline) revert SignatureExpired();
        if (amount == 0) revert ZeroAmount();

        kSiloStorage storage $ = _getkSiloStorage();
        if ($.nonces[msg.sender] != nonce) revert InvalidNonce();

        // Construct EIP-712 message
        bytes32 structHash = keccak256(
            abi.encode(INSURANCE_OPERATION_TYPEHASH, strategyId, amount, keccak256(data), nonce, deadline, isDeployment)
        );

        bytes32 digest = _hashTypedData(structHash);
        address recovered = digest.recover(signature);

        if (!hasAnyRole(recovered, BACKEND_SIGNER_ROLE)) revert InvalidSignature();

        // Increment nonce
        $.nonces[msg.sender]++;
    }

    /// @notice Deploys insurance funds to strategy
    function _deployInsuranceFunds(bytes32 strategyId, uint256 amount, bytes calldata data) internal {
        kSiloStorage storage $ = _getkSiloStorage();

        if ($.insuranceBalance < amount) revert InsufficientInsuranceBalance();
        if ($.insuranceStrategies[strategyId] == address(0)) revert StrategyNotRegistered();

        // Update insurance balance
        $.insuranceBalance -= amount;
        $.deployedToStrategy[strategyId] += amount;

        // Transfer funds to strategy and execute deployment
        address strategy = $.insuranceStrategies[strategyId];
        $.underlyingAsset.safeTransfer(strategy, amount);

        try IInsuranceStrategy(strategy).deploy(amount, data) returns (bytes memory result) {
            emit InsuranceFundsDeployed(strategyId, amount, data, result);
            emit InsuranceBalanceUpdated($.insuranceBalance + amount, $.insuranceBalance, "Deployed to strategy");
        } catch {
            // Revert state changes on failure
            $.insuranceBalance += amount;
            $.deployedToStrategy[strategyId] -= amount;
            revert InsuranceOperationFailed();
        }
    }

    /// @notice Withdraws insurance funds from strategy
    function _withdrawInsuranceFunds(bytes32 strategyId, uint256 amount, bytes calldata data) internal {
        kSiloStorage storage $ = _getkSiloStorage();

        if ($.insuranceStrategies[strategyId] == address(0)) revert StrategyNotRegistered();
        if ($.deployedToStrategy[strategyId] < amount) revert InsufficientBalance();

        address strategy = $.insuranceStrategies[strategyId];

        try IInsuranceStrategy(strategy).withdraw(amount, data) returns (bytes memory result) {
            // Update balances
            $.insuranceBalance += amount;
            $.deployedToStrategy[strategyId] -= amount;
            $.totalInsuranceWithdrawn += amount;

            emit InsuranceFundsWithdrawn(strategyId, amount, data, result);
            emit InsuranceBalanceUpdated($.insuranceBalance - amount, $.insuranceBalance, "Withdrawn from strategy");
        } catch {
            revert InsuranceOperationFailed();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          EIP712 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the EIP712 domain name and version
    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return ("kSiloContract", "1");
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
