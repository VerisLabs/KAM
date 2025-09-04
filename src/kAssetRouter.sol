// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OptimizedEfficientHashLib } from "src/libraries/OptimizedEfficientHashLib.sol";
import { OptimizedFixedPointMathLib } from "src/libraries/OptimizedFixedPointMathLib.sol";

import { OptimizedSafeCastLib } from "src/libraries/OptimizedSafeCastLib.sol";
import { Initializable } from "src/vendor/Initializable.sol";
import { Multicallable } from "src/vendor/Multicallable.sol";
import { SafeTransferLib } from "src/vendor/SafeTransferLib.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";

import { kBase } from "src/base/kBase.sol";
import {
    KASSETROUTER_BATCH_ID_PROPOSED,
    KASSETROUTER_COOLDOOWN_IS_UP,
    KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE,
    KASSETROUTER_INVALID_COOLDOWN,
    KASSETROUTER_INVALID_VAULT,
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
import { OptimizedBytes32EnumerableSetLib } from "src/libraries/OptimizedBytes32EnumerableSetLib.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kAssetRouter
/// @notice Router contract for managing all the money flows between protocol actors
/// @dev Inherits from kBase and Multicallable
contract kAssetRouter is IkAssetRouter, Initializable, UUPSUpgradeable, kBase, Multicallable {
    using OptimizedFixedPointMathLib for uint256;
    using SafeTransferLib for address;
    using OptimizedSafeCastLib for uint256;
    using OptimizedSafeCastLib for uint128;
    using OptimizedBytes32EnumerableSetLib for OptimizedBytes32EnumerableSetLib.Bytes32Set;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default cooldown period for vault settlements
    uint256 private constant DEFAULT_VAULT_SETTLEMENT_COOLDOWN = 1 hours;

    /// @notice Maximum cooldown period for vault settlements
    uint256 private constant MAX_VAULT_SETTLEMENT_COOLDOWN = 1 days;

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        uint256 proposalCounter;
        uint256 vaultSettlementCooldown;
        OptimizedBytes32EnumerableSetLib.Bytes32Set executedProposalIds;
        OptimizedBytes32EnumerableSetLib.Bytes32Set batchIds;
        mapping(address vault => OptimizedBytes32EnumerableSetLib.Bytes32Set) vaultPendingProposalIds;
        mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
        mapping(address vault => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
        mapping(bytes32 proposalId => VaultSettlementProposal) settlementProposals;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kAssetRouter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
        0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;

    /// @dev Returns the kAssetRouter storage pointer
    function _getkAssetRouterStorage() private pure returns (kAssetRouterStorage storage $) {
        assembly {
            $.slot := KASSETROUTER_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the kAssetRouter with asset and admin configuration
    /// @param registry_ Address of the kRegistry contract
    function initialize(address registry_) external initializer {
        __kBase_init(registry_);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.vaultSettlementCooldown = DEFAULT_VAULT_SETTLEMENT_COOLDOWN;

        emit ContractInitialized(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            kMINTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Push assets from kMinter to designated DN vault
    /// @param _asset The asset being deposited
    /// @param amount Amount of assets being pushed
    /// @param batchId The batch ID from the DN vault
    function kAssetPush(address _asset, uint256 amount, bytes32 batchId) external payable {
        _unlockReentrant();
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
        address kMinter = msg.sender;
        require(_isKMinter(kMinter), KASSETROUTER_WRONG_ROLE);
        require(amount != 0, KASSETROUTER_ZERO_AMOUNT);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Increase deposits in the batch for kMinter
        $.vaultBatchBalances[kMinter][batchId].deposited += amount.toUint128();
        emit AssetsPushed(kMinter, amount);
        _lockReentrant();
    }

    /// @notice Request to pull assets for kMinter redemptions
    /// @param _asset The asset to redeem
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kAssetRequestPull(address _asset, address _vault, uint256 amount, bytes32 batchId) external payable {
        _unlockReentrant();
        require(amount != 0, KASSETROUTER_ZERO_AMOUNT);
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
        address kMinter = msg.sender;
        require(_isKMinter(kMinter), KASSETROUTER_ONLY_KMINTER);
        address vault = _getDNVaultByAsset(_asset);
        require(_virtualBalance(vault, _asset) >= amount, KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Account the withdrawal requset in the batch for kMinter
        $.vaultBatchBalances[kMinter][batchId].requested += amount.toUint128();

        // Set batch receiver for the vault, this contract will receive the assets
        // requested in this batch
        address batchReceiver = IkStakingVault(_vault).createBatchReceiver(batchId);
        require(batchReceiver != address(0), KASSETROUTER_ZERO_ADDRESS);

        emit AssetsRequestPulled(kMinter, _asset, batchReceiver, amount);
        _lockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                            kSTAKING VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer assets between kStakingVaults
    /// @param sourceVault The vault to transfer assets from
    /// @param targetVault The vault to transfer assets to
    /// @param _asset The asset to transfer
    /// @param amount Amount of assets to transfer
    /// @param batchId The batch ID for this transfer
    /// @notice It's only a virtual transfer, no assets are moved
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
        _unlockReentrant();
        require(amount != 0, KASSETROUTER_ZERO_AMOUNT);
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
        require(_isVault(msg.sender), KASSETROUTER_ONLY_KSTAKING_VAULT);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Verify virtual balance
        uint256 virtualBalance;
        if (sourceVault == _getKMinter()) {
            virtualBalance = _virtualBalance(_getDNVaultByAsset(_asset), _asset);
        } else {
            virtualBalance = _virtualBalance(sourceVault, _asset);
        }

        require(virtualBalance >= amount, KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE);
        // Update batch tracking for settlement
        $.vaultBatchBalances[sourceVault][batchId].requested += amount.toUint128();
        $.vaultBatchBalances[targetVault][batchId].deposited += amount.toUint128();

        emit AssetsTransfered(sourceVault, targetVault, _asset, amount);
        _lockReentrant();
    }

    /// @notice Request to pull shares for kStakingVault redemptions
    /// @param sourceVault The vault to redeem shares from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kSharesRequestPush(address sourceVault, uint256 amount, bytes32 batchId) external payable {
        _unlockReentrant();
        require(amount != 0, KASSETROUTER_ZERO_AMOUNT);
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
        require(_isVault(msg.sender), KASSETROUTER_ONLY_KSTAKING_VAULT);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Update batch tracking for settlement
        $.vaultRequestedShares[sourceVault][batchId] += amount;

        emit SharesRequestedPushed(sourceVault, batchId, amount);
        _lockReentrant();
    }

    /// @notice Request to pull shares for kStakingVault redemptions
    /// @param sourceVault The vault to redeem shares from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kSharesRequestPull(address sourceVault, uint256 amount, bytes32 batchId) external payable {
        _unlockReentrant();
        require(amount != 0, KASSETROUTER_ZERO_AMOUNT);
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
        require(_isVault(msg.sender), KASSETROUTER_ONLY_KSTAKING_VAULT);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Update batch tracking for settlement
        $.vaultRequestedShares[sourceVault][batchId] -= amount;

        emit SharesRequestedPulled(sourceVault, batchId, amount);
        _lockReentrant();
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Propose a settlement for a vault's batch, including all new accounting
    /// @param asset Asset address
    /// @param vault Vault address to settle
    /// @param batchId Batch ID to settle
    /// @param totalAssets_ Total assets in the vault with Deposited and Requested and Shares
    /// @param netted Netted amount in current batch
    /// @param yield Yield in current batch
    /// @param profit Whether the batch is profitable
    /// @return proposalId The unique identifier for this proposal
    function proposeSettleBatch(
        address asset,
        address vault,
        bytes32 batchId,
        uint256 totalAssets_,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        external
        payable
        returns (bytes32 proposalId)
    {
        _unlockReentrant();
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
        require(_isRelayer(msg.sender), KASSETROUTER_WRONG_ROLE);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        require(!$.batchIds.contains(batchId), KASSETROUTER_BATCH_ID_PROPOSED);
        $.batchIds.add(batchId);

        // Increase the counter to generate unique proposal id
        unchecked {
            $.proposalCounter++;
        }
        proposalId = OptimizedEfficientHashLib.hash(
            uint256(uint160(vault)), uint256(batchId), block.timestamp, $.proposalCounter
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
            profit: profit,
            executeAfter: executeAfter
        });

        emit SettlementProposed(proposalId, vault, batchId, totalAssets_, netted, yield, profit, executeAfter);
    }

    /// @notice Execute a settlement proposal after cooldown period
    /// @param proposalId The proposal ID to execute
    function executeSettleBatch(bytes32 proposalId) external payable {
        _lockReentrant();
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);

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

    /// @notice Cancel a settlement proposal before execution
    /// @notice Guardian can cancel a settlement proposal if some data is wrong
    /// @param proposalId The proposal ID to cancel
    function cancelProposal(bytes32 proposalId) external {
        _lockReentrant();
        require(!_isPaused(), KASSETROUTER_IS_PAUSED);
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

    /// @notice Internal function to execute settlement logic
    /// @param proposal The settlement proposal to execute
    function _executeSettlement(VaultSettlementProposal storage proposal) private {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Cache some values
        address asset = proposal.asset;
        address vault = proposal.vault;
        bytes32 batchId = proposal.batchId;
        uint256 totalAssets_ = proposal.totalAssets;
        uint256 netted = proposal.netted;
        uint256 yield = proposal.yield;
        bool profit = proposal.profit;
        uint256 requested = $.vaultBatchBalances[vault][batchId].requested;

        address kToken = _getKTokenForAsset(asset);

        // Track wether it was originally a kMinter
        // Since kMinters are treated as DN vaults in some operations
        bool isKMinter; // for event Deposited

        // Clear batch balances
        delete $.vaultBatchBalances[vault][batchId];
        delete $.vaultRequestedShares[vault][batchId];

        // kMinter settlement
        if (vault == _getKMinter()) {
            // kMinter settlement: handle institutional deposits and redemptions
            isKMinter = true;

            // Redirect to DN vault
            vault = _getDNVaultByAsset(asset);

            if (requested > 0) {
                // Transfer assets to batch receiver for redemptions
                address receiver = IkStakingVault(vault).getSafeBatchReceiver(batchId);
                require(receiver != address(0), KASSETROUTER_ZERO_ADDRESS);
                asset.safeTransfer(receiver, requested);
            }
        } else {
            // kMinter yield is sent to insuranceFund, cannot be minted.
            if (yield > 0) {
                if (profit) {
                    IkToken(kToken).mint(vault, yield);
                    emit YieldDistributed(vault, yield, true);
                } else {
                    IkToken(kToken).burn(vault, yield);
                    emit YieldDistributed(vault, yield, false);
                }
            }
        }

        // Fetch adapters of the vault(Initially one adapter per vault)
        // That might change in future upgrades
        address[] memory adapters = _registry().getAdapters(vault);
        IAdapter adapter = IAdapter(adapters[0]);

        // If netted assets are positive(it means more deposits than withdrawals)
        if (netted > 0) {
            // Deposit the net deposits into the DN strategy by default
            address dnVault = _getDNVaultByAsset(asset);

            // If it was originally the minter
            if (vault == dnVault && isKMinter) {
                // at some point we will have multiple adapters for a vault
                // for now we just use the first one
                require(adapters[0] != address(0), KASSETROUTER_ZERO_ADDRESS);
                asset.safeTransfer(address(adapter), netted);
                adapter.deposit(asset, netted, vault);
            }

            emit Deposited(vault, asset, netted, isKMinter);
        }

        // Update vault's total assets
        if (_registry().getVaultType(vault) > 0) {
            adapter.setTotalAssets(vault, asset, totalAssets_);
        }

        // Mark batch as settled in the vault
        IkStakingVault(vault).settleBatch(batchId);

        emit BatchSettled(vault, batchId, totalAssets_);
    }

    /*////////////////////////////////////////////////////////////
                          ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the cooldown period for settlement proposals
    /// @param cooldown New cooldown period in seconds
    function setSettlementCooldown(uint256 cooldown) external {
        require(_isAdmin(msg.sender), KASSETROUTER_WRONG_ROLE);
        require(cooldown <= MAX_VAULT_SETTLEMENT_COOLDOWN, KASSETROUTER_INVALID_COOLDOWN);

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        uint256 oldCooldown = $.vaultSettlementCooldown;
        $.vaultSettlementCooldown = cooldown;

        emit SettlementCooldownUpdated(oldCooldown, cooldown);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get All the pendingProposals
    /// @return pendingProposals An array of proposalIds
    function getPendingProposals(address vault) external view returns (bytes32[] memory pendingProposals) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        pendingProposals = $.vaultPendingProposalIds[vault].values();
        require(pendingProposals.length > 0, KASSETROUTER_NO_PROPOSAL);
    }

    /// @notice Get details of a settlement proposal
    /// @param proposalId The proposal ID
    /// @return proposal The settlement proposal details
    function getSettlementProposal(bytes32 proposalId)
        external
        view
        returns (VaultSettlementProposal memory proposal)
    {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        proposal = $.settlementProposals[proposalId];
    }

    /// @notice Check if a proposal can be executed
    /// @param proposalId The proposal ID
    /// @return canExecute Whether the proposal can be executed
    /// @return reason Reason if cannot execute
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

    /// @notice Get the current settlement cooldown period
    /// @return cooldown The cooldown period in seconds
    function getSettlementCooldown() external view returns (uint256) {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        return $.vaultSettlementCooldown;
    }

    /// @notice gets the virtual balance of a vault
    /// @param vault the vault address
    /// @param asset the asset address
    /// @return balance the balance of the vault in all adapters.
    function _virtualBalance(address vault, address asset) internal view returns (uint256 balance) {
        address[] memory assets = _getVaultAssets(vault);
        address[] memory adapters = _registry().getAdapters(vault);
        uint256 length = adapters.length;
        for (uint256 i; i < length; ++i) {
            IAdapter adapter = IAdapter(adapters[i]);
            // For now, assume single asset per vault (use first asset)
            balance += adapter.totalAssets(vault, assets[0]);
        }
    }

    /// @notice verifies if a proposal is pending or not
    /// @param vault the vault address
    /// @param proposalId the proposalId to verify
    /// @return bool proposal exists or not
    function _isPendingProposal(address vault, bytes32 proposalId) internal view returns (bool) {
        return _getkAssetRouterStorage().vaultPendingProposalIds[vault].contains(proposalId);
    }

    /// @notice Check if contract is paused
    /// @return True if paused
    function isPaused() external view returns (bool) {
        return _isPaused();
    }

    /// @notice Gets the DN vault address for a given asset
    /// @param asset The asset address
    /// @return vault The corresponding DN vault address
    /// @dev Reverts if asset not supported
    function getDNVaultByAsset(address asset) external view returns (address vault) {
        vault = _registry().getVaultByAssetAndType(asset, uint8(IkRegistry.VaultType.DN));
        require(vault != address(0), KASSETROUTER_INVALID_VAULT);
    }

    /// @notice Get batch balances for a vault
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return deposited Amount deposited in this batch
    /// @return requested Amount requested in this batch
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

    /// @notice Get requested shares for a vault batch
    /// @param vault Vault address
    /// @param batchId Batch ID
    /// @return Requested shares amount
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
        require(_isAdmin(msg.sender), KASSETROUTER_WRONG_ROLE);
        require(newImplementation != address(0), KASSETROUTER_ZERO_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Receive ETH (for gas refunds, etc.)
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the contract name
    /// @return Contract name
    function contractName() external pure returns (string memory) {
        return "kAssetRouter";
    }

    /// @notice Returns the contract version
    /// @return Contract version
    function contractVersion() external pure returns (string memory) {
        return "1.0.0";
    }
}
