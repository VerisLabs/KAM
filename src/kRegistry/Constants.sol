// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

bytes32 constant PROCESS_FEES_DN = keccak256("PROCESS_FEES_DN"); // IF Management or Performance need to be charged
bytes32 constant DN_NET_POSITIVE = keccak256("PROPOSE_SETTLE_DN_NET_POSITIVE"); // transferFrom KMinter to DN
bytes32 constant DN_NET_NEGATIVE = keccak256("PROPOSE_SETTLE_DN_NET_NEGATIVE"); // transfer DN to KMinter
bytes32 constant KMINTER_NET_POSITIVE = keccak256("KMINTER_NET_POSITIVE"); // requestDeposit - might occur later
bytes32 constant KMINTER_NET_NEGATIVE = keccak256("KMINTER_NET_NEGATIVE");
