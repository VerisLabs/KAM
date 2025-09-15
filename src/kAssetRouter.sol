// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedEfficientHashLib } from "solady/utils/OptimizedEfficientHashLib.sol";
import { OptimizedFixedPointMathLib } from "solady/utils/OptimizedFixedPointMathLib.sol";

import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { OptimizedSafeCastLib } from "solady/utils/OptimizedSafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { kBase } from "src/base/kBase.sol";
import {
    KASSETROUTER_BATCH_ID_PROPOSED,
    KASSETROUTER_COOLDOOWN_IS_UP,
    KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE,
    KASSETROUTER_INVALID_COOLDOWN,
    KASSETROUTER_IS_PAUSED,
    KASSETROUTER_NO_PROPOSAL,
    KASSETROUTER_ONLY_KMINTER,
    KASSETROUTER_ONLY_KSTAKING_VAULT,
    KASSETROUTER_PROPOSAL_EXECUTED,
    KASSETROUTER_PROPOSAL_EXISTS,
    KASSETROUTER_PROPOSAL_NOT_FOUND,
    KASSETROUTER_WRONG_ROLE,
    KASSETROUTER_ZERO_ADDRESS,
    KASSETROUTER_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { OptimizedBytes32EnumerableSetLib } from
    "src/vendor/solady/utils/EnumerableSetLib/OptimizedBytes32EnumerableSetLib.sol";

import { IVaultAdapter } from "src/interfaces/IVaultAdapter.sol";
import { ISettleBatch, IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";

import { IVersioned } from "src/interfaces/IVersioned.sol";
import { IkMinter } from "src/interfaces/IkMinter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kAssetRouter
/// @notice Central money flow coordinator for the KAM protocol, orchestrating all asset movements and yield
/// distribution
/// @dev This contract serves as the heart of the KAM protocol's financial infrastructure, coordinating complex
/// interactions between institutional flows (kMinter), retail flows (kStakingVaults), and yield generation (DN vaults).
/// Key responsibilities include: (1) Managing asset pushes from kMinter institutional deposits to DN vaults for yield
/// generation, (2) Coordinating virtual asset transfers between kStakingVaults for optimal capital allocation,
/// (3) Processing batch settlements with yield distribution through precise kToken minting/burning operations,
/// (4) Maintaining virtual balance tracking across all vaults for accurate accounting, (5) Implementing security
/// cooldown periods for settlement proposals, (6) Executing peg protection mechanisms during market stress.
/// The contract ensures protocol integrity by maintaining the 1:1 backing guarantee through carefully orchestrated
/// money flows while enabling efficient capital utilization across the entire vault network.
contract kAssetRouter is IkAssetRouter, Initializable, UUPSUpgradeable, kBase, Multicallable {
    using OptimizedFixedPointMathLib for uint256;
    using OptimizedFixedPointMathLib for int256;
    using SafeTransferLib for address;
    using OptimizedSafeCastLib for uint256;
    using OptimizedSafeCastLib for uint128;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default cooldown period for vault settlement proposals (1 hour)
    /// @dev Provides initial security delay between proposal creation and execution, allowing guardians
    /// to verify yield calculations and detect potential errors before irreversible yield distribution
    uint256 private constant DEFAULT_VAULT_SETTLEMENT_COOLDOWN = 1 hours;

    /// @notice Maximum allowed cooldown period for vault settlement proposals (1 day)
    /// @dev Caps the maximum security delay to balance protocol safety with operational efficiency.
    /// Prevents excessive delays that could harm user experience while maintaining security standards
    uint256 private constant MAX_VAULT_SETTLEMENT_COOLDOWN = 1 days;

    /// @notice Default yield tolerance for settlement proposals (10%)
    /// @dev Provides initial yield deviation threshold to prevent settlements with excessive yield changes
    /// that could indicate errors in yield calculation or potential manipulation attempts
    uint256 private constant DEFAULT_MAX_DELTA = 1000; // 10% in basis points

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @notice Core storage structure for kAssetRouter using ERC-7201 namespaced storage pattern
    /// @dev This structure manages all state for money flow coordination and settlement operations.
    /// Uses the diamond storage pattern to avoid storage collisions in upgradeable contracts.
    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        /// @dev Monotonically increasing counter for generating unique settlement proposal IDs
        uint256 proposalCounter;
        /// @dev Current cooldown period in seconds before settlement proposals can be executed
        uint256 vaultSettlementCooldown;
        /// @dev Maximum allowed yield deviation in basis points before settlement proposal is rejected
        uint256 maxAllowedDelta;
        /// @dev Set of proposal IDs that have been executed to prevent double-execution
        OptimizedBytes32EnumerableSetLib.Bytes32Set executedProposalIds;
        /// @dev Set of all batch IDs processed by the router for tracking and management
        OptimizedBytes32EnumerableSetLib.Bytes32Set batchIds;
        /// @dev Maps each vault to its set of pending settlement proposal IDs awaiting execution
        mapping(address vault => OptimizedBytes32EnumerableSetLib.Bytes32Set) vaultPendingProposalIds;
        /// @dev Virtual balance tracking for each vault-batch combination (deposited/requested amounts)
        mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
        /// @dev Tracks requested shares for each vault-batch combination in share-based accounting
        mapping(address vault => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
        /// @dev Complete settlement proposal data indexed by unique proposal ID
        mapping(bytes32 proposalId => VaultSettlementProposal) settlementProposals;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kAssetRouter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
        0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;

    /// @notice Retrieves the kAssetRouter storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The kAssetRouterStorage struct reference for state modifications
    function _getkAssetRouterStorage() private pure returns (kAssetRouterStorage storage $) {
        assembly {
            $.slot := KASSETROUTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Disables initializers to prevent implementation contract initialization
    /// @dev Ensures the implementation contract cannot be initialized directly, only through proxies
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the kAssetRouter with protocol configuration and default parameters
    /// @dev Sets up the contract with protocol registry connection and default settlement cooldown.
    /// Must be called immediately after proxy deployment to establish connection with the protocol
    /// registry and initialize the money flow coordination system.
    /// @param registry_ Address of the kRegistry contract that manages protocol configuration
    function initialize(address registry_) external initializer {
        __kBase_init(registry_);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.vaultSettlementCooldown = DEFAULT_VAULT_SETTLEMENT_COOLDOWN;
        $.maxAllowedDelta = DEFAULT_MAX_DELTA;

        emit ContractInitialized(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            kMINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkAssetRouter
    function kAssetPush(address _asset, uint256 amount, bytes32 batchId) external payable {
        _lockReentrant();
        _checkPaused();
        _checkAmountNotZero(amount);
        address kMinter = msg.sender;
        _checkKMinter(kMinter);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Increase deposits in the batch for kMinter
        $.vaultBatchBalances[kMinter][batchId].deposited += amount.toUint128();
        emit AssetsPushed(kMinter, amount);

        _unlockReentrant();
    }

    /// @inheritdoc IkAssetRouter
    function kAssetRequestPull(address _asset, uint256 amount, bytes32 batchId) external payable {
        _lockReentrant();
        _checkPaused();
        _checkAmountNotZero(amount);
        address kMinter = msg.sender;
        _checkKMinter(kMinter);
        _checkSufficientVirtualBalance(kMinter, _asset, amount);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Account the withdrawal requset in the batch for kMinter
        $.vaultBatchBalances[kMinter][batchId].requested += amount.toUint128();

        emit AssetsRequestPulled(kMinter, _asset, amount);
        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                            kSTAKING VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkAssetRouter
    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
    {
        _lockReentrant();
        _checkPaused();
        _checkAmountNotZero(amount);
        _checkVault(msg.sender);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        _checkSufficientVirtualBalance(sourceVault, _asset, amount);

        // Update batch tracking for settlement
        $.vaultBatchBalances[sourceVault][batchId].requested += amount.toUint128();
        $.vaultBatchBalances[targetVault][batchId].deposited += amount.toUint128();

        emit AssetsTransfered(sourceVault, targetVault, _asset, amount);
        _unlockReentrant();
    }

    /// @inheritdoc IkAssetRouter
    function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable {
        _lockReentrant();
        _checkPaused();
        _checkAmountNotZero(amount);
        _checkVault(msg.sender);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Update batch tracking for settlement
        $.vaultRequestedShares[sourceVault][batchId] += amount;

        emit SharesRequestedPushed(sourceVault, batchId, amount);
        _unlockReentrant();
    }

    /// @inheritdoc IkAssetRouter
    function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable {
        _lockReentrant();
        _checkPaused();
        _checkAmountNotZero(amount);
        _checkVault(msg.sender);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Update batch tracking for settlement
        $.vaultRequestedShares[sourceVault][batchId] -= amount;

        emit SharesRequestedPulled(sourceVault, batchId, amount);
        _unlockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkAssetRouter
    function proposeSettleBatch(
        address asset,
        address vault,
        bytes32 batchId,
        uint256 totalAssets_,
        uint64 lastFeesChargedManagement,
        uint64 lastFeesChargedPerformance
    )
        external
        payable
        returns (bytes32 proposalId)
    {
        _lockReentrant();
        _checkPaused();

        require(_isRelayer(msg.sender), KASSETROUTER_WRONG_ROLE);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        require(!$.batchIds.contains(batchId), KASSETROUTER_BATCH_ID_PROPOSED);
        $.batchIds.add(batchId);

        int256 netted;
        int256 yield;
        uint256 lastTotalAssets = _virtualBalance(vault, asset);

        // Increase the counter to generate unique proposal id
        unchecked {
            $.proposalCounter++;
        }

        // To calculate the strategy yield we need to discount the deposits and requests
        // First to match last total assets

        // Example : total assets were 1000 before and there was 200 deposits and 100 withdrawal requests
        // New total assets is 1200, but this new total assets include settled deposits and withdrawals
        // So it will be 1000 + (200 - 100) +/- profit = 1100 +/- profit
        // So first we need to adjust the substract the netted as follows:
        // 1200 - (200 - 100) = 1100
        // And now we can calculate the profit as 1100 - 1000 = 100

        if (_isKMinter(vault)) {
            netted = int256(uint256($.vaultBatchBalances[vault][batchId].deposited))
                - int256(uint256($.vaultBatchBalances[vault][batchId].requested));
        } else {
            uint256 totalSupply = IkStakingVault(vault).totalSupply();
            uint256 requestedAssets = (totalSupply == 0 || totalAssets_ == 0)
                ? $.vaultRequestedShares[vault][batchId]
                : $.vaultRequestedShares[vault][batchId].fullMulDiv(totalAssets_, totalSupply);
            netted = int256(uint256($.vaultBatchBalances[vault][batchId].deposited)) - int256(uint256(requestedAssets));
        }

        uint256 totalAssetsAdjusted = uint256(int256(totalAssets_) - netted);

        yield = int256(totalAssetsAdjusted) - int256(lastTotalAssets);

        // Check if yield exceeds tolerance threshold to prevent excessive yield deviations
        if (lastTotalAssets > 0) {
            uint256 maxAllowedYield = lastTotalAssets * $.maxAllowedDelta / 10_000;
            if (yield.abs() > maxAllowedYield) {
                emit YieldExceedsMaxDeltaWarning(vault, asset, batchId, yield, maxAllowedYield);
            }
        }

        proposalId = OptimizedEfficientHashLib.hash(
            uint256(uint160(vault)), uint256(uint160(asset)), uint256(batchId), block.timestamp, $.proposalCounter
        );

        // Check if proposal already exists
        require(!$.executedProposalIds.contains(proposalId), KASSETROUTER_PROPOSAL_EXECUTED);
        require(!_isPendingProposal(vault, proposalId), KASSETROUTER_PROPOSAL_EXISTS);
        $.vaultPendingProposalIds[vault].add(proposalId);

        // Compute execution time in the future
        uint256 executeAfter;
        unchecked {
            executeAfter = block.timestamp + $.vaultSettlementCooldown;
        }

        // Store the proposal
        $.settlementProposals[proposalId] = VaultSettlementProposal({
            asset: asset,
            vault: vault,
            batchId: batchId,
            totalAssets: totalAssets_,
            netted: netted,
            yield: yield,
            executeAfter: executeAfter.toUint64(),
            lastFeesChargedManagement: lastFeesChargedManagement,
            lastFeesChargedPerformance: lastFeesChargedPerformance
        });

        emit SettlementProposed(
            proposalId,
            vault,
            batchId,
            totalAssets_,
            netted,
            yield,
            executeAfter,
            lastFeesChargedManagement,
            lastFeesChargedPerformance
        );
        _unlockReentrant();
    }

    /// @inheritdoc IkAssetRouter
    function executeSettleBatch(bytes32 proposalId) external payable {
        _lockReentrant();
        _checkPaused();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        VaultSettlementProposal storage proposal = $.settlementProposals[proposalId];

        // Validations
        address vault = proposal.vault;
        require(_isPendingProposal(vault, proposalId), KASSETROUTER_PROPOSAL_NOT_FOUND);
        require(block.timestamp >= proposal.executeAfter, KASSETROUTER_COOLDOOWN_IS_UP);

        // Mark the proposal as executed, add to the list of executed
        $.executedProposalIds.add(proposalId);
        $.vaultPendingProposalIds[vault].remove(proposalId);

        // Execute the settlement logic
        _executeSettlement(proposal);

        emit SettlementExecuted(proposalId, vault, proposal.batchId, msg.sender);

        _unlockReentrant();
    }

    /// @inheritdoc IkAssetRouter
    function cancelProposal(bytes32 proposalId) external {
        _lockReentrant();
        _checkPaused();

        require(_isGuardian(msg.sender), KASSETROUTER_WRONG_ROLE);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        VaultSettlementProposal storage proposal = $.settlementProposals[proposalId];

        address vault = proposal.vault;
        require(_isPendingProposal(vault, proposalId), KASSETROUTER_PROPOSAL_NOT_FOUND);

        $.vaultPendingProposalIds[vault].remove(proposalId);
        $.batchIds.remove(proposal.batchId);

        emit SettlementCancelled(proposalId, vault, proposal.batchId);

        _unlockReentrant();
    }

    /// @notice Internal function to execute the core settlement logic with yield distribution
    /// @dev This function performs the critical yield distribution process: (1) mints or burns kTokens
    /// to reflect yield gains/losses, (2) updates vault accounting and batch tracking, (3) coordinates
    /// the 1:1 backing maintenance. This is where the protocol's fundamental promise is maintained -
    /// the kToken supply is adjusted to precisely match underlying asset changes plus distributed yield.
    /// @param proposal The settlement proposal storage reference containing all settlement parameters
    function _executeSettlement(VaultSettlementProposal storage proposal) private {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Cache some values
        address asset = proposal.asset;
        address vault = proposal.vault;
        bytes32 batchId = proposal.batchId;
        uint256 totalAssets_ = proposal.totalAssets;
        int256 netted = proposal.netted;
        int256 yield = proposal.yield;
        bool profit = yield > 0;
        uint256 requested = $.vaultBatchBalances[vault][batchId].requested;
        address kMinter = _getKMinter();
        address kToken = _getKTokenForAsset(asset);

        IVaultAdapter adapter = IVaultAdapter(_registry().getAdapter(vault, asset));
        _checkAddressNotZero(address(adapter));

        // kMinter settlement
        if (vault == kMinter) {
            delete $.vaultBatchBalances[vault][batchId];

            if (requested > 0) {
                // Transfer assets to batch receiver for redemptions
                address receiver = IkMinter(vault).getBatchReceiver(batchId);
                _checkAddressNotZero(receiver);
                asset.safeTransfer(receiver, requested);
            }

            // If netted assets are positive(it means more deposits than withdrawals)
            if (netted > 0) {
                asset.safeTransfer(address(adapter), uint256(netted));
                emit Deposited(vault, asset, uint256(netted));
            }

            // Mark batch as settled in the vault
            ISettleBatch(vault).settleBatch(batchId);
            adapter.setTotalAssets(totalAssets_);
        } else {
            uint256 totalRequestedShares = $.vaultRequestedShares[vault][batchId];
            delete $.vaultRequestedShares[vault][batchId];

            // kMinter yield is sent to insuranceFund, cannot be minted.
            if (yield != 0) {
                if (profit) {
                    IkToken(kToken).mint(vault, uint256(yield));
                } else {
                    IkToken(kToken).burn(vault, yield.abs());
                }
                emit YieldDistributed(vault, yield);
            }

            IVaultAdapter kMinterAdapter = IVaultAdapter(_registry().getAdapter(_getKMinter(), asset));
            _checkAddressNotZero(address(kMinterAdapter));
            int256 kMinterTotalAssets = int256(kMinterAdapter.totalAssets()) - netted;
            require(kMinterTotalAssets >= 0, KASSETROUTER_ZERO_AMOUNT);
            kMinterAdapter.setTotalAssets(uint256(kMinterTotalAssets));

            // Mark batch as settled in the vault
            ISettleBatch(vault).settleBatch(batchId);
            adapter.setTotalAssets(totalAssets_);

            // If there were withdrawals we take fees on them
            if (totalRequestedShares != 0) {
                // Discount protocol fees
                uint256 netRequestedShares = totalRequestedShares * IkStakingVault(vault).netSharePrice() / IkStakingVault(vault).sharePrice();
                uint256 feeShares = totalRequestedShares - netRequestedShares;
                uint256 feeAssets = IkStakingVault(vault).convertToAssets(feeShares);

                // Burn redemption shares of staking vault corresponding to protocol fees
                if (feeShares != 0) IkStakingVault(vault).burnFees(feeShares);

                // Move fees as ktokens to treasury
                if (feeAssets != 0) {
                    IkToken(kToken).burn(vault, feeAssets);
                    IkToken(kToken).mint(_registry().getTreasury(), feeAssets);
                }
            }
            if (proposal.lastFeesChargedManagement != 0) {
                IkStakingVault(vault).notifyManagementFeesCharged(proposal.lastFeesChargedManagement);
            }

            if (proposal.lastFeesChargedPerformance != 0) {
                IkStakingVault(vault).notifyPerformanceFeesCharged(proposal.lastFeesChargedPerformance);
            }
        }

        emit BatchSettled(vault, batchId, totalAssets_);
    }

    /*////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkAssetRouter
    function setSettlementCooldown(uint256 cooldown) external {
        _checkAdmin(msg.sender);
        require(cooldown <= MAX_VAULT_SETTLEMENT_COOLDOWN, KASSETROUTER_INVALID_COOLDOWN);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        uint256 oldCooldown = $.vaultSettlementCooldown;
        $.vaultSettlementCooldown = cooldown;

        emit SettlementCooldownUpdated(oldCooldown, cooldown);
    }

    /// @notice Updates the yield tolerance threshold for settlement proposals
    /// @dev This function allows protocol governance to adjust the maximum acceptable yield deviation before
    /// settlement proposals are rejected. The yield tolerance acts as a safety mechanism to prevent settlement
    /// proposals with extremely high or low yield values that could indicate calculation errors, data corruption,
    /// or potential manipulation attempts. Setting an appropriate tolerance balances protocol safety with
    /// operational flexibility, allowing normal yield fluctuations while blocking suspicious proposals.
    /// @param maxDelta_ The new yield tolerance in basis points (e.g., 1000 = 10%)
    function setMaxAllowedDelta(uint256 maxDelta_) external {
        _checkAdmin(msg.sender);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        uint256 oldTolerance = $.maxAllowedDelta;
        $.maxAllowedDelta = maxDelta_;

        emit MaxAllowedDeltaUpdated(oldTolerance, maxDelta_);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IkAssetRouter
    function getPendingProposals(address vault) external view returns (bytes32[] memory pendingProposals) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        pendingProposals = $.vaultPendingProposalIds[vault].values();
        require(pendingProposals.length > 0, KASSETROUTER_NO_PROPOSAL);
    }

    /// @inheritdoc IkAssetRouter
    function getSettlementProposal(bytes32 proposalId)
        external
        view
        returns (VaultSettlementProposal memory proposal)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        proposal = $.settlementProposals[proposalId];
    }

    /// @inheritdoc IkAssetRouter
    function canExecuteProposal(bytes32 proposalId) external view returns (bool canExecute, string memory reason) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        VaultSettlementProposal storage proposal = $.settlementProposals[proposalId];

        if (proposal.executeAfter == 0) {
            return (false, "Proposal not found");
        }
        if (block.timestamp < proposal.executeAfter) {
            return (false, "Cooldown not passed");
        }

        return (true, "");
    }

    /// @inheritdoc IkAssetRouter
    function getSettlementCooldown() external view returns (uint256) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.vaultSettlementCooldown;
    }

    /// @notice Gets the current yield tolerance threshold for settlement proposals
    /// @dev The yield tolerance determines the maximum acceptable yield deviation before settlement proposals
    /// are automatically rejected. This acts as a safety mechanism to prevent processing of settlement proposals
    /// with excessive yield values that could indicate calculation errors or potential manipulation. The tolerance
    /// is expressed in basis points where 10000 equals 100%.
    /// @return tolerance The current yield tolerance in basis points
    function getYieldTolerance() external view returns (uint256) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.maxAllowedDelta;
    }

    function virtualBalance(address vault, address asset) external view returns (uint256) {
        return _virtualBalance(vault, asset);
    }

    /// @notice Calculates the virtual balance of assets for a vault across all its adapters
    /// @dev This function aggregates asset balances across all adapters connected to a vault to determine
    /// the total virtual balance available for operations. Essential for coordination between physical
    /// asset locations and protocol accounting. Used for settlement calculations and ensuring sufficient
    /// assets are available for redemptions and transfers within the money flow system.
    /// @param vault The vault address to calculate virtual balance for
    /// @return balance The total virtual asset balance across all vault adapters
    function _virtualBalance(address vault, address asset) private view returns (uint256 balance) {
        _isVault(vault);
        _isAsset(asset);
        IVaultAdapter adapter = IVaultAdapter(_registry().getAdapter(vault, asset));
        balance += adapter.totalAssets();
    }

    /// @notice Validates that the caller is an authorized kMinter contract
    /// @dev Ensures only kMinter can push assets and request pulls for institutional operations.
    /// Critical for maintaining proper access control in the money flow coordination system.
    /// @param user Address to validate as authorized kMinter
    function _checkKMinter(address user) private view {
        require(_isKMinter(user), KASSETROUTER_ONLY_KMINTER);
    }

    /// @notice Validates that the caller is an authorized kStakingVault contract
    /// @dev Ensures only registered vaults can request share operations and asset transfers.
    /// Essential for maintaining protocol security and preventing unauthorized money flows.
    /// @param user Address to validate as authorized vault
    function _checkVault(address user) private view {
        require(_isVault(user), KASSETROUTER_ONLY_KSTAKING_VAULT);
    }

    /// @notice Validates that an amount parameter is not zero to prevent invalid operations
    /// @dev Prevents zero-amount operations that could cause accounting errors or waste gas
    /// @param amount The amount value to validate
    function _checkAmountNotZero(uint256 amount) private pure {
        require(amount != 0, KASSETROUTER_ZERO_AMOUNT);
    }

    /// @notice Validates that an address parameter is not the zero address
    /// @dev Prevents operations with invalid zero addresses that could cause loss of funds
    /// @param addr The address to validate
    function _checkAddressNotZero(address addr) private pure {
        require(addr != address(0), KASSETROUTER_ZERO_ADDRESS);
    }

    /// @notice Check if virtual balance is sufficient
    /// @param vault Vault address
    /// @param requiredAmount Required amount
    function _checkSufficientVirtualBalance(address vault, address asset, uint256 requiredAmount) private view {
        require(_virtualBalance(vault, asset) >= requiredAmount, KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE);
    }

    /// @notice Check if caller is an admin
    /// @param user Address to check
    function _checkAdmin(address user) private view {
        require(_isAdmin(user), KASSETROUTER_WRONG_ROLE);
    }

    /// @notice Verifies contract is not paused
    function _checkPaused() private view {
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
    }

    /// @param proposalId the proposalId to verify
    /// @return bool proposal exists or not
    function _isPendingProposal(address vault, bytes32 proposalId) private view returns (bool) {
        return _getkAssetRouterStorage().vaultPendingProposalIds[vault].contains(proposalId);
    }

    /// @inheritdoc IkAssetRouter
    function isPaused() external view returns (bool) {
        return _isPaused();
    }

    /// @inheritdoc IkAssetRouter
    function getDNVaultByAsset(address asset) external view returns (address vault) {
        vault = _registry().getVaultByAssetAndType(asset, uint8(IkRegistry.VaultType.DN));
        _checkAddressNotZero(vault);
    }

    /// @inheritdoc IkAssetRouter
    function getBatchIdBalances(
        address vault,
        bytes32 batchId
    )
        external
        view
        returns (uint256 deposited, uint256 requested)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        Balances memory balances = $.vaultBatchBalances[vault][batchId];
        return (balances.deposited, balances.requested);
    }

    /// @inheritdoc IkAssetRouter
    function getRequestedShares(address vault, bytes32 batchId) external view returns (uint256) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.vaultRequestedShares[vault][batchId];
    }

    /*//////////////////////////////////////////////////////////////
                          UPGRADE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Authorize contract upgrade
    /// @param newImplementation New implementation address
    function _authorizeUpgrade(address newImplementation) internal view override {
        _checkAdmin(msg.sender);
        _checkAddressNotZero(newImplementation);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive ETH (for gas refunds, etc.)
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVersioned
    function contractName() external pure returns (string memory) {
        return "kAssetRouter";
    }

    /// @inheritdoc IVersioned
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
