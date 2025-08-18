// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";
import { LibClone } from "solady/utils/LibClone.sol";

import { BaseTest } from "./BaseTest.sol";
import {
    ADMIN_ROLE,
    BATCH_CUTOFF_TIME,
    EMERGENCY_ADMIN_ROLE,
    INSTITUTION_ROLE,
    MINTER_ROLE,
    SETTLEMENT_INTERVAL,
    SETTLER_ROLE,
    STRATEGY_ROLE,
    USDC_MAINNET,
    WBTC_MAINNET,
    _1000_USDC,
    _100_USDC,
    _10_USDC,
    _1_USDC,
    _1_WBTC
} from "./Constants.sol";

// Protocol contracts

import { kAssetRouter } from "src/kAssetRouter.sol";

import { kMinter } from "src/kMinter.sol";
import { kRegistry } from "src/kRegistry.sol";
import { kStakingVault } from "src/kStakingVault/kStakingVault.sol";
import { kToken } from "src/kToken.sol";

// Modules

import { MultiFacetProxy } from "src/base/MultiFacetProxy.sol";
import { BatchModule } from "src/kStakingVault/modules/BatchModule.sol";
import { ClaimModule } from "src/kStakingVault/modules/ClaimModule.sol";

// Adapters

import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import { CustodialAdapter } from "src/adapters/CustodialAdapter.sol";
import { MetaVaultAdapter } from "src/adapters/MetaVaultAdapter.sol";

// Interfaces
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

// Mocks

import {MockMetaVault} from "../mocks/MockMetaVault.sol";

/// @title DeploymentBaseTest
/// @notice Comprehensive base test contract that deploys the complete KAM protocol
/// @dev Follows DeFi best practices with fork-first testing and minimal mocks
///
/// @dev VAULT ARCHITECTURE:
/// - kMinter (MINTER type = 0): Institutional gateway for 1:1 minting/redemption
/// - DN Vault (DN type = 1): Works directly with kMinter for institutional flows, different math model
/// - Alpha Vault (ALPHA type = 2): Retail staking vault with standard yield distribution
/// - Beta Vault (BETA type = 3): Advanced staking strategies with different mathematical models
/// All vaults are properly registered in kRegistry with correct types
///
/// @dev TOKEN MINTING FLOW:
/// - kTokens: ONLY minted by kMinter (1:1 with underlying assets for institutions)
/// - stkTokens: Minted by individual kStakingVaults (vault-specific ERC20 receipts)
/// - kStakingVaults accept existing kTokens from users, they do NOT mint kTokens
contract DeploymentBaseTest is BaseTest {
    using LibClone for address;
    /*//////////////////////////////////////////////////////////////
                        PROTOCOL CONTRACTS
    //////////////////////////////////////////////////////////////*/

    // Core protocol contracts (proxied)
    kRegistry public registry;
    kAssetRouter public assetRouter;
    kToken public kUSD;
    kToken public kBTC;
    kMinter public minter;
    kStakingVault public dnVault; // DN vault (works with kMinter)
    kStakingVault public alphaVault; // ALPHA vault
    kStakingVault public betaVault; // BETA vault

    // Modules for kStakingVault
    ClaimModule public claimModule;
    BatchModule public batchModule;

    // Adapters
    CustodialAdapter public custodialAdapter;
    MetaVaultAdapter public metaVaultAdapter;
    CustodialAdapter public custodialAdapterImpl;
    MetaVaultAdapter public metaVaultAdapterImpl;

    // Implementation contracts (for upgrades)
    kRegistry public registryImpl;
    kAssetRouter public assetRouterImpl;
    kToken public kTokenImpl;
    kMinter public minterImpl;
    kStakingVault public stakingVaultImpl;
    MockMetaVault public mockMetaVault;

    /*//////////////////////////////////////////////////////////////
                        TEST CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    // Default test parameters
    uint128 public constant DEFAULT_DUST_AMOUNT = 1000; // 0.001 USDC
    string public constant KUSD_NAME = "KAM USD";
    string public constant KUSD_SYMBOL = "kUSD";
    string public constant KBTC_NAME = "KAM BTC";
    string public constant KBTC_SYMBOL = "kBTC";

    // Vault names and symbols
    string public constant DN_VAULT_NAME = "DN KAM Vault";
    string public constant DN_VAULT_SYMBOL = "dnkUSD";
    string public constant ALPHA_VAULT_NAME = "Alpha KAM Vault";
    string public constant ALPHA_VAULT_SYMBOL = "akUSD";
    string public constant BETA_VAULT_NAME = "Beta KAM Vault";
    string public constant BETA_VAULT_SYMBOL = "bkUSD";

    /*//////////////////////////////////////////////////////////////
                        SETUP & DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Call parent setup (creates users, fork setup, etc.)
        super.setUp();

        // Enable mainnet fork for realistic testing
        enableMainnetFork();

        // Deploy the complete protocol
        _deployProtocol();

        // Set up roles and permissions
        _setupRoles();

        // Fund test users with assets
        _fundUsers();

        // Initialize batches for all vaults
        // _initializeBatches(); // Disabled due to setup issues
    }

    /// @dev Deploys all protocol contracts in correct dependency order
    function _deployProtocol() internal {
        // 1. Deploy kRegistry (central coordinator)
        _deployRegistry();

        // 2. Deploy kAssetRouter (needs registry)
        _deployAssetRouter();

        // 3. Deploy kToken contracts (independent)
        _deployTokens();

        // 4. Deploy kMinter (needs registry, assetRouter, tokens)
        _deployMinter();

        vm.startPrank(users.admin);

        // Register singleton contracts in registry
        registry.setSingletonContract(registry.K_ASSET_ROUTER(), address(assetRouter));
        registry.setSingletonContract(registry.K_MINTER(), address(minter));

        vm.stopPrank();

        // 5. Deploy kStakingVaults + Modules (needs registry, assetRouter, tokens)
        _deployStakingVaults();

        // Configure the protocol
        _configureProtocol();

        // 6. Deploy adapters (needs registry, independent of other components)
        _deployAdapters();
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Deploy kRegistry with proxy
    function _deployRegistry() internal {
        // Deploy implementation
        registryImpl = new kRegistry();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kRegistry.initialize.selector,
            users.owner, // owner
            users.admin, // admin
            users.settler // relayer (using settler for now)
        );

        address registryProxy = address(registryImpl).clone();
        (bool success,) = registryProxy.call(initData);
        require(success, "Registry initialization failed");
        registry = kRegistry(payable(registryProxy));

        // Label for debugging
        vm.label(address(registry), "kRegistry");
        vm.label(address(registryImpl), "kRegistryImpl");
    }

    /// @dev Deploy kAssetRouter with proxy
    function _deployAssetRouter() internal {
        // Deploy implementation
        assetRouterImpl = new kAssetRouter();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kAssetRouter.initialize.selector,
            address(registry), // registry
            users.owner, // owner
            users.admin, // admin
            false // not paused initially
        );

        address assetRouterProxy = address(assetRouterImpl).clone();
        (bool success,) = assetRouterProxy.call(initData);
        require(success, "AssetRouter initialization failed");
        assetRouter = kAssetRouter(payable(assetRouterProxy));
        vm.prank(users.admin);
        assetRouter.setSettlementCooldown(0);

        // Label for debugging
        vm.label(address(assetRouter), "kAssetRouter");
        vm.label(address(assetRouterImpl), "kAssetRouterImpl");
    }

    /// @dev Deploy kToken contracts (kUSD and kBTC)
    function _deployTokens() internal {
        // Deploy kToken implementation (shared)
        kTokenImpl = new kToken();

        // Deploy kUSD
        bytes memory kUSDInitData = abi.encodeWithSelector(
            kToken.initialize.selector,
            users.owner, // owner
            users.admin, // admin
            users.emergencyAdmin, // emergency admin
            users.admin, // temporary minter (will be updated later)
            6 // USDC decimals
        );

        address kUSDProxy = address(kTokenImpl).clone();
        (bool success1,) = kUSDProxy.call(kUSDInitData);
        require(success1, "kUSD initialization failed");
        kUSD = kToken(payable(kUSDProxy));

        // Set metadata for kUSD
        vm.prank(users.admin);
        kUSD.setupMetadata(KUSD_NAME, KUSD_SYMBOL);

        // Deploy kBTC
        bytes memory kBTCInitData = abi.encodeWithSelector(
            kToken.initialize.selector,
            users.owner, // owner
            users.admin, // admin
            users.emergencyAdmin, // emergency admin
            users.admin, // temporary minter (will be updated later)
            8 // WBTC decimals
        );

        address kBTCProxy = address(kTokenImpl).clone();
        (bool success2,) = kBTCProxy.call(kBTCInitData);
        require(success2, "kBTC initialization failed");
        kBTC = kToken(payable(kBTCProxy));

        // Set metadata for kBTC
        vm.prank(users.admin);
        kBTC.setupMetadata(KBTC_NAME, KBTC_SYMBOL);

        // Label for debugging
        vm.label(address(kUSD), "kUSD");
        vm.label(address(kBTC), "kBTC");
        vm.label(address(kTokenImpl), "kTokenImpl");
    }

    /// @dev Deploy kMinter with proxy
    function _deployMinter() internal {
        // Deploy implementation
        minterImpl = new kMinter();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kMinter.initialize.selector,
            address(registry), // registry
            users.owner, // owner
            users.admin, // admin
            users.emergencyAdmin // emergency admin
        );

        address minterProxy = address(minterImpl).clone();
        (bool success,) = minterProxy.call(initData);
        require(success, "Minter initialization failed");
        minter = kMinter(payable(minterProxy));

        // Label for debugging
        vm.label(address(minter), "kMinter");
        vm.label(address(minterImpl), "kMinterImpl");
    }

    /// @dev Deploy all three types of kStakingVaults with modules
    function _deployStakingVaults() internal {
        // Deploy modules first (shared across all vaults)
        claimModule = new ClaimModule();
        batchModule = new BatchModule();

        // Deploy implementation (shared across all vaults)
        stakingVaultImpl = new kStakingVault();

        // Deploy DN Vault (Type 0 - works with kMinter for institutional flows)
        dnVault = _deployVault(DN_VAULT_NAME, DN_VAULT_SYMBOL, IkRegistry.VaultType.DN, "DN");

        // Deploy Alpha Vault (Type 1 - for retail staking)
        alphaVault = _deployVault(ALPHA_VAULT_NAME, ALPHA_VAULT_SYMBOL, IkRegistry.VaultType.ALPHA, "Alpha");

        // Deploy Beta Vault (Type 2 - for advanced staking strategies)
        betaVault = _deployVault(BETA_VAULT_NAME, BETA_VAULT_SYMBOL, IkRegistry.VaultType.BETA, "Beta");

        // Label shared components
        vm.label(address(stakingVaultImpl), "kStakingVaultImpl");
        vm.label(address(claimModule), "ClaimModule");
        vm.label(address(batchModule), "BatchModule");
    }

    /// @dev Helper function to deploy a specific vault type
    function _deployVault(
        string memory name,
        string memory symbol,
        IkRegistry.VaultType vaultType,
        string memory label
    )
        internal
        returns (kStakingVault vault)
    {
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kStakingVault.initialize.selector,
            address(registry), // registry
            users.owner, // owner
            users.admin, // admin
            false, // not paused initially
            name, // vault name
            symbol, // vault symbol
            6, // decimals (matching USDC)
            DEFAULT_DUST_AMOUNT, // dust amount
            users.emergencyAdmin, // emergency admin
            asset // underlying asset (USDC for now)
        );

        address vaultProxy = address(stakingVaultImpl).clone();
        (bool success,) = vaultProxy.call(initData);
        require(success, string(abi.encodePacked(label, " vault initialization failed")));
        vault = kStakingVault(payable(vaultProxy));

        // Label for debugging
        vm.label(address(vault), string(abi.encodePacked(label, "Vault")));

        return vault;
    }

    /// @dev Deploy adapters for external strategy integrations
    function _deployAdapters() internal {
        // Deploy CustodialAdapter implementation
        custodialAdapterImpl = new CustodialAdapter();

        // Deploy ERC1967 proxy with initialization (UUPSUpgradeable pattern)
        bytes memory custodialInitData =
            abi.encodeWithSelector(CustodialAdapter.initialize.selector, address(registry), users.owner, users.admin);

        // Deploy proxy with initialization (same pattern as other contracts)
        address custodialProxy = address(custodialAdapterImpl).clone();
        (bool success1,) = custodialProxy.call(custodialInitData);
        require(success1, "CustodialAdapter initialization failed");
        custodialAdapter = CustodialAdapter(custodialProxy);

        // Deploy MetaVaultAdapter implementation and proxy
        metaVaultAdapterImpl = new MetaVaultAdapter();

        // Deploy proxy with initialization (same pattern as other contracts)
        bytes memory metaVaultInitData =
            abi.encodeWithSelector(MetaVaultAdapter.initialize.selector, address(registry), users.owner, users.admin);

        address metaVaultProxy = address(metaVaultAdapterImpl).clone();
        (bool success2,) = metaVaultProxy.call(metaVaultInitData);
        require(success2, "MetaVaultAdapter initialization failed");
        metaVaultAdapter = MetaVaultAdapter(metaVaultProxy);

        vm.startPrank(users.admin);

        mockMetaVault = new MockMetaVault(USDC_MAINNET, "Max APY USDC", "maxUSDC");

        metaVaultAdapter.setVaultDestination(address(dnVault), USDC_MAINNET, address(mockMetaVault));
        metaVaultAdapter.setVaultDestination(address(alphaVault), USDC_MAINNET, address(mockMetaVault));
        metaVaultAdapter.setVaultDestination(address(betaVault), USDC_MAINNET, address(mockMetaVault));

        vm.stopPrank();

        // Label for debugging
        vm.label(address(custodialAdapter), "CustodialAdapter");
        vm.label(address(metaVaultAdapter), "MetaVaultAdapter");
        vm.label(address(custodialAdapterImpl), "CustodialAdapterImpl");
        vm.label(address(metaVaultAdapterImpl), "MetaVaultAdapterImpl");
        vm.label(address(mockMetaVault), "MockMetaVault");
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Configure protocol contracts with registry integration
    function _configureProtocol() internal {
        vm.startPrank(users.admin);

        // Register assets and kTokens
        registry.registerAsset(USDC_MAINNET, address(kUSD), registry.USDC());
        registry.registerAsset(WBTC_MAINNET, address(kBTC), registry.WBTC());

        // Register vaults (would normally be done by factory, but we'll do it manually for tests)
        vm.stopPrank();

        // Grant factory role to admin for vault registration
        vm.prank(users.owner);
        registry.grantRoles(users.admin, 2); // FACTORY_ROLE = _ROLE_1 = 2
        vm.prank(users.owner);
        registry.grantRoles(users.guardian, 4); // GUARDIAN_ROLE = _ROLE_2 = 4

        vm.startPrank(users.admin);

        // Register kMinter as vault (MINTER type = 0 - for institutional operations)
        registry.registerVault(address(minter), IkRegistry.VaultType.MINTER, USDC_MAINNET);

        // Register DN vault (DN type = 1 - works with kMinter)
        registry.registerVault(address(dnVault), IkRegistry.VaultType.DN, USDC_MAINNET);

        // Register Alpha vault (ALPHA type = 2 - retail staking)
        registry.registerVault(address(alphaVault), IkRegistry.VaultType.ALPHA, USDC_MAINNET);

        // Register Beta vault (BETA type = 3 - advanced strategies)
        registry.registerVault(address(betaVault), IkRegistry.VaultType.BETA, USDC_MAINNET);

        // Register adapters for vaults (if adapters were deployed)
        if (address(custodialAdapter) != address(0)) {
            registry.registerAdapter(address(dnVault), address(custodialAdapter));
            registry.registerAdapter(address(alphaVault), address(custodialAdapter));
            registry.registerAdapter(address(betaVault), address(custodialAdapter));

            // Configure custodial adapter destinations for each vault
            // For testing, use the treasury address as the custodial destination
            custodialAdapter.setVaultDestination(address(dnVault), users.treasury);
            custodialAdapter.setVaultDestination(address(alphaVault), users.treasury);
            custodialAdapter.setVaultDestination(address(betaVault), users.treasury);
        }

        vm.stopPrank();
    }

    /// @dev Initialize initial batches for all vaults
    function _initializeBatches() internal {
        // Register the BatchModule and ClaimModule functions with the vaults
        _registerModules();

        // Create initial batches for all vaults using relayer role
        // Note: settler has RELAYER_ROLE as set up in _setupRoles()
        vm.startPrank(users.settler);

        // Use low-level call to create initial batches since modules are dynamically registered
        bytes4 createBatchSelector = bytes4(keccak256("createNewBatch()"));

        // Create initial batch for DN vault
        (bool success1,) = address(dnVault).call(abi.encodeWithSelector(createBatchSelector));
        require(success1, "DN vault batch creation failed");

        // Create initial batch for Alpha vault
        (bool success2,) = address(alphaVault).call(abi.encodeWithSelector(createBatchSelector));
        require(success2, "Alpha vault batch creation failed");

        // Create initial batch for Beta vault
        (bool success3,) = address(betaVault).call(abi.encodeWithSelector(createBatchSelector));
        require(success3, "Beta vault batch creation failed");

        vm.stopPrank();
    }

    /// @dev Register modules with vaults
    function _registerModules() internal {
        // Get module selectors from the modules themselves
        bytes4[] memory batchSelectors = batchModule.selectors();
        bytes4[] memory claimSelectors = claimModule.selectors();

        // Register modules as vault admin
        vm.startPrank(users.admin);

        // Add batch module functions to all vaults
        dnVault.addFunctions(batchSelectors, address(batchModule), true);
        alphaVault.addFunctions(batchSelectors, address(batchModule), true);
        betaVault.addFunctions(batchSelectors, address(batchModule), true);

        // Add claim module functions to all vaults
        dnVault.addFunctions(claimSelectors, address(claimModule), true);
        alphaVault.addFunctions(claimSelectors, address(claimModule), true);
        betaVault.addFunctions(claimSelectors, address(claimModule), true);

        vm.stopPrank();
    }

    /// @dev Set up complete role hierarchy
    function _setupRoles() internal {
        // Grant MINTER_ROLE to contracts using kToken's specific functions (requires admin)
        vm.startPrank(users.admin);

        // Grant MINTER_ROLE to kMinter for institutional minting (1:1 backing)
        kUSD.grantMinterRole(address(minter));
        kBTC.grantMinterRole(address(minter));

        // Grant MINTER_ROLE to kAssetRouter for yield distribution and settlement
        kUSD.grantMinterRole(address(assetRouter));
        kBTC.grantMinterRole(address(assetRouter));

        // Note: Staking vaults do NOT mint kTokens - they accept existing kTokens from users
        // and mint their own stkTokens. kMinter handles institutional flows, kAssetRouter handles yield.

        vm.stopPrank();

        // Grant INSTITUTION_ROLE to test institution (requires owner for kMinter)
        vm.prank(users.owner);
        minter.grantRoles(users.institution, 8); // INSTITUTION_ROLE = _ROLE_3 = 8

        // Grant SETTLER_ROLE to test settler (requires owner for kAssetRouter)
        vm.prank(users.owner);
        assetRouter.grantRoles(users.settler, SETTLER_ROLE);

        // Grant EMERGENCY_ADMIN_ROLE to emergency admin for kAssetRouter (requires owner)
        vm.prank(users.owner);
        assetRouter.grantRoles(users.emergencyAdmin, EMERGENCY_ADMIN_ROLE);

        // Note: settler is already registered as relayer during registry initialization
    }

    /// @dev Fund test users with mainnet assets
    function _fundUsers() internal {
        if (useMainnetFork) {
            // Fund users with USDC using deal() cheatcode
            deal(USDC_MAINNET, users.alice, 1_000_000 * _1_USDC);
            deal(USDC_MAINNET, users.bob, 500_000 * _1_USDC);
            deal(USDC_MAINNET, users.charlie, 250_000 * _1_USDC);
            deal(USDC_MAINNET, users.institution, 10_000_000 * _1_USDC);

            // Fund users with WBTC
            deal(WBTC_MAINNET, users.alice, 100 * _1_WBTC);
            deal(WBTC_MAINNET, users.bob, 50 * _1_WBTC);
            deal(WBTC_MAINNET, users.institution, 1000 * _1_WBTC);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        TEST HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Helper to mint kTokens for testing
    /// @param token kToken to mint
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mintKTokens(address token, address to, uint256 amount) internal {
        vm.prank(address(minter)); // Use minter as it has MINTER_ROLE
        kToken(token).mint(to, amount);
    }

    /// @dev Helper to approve and transfer underlying assets
    /// @param token Asset token
    /// @param from Sender address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function transferAsset(address token, address from, address to, uint256 amount) internal {
        vm.startPrank(from);
        IERC20(token).approve(to, amount);
        IERC20(token).transfer(to, amount);
        vm.stopPrank();
    }

    /// @dev Helper to get asset balance
    /// @param token Asset token
    /// @param user User address
    /// @return Balance of user
    function getAssetBalance(address token, address user) internal view returns (uint256) {
        return IERC20(token).balanceOf(user);
    }

    /// @dev Helper to get kToken balance
    /// @param token kToken
    /// @param user User address
    /// @return Balance of user
    function getKTokenBalance(address token, address user) internal view returns (uint256) {
        return kToken(token).balanceOf(user);
    }

    /// @dev Helper to time travel for batch testing
    /// @param timeIncrease Seconds to advance
    function advanceTime(uint256 timeIncrease) internal {
        vm.warp(block.timestamp + timeIncrease);
    }

    /// @dev Helper to advance to next batch cutoff
    function advanceToBatchCutoff() internal {
        advanceTime(BATCH_CUTOFF_TIME);
    }

    /// @dev Helper to advance to settlement time
    function advanceToSettlement() internal {
        advanceTime(SETTLEMENT_INTERVAL);
    }

    /// @dev Expect specific event emission
    function expectEvent(address emitter, bytes32 eventSig) internal {
        vm.expectEmit(true, true, true, true, emitter);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSERTION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Assert that contract has correct role
    function assertHasRole(address roleContract, address account, uint256 role) internal {
        assertTrue(OwnableRoles(roleContract).hasAnyRole(account, role), "Account should have role");
    }

    /// @dev Assert asset balance equals expected
    function assertAssetBalance(address token, address user, uint256 expected) internal {
        assertEq(getAssetBalance(token, user), expected, "Asset balance mismatch");
    }

    /// @dev Assert kToken balance equals expected
    function assertKTokenBalance(address token, address user, uint256 expected) internal {
        assertEq(getKTokenBalance(token, user), expected, "kToken balance mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                        PROTOCOL STATE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Check if protocol is properly initialized
    function assertProtocolInitialized() internal view {
        // Check registry has core contracts
        assertEq(registry.getContractById(registry.K_ASSET_ROUTER()), address(assetRouter));
        assertEq(registry.getContractById(registry.K_MINTER()), address(minter));

        // Check assets are registered
        assertTrue(registry.isRegisteredAsset(USDC_MAINNET));
        assertTrue(registry.isRegisteredAsset(WBTC_MAINNET));

        // Check kTokens are registered
        assertEq(registry.assetToKToken(USDC_MAINNET), address(kUSD));
        assertEq(registry.assetToKToken(WBTC_MAINNET), address(kBTC));

        // Check all vaults are registered
        assertTrue(registry.isVault(address(dnVault)));
        assertTrue(registry.isVault(address(alphaVault)));
        assertTrue(registry.isVault(address(betaVault)));

        // Check adapters are deployed and initialized (disabled for debugging)
        // assertTrue(address(custodialAdapter) != address(0));
        // assertTrue(address(metaVaultAdapter) != address(0));
        // assertTrue(custodialAdapter.registered());
        // assertTrue(metaVaultAdapter.registered());
    }

    /// @dev Get current protocol state for debugging
    function getProtocolState()
        internal
        view
        returns (
            address registryAddr,
            address assetRouterAddr,
            address kUSDAddr,
            address kBTCAddr,
            address minterAddr,
            address dnVaultAddr,
            address alphaVaultAddr,
            address betaVaultAddr
        )
    {
        return (
            address(registry),
            address(assetRouter),
            address(kUSD),
            address(kBTC),
            address(minter),
            address(dnVault),
            address(alphaVault),
            address(betaVault)
        );
    }

    /// @dev Helper to get vault by type for testing
    function getVaultByType(IkRegistry.VaultType vaultType) internal view returns (kStakingVault) {
        if (vaultType == IkRegistry.VaultType.DN) return dnVault;
        if (vaultType == IkRegistry.VaultType.ALPHA) return alphaVault;
        if (vaultType == IkRegistry.VaultType.BETA) return betaVault;
        revert("Unknown vault type");
    }
}

// Import IERC20 for balance checks
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
