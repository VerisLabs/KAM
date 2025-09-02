// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title BaseVaultErrors library
 * @notice Defines the error messages emitted by the different contracts of the KAM vault protocol
 */
library BaseVaultErrors {
    // BaseVaultModule errors
    string public constant ZERO_ADDRESS = "BV1";
    string public constant INVALID_REGISTRY = "BV2";
    string public constant NOT_INITIALIZED = "BV3";
    string public constant CONTRACT_NOT_FOUND = "BV4";
    string public constant ZERO_AMOUNT = "BV5";
    string public constant AMOUNT_BELOW_DUST_THRESHOLD = "BV6";
    string public constant VAULT_CLOSED = "BV7";
    string public constant VAULT_SETTLED = "BV8";
    string public constant REQUEST_NOT_FOUND = "BV9";
    string public constant REQUEST_NOT_ELIGIBLE = "BV10";
    string public constant INVALID_VAULT = "BV11";
    string public constant IS_PAUSED = "BV12";
    string public constant ALREADY_INITIALIZED = "BV13";
    string public constant WRONG_ROLE = "BV14";
    string public constant WRONG_ASSET = "BV15";
    string public constant TRANSFER_FAILED = "BV16";
    string public constant NOT_CLOSED = "BV17";
    string public constant FEE_EXCEEDS_MAXIMUM = "BV18";
    string public constant INVALID_TIMESTAMP = "BV19";
    string public constant BATCH_NOT_SETTLED = "BV20";
    string public constant INVALID_BATCH_ID = "BV21";
    string public constant REQUEST_NOT_PENDING = "BV22";
    string public constant NOT_BENEFICIARY = "BV23";
    string public constant INSUFFICIENT_BALANCE = "BV24";
    string public constant UNAUTHORIZED = "BV25";
}
