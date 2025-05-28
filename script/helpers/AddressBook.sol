// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library AddressBook {
    
    address constant zeroAddress = 0x0000000000000000000000000000000000000000;

    // CHAIN IDS
    uint32 constant OPTIMISM = 10;
    uint32 constant BASE = 8453;

    // CHAIN_SELECTORS from Chainlink CCIP
    uint64 constant BASE_CHAIN_SELECTOR = 15_971_525_489_660_198_786;
    uint64 constant OP_CHAIN_SELECTOR = 3_734_403_246_176_062_136;

    // DEPLOYED_ADDRESSES
    address constant DEPLOYER_ADDRESS = zeroAddress;

    address constant BASE_KUSD = zeroAddress;
    address constant BASE_POOL = zeroAddress;

    address constant OP_KUSD = zeroAddress;
    address constant OP_POOL = zeroAddress;
}