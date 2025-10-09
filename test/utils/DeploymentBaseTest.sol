// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest } from "./BaseTest.sol";
import { ADMIN_ROLE, _1_USDC, _1_WBTC } from "./Constants.sol";
import { OptimizedOwnableRoles } from "solady/auth/OptimizedOwnableRoles.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

// Protocol contracts

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";
import { kAssetRouter } from "kam/src/kAssetRouter.sol";
import { kBatchReceiver } from "kam/src/kBatchReceiver.sol";
import { kMinter } from "kam/src/kMinter.sol";
import { kRegistry } from "kam/src/kRegistry/kRegistry.sol";
import { kStakingVault } from "kam/src/kStakingVault/kStakingVault.sol";
import { kToken } from "kam/src/kToken.sol";

// Modules
import { AdapterGuardianModule } from "kam/src/kRegistry/modules/AdapterGuardianModule.sol";
import { ReaderModule } from "kam/src/kStakingVault/modules/ReaderModule.sol";

// Adapters
import { VaultAdapter } from "kam/src/adapters/VaultAdapter.sol";

// Interfaces
import { IRegistry, IkRegistry } from "kam/src/interfaces/IkRegistry.sol";

contract DeploymentBaseTest is BaseTest {
    // Core protocol contracts (proxied)
    ERC1967Factory public factory;
    kRegistry public registry;
    kAssetRouter public assetRouter;
    kToken public kUSD;
    kToken public kBTC;
    kMinter public minter;
    IkStakingVault public dnVault; // DN vault (works with kMinter)
    IkStakingVault public alphaVault; // ALPHA vault
    IkStakingVault public betaVault; // BETA vault
    kBatchReceiver public batchReceiver;

    // Modules for kStakingVault
    ReaderModule public readerModule;

    // Adapters
    VaultAdapter public minterAdapterUSDC;
    VaultAdapter public minterAdapterWBTC;
    VaultAdapter public DNVaultAdapterUSDC;
    VaultAdapter public ALPHAVaultAdapterUSDC;
    VaultAdapter public BETHAVaultAdapterUSDC;
    VaultAdapter public vaultAdapter6;
    VaultAdapter public vaultAdapterImpl;

    // Implementation contracts (for upgrades)
    kRegistry public registryImpl;
    kAssetRouter public assetRouterImpl;
    kMinter public minterImpl;
    kStakingVault public stakingVaultImpl;

    /* //////////////////////////////////////////////////////////////
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

    /* //////////////////////////////////////////////////////////////
                        SETUP & DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Call parent setup (creates users, etc.)
        super.setUp();

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

    /* //////////////////////////////////////////////////////////////
                        DEPLOYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _deployRegistry() internal {
        // Deploy implementation
        registryImpl = new kRegistry();

        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kRegistry.initialize.selector,
            users.owner,
            users.admin,
            users.emergencyAdmin,
            users.guardian,
            users.relayer,
            users.treasury
        );

        address registryProxy = factory.deployAndCall(address(registryImpl), users.admin, initData);
        registry = kRegistry(payable(registryProxy));

        AdapterGuardianModule registryModule = new AdapterGuardianModule();
        bytes4[] memory registrySelectors = registryModule.selectors();

        vm.prank(users.owner);
        // Add registry module functions to all vaults
        kRegistry(payable(address(registry))).addFunctions(registrySelectors, address(registryModule), true);

        // Label for debugging
        vm.label(address(registry), "kRegistry");
        vm.label(address(registryImpl), "kRegistryImpl");
    }

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

    function _deployTokens() internal {
        // Deploy kUSD through registry using mock USDC address
        vm.startPrank(users.admin);
        address kUSDAddress = registry.registerAsset(
            KUSD_NAME, KUSD_SYMBOL, tokens.usdc, registry.USDC(), type(uint256).max, type(uint256).max
        );
        kUSD = kToken(payable(kUSDAddress));
        kUSD.grantEmergencyRole(users.emergencyAdmin);

        address kBTCAddress = registry.registerAsset(
            KBTC_NAME, KBTC_SYMBOL, tokens.wbtc, registry.WBTC(), type(uint256).max, type(uint256).max
        );
        kBTC = kToken(payable(kBTCAddress));
        kBTC.grantEmergencyRole(users.emergencyAdmin);
        vm.stopPrank();

        // Label for debugging
        vm.label(address(kUSD), "kUSD");
        vm.label(address(kBTC), "kBTC");
    }

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

    function _deployStakingVaults() internal {
        vm.startPrank(users.admin);

        // Deploy implementation (shared across all vaults)
        stakingVaultImpl = new kStakingVault();

        // Deploy DN Vault (Type 0 - works with kMinter for institutional flows)
        dnVault = _deployVault(DN_VAULT_NAME, DN_VAULT_SYMBOL, "DN");

        // Deploy Alpha Vault (Type 1 - for retail staking)
        alphaVault = _deployVault(ALPHA_VAULT_NAME, ALPHA_VAULT_SYMBOL, "Alpha");

        // Deploy Beta Vault (Type 2 - for advanced staking strategies)
        betaVault = _deployVault(BETA_VAULT_NAME, BETA_VAULT_SYMBOL, "Beta");

        // Label shared components
        vm.label(address(stakingVaultImpl), "kStakingVaultImpl");
        vm.label(address(readerModule), "ReaderModule");
    }

    function _deployVault(string memory name, string memory symbol, string memory label)
        internal
        returns (IkStakingVault vault)
    {
        // Deploy proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            kStakingVault.initialize.selector,
            users.owner,
            address(registry),
            false, // paused
            name,
            symbol,
            6, // decimals
            tokens.usdc // underlying asset (USDC for now)
        );

        address vaultProxy = factory.deployAndCall(address(stakingVaultImpl), users.admin, initData);
        vault = IkStakingVault(payable(vaultProxy));

        // Label for debugging
        vm.label(address(vault), string(abi.encodePacked(label, "Vault")));

        return vault;
    }

    function _deployAdapters() internal {
        // Deploy VaultAdapter implementation
        vaultAdapterImpl = new VaultAdapter();

        // Deploy ERC1967 proxy with initialization (UUPSUpgradeable pattern)
        bytes memory adapterInitData = abi.encodeWithSelector(VaultAdapter.initialize.selector, address(registry));

        // Deploy proxy with initialization using ERC1967Factory
        minterAdapterUSDC = VaultAdapter(factory.deployAndCall(address(vaultAdapterImpl), users.admin, adapterInitData));
        minterAdapterWBTC = VaultAdapter(factory.deployAndCall(address(vaultAdapterImpl), users.admin, adapterInitData));
        DNVaultAdapterUSDC =
            VaultAdapter(factory.deployAndCall(address(vaultAdapterImpl), users.admin, adapterInitData));
        ALPHAVaultAdapterUSDC =
            VaultAdapter(factory.deployAndCall(address(vaultAdapterImpl), users.admin, adapterInitData));
        BETHAVaultAdapterUSDC =
            VaultAdapter(factory.deployAndCall(address(vaultAdapterImpl), users.admin, adapterInitData));
        vaultAdapter6 = VaultAdapter(factory.deployAndCall(address(vaultAdapterImpl), users.admin, adapterInitData));

        // Label for debugging
        vm.label(address(minterAdapterUSDC), "VaultAdapter1");
        vm.label(address(minterAdapterWBTC), "VaultAdapter2");
        vm.label(address(DNVaultAdapterUSDC), "VaultAdapter3");
        vm.label(address(ALPHAVaultAdapterUSDC), "VaultAdapter4");
        vm.label(address(BETHAVaultAdapterUSDC), "VaultAdapter5");
        vm.label(address(vaultAdapter6), "VaultAdapter6");
        vm.label(address(vaultAdapterImpl), "VaultAdapterImpl");
    }

    /* //////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _configureProtocol() internal {
        // Register Vaults
        vm.startPrank(users.admin);
        registry.registerVault(address(minter), IRegistry.VaultType.MINTER, tokens.usdc);
        registry.registerVault(address(dnVault), IRegistry.VaultType.DN, tokens.usdc);
        registry.registerVault(address(alphaVault), IRegistry.VaultType.ALPHA, tokens.usdc);
        registry.registerVault(address(betaVault), IRegistry.VaultType.BETA, tokens.usdc);

        // Register adapters for vaults (if adapters were deployed)
        registry.registerAdapter(address(minter), tokens.usdc, address(minterAdapterUSDC));
        registry.registerAdapter(address(minter), tokens.wbtc, address(minterAdapterWBTC));
        registry.registerAdapter(address(dnVault), tokens.usdc, address(DNVaultAdapterUSDC));
        registry.registerAdapter(address(alphaVault), tokens.usdc, address(ALPHAVaultAdapterUSDC));
        registry.registerAdapter(address(betaVault), tokens.usdc, address(BETHAVaultAdapterUSDC));

        IkRegistry(address(registry))
            .setAdapterAllowedSelector(
                address(minterAdapterUSDC), tokens.usdc, 1, bytes4(keccak256("transfer(address,uint256)")), true
            );

        IkRegistry(address(registry))
            .setAdapterAllowedSelector(
                address(ALPHAVaultAdapterUSDC), tokens.usdc, 1, bytes4(keccak256("transfer(address,uint256)")), true
            );

        registry.setAssetBatchLimits(address(dnVault), type(uint256).max, type(uint256).max);
        registry.setAssetBatchLimits(address(alphaVault), type(uint256).max, type(uint256).max);
        registry.setAssetBatchLimits(address(betaVault), type(uint256).max, type(uint256).max);

        dnVault.setMaxTotalAssets(type(uint128).max);
        alphaVault.setMaxTotalAssets(type(uint128).max);
        betaVault.setMaxTotalAssets(type(uint128).max);

        vm.stopPrank();

        // Give admin permissions to router
        vm.prank(users.owner);
        registry.grantRoles(address(assetRouter), ADMIN_ROLE);
    }

    function _initializeBatches() internal {
        _registerModules();

        vm.startPrank(users.relayer);

        bytes4 createBatchSelector = bytes4(keccak256("createNewBatch()"));

        (bool success1,) = address(dnVault).call(abi.encodeWithSelector(createBatchSelector));
        require(success1, "DN vault batch creation failed");

        (bool success2,) = address(alphaVault).call(abi.encodeWithSelector(createBatchSelector));
        require(success2, "Alpha vault batch creation failed");

        (bool success3,) = address(betaVault).call(abi.encodeWithSelector(createBatchSelector));
        require(success3, "Beta vault batch creation failed");

        // // Create initial batch for Minter vault
        // (bool success4,) = address(minter).call(abi.encodeWithSelector(createBatchSelector));
        // require(success4, "Minter vault batch creation failed");

        vm.stopPrank();
    }

    function _registerModules() internal {
        readerModule = new ReaderModule();
        bytes4[] memory readerSelectors = readerModule.selectors();

        // Register modules as vault admin
        vm.startPrank(users.owner);

        kStakingVault(payable(address(dnVault))).addFunctions(readerSelectors, address(readerModule), true);
        kStakingVault(payable(address(alphaVault))).addFunctions(readerSelectors, address(readerModule), true);
        kStakingVault(payable(address(betaVault))).addFunctions(readerSelectors, address(readerModule), true);

        vm.stopPrank();
    }

    /// @dev Set up complete role hierarchy
    function _setupRoles() internal {
        vm.startPrank(users.admin);
        kUSD.grantMinterRole(address(minter));
        kBTC.grantMinterRole(address(minter));
        kUSD.grantMinterRole(address(assetRouter));
        kBTC.grantMinterRole(address(assetRouter));

        registry.grantInstitutionRole(users.institution);
        registry.grantInstitutionRole(users.institution2);
        registry.grantInstitutionRole(users.institution3);
        registry.grantInstitutionRole(users.institution4);
        vm.stopPrank();
    }

    /// @dev Fund test users with test assets
    function _fundUsers() internal {
        mockUSDC.mint(users.alice, 1_000_000 * _1_USDC);
        mockUSDC.mint(users.bob, 500_000 * _1_USDC);
        mockUSDC.mint(users.charlie, 250_000 * _1_USDC);
        mockUSDC.mint(users.institution, 10_000_000 * _1_USDC);
        mockUSDC.mint(users.institution2, 10_000_000 * _1_USDC);
        mockUSDC.mint(users.institution3, 10_000_000 * _1_USDC);
        mockUSDC.mint(users.institution4, 10_000_000 * _1_USDC);

        mockWBTC.mint(users.alice, 100 * _1_WBTC);
        mockWBTC.mint(users.bob, 50 * _1_WBTC);
        mockWBTC.mint(users.institution, 1000 * _1_WBTC);
    }

    /* //////////////////////////////////////////////////////////////
                        TEST HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mintKTokens(address token, address to, uint256 amount) internal {
        vm.prank(address(minter)); // Use minter as it has MINTER_ROLE
        kToken(token).mint(to, amount);
    }

    function getAssetBalance(address token, address user) internal view returns (uint256) {
        return kToken(token).balanceOf(user);
    }

    function getKTokenBalance(address token, address user) internal view returns (uint256) {
        return kToken(token).balanceOf(user);
    }

    function expectEvent(address emitter, bytes32 eventSig) internal {
        vm.expectEmit(true, true, true, true, emitter);
    }

    /* //////////////////////////////////////////////////////////////
                        ASSERTION HELPERS
    //////////////////////////////////////////////////////////////*/

    function assertHasRole(address roleContract, address account, uint256 role) internal view {
        assertTrue(OptimizedOwnableRoles(roleContract).hasAnyRole(account, role), "Account should have role");
    }

    function assertAssetBalance(address token, address user, uint256 expected) internal view {
        assertEq(getAssetBalance(token, user), expected, "Asset balance mismatch");
    }

    function assertKTokenBalance(address token, address user, uint256 expected) internal view {
        assertEq(getKTokenBalance(token, user), expected, "kToken balance mismatch");
    }

    /* //////////////////////////////////////////////////////////////
                        PROTOCOL STATE HELPERS
    //////////////////////////////////////////////////////////////*/

    function assertProtocolInitialized() internal view {
        // Check registry has core contracts
        assertEq(registry.getContractById(registry.K_ASSET_ROUTER()), address(assetRouter));
        assertEq(registry.getContractById(registry.K_MINTER()), address(minter));

        // Check assets are registered
        assertTrue(registry.isAsset(tokens.usdc));
        assertTrue(registry.isAsset(tokens.wbtc));

        // Check kTokens are registered
        assertEq(registry.assetToKToken(tokens.usdc), address(kUSD));
        assertEq(registry.assetToKToken(tokens.wbtc), address(kBTC));

        // Check all vaults are registered
        assertTrue(registry.isVault(address(dnVault)));
        assertTrue(registry.isVault(address(alphaVault)));
        assertTrue(registry.isVault(address(betaVault)));

        // Check adapters are deployed and initialized (disabled for debugging)
        assertTrue(address(minterAdapterUSDC) != address(0));
        assertTrue(address(minterAdapterWBTC) != address(0));
        assertTrue(address(DNVaultAdapterUSDC) != address(0));
        assertTrue(address(ALPHAVaultAdapterUSDC) != address(0));
        assertTrue(address(BETHAVaultAdapterUSDC) != address(0));
    }

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

    function getVaultByType(IRegistry.VaultType vaultType) internal view returns (IkStakingVault) {
        if (vaultType == IRegistry.VaultType.DN) return dnVault;
        if (vaultType == IRegistry.VaultType.ALPHA) return alphaVault;
        if (vaultType == IRegistry.VaultType.BETA) return betaVault;
        revert("Unknown vault type");
    }
}
