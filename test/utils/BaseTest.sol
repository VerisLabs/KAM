// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MockERC20 } from "../mocks/MockERC20.sol";
import { Utilities } from "./Utilities.sol";
import { Test } from "forge-std/Test.sol";

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
        address payable institution2;
        address payable institution3;
        address payable institution4;
        address payable relayer;
        address payable treasury;
        address payable owner;
        address payable guardian;
    }

    Users internal users;

    struct Tokens {
        address usdc;
        address wbtc;
    }

    Tokens internal tokens;

    // Mock tokens
    MockERC20 internal mockUSDC;
    MockERC20 internal mockWBTC;

    function setUp() public virtual {
        utils = new Utilities();

        // Set up test assets
        _setupAssets();

        // Create test users
        _createUsers();

        // Label addresses for better trace output
        _labelAddresses();
    }

    function getMockUSDC() internal view returns (MockERC20) {
        return mockUSDC;
    }

    function getMockWBTC() internal view returns (MockERC20) {
        return mockWBTC;
    }

    function _createUsers() internal {
        users.alice = utils.createUser("Alice");
        users.bob = utils.createUser("Bob");
        users.charlie = utils.createUser("Charlie");
        users.admin = utils.createUser("Admin");
        users.guardian = utils.createUser("Guardian");
        users.emergencyAdmin = utils.createUser("EmergencyAdmin");
        users.institution = utils.createUser("Institution");
        users.institution2 = utils.createUser("Institution2");
        users.institution3 = utils.createUser("Institution3");
        users.institution4 = utils.createUser("Institution4");
        users.relayer = utils.createUser("relayer");
        users.treasury = utils.createUser("Treasury");
        users.owner = utils.createUser("Owner");
    }

    function _setupAssets() internal {
        // Deploy mock tokens
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        mockWBTC = new MockERC20("Mock WBTC", "WBTC", 8);

        // Set asset addresses to mock tokens
        tokens.usdc = address(mockUSDC);
        tokens.wbtc = address(mockWBTC);

        // Label
        vm.label(tokens.usdc, "USDC");
        vm.label(tokens.wbtc, "WBTC");
    }

    function _labelAddresses() internal {
        vm.label(users.alice, "Alice");
        vm.label(users.bob, "Bob");
        vm.label(users.charlie, "Charlie");
        vm.label(users.admin, "Admin");
        vm.label(users.emergencyAdmin, "EmergencyAdmin");
        vm.label(users.institution, "Institution");
        vm.label(users.relayer, "Relayer");
        vm.label(users.treasury, "Treasury");
        vm.label(users.owner, "Owner");
        vm.label(users.guardian, "Guardian");
        vm.label(users.institution2, "Institution2");
        vm.label(users.institution3, "Institution3");
        vm.label(users.institution4, "Institution4");
    }
}
