// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {kMinter} from "../src/kMinter.sol";
import {DataTypes} from "../src/types/DataTypes.sol";

contract ExtsloadTest is Test {
    kMinter minter;

    // Storage location for kMinter
    bytes32 constant KMINTER_STORAGE_LOCATION = 0xd7df67ea9a5dbfe32636a20098d87d60f65e8140be3a76c5824fb5a4c8e19d00;

    function setUp() public {
        // Deploy kMinter (would need proper initialization in real test)
        minter = new kMinter();
    }

    function test_extsload_singleSlot() public {
        // Set a value in storage
        uint256 testValue = 12345;
        bytes32 slot = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 5); // currentBatchId slot
        vm.store(address(minter), slot, bytes32(testValue));

        // Read it back using extsload
        bytes32 value = minter.extsload(slot);
        assertEq(uint256(value), testValue);
    }

    function test_extsload_multipleSlots() public {
        // Set multiple consecutive values
        uint256 startSlot = uint256(KMINTER_STORAGE_LOCATION) + 5;
        uint256[] memory testValues = new uint256[](3);
        testValues[0] = 100; // currentBatchId
        testValues[1] = 200; // requestCounter
        testValues[2] = 300; // next slot

        for (uint256 i = 0; i < testValues.length; i++) {
            vm.store(address(minter), bytes32(startSlot + i), bytes32(testValues[i]));
        }

        // Read them back in one call
        bytes32[] memory values = minter.extsload(bytes32(startSlot), 3);

        assertEq(values.length, 3);
        assertEq(uint256(values[0]), testValues[0]);
        assertEq(uint256(values[1]), testValues[1]);
        assertEq(uint256(values[2]), testValues[2]);
    }

    function test_extsload_arbitrarySlots() public {
        // Test reading non-consecutive slots
        bytes32[] memory slots = new bytes32[](3);
        uint256[] memory testValues = new uint256[](3);

        // Set up test data at arbitrary slots
        slots[0] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 1); // kToken address
        slots[1] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 5); // currentBatchId
        slots[2] = bytes32(uint256(KMINTER_STORAGE_LOCATION) + 14); // totalDeposited

        testValues[0] = uint256(uint160(address(0x1234)));
        testValues[1] = 42;
        testValues[2] = 1000000;

        for (uint256 i = 0; i < slots.length; i++) {
            vm.store(address(minter), slots[i], bytes32(testValues[i]));
        }

        // Read all slots in one call
        bytes32[] memory values = minter.extsload(slots);

        assertEq(values.length, 3);
        assertEq(uint256(values[0]), testValues[0]);
        assertEq(uint256(values[1]), testValues[1]);
        assertEq(uint256(values[2]), testValues[2]);
    }
}
