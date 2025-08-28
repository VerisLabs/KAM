// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {
    ADMIN_ROLE,
    BATCH_CUTOFF_TIME,
    EMERGENCY_ADMIN_ROLE,
    INSTITUTION_ROLE,
    MINTER_ROLE,
    SETTLEMENT_INTERVAL,
    USDC_MAINNET,
    WBTC_MAINNET,
    _1000_USDC,
    _100_USDC,
    _10_USDC,
    _1_USDC,
    _1_WBTC,
    getMainnetTokens,
    getUSDCToken
} from "./Constants.sol";
import { Utilities } from "./Utilities.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

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
        address payable relayer;
        address payable treasury;
        address payable owner;
        address payable guardian;
    }

    Users internal users;

    address internal asset; // Main test asset
    address internal usdc;
    address internal wbtc;

    // Fork setup
    uint256 internal mainnetFork;
    bool internal useMainnetFork;

    function setUp() public virtual {
        utils = new Utilities();

        // Create test users
        _createUsers();

        // Setup fork if needed
        _setupFork();

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
        users.guardian = utils.createUser("Guardian", tokens);
        users.emergencyAdmin = utils.createUser("EmergencyAdmin", tokens);
        users.institution = utils.createUser("Institution", tokens);
        users.relayer = utils.createUser("relayer", tokens);
        users.treasury = utils.createUser("Treasury", tokens);
        users.owner = utils.createUser("Owner", tokens);
    }

    /// @dev Setup mainnet fork for integration tests
    function _setupFork() internal {
        if (useMainnetFork) {
            string memory rpcUrl = vm.envString("RPC_MAINNET");
            mainnetFork = vm.createFork(rpcUrl, 22_847_000);
            vm.selectFork(mainnetFork);

            // Use USDC as main test asset
            asset = USDC_MAINNET;
            usdc = USDC_MAINNET;
            wbtc = WBTC_MAINNET;

            // Label
            vm.label(asset, "USDC");
            vm.label(usdc, "USDC");
            vm.label(wbtc, "WBTC");
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
        vm.label(users.relayer, "relayer");
        vm.label(users.treasury, "Treasury");

        if (useMainnetFork) {
            vm.label(USDC_MAINNET, "USDC");
            vm.label(WBTC_MAINNET, "WBTC");
        }
    }

    /// @dev Enable mainnet fork for specific tests
    function enableMainnetFork() internal {
        useMainnetFork = true;
        _setupFork();
    }
}
