// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { Initializable } from "solady/utils/Initializable.sol";
import { Multicallable } from "solady/utils/Multicallable.sol";
import { SafeCastLib } from "solady/utils/SafeCastLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { UUPSUpgradeable } from "solady/utils/UUPSUpgradeable.sol";

import { kBase } from "src/base/kBase.sol";

import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkAssetRouter } from "src/interfaces/IkAssetRouter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { IkToken } from "src/interfaces/IkToken.sol";

/// @title kAssetRouter
contract kAssetRouter is IkAssetRouter, Initializable, UUPSUpgradeable, kBase, Multicallable {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;
    using SafeCastLib for uint256;
    using SafeCastLib for uint128;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant DEFAULT_VAULT_SETTLEMENT_COOLDOWN = 1 hours;
    uint256 private constant MAX_VAULT_SETTLEMENT_COOLDOWN = 1 days;

    /*//////////////////////////////////////////////////////////////
                            STORAGE LAYOUT
    //////////////////////////////////////////////////////////////*/

    /// @custom:storage-location erc7201:kam.storage.kAssetRouter
    struct kAssetRouterStorage {
        uint256 vaultSettlementCooldown;
        mapping(address account => mapping(bytes32 batchId => Balances)) vaultBatchBalances;
        mapping(address vault => mapping(bytes32 batchId => uint256)) vaultRequestedShares;
        mapping(bytes32 proposalId => VaultSettlementProposal) settlementProposals;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.kAssetRouter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant KASSETROUTER_STORAGE_LOCATION =
        0x72fdaf6608fcd614cdab8afd23d0b707bfc44e685019cc3a5ace611655fe7f00;

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
    function kAssetPush(
        address _asset,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
    {
        if(_isPaused()) revert IsPaused();
        address kMinter = msg.sender;
        if(!_isKMinter(kMinter)) revert WrongRole();
        if (amount == 0) revert ZeroAmount();
        
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.vaultBatchBalances[kMinter][batchId].deposited += amount.toUint128();
        emit AssetsPushed(kMinter, amount);
    }

    /// @notice Request to pull assets for kMinter redemptions
    /// @param _asset The asset to redeem
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kAssetRequestPull(
        address _asset,
        address _vault,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if(_isPaused()) revert IsPaused();
        address kMinter = msg.sender;
        if(!_isKMinter(kMinter)) revert OnlyMinter();
        address vault = _getDNVaultByAsset(_asset);
        if (_virtualBalance(vault, _asset) < amount) {
            revert InsufficientVirtualBalance();
        }

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        $.vaultBatchBalances[kMinter][batchId].requested += amount.toUint128();

        // Set batch receiver for the vault
        address batchReceiver = IkStakingVault(_vault).createBatchReceiver(batchId);
        if (batchReceiver == address(0)) revert ZeroAddress();

        emit AssetsRequestPulled(kMinter, _asset, batchReceiver, amount);
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
    function kAssetTransfer(
        address sourceVault,
        address targetVault,
        address _asset,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if(_isPaused()) revert IsPaused();
        if(!_isVault(msg.sender)) revert OnlyStakingVault();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        uint256 virtualBalance;
        if (sourceVault == _getKMinter()) {
            virtualBalance = _virtualBalance(_getDNVaultByAsset(_asset), _asset);
        } else {
            virtualBalance = _virtualBalance(sourceVault, _asset);
        }

        if (virtualBalance < amount) {
            revert InsufficientVirtualBalance();
        }
        // Update batch tracking for settlement
        $.vaultBatchBalances[sourceVault][batchId].requested += amount.toUint128();
        $.vaultBatchBalances[targetVault][batchId].deposited += amount.toUint128();

        emit AssetsTransfered(sourceVault, targetVault, _asset, amount);
    }

    /// @notice Request to pull shares for kStakingVault redemptions
    /// @param sourceVault The vault to redeem shares from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kSharesRequestPush(
        address sourceVault,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if(_isPaused()) revert IsPaused();
        if(!_isVault(msg.sender)) revert OnlyStakingVault();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        $.vaultRequestedShares[sourceVault][batchId] += amount;

        emit SharesRequestedPushed(sourceVault, batchId, amount);
    }

    /// @notice Request to pull shares for kStakingVault redemptions
    /// @param sourceVault The vault to redeem shares from
    /// @param amount Amount requested for redemption
    /// @param batchId The batch ID for this redemption
    function kSharesRequestPull(
        address sourceVault,
        uint256 amount,
        bytes32 batchId
    )
        external
        payable
        nonReentrant
    {
        if (amount == 0) revert ZeroAmount();
        if(_isPaused()) revert IsPaused();
        if(!_isVault(msg.sender)) revert OnlyStakingVault();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        $.vaultRequestedShares[sourceVault][batchId] -= amount;

        emit SharesRequestedPulled(sourceVault, batchId, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Propose a settlement for a vault's batch
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
        nonReentrant
        returns (bytes32 proposalId)
    {
        if(_isPaused()) revert IsPaused();
        if(!_isRelayer(msg.sender)) revert WrongRole();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        // Generate unique proposal ID
        proposalId = keccak256(abi.encodePacked(vault, batchId, block.timestamp));

        // Check if proposal already exists
        if ($.settlementProposals[proposalId].executeAfter != 0) revert ProposalAlreadyExists();
        

        uint256 executeAfter = block.timestamp + $.vaultSettlementCooldown;

        // Store the proposal
        $.settlementProposals[proposalId] = VaultSettlementProposal({
            asset: asset,
            vault: vault,
            batchId: batchId,
            totalAssets: totalAssets_,
            netted: netted,
            yield: yield,
            profit: profit,
            executeAfter: executeAfter,
            executed: false,
            cancelled: false
        });

        emit SettlementProposed(proposalId, vault, batchId, totalAssets_, netted, yield, profit, executeAfter);
    }

    /// @notice Execute a settlement proposal after cooldown period
    /// @param proposalId The proposal ID to execute
    function executeSettleBatch(bytes32 proposalId) external nonReentrant {
        if(_isPaused()) revert IsPaused();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        VaultSettlementProposal storage proposal = $.settlementProposals[proposalId];

        // Validations
        if (proposal.executeAfter == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalCancelled();
        if (block.timestamp < proposal.executeAfter) {
            revert CooldownNotPassed();
        }

        // Mark as executed
        proposal.executed = true;

        // Execute the settlement logic
        _executeSettlement(proposal);

        emit SettlementExecuted(proposalId, proposal.vault, proposal.batchId, msg.sender);
    }

    /// @notice Cancel a settlement proposal before execution
    /// @param proposalId The proposal ID to cancel
    function cancelProposal(bytes32 proposalId) external nonReentrant {
        if(_isPaused()) revert IsPaused();
        if(!_isGuardian(msg.sender)) revert WrongRole();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        VaultSettlementProposal storage proposal = $.settlementProposals[proposalId];

        // Validations
        if (proposal.executeAfter == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalCancelled();

        // Mark as cancelled
        proposal.cancelled = true;

        emit SettlementCancelled(proposalId, proposal.vault, proposal.batchId);
    }

    /// @notice Update a settlement proposal before execution
    /// @param proposalId The proposal ID to update
    /// @param totalAssets_ New total assets value
    /// @param netted New netted amount
    /// @param yield New yield amount
    /// @param profit New profit status
    function updateProposal(
        bytes32 proposalId,
        uint256 totalAssets_,
        uint256 netted,
        uint256 yield,
        bool profit
    )
        external
        nonReentrant
    {
        if(_isPaused()) revert IsPaused();
        if(!_isRelayer(msg.sender)) revert WrongRole();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        VaultSettlementProposal storage proposal = $.settlementProposals[proposalId];

        // Validations
        if (proposal.executeAfter == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalCancelled();

        // Update proposal parameters
        proposal.totalAssets = totalAssets_;
        proposal.netted = netted;
        proposal.yield = yield;
        proposal.profit = profit;

        emit SettlementUpdated(proposalId, totalAssets_, netted, yield, profit);
    }

    /// @notice Internal function to execute settlement logic
    /// @param proposal The settlement proposal to execute
    function _executeSettlement(VaultSettlementProposal storage proposal) private {
        kAssetRouterStorage storage $ = _getkAssetRouterStorage();

        address asset = proposal.asset;
        address vault = proposal.vault;
        bytes32 batchId = proposal.batchId;
        uint256 totalAssets_ = proposal.totalAssets;
        uint256 netted = proposal.netted;
        uint256 yield = proposal.yield;
        bool profit = proposal.profit;
        uint256 requested = $.vaultBatchBalances[vault][batchId].requested;

        address kToken = _getKTokenForAsset(asset);
        bool isKMinter; // for event Deposited

        // Clear batch balances
        delete $.vaultBatchBalances[vault][batchId];
        delete $.vaultRequestedShares[vault][batchId];

        // kMinter settlement
        if (vault == _getKMinter()) {
            // kMinter settlement: handle institutional deposits and redemptions
            isKMinter = true;

            vault = _getDNVaultByAsset(asset);

            if (requested > 0) {
                // Transfer assets to batch receiver for redemptions
                address receiver = IkStakingVault(vault).getSafeBatchReceiver(batchId);
                if (receiver == address(0)) revert ZeroAddress();
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

        address[] memory adapters = _registry().getAdapters(vault);
        IAdapter adapter = IAdapter(adapters[0]);

        if (netted > 0) {
            address dnVault = _getDNVaultByAsset(asset);
            if (vault == dnVault) {
                // at some point we will have multiple adapters for a vault
                // for now we just use the first one
                if (adapters[0] == address(0)) revert ZeroAddress();
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

    /// @notice Set contract pause state
    /// @param paused New pause state
    function setPaused(bool paused) external {
        if(!_isEmergencyAdmin(msg.sender)) revert WrongRole();

        _setPaused(paused);
        emit Paused(paused);
    }

    /// @notice Set the cooldown period for settlement proposals
    /// @param cooldown New cooldown period in seconds
    function setSettlementCooldown(uint256 cooldown) external {
        if(!_isAdmin(msg.sender)) revert WrongRole();
        if (cooldown > MAX_VAULT_SETTLEMENT_COOLDOWN) revert InvalidCooldown();

        kAssetRouterStorage storage $ = _getkAssetRouterStorage();
        uint256 oldCooldown = $.vaultSettlementCooldown;
        $.vaultSettlementCooldown = cooldown;

        emit SettlementCooldownUpdated(oldCooldown, cooldown);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        if (proposal.executed) {
            return (false, "Already executed");
        }
        if (proposal.cancelled) {
            return (false, "Proposal cancelled");
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
        for (uint256 i; i < length;) {
            IAdapter adapter = IAdapter(adapters[i]);
            // For now, assume single asset per vault (use first asset)
            balance += adapter.totalAssets(vault, assets[0]);

            unchecked {
                ++i;
            }
        }
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
        if (vault == address(0)) revert InvalidVault(vault);
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
        if(!_isAdmin(msg.sender)) revert WrongRole();
        if (newImplementation == address(0)) revert ZeroAddress();
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
