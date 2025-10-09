// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import { IVersioned } from "kam/src/interfaces/IVersioned.sol";

interface IRegistry is IVersioned {
    /* //////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a singleton contract is registered in the protocol
    /// @param id The unique identifier for the contract (e.g., K_MINTER, K_ASSET_ROUTER)
    /// @param contractAddress The address of the registered singleton contract
    event SingletonContractSet(bytes32 indexed id, address indexed contractAddress);

    /// @notice Emitted when a new vault is registered in the protocol
    /// @param vault The vault contract address
    /// @param asset The underlying asset the vault manages
    /// @param vaultType The classification type of the vault
    event VaultRegistered(address indexed vault, address indexed asset, VaultType indexed vaultType);

    /// @notice Emitted when a vault is removed from the protocol
    /// @param vault The vault contract address being removed
    event VaultRemoved(address indexed vault);

    /// @notice Emitted when an asset and its kToken are registered
    /// @param asset The underlying asset address
    /// @param kToken The corresponding kToken address
    event AssetRegistered(address indexed asset, address indexed kToken);

    /// @notice Emitted when an asset is added to the supported set
    /// @param asset The newly supported asset address
    event AssetSupported(address indexed asset);

    /// @notice Emitted when an adapter is registered for a vault
    /// @param vault The vault receiving the adapter
    /// @param asset The asset of the vault
    /// @param adapter The adapter contract address
    event AdapterRegistered(address indexed vault, address asset, address indexed adapter);

    /// @notice Emitted when an adapter is removed from a vault
    /// @param vault The vault losing the adapter
    /// @param asset The asset of the vault
    /// @param adapter The adapter being removed
    event AdapterRemoved(address indexed vault, address asset, address indexed adapter);

    /// @notice Emitted when a new kToken is deployed
    /// @param kTokenContract The deployed kToken address
    /// @param name_ The kToken name
    /// @param symbol_ The kToken symbol
    /// @param decimals_ The kToken decimals (matches underlying)
    event KTokenDeployed(address indexed kTokenContract, string name_, string symbol_, uint8 decimals_);

    /// @notice Emitted when the kToken implementation is updated
    /// @param implementation The new implementation address
    event KTokenImplementationSet(address indexed implementation);

    /// @notice Emitted when ERC20 assets are rescued from the contract
    /// @param asset The rescued asset address
    /// @param to The recipient address
    /// @param amount The amount rescued
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);

    /// @notice Emitted when ETH is rescued from the contract
    /// @param asset The recipient address (asset field for consistency)
    /// @param amount The amount of ETH rescued
    event RescuedETH(address indexed asset, uint256 amount);

    /// @notice Emitted when the treasury address is updated
    /// @param treasury The new treasury address
    event TreasurySet(address indexed treasury);

    /// @notice Emitted when a hurdle rate is set for an asset
    /// @param asset The asset receiving the hurdle rate
    /// @param hurdleRate The hurdle rate in basis points
    event HurdleRateSet(address indexed asset, uint16 hurdleRate);

    /// @notice Emitted when a vault-target-selector permission is registered
    /// @param vault The vault receiving the permission
    /// @param target The target contract address
    /// @param selector The function selector being allowed
    event VaultTargetSelectorRegistered(address indexed vault, address indexed target, bytes4 indexed selector);

    /// @notice Emitted when a vault-target-selector permission is removed
    /// @param vault The vault losing the permission
    /// @param target The target contract address
    /// @param selector The function selector being removed
    event VaultTargetSelectorRemoved(address indexed vault, address indexed target, bytes4 indexed selector);

    /* //////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emergency function to rescue accidentally sent assets (ETH or ERC20) from the contract
    /// @dev This function provides a recovery mechanism for assets mistakenly sent to the registry. It includes
    /// critical safety checks: (1) Only callable by ADMIN_ROLE to prevent unauthorized access, (2) Cannot rescue
    /// registered protocol assets to prevent draining legitimate funds, (3) Validates amounts and balances.
    /// For ETH rescue, use address(0) as the asset parameter. The function ensures protocol integrity by
    /// preventing rescue of assets that are part of normal protocol operations.
    /// @param asset_ The asset address to rescue (use address(0) for ETH)
    /// @param to_ The destination address that will receive the rescued assets
    /// @param amount_ The amount of assets to rescue (must not exceed contract balance)
    function rescueAssets(address asset_, address to_, uint256 amount_) external payable;

    /// @notice Registers a core singleton contract in the protocol
    /// @dev Only callable by ADMIN_ROLE. Ensures single source of truth for protocol contracts.
    /// @param id Unique contract identifier (e.g., K_MINTER, K_ASSET_ROUTER)
    /// @param contractAddress Address of the singleton contract
    function setSingletonContract(bytes32 id, address contractAddress) external payable;

    /// @notice Registers a new underlying asset in the protocol and deploys its corresponding kToken
    /// @dev This function performs critical asset onboarding: (1) Validates the asset isn't already registered,
    /// (2) Adds asset to the supported set and singleton registry, (3) Deploys a new kToken contract with
    /// matching decimals, (4) Establishes bidirectional asset-kToken mapping, (5) Grants minting privileges
    /// to kMinter. The function automatically inherits decimals from the underlying asset for consistency.
    /// Only callable by ADMIN_ROLE to maintain protocol security and prevent unauthorized token creation.
    /// @param name The name for the kToken (e.g., "KAM USDC")
    /// @param symbol The symbol for the kToken (e.g., "kUSDC")
    /// @param asset The underlying asset contract address to register
    /// @param id The unique identifier for singleton asset storage (e.g., USDC, WBTC)
    /// @param maxMintPerBatch Maximum amount of the asset that can be minted in a single batch
    /// @param maxBurnPerBatch Maximum amount of the asset that can be redeemed in a single batch
    /// @return The deployed kToken contract address
    function registerAsset(
        string memory name,
        string memory symbol,
        address asset,
        bytes32 id,
        uint256 maxMintPerBatch,
        uint256 maxBurnPerBatch
    )
        external
        payable
        returns (address);

    /// @notice Registers a new vault contract in the protocol's vault management system
    /// @dev This function integrates vaults into the protocol by: (1) Validating the vault isn't already registered,
    /// (2) Verifying the asset is supported by the protocol, (3) Classifying the vault by type for routing,
    /// (4) Establishing vault-asset relationships for both forward and reverse lookups, (5) Setting as primary
    /// vault for the asset-type combination if it's the first registered. The vault type determines routing
    /// logic and strategy selection (DN for institutional, ALPHA/BETA for different risk profiles).
    /// Only callable by ADMIN_ROLE to ensure proper vault vetting and integration.
    /// @param vault The vault contract address to register
    /// @param type_ The vault classification type (DN, ALPHA, BETA, etc.) determining its role
    /// @param asset The underlying asset address this vault will manage
    function registerVault(address vault, VaultType type_, address asset) external payable;

    /// @notice Registers an external protocol adapter for a vault
    /// @dev Enables yield strategy integrations through external DeFi protocols. Only callable by ADMIN_ROLE.
    /// @param vault The vault address receiving the adapter
    /// @param asset The vault underlying asset
    /// @param adapter The adapter contract address
    function registerAdapter(address vault, address asset, address adapter) external payable;

    /// @notice Removes an adapter from a vault's registered adapter set
    /// @dev This disables a specific external protocol integration for the vault. Only callable by ADMIN_ROLE
    /// to ensure proper risk assessment before removing yield strategies.
    /// @param vault The vault address to remove the adapter from
    /// @param asset The vault underlying asset
    /// @param adapter The adapter address to remove
    function removeAdapter(address vault, address asset, address adapter) external payable;

    /// @notice Grants institution role to enable privileged protocol access
    /// @dev Only callable by VENDOR_ROLE. Institutions gain access to kMinter and other premium features.
    /// @param institution_ The address to grant institution privileges
    function grantInstitutionRole(address institution_) external payable;

    /// @notice Grants vendor role for vendor management capabilities
    /// @dev Only callable by ADMIN_ROLE. Vendors can grant institution roles and manage vendor vaults.
    /// @param vendor_ The address to grant vendor privileges
    function grantVendorRole(address vendor_) external payable;

    /// @notice Grants relayer role for external vault operations
    /// @dev Only callable by ADMIN_ROLE. Relayers manage external vaults and set hurdle rates.
    /// @param relayer_ The address to grant relayer privileges
    function grantRelayerRole(address relayer_) external payable;

    /// @notice Grants manager role for vault adapter operations
    /// @dev Only callable by ADMIN_ROLE. Managers can execute calls in the vault adapter.
    /// @param manager_ The address to grant manager privileges
    function grantManagerRole(address manager_) external payable;

    /// @notice Retrieves a singleton contract address by identifier
    /// @dev Reverts if contract not registered. Used for protocol contract discovery.
    /// @param id Contract identifier (e.g., K_MINTER, K_ASSET_ROUTER)
    /// @return The contract address
    function getContractById(bytes32 id) external view returns (address);

    /// @notice Gets all protocol-supported asset addresses
    /// @dev Returns the complete whitelist of supported underlying assets.
    /// @return Array of all supported asset addresses
    function getAllAssets() external view returns (address[] memory);

    /// @notice Retrieves core protocol contract addresses in one call
    /// @dev Optimized getter for frequently accessed contracts. Reverts if either not set.
    /// @return kMinter The kMinter contract address
    /// @return kAssetRouter The kAssetRouter contract address
    function getCoreContracts() external view returns (address kMinter, address kAssetRouter);

    /// @notice Gets all vaults that support a specific asset
    /// @dev Enables discovery of all vaults capable of handling an asset across different types.
    /// @param asset Asset address to query
    /// @return Array of vault addresses supporting the asset
    function getVaultsByAsset(address asset) external view returns (address[] memory);

    /// @notice Retrieves the primary vault for an asset-type combination
    /// @dev Used for routing operations to the appropriate vault. Reverts if not found.
    /// @param asset The asset address
    /// @param vaultType The vault type classification
    /// @return The vault address for the asset-type pair
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address);

    /// @notice Gets the classification type of a vault
    /// @dev Returns the VaultType enum value for routing and strategy selection.
    /// @param vault The vault address to query
    /// @return The vault's type classification
    function getVaultType(address vault) external view returns (uint8);

    /// @notice Checks if an address has admin privileges
    /// @dev Admin role has broad protocol management capabilities.
    /// @param user The address to check
    /// @return True if address has ADMIN_ROLE
    function isAdmin(address user) external view returns (bool);

    /// @notice Checks if an address has emergency admin privileges
    /// @dev Emergency admin can perform critical safety operations.
    /// @param user The address to check
    /// @return True if address has EMERGENCY_ADMIN_ROLE
    function isEmergencyAdmin(address user) external view returns (bool);

    /// @notice Checks if an address has guardian privileges
    /// @dev Guardian acts as circuit breaker for settlement proposals.
    /// @param user The address to check
    /// @return True if address has GUARDIAN_ROLE
    function isGuardian(address user) external view returns (bool);

    /// @notice Checks if an address has relayer privileges
    /// @dev Relayer manages external vault operations and hurdle rates.
    /// @param user The address to check
    /// @return True if address has RELAYER_ROLE
    function isRelayer(address user) external view returns (bool);

    /// @notice Checks if an address is a qualified institution
    /// @dev Institutions have access to privileged operations like kMinter.
    /// @param user The address to check
    /// @return True if address has INSTITUTION_ROLE
    function isInstitution(address user) external view returns (bool);

    /// @notice Checks if an address has vendor privileges
    /// @dev Vendors can grant institution roles and manage vendor vaults.
    /// @param user The address to check
    /// @return True if address has VENDOR_ROLE
    function isVendor(address user) external view returns (bool);

    /// @notice Checks if an address has manager privileges
    /// @dev Managers can execute calls in the vault adapter.
    /// @param user The address to check
    /// @return True if address has MANAGER_ROLE
    function isManager(address user) external view returns (bool);

    /// @notice Checks if an asset is supported by the protocol
    /// @dev Used for validation before operations. Checks supportedAssets set membership.
    /// @param asset The asset address to verify
    /// @return True if asset is in the protocol whitelist
    function isAsset(address asset) external view returns (bool);

    /// @notice Checks if a vault is registered in the protocol
    /// @dev Used for validation before vault operations. Checks allVaults set membership.
    /// @param vault The vault address to verify
    /// @return True if vault is registered
    function isVault(address vault) external view returns (bool);

    /// @notice Gets the adapter registered for a specific vault and asset
    /// @dev Returns external protocol integration enabling yield strategies. Reverts if no adapter is set.
    /// @param vault The vault address to query
    /// @param asset The underlying asset of the vault
    /// @return The adapter address for the vault-asset pair
    function getAdapter(address vault, address asset) external view returns (address);

    /// @notice Checks if a specific adapter is registered for a vault
    /// @dev Used to validate adapter-vault relationships before operations.
    /// @param vault The vault address to check
    /// @param asset The underlying asset of the vault
    /// @param adapter The adapter address to verify
    /// @return True if adapter is registered for the vault
    function isAdapterRegistered(address vault, address asset, address adapter) external view returns (bool);

    /// @notice Gets all assets managed by a specific vault
    /// @dev Most vaults manage single asset, some (like kMinter) handle multiple.
    /// @param vault The vault address to query
    /// @return Array of asset addresses the vault manages
    function getVaultAssets(address vault) external view returns (address[] memory);

    /// @notice Gets the kToken address for a specific underlying asset
    /// @dev Critical for minting/redemption operations. Reverts if no kToken exists.
    /// @param asset The underlying asset address
    /// @return The corresponding kToken address
    function assetToKToken(address asset) external view returns (address);

    /// @notice Gets all registered vaults in the protocol
    /// @dev Returns array of all vault addresses that have been registered through registerVault().
    /// Includes both active and inactive vaults. Used for protocol monitoring and management operations.
    /// @return Array of all registered vault addresses
    function getAllVaults() external view returns (address[] memory);

    /// @notice Gets the protocol treasury address
    /// @dev Treasury receives protocol fees and serves as emergency fund holder.
    /// @return The treasury address
    function getTreasury() external view returns (address);

    /// @notice Sets the hurdle rate for a specific asset
    /// @dev Only relayer can set hurdle rates (performance thresholds). Ensures hurdle rate doesn't exceed 100%.
    /// Asset must be registered before setting hurdle rate. Sets minimum performance threshold for yield distribution.
    /// @param asset The asset address to set hurdle rate for
    /// @param hurdleRate The hurdle rate in basis points (100 = 1%)
    function setHurdleRate(address asset, uint16 hurdleRate) external payable;

    /// @notice Gets the hurdle rate for a specific asset
    /// @dev Returns minimum performance threshold in basis points for yield distribution.
    /// Asset must be registered to query hurdle rate.
    /// @param asset The asset address to query
    /// @return The hurdle rate in basis points
    function getHurdleRate(address asset) external view returns (uint16);

    /// @notice Removes a vault from the protocol registry
    /// @dev This function deregisters a vault, removing it from the active vault set. This operation should be
    /// used carefully as it affects routing and asset management. Only callable by ADMIN_ROLE to ensure proper
    /// decommissioning procedures are followed. Note that this doesn't clear all vault mappings for gas efficiency.
    /// @param vault The vault contract address to remove from the registry
    function removeVault(address vault) external payable;

    /// @notice Sets the treasury address
    /// @dev Treasury receives protocol fees and serves as emergency fund holder. Only callable by ADMIN_ROLE.
    /// @param treasury_ The new treasury address
    function setTreasury(address treasury_) external payable;

    /// @notice Sets maximum mint and redeem amounts per batch for an asset
    /// @dev Only callable by ADMIN_ROLE. Helps manage liquidity and risk for high-volume assets.
    /// @param asset The asset address to set limits for
    /// @param maxMintPerBatch_ Maximum amount of the asset that can be minted in a single batch
    /// @param maxBurnPerBatch_ Maximum amount of the asset that can be redeemed in a single batch
    function setAssetBatchLimits(address asset, uint256 maxMintPerBatch_, uint256 maxBurnPerBatch_) external payable;

    /// @notice Gets the maximum mint amount per batch for an asset
    /// @dev Used to enforce minting limits for liquidity and risk management. Reverts if asset not registered.
    /// @param asset The asset address to query
    /// @return The maximum mint amount per batch
    function getMaxMintPerBatch(address asset) external view returns (uint256);

    /// @notice Gets the maximum redeem amount per batch for an asset
    /// @dev Used to enforce redemption limits for liquidity and risk management. Reverts if asset not registered.
    /// @param asset The asset address to query
    /// @return The maximum redeem amount per batch
    function getMaxBurnPerBatch(address asset) external view returns (uint256);

    /* //////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    enum VaultType {
        MINTER,
        DN,
        ALPHA,
        BETA,
        GAMMA,
        DELTA,
        EPSILON,
        ZETA,
        ETA,
        THETA,
        IOTA,
        KAPPA,
        LAMBDA,
        MU,
        NU,
        XI,
        OMICRON,
        PI,
        RHO,
        SIGMA,
        TAU,
        UPSILON,
        PHI,
        CHI,
        PSI,
        OMEGA,
        VAULT_27,
        VAULT_28,
        VAULT_29,
        VAULT_30,
        VAULT_31,
        VAULT_32,
        VAULT_33,
        VAULT_34,
        VAULT_35,
        VAULT_36,
        VAULT_37,
        VAULT_38,
        VAULT_39,
        VAULT_40,
        VAULT_41,
        VAULT_42,
        VAULT_43,
        VAULT_44,
        VAULT_45,
        VAULT_46,
        VAULT_47,
        VAULT_48,
        VAULT_49,
        VAULT_50,
        VAULT_51,
        VAULT_52,
        VAULT_53,
        VAULT_54,
        VAULT_55,
        VAULT_56,
        VAULT_57,
        VAULT_58,
        VAULT_59,
        VAULT_60,
        VAULT_61,
        VAULT_62,
        VAULT_63,
        VAULT_64,
        VAULT_65,
        VAULT_66,
        VAULT_67,
        VAULT_68,
        VAULT_69,
        VAULT_70,
        VAULT_71,
        VAULT_72,
        VAULT_73,
        VAULT_74,
        VAULT_75,
        VAULT_76,
        VAULT_77,
        VAULT_78,
        VAULT_79,
        VAULT_80,
        VAULT_81,
        VAULT_82,
        VAULT_83,
        VAULT_84,
        VAULT_85,
        VAULT_86,
        VAULT_87,
        VAULT_88,
        VAULT_89,
        VAULT_90,
        VAULT_91,
        VAULT_92,
        VAULT_93,
        VAULT_94,
        VAULT_95,
        VAULT_96,
        VAULT_97,
        VAULT_98,
        VAULT_99,
        VAULT_100,
        VAULT_101,
        VAULT_102,
        VAULT_103,
        VAULT_104,
        VAULT_105,
        VAULT_106,
        VAULT_107,
        VAULT_108,
        VAULT_109,
        VAULT_110,
        VAULT_111,
        VAULT_112,
        VAULT_113,
        VAULT_114,
        VAULT_115,
        VAULT_116,
        VAULT_117,
        VAULT_118,
        VAULT_119,
        VAULT_120,
        VAULT_121,
        VAULT_122,
        VAULT_123,
        VAULT_124,
        VAULT_125,
        VAULT_126,
        VAULT_127,
        VAULT_128,
        VAULT_129,
        VAULT_130,
        VAULT_131,
        VAULT_132,
        VAULT_133,
        VAULT_134,
        VAULT_135,
        VAULT_136,
        VAULT_137,
        VAULT_138,
        VAULT_139,
        VAULT_140,
        VAULT_141,
        VAULT_142,
        VAULT_143,
        VAULT_144,
        VAULT_145,
        VAULT_146,
        VAULT_147,
        VAULT_148,
        VAULT_149,
        VAULT_150,
        VAULT_151,
        VAULT_152,
        VAULT_153,
        VAULT_154,
        VAULT_155,
        VAULT_156,
        VAULT_157,
        VAULT_158,
        VAULT_159,
        VAULT_160,
        VAULT_161,
        VAULT_162,
        VAULT_163,
        VAULT_164,
        VAULT_165,
        VAULT_166,
        VAULT_167,
        VAULT_168,
        VAULT_169,
        VAULT_170,
        VAULT_171,
        VAULT_172,
        VAULT_173,
        VAULT_174,
        VAULT_175,
        VAULT_176,
        VAULT_177,
        VAULT_178,
        VAULT_179,
        VAULT_180,
        VAULT_181,
        VAULT_182,
        VAULT_183,
        VAULT_184,
        VAULT_185,
        VAULT_186,
        VAULT_187,
        VAULT_188,
        VAULT_189,
        VAULT_190,
        VAULT_191,
        VAULT_192,
        VAULT_193,
        VAULT_194,
        VAULT_195,
        VAULT_196,
        VAULT_197,
        VAULT_198,
        VAULT_199,
        VAULT_200,
        VAULT_201,
        VAULT_202,
        VAULT_203,
        VAULT_204,
        VAULT_205,
        VAULT_206,
        VAULT_207,
        VAULT_208,
        VAULT_209,
        VAULT_210,
        VAULT_211,
        VAULT_212,
        VAULT_213,
        VAULT_214,
        VAULT_215,
        VAULT_216,
        VAULT_217,
        VAULT_218,
        VAULT_219,
        VAULT_220,
        VAULT_221,
        VAULT_222,
        VAULT_223,
        VAULT_224,
        VAULT_225,
        VAULT_226,
        VAULT_227,
        VAULT_228,
        VAULT_229,
        VAULT_230,
        VAULT_231,
        VAULT_232,
        VAULT_233,
        VAULT_234,
        VAULT_235,
        VAULT_236,
        VAULT_237,
        VAULT_238,
        VAULT_239,
        VAULT_240,
        VAULT_241,
        VAULT_242,
        VAULT_243,
        VAULT_244,
        VAULT_245,
        VAULT_246,
        VAULT_247,
        VAULT_248,
        VAULT_249,
        VAULT_250,
        VAULT_251,
        VAULT_252,
        VAULT_253,
        VAULT_254,
        VAULT_255
    }
}
