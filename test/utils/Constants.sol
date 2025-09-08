// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Common token amounts for testing
uint256 constant _1_USDC = 1e6;
uint256 constant _10_USDC = 10e6;
uint256 constant _40_USDC = 40e6;
uint256 constant _50_USDC = 50e6;
uint256 constant _60_USDC = 60e6;
uint256 constant _100_USDC = 100e6;
uint256 constant _200_USDC = 200e6;
uint256 constant _1000_USDC = 1000e6;
uint256 constant _10000_USDC = 10_000e6;

uint256 constant _1_WBTC = 1e8;
uint256 constant _10_WBTC = 10e8;

uint256 constant _1_ETHER = 1 ether;
uint256 constant _10_ETHER = 10 ether;
uint256 constant _100_ETHER = 100 ether;

// Mock vault address
address constant METAVAULT_USDC = 0x349c996C4a53208b6EB09c103782D86a3F1BB57E;

// Role constants (matching Solady OptimizedOwnableRoles pattern)
uint256 constant ADMIN_ROLE = 1; // _ROLE_0
uint256 constant EMERGENCY_ADMIN_ROLE = 2; // _ROLE_1
uint256 constant GUARDIAN_ROLE = 4; // _ROLE_2
uint256 constant MINTER_ROLE = 4; // _ROLE_2
uint256 constant RELAYER_ROLE = 8; // _ROLE_3
uint256 constant INSTITUTION_ROLE = 16; // _ROLE_4
uint256 constant VENDOR_ROLE = 32; // _ROLE_5

// Time constants
uint256 constant SETTLEMENT_INTERVAL = 8 hours;
uint256 constant BATCH_CUTOFF_TIME = 4 hours;
uint256 constant ONE_DAY = 24 hours;
uint256 constant ONE_WEEK = 7 days;

// Gas limits for testing
uint256 constant DEPLOY_GAS_LIMIT = 10_000_000;
uint256 constant CALL_GAS_LIMIT = 1_000_000;
