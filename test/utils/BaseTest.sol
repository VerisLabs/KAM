// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MockERC20 } from "../mocks/MockERC20.sol";
import { Utilities } from "./Utilities.sol";
import { Test } from "forge-std/Test.sol";

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

    /// @dev Get mock USDC token instance (for minting in child contracts)
    function getMockUSDC() internal view returns (MockERC20) {
        return mockUSDC;
    }

    /// @dev Get mock WBTC token instance (for minting in child contracts)
    function getMockWBTC() internal view returns (MockERC20) {
        return mockWBTC;
    }

    /// @dev Creates test users with appropriate funding
    function _createUsers() internal {
        address[] memory _tokens = new address[](2);
        _tokens[0] = tokens.usdc;
        _tokens[1] = tokens.wbtc;
        users.alice = utils.createUser("Alice", _tokens);
        users.bob = utils.createUser("Bob", _tokens);
        users.charlie = utils.createUser("Charlie", _tokens);
        users.admin = utils.createUser("Admin", _tokens);
        users.guardian = utils.createUser("Guardian", _tokens);
        users.emergencyAdmin = utils.createUser("EmergencyAdmin", _tokens);
        users.institution = utils.createUser("Institution", _tokens);
        users.institution2 = utils.createUser("Institution2", _tokens);
        users.institution3 = utils.createUser("Institution3", _tokens);
        users.institution4 = utils.createUser("Institution4", _tokens);
        users.relayer = utils.createUser("relayer", _tokens);
        users.treasury = utils.createUser("Treasury", _tokens);
        users.owner = utils.createUser("Owner", _tokens);
    }

    /// @dev Setup test assets (deploy mock tokens)
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

    /// @dev Label addresses for better debugging
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
