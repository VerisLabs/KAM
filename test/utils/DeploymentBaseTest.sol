// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest, console2 } from "./BaseTest.sol";
import {
    ADMIN_ROLE,
    EMERGENCY_ADMIN_ROLE,
    GUARDIAN_ROLE,
    INSTITUTION_ROLE,
    MINTER_ROLE,
    RELAYER_ROLE,
    USDC_MAINNET,
    WBTC_MAINNET,
    _1000_USDC,
    _100_USDC,
    _10_USDC,
    _1_USDC,
    _1_WBTC
} from "./Constants.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

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
import { FeesModule } from "src/kStakingVault/modules/FeesModule.sol";

// Adapters
import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import { CustodialAdapter } from "src/adapters/CustodialAdapter.sol";

// Interfaces

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

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
    /*//////////////////////////////////////////////////////////////
                        PROTOCOL CONTRACTS
    //////////////////////////////////////////////////////////////*/

    // Core protocol contracts (proxied)
    ERC1967Factory public factory;
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
    FeesModule public feesModule;

    // Adapters
    CustodialAdapter public custodialAdapter;
    CustodialAdapter public custodialAdapterImpl;

    // Implementation contracts (for upgrades)
    kRegistry public registryImpl;
    kAssetRouter public assetRouterImpl;
    kMinter public minterImpl;
    kStakingVault public stakingVaultImpl;

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

        // Deploy factory for the proxies
        factory = new ERC1967Factory();

        // Deploy the complete protocol
        _deployProtocol();

        // Set up roles and permissions
        _setupRoles();

        // Fund test users with assets
        _fundUsers();

        // Initialize batches for all vaults
        _initializeBatches(); // Disabled due to setup issues
    }

    /// @dev Deploys all protocol contracts in correct dependency order
    function _deployProtocol() internal {
        // 1. Deploy kRegistry (central coordinator)
        _deployRegistry();

        // 2. Deploy kAssetRouter (needs registry)
        _deployAssetRouter();

        // 3. Deploy kMinter (needs registry, assetRouter)
        _deployMinter();

        // 4. Register singleton contracts in registry (required before deploying kTokens)
        vm.startPrank(users.admin);
        registry.setSingletonContract(registry.K_ASSET_ROUTER(), address(assetRouter));
        registry.setSingletonContract(registry.K_MINTER(), address(minter));
        vm.stopPrank();

        // 5. Deploy kToken contracts (needs minter to be registered in registry)
        _deployTokens();

        // 6. Deploy kStakingVaults + Modules (needs registry, assetRouter, tokens, and asset registration)
        _deployStakingVaults();

        // 7. Deploy adapters (needs registry, independent of other components)
        _deployAdapters();

        // Configure the protocol
        _configureProtocol();
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
            kRegistry.initialize.selector, users.owner, users.admin, users.emergencyAdmin, users.guardian, users.relayer
        );

        address registryProxy = factory.deployAndCall(address(registryImpl), users.admin, initData);
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
        bytes memory initData = abi.encodeWithSelector(kAssetRouter.initialize.selector, address(registry));

        address assetRouterProxy = factory.deployAndCall(address(assetRouterImpl), users.admin, initData);
        assetRouter = kAssetRouter(payable(assetRouterProxy));
        vm.prank(users.admin);
        assetRouter.setSettlementCooldown(0);

        // Label for debugging
        vm.label(address(assetRouter), "kAssetRouter");
        vm.label(address(assetRouterImpl), "kAssetRouterImpl");
    }

    /// @dev Deploy kToken contracts (kUSD and kBTC)
    function _deployTokens() internal {
        // Deploy kUSD through registry
        vm.startPrank(users.admin);
        address kUSDAddress = registry.registerAsset(KUSD_NAME, KUSD_SYMBOL, USDC_MAINNET, registry.USDC());
        kUSD = kToken(payable(kUSDAddress));
        kUSD.grantEmergencyRole(users.emergencyAdmin);

        address kBTCAddress = registry.registerAsset(KBTC_NAME, KBTC_SYMBOL, WBTC_MAINNET, registry.WBTC());
        kBTC = kToken(payable(kBTCAddress));
        kBTC.grantEmergencyRole(users.emergencyAdmin);
        vm.stopPrank();

        // Label for debugging
        vm.label(address(kUSD), "kUSD");
        vm.label(address(kBTC), "kBTC");
    }

    /// @dev Deploy kMinter with proxy
    function _deployMinter() internal {
        // Deploy implementation
        minterImpl = new kMinter();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(kMinter.initialize.selector, address(registry));

        address minterProxy = factory.deployAndCall(address(minterImpl), users.admin, initData);
        minter = kMinter(payable(minterProxy));

        // Label for debugging
        vm.label(address(minter), "kMinter");
        vm.label(address(minterImpl), "kMinterImpl");
    }

    /// @dev Deploy all three types of kStakingVaults with modules
    function _deployStakingVaults() internal {
        vm.startPrank(users.admin);

        // Deploy modules first (shared across all vaults)
        claimModule = new ClaimModule();
        batchModule = new BatchModule();
        feesModule = new FeesModule();

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
        vm.label(address(feesModule), "FeesModule");
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
            address(registry),
            users.owner,
            users.admin,
            false, // paused
            name,
            symbol,
            6, // decimals
            DEFAULT_DUST_AMOUNT,
            users.emergencyAdmin,
            asset // underlying asset (USDC for now)
        );

        address vaultProxy = factory.deployAndCall(address(stakingVaultImpl), users.admin, initData);
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

        // Deploy proxy with initialization using ERC1967Factory
        address custodialProxy = factory.deployAndCall(address(custodialAdapterImpl), users.admin, custodialInitData);
        custodialAdapter = CustodialAdapter(custodialProxy);

        // Label for debugging
        vm.label(address(custodialAdapter), "CustodialAdapter");
        vm.label(address(custodialAdapterImpl), "CustodialAdapterImpl");
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Configure protocol contracts with registry integration
    function _configureProtocol() internal {
        // Register Vaults
        vm.startPrank(users.admin);
        registry.registerVault(address(minter), IkRegistry.VaultType.MINTER, USDC_MAINNET);
        registry.registerVault(address(dnVault), IkRegistry.VaultType.DN, USDC_MAINNET);
        registry.registerVault(address(alphaVault), IkRegistry.VaultType.ALPHA, USDC_MAINNET);
        registry.registerVault(address(betaVault), IkRegistry.VaultType.BETA, USDC_MAINNET);

        // Register adapters for vaults (if adapters were deployed)
        if (address(custodialAdapter) != address(0)) {
            registry.registerAdapter(address(minter), address(custodialAdapter));
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
        // Note: relayer has RELAYER_ROLE as set up in _setupRoles()
        vm.startPrank(users.relayer);

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
        bytes4[] memory feesSelectors = feesModule.selectors();

        // Register modules as vault admin
        vm.startPrank(users.admin);

        // Add batch module functions to all vaults
        dnVault.addFunctions(batchSelectors, address(batchModule), true);
        alphaVault.addFunctions(batchSelectors, address(batchModule), true);
        betaVault.addFunctions(batchSelectors, address(batchModule), true);

        // Add fees module functions to all vaults
        dnVault.addFunctions(feesSelectors, address(feesModule), true);
        alphaVault.addFunctions(feesSelectors, address(feesModule), true);
        betaVault.addFunctions(feesSelectors, address(feesModule), true);

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

        registry.grantInstitutionRole(users.institution);
        vm.stopPrank();
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
        assertTrue(registry.isAsset(USDC_MAINNET));
        assertTrue(registry.isAsset(WBTC_MAINNET));

        // Check kTokens are registered
        assertEq(registry.assetToKToken(USDC_MAINNET), address(kUSD));
        assertEq(registry.assetToKToken(WBTC_MAINNET), address(kBTC));

        // Check all vaults are registered
        assertTrue(registry.isVault(address(dnVault)));
        assertTrue(registry.isVault(address(alphaVault)));
        assertTrue(registry.isVault(address(betaVault)));

        // Check adapters are deployed and initialized (disabled for debugging)
        assertTrue(address(custodialAdapter) != address(0));
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
