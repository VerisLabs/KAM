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

    address internal asset; // Main test asset
    address internal usdc;
    address internal wbtc;

    // Mock tokens
    MockERC20 internal mockUSDC;
    MockERC20 internal mockWBTC;

    function setUp() public virtual {
        utils = new Utilities();

        // Create test users
        _createUsers();

        // Set up test assets
        _setupAssets();

        // Label addresses for better trace output
        _labelAddresses();
    }

    /// @dev Get USDC token address (for use in child contracts)
    function getUSDC() internal view returns (address) {
        return usdc;
    }

    /// @dev Get WBTC token address (for use in child contracts)
    function getWBTC() internal view returns (address) {
        return wbtc;
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

    /// @dev Setup test assets (deploy mock tokens)
    function _setupAssets() internal {
        // Deploy mock tokens
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);
        mockWBTC = new MockERC20("Mock WBTC", "WBTC", 8);

        // Set asset addresses to mock tokens
        asset = address(mockUSDC);
        usdc = address(mockUSDC);
        wbtc = address(mockWBTC);

        // Label
        vm.label(asset, "USDC");
        vm.label(usdc, "USDC");
        vm.label(wbtc, "WBTC");
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
    }
}
