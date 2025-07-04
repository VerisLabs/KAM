// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Utilities} from "./Utilities.sol";
import {
    getMainnetTokens,
    getUSDCToken,
    USDC_MAINNET,
    _1_USDC,
    _10_USDC,
    _100_USDC,
    _1000_USDC,
    _1_WBTC,
    ADMIN_ROLE,
    EMERGENCY_ADMIN_ROLE,
    INSTITUTION_ROLE,
    SETTLER_ROLE,
    MINTER_ROLE,
    STRATEGY_ROLE,
    SETTLEMENT_INTERVAL,
    BATCH_CUTOFF_TIME
} from "./Constants.sol";
import {MockToken} from "../helpers/MockToken.sol";

/// @title BaseTest
/// @notice Base contract for all tests with common setup and utilities
contract BaseTest is Test {
    Utilities internal utils;

    // Test users
    struct Users {
        address payable alice;
        address payable bob;
        address payable charlie;
        address payable admin;
        address payable emergencyAdmin;
        address payable institution;
        address payable settler;
        address payable treasury;
    }

    Users internal users;

    // Test tokens
    MockToken internal mockUSDC;
    MockToken internal mockWBTC;
    address internal asset; // Main test asset

    // Fork setup
    uint256 internal mainnetFork;
    bool internal useMainnetFork = false;

    function setUp() public virtual {
        utils = new Utilities();

        // Create test users
        _createUsers();

        // Setup fork if needed
        _setupFork();

        // Deploy mock tokens
        _deployMockTokens();

        // Label addresses for better trace output
        _labelAddresses();
    }

    /// @dev Creates test users with appropriate funding
    function _createUsers() internal {
        address[] memory tokens = useMainnetFork ? getUSDCToken() : new address[](0);

        users.alice = utils.createUser("Alice", tokens);
        users.bob = utils.createUser("Bob", tokens);
        users.charlie = utils.createUser("Charlie", tokens);
        users.admin = utils.createUser("Admin", tokens);
        users.emergencyAdmin = utils.createUser("EmergencyAdmin", tokens);
        users.institution = utils.createUser("Institution", tokens);
        users.settler = utils.createUser("Settler", tokens);
        users.treasury = utils.createUser("Treasury", tokens);
    }

    /// @dev Setup mainnet fork for integration tests
    function _setupFork() internal {
        if (useMainnetFork) {
            string memory rpcUrl = vm.envString("RPC_MAINNET");
            mainnetFork = vm.createFork(rpcUrl, 22847000);
            vm.selectFork(mainnetFork);

            // Use USDC as main test asset
            asset = USDC_MAINNET;
        }
    }

    /// @dev Deploy mock tokens for unit tests
    function _deployMockTokens() internal {
        mockUSDC = new MockToken("Mock USDC", "mUSDC", 6);
        mockWBTC = new MockToken("Mock WBTC", "mWBTC", 8);

        if (!useMainnetFork) {
            asset = address(mockUSDC);

            // Mint initial tokens to users
            mockUSDC.mint(users.alice, 1000000 * _1_USDC); // 1M USDC
            mockUSDC.mint(users.bob, 500000 * _1_USDC); // 500K USDC
            mockUSDC.mint(users.institution, 10000000 * _1_USDC); // 10M USDC

            mockWBTC.mint(users.alice, 100 * _1_WBTC); // 100 WBTC
            mockWBTC.mint(users.bob, 50 * _1_WBTC); // 50 WBTC
        }
    }

    /// @dev Label addresses for better debugging
    function _labelAddresses() internal {
        vm.label(users.alice, "Alice");
        vm.label(users.bob, "Bob");
        vm.label(users.charlie, "Charlie");
        vm.label(users.admin, "Admin");
        vm.label(users.emergencyAdmin, "EmergencyAdmin");
        vm.label(users.institution, "Institution");
        vm.label(users.settler, "Settler");
        vm.label(users.treasury, "Treasury");

        vm.label(address(mockUSDC), "MockUSDC");
        vm.label(address(mockWBTC), "MockWBTC");

        if (useMainnetFork) {
            vm.label(USDC_MAINNET, "USDC");
        }
    }

    /// @dev Enable mainnet fork for specific tests
    function enableMainnetFork() internal {
        useMainnetFork = true;
        _setupFork();
    }

    /// @dev Helper to mint tokens to user
    function mintTokens(address token, address to, uint256 amount) internal {
        if (useMainnetFork) {
            deal(token, to, amount);
        } else {
            MockToken(token).mint(to, amount);
        }
    }

    /// @dev Helper to get token balance
    function getBalance(address token, address user) internal view returns (uint256) {
        return MockToken(token).balanceOf(user);
    }

    /// @dev Skip tests that require mainnet fork if RPC_MAINNET not set
    function requireMainnetFork() internal {
        try vm.envString("RPC_MAINNET") returns (string memory) {
            // RPC_MAINNET is set, continue
        } catch {
            vm.skip(true);
        }
    }

    /// @dev Common assertion helpers available from forge-std
}
