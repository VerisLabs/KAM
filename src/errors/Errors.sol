// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @dev All error codes use contract-specific prefixes for easier debugging:
///      - A*: kAssetRouter errors
///      - BA*: BaseAdapter errors
///      - BV*: BaseVault errors
///      - B*: kBatchReceiver errors
///      - C*: Custodial adapter errors
///      - K*: kBase errors
///      - M*: kMinter errors
///      - R*: kRegistry errors
///      - SV*: kStakingVault errors
///      - T*: kToken errors
///      - VB*: VaultBatches errors
///      - VC*: VaultClaims errors
///      - VF*: VaultFees errors

// kAssetRouter Errors
string constant KASSETROUTER_ALREADY_REGISTERED = "A1";
string constant KASSETROUTER_BATCH_CLOSED = "A2";
string constant KASSETROUTER_BATCH_ID_PROPOSED = "A3";
string constant KASSETROUTER_BATCH_SETTLED = "A4";
string constant KASSETROUTER_COOLDOOWN_IS_UP = "A5";
string constant KASSETROUTER_INSUFFICIENT_VIRTUAL_BALANCE = "A6";
string constant KASSETROUTER_INVALID_COOLDOWN = "A7";
string constant KASSETROUTER_INVALID_VAULT = "A8";
string constant KASSETROUTER_IS_PAUSED = "A9";
string constant KASSETROUTER_NO_PROPOSAL = "A10";
string constant KASSETROUTER_ONLY_KMINTER = "A11";
string constant KASSETROUTER_ONLY_KSTAKING_VAULT = "A12";
string constant KASSETROUTER_PROPOSAL_EXECUTED = "A13";
string constant KASSETROUTER_PROPOSAL_EXISTS = "A14";
string constant KASSETROUTER_PROPOSAL_NOT_FOUND = "A15";
string constant KASSETROUTER_WRONG_ROLE = "A16";
string constant KASSETROUTER_ZERO_ADDRESS = "A17";
string constant KASSETROUTER_ZERO_AMOUNT = "A18";
string constant KASSETROUTER_INVALID_TOLERANCE = "A19";

// Base Adapter Errors
string constant ADAPTER_ALREADY_INITIALIZED = "BA1";
string constant ADAPTER_INVALID_REGISTRY = "BA2";
string constant ADAPTER_TRANSFER_FAILED = "BA3";
string constant ADAPTER_WRONG_ASSET = "BA4";
string constant ADAPTER_WRONG_ROLE = "BA5";
string constant ADAPTER_ZERO_ADDRESS = "BA6";
string constant ADAPTER_ZERO_AMOUNT = "BA7";
string constant ADAPTER_INSUFFICIENT_BALANCE = "BA8";

string constant BASEVAULT_ALREADY_INITIALIZED = "BV1";
string constant BASEVAULT_CONTRACT_NOT_FOUND = "BV2";
string constant BASEVAULT_INVALID_REGISTRY = "BV3";
string constant BASEVAULT_INVALID_VAULT = "BV4";
string constant BASEVAULT_NOT_INITIALIZED = "BV5";

// kBatchReceiver Errors
string constant KBATCHRECEIVER_ALREADY_INITIALIZED = "B1";
string constant KBATCHRECEIVER_INVALID_BATCH_ID = "B2";
string constant KBATCHRECEIVER_ONLY_KMINTER = "B3";
string constant KBATCHRECEIVER_TRANSFER_FAILED = "B4";
string constant KBATCHRECEIVER_WRONG_ASSET = "B5";
string constant KBATCHRECEIVER_ZERO_ADDRESS = "B6";
string constant KBATCHRECEIVER_ZERO_AMOUNT = "B7";

// Custodial Adapter Errors
string constant CUSTODIAL_INVALID_CUSTODIAL_ADDRESS = "C1";
string constant CUSTODIAL_TRANSFER_FAILED = "C2";
string constant CUSTODIAL_VAULT_DESTINATION_NOT_SET = "C3";
string constant CUSTODIAL_WRONG_ASSET = "C4";
string constant CUSTODIAL_WRONG_ROLE = "C5";
string constant CUSTODIAL_ZERO_ADDRESS = "C6";
string constant CUSTODIAL_ZERO_AMOUNT = "C7";

// kBase Errors
string constant KBASE_ALREADY_INITIALIZED = "K1";
string constant KBASE_INVALID_REGISTRY = "K2";
string constant KBASE_NOT_INITIALIZED = "K3";
string constant KBASE_WRONG_ROLE = "K4";
string constant KBASE_ZERO_ADDRESS = "K5";
string constant KBASE_ZERO_AMOUNT = "K6";
string constant KBASE_TRANSFER_FAILED = "K7";
string constant KBASE_WRONG_ASSET = "K8";
string constant KBASE_CONTRACT_NOT_FOUND = "K9";
string constant KBASE_ASSET_NOT_SUPPORTED = "K10";
string constant KBASE_INVALID_VAULT = "K11";

// kMinter Errors
string constant KMINTER_BATCH_CLOSED = "M1";
string constant KMINTER_BATCH_SETTLED = "M2";
string constant KMINTER_INSUFFICIENT_BALANCE = "M3";
string constant KMINTER_IS_PAUSED = "M4";
string constant KMINTER_REQUEST_NOT_ELIGIBLE = "M5";
string constant KMINTER_REQUEST_NOT_FOUND = "M6";
string constant KMINTER_REQUEST_PROCESSED = "M7";
string constant KMINTER_WRONG_ASSET = "M8";
string constant KMINTER_WRONG_ROLE = "M9";
string constant KMINTER_ZERO_ADDRESS = "M10";
string constant KMINTER_ZERO_AMOUNT = "M11";
string constant KMINTER_BATCH_MINT_REACHED = "M12";
string constant KMINTER_BATCH_REDEEM_REACHED = "M13";
string constant KMINTER_BATCH_NOT_CLOSED = "M14";
string constant KMINTER_BATCH_NOT_SET = "M15";

// kRegistry Errors
string constant KREGISTRY_ADAPTER_ALREADY_SET = "R1";
string constant KREGISTRY_ALREADY_REGISTERED = "R2";
string constant KREGISTRY_ASSET_NOT_SUPPORTED = "R3";
string constant KREGISTRY_INVALID_ADAPTER = "R4";
string constant KREGISTRY_TRANSFER_FAILED = "R5";
string constant KREGISTRY_WRONG_ASSET = "R6";
string constant KREGISTRY_WRONG_ROLE = "R7";
string constant KREGISTRY_ZERO_ADDRESS = "R8";
string constant KREGISTRY_ZERO_AMOUNT = "R9";
string constant KREGISTRY_FEE_EXCEEDS_MAXIMUM = "R10";
string constant KREGISTRY_SELECTOR_ALREADY_SET = "R11";
string constant KREGISTRY_SELECTOR_NOT_FOUND = "R12";

string constant GUARDIANMODULE_UNAUTHORIZED = "GM1";
string constant GUARDIANMODULE_NOT_ALLOWED = "GM2";
string constant GUARDIANMODULE_INVALID_ADAPTER = "GM3";
string constant GUARDIANMODULE_SELECTOR_ALREADY_SET = "GM4";
string constant GUARDIANMODULE_SELECTOR_NOT_FOUND = "GM5";
string constant GUARDIANMODULE_ZERO_ADDRESS = "GM6";

// kRegistryBase Errors
string constant KROLESBASE_ALREADY_INITIALIZED = "KB1";
string constant KROLESBASE_WRONG_ROLE = "KB2";
string constant KROLESBASE_ZERO_ADDRESS = "KB3";
string constant KROLESBASE_NOT_INITIALIZED = "KB4";
string constant KROLESBASE_ZERO_AMOUNT = "KB5";
string constant KROLESBASE_TRANSFER_FAILED = "KB6";

// kStakingVault Errors
string constant KSTAKINGVAULT_INSUFFICIENT_BALANCE = "SV1";
string constant KSTAKINGVAULT_IS_PAUSED = "SV2";
string constant KSTAKINGVAULT_NOT_INITIALIZED = "SV3";
string constant KSTAKINGVAULT_REQUEST_NOT_ELIGIBLE = "SV4";
string constant KSTAKINGVAULT_REQUEST_NOT_FOUND = "SV5";
string constant KSTAKINGVAULT_UNAUTHORIZED = "SV6";
string constant KSTAKINGVAULT_VAULT_CLOSED = "SV7";
string constant KSTAKINGVAULT_VAULT_SETTLED = "SV8";
string constant KSTAKINGVAULT_WRONG_ROLE = "SV9";
string constant KSTAKINGVAULT_ZERO_ADDRESS = "SV10";
string constant KSTAKINGVAULT_ZERO_AMOUNT = "SV11";

// kToken Errors
string constant KTOKEN_IS_PAUSED = "T1";
string constant KTOKEN_TRANSFER_FAILED = "T2";
string constant KTOKEN_ZERO_ADDRESS = "T3";
string constant KTOKEN_ZERO_AMOUNT = "T4";

// VaultBatches Errors
string constant VAULTBATCHES_NOT_CLOSED = "VB1";
string constant VAULTBATCHES_VAULT_CLOSED = "VB2";
string constant VAULTBATCHES_VAULT_SETTLED = "VB3";

// VaultClaims Errors
string constant VAULTCLAIMS_BATCH_NOT_SETTLED = "VC1";
string constant VAULTCLAIMS_INVALID_BATCH_ID = "VC2";
string constant VAULTCLAIMS_NOT_BENEFICIARY = "VC4";
string constant VAULTCLAIMS_REQUEST_NOT_PENDING = "VC5";

// VaultFees Errors
string constant VAULTFEES_FEE_EXCEEDS_MAXIMUM = "VF1";
string constant VAULTFEES_INVALID_TIMESTAMP = "VF2";

// VaultAdapter Errors
string constant VAULTADAPTER_EXPIRED_SIGNATURE = "VA1";
string constant VAULTADAPTER_INVALID_SIGNATURE = "VA2";
string constant VAULTADAPTER_ZERO_ADDRESS = "VA3";
string constant VAULTADAPTER_WRONG_ROLE = "VA4";
string constant VAULTADAPTER_IS_PAUSED = "VA5";
string constant VAULTADAPTER_NOT_INITIALIZED = "VA6";
string constant VAULTADAPTER_ZERO_AMOUNT = "VA7";
string constant VAULTADAPTER_TRANSFER_FAILED = "VA8";
string constant VAULTADAPTER_WRONG_ASSET = "VA9";
string constant VAULTADAPTER_WRONG_SELECTOR = "VA10";
string constant VAULTADAPTER_INVALID_NONCE = "VA11";
string constant VAULTADAPTER_WRONG_TARGET = "VA12";
string constant VAULTADAPTER_SELECTOR_NOT_ALLOWED = "VA13";

// ParamsChecker Errors
string constant PARAMETERCHECKER_NOT_ALLOWED = "PC1";
string constant PARAMETERCHECKER_ZERO_ADDRESS = "PC2";
