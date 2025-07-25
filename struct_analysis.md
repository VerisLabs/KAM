# Struct Storage Analysis for KAM Protocol

## Overview
This analysis examines all struct definitions in the KAM protocol to identify storage optimization opportunities. Each struct is analyzed for:
- Current storage layout and slot usage
- Wasted bytes per slot
- Potential optimization opportunities
- Whether stored in storage vs only used in memory

## Struct Analysis

### 1. kAssetRouterTypes.InitParams
**Location**: `src/types/kAssetRouterTypes.sol`
**Usage**: Memory only (initialization parameter)
**Current Layout**:
```solidity
struct InitParams {
    address kToken;          // 20 bytes, slot 0
    address underlyingAsset; // 20 bytes, slot 1
    address owner;           // 20 bytes, slot 2
    address admin;           // 20 bytes, slot 3
    address emergencyAdmin;  // 20 bytes, slot 4
    address institution;     // 20 bytes, slot 5
    address kBatch;          // 20 bytes, slot 6
    address kAssetRouter;    // 20 bytes, slot 7
}
```
**Analysis**: 
- Uses 8 slots (256 bytes total)
- Wastes 12 bytes per slot (96 bytes total waste)
- **Optimization**: Not needed - this is only used in memory for initialization

### 2. kAssetRouterTypes.Balances
**Location**: `src/types/kAssetRouterTypes.sol`
**Usage**: Storage (in kAssetRouterStorage mapping)
**Current Layout**:
```solidity
struct Balances {
    uint256 requested; // 32 bytes, slot 0
    uint256 deposited; // 32 bytes, slot 1
}
```
**Analysis**: 
- Uses 2 slots (64 bytes total)
- No waste - optimal layout
- **Optimization**: Could potentially use uint128 if values don't exceed 2^128-1

### 3. kMinterTypes.RedeemRequest
**Location**: `src/types/kMinterTypes.sol`
**Usage**: Storage (in kMinterStorage mapping)
**Current Layout**:
```solidity
struct RedeemRequest {
    bytes32 id;                  // 32 bytes, slot 0
    address user;                // 20 bytes, slot 1
    address asset;               // 20 bytes, slot 2 (12 bytes wasted in slot 1)
    uint96 amount;               // 12 bytes, slot 2
    address recipient;           // 20 bytes, slot 3
    uint64 requestTimestamp;     // 8 bytes, slot 3 (4 bytes wasted)
    RequestStatus status;        // 1 byte, slot 4
    uint256 batchId;            // 32 bytes, slot 5 (31 bytes wasted in slot 4)
}
```
**Analysis**: 
- Uses 6 slots (192 bytes total)
- Wastes 47 bytes total
- **Major optimization opportunity!**

**Optimized Layout**:
```solidity
struct RedeemRequest {
    bytes32 id;                  // 32 bytes, slot 0
    address user;                // 20 bytes, slot 1
    uint96 amount;               // 12 bytes, slot 1 (packed)
    address asset;               // 20 bytes, slot 2
    address recipient;           // 20 bytes, slot 3 (12 bytes free)
    uint64 requestTimestamp;     // 8 bytes, slot 3 (packed, 4 bytes free)
    RequestStatus status;        // 1 byte, slot 3 (packed, 3 bytes free)
    uint256 batchId;            // 32 bytes, slot 4
}
```
**Result**: Reduced from 6 slots to 5 slots (saves 32 bytes per request)

### 4. kBatchTypes.BatchInfo
**Location**: `src/types/kBatchTypes.sol`
**Usage**: Storage (in kBatchStorage mapping)
**Current Layout**:
```solidity
struct BatchInfo {
    uint256 batchId;                    // 32 bytes, slot 0
    address batchReceiver;              // 20 bytes, slot 1
    bool isClosed;                      // 1 byte, slot 1
    bool isSettled;                     // 1 byte, slot 1 (10 bytes wasted)
    EnumerableSetLib.AddressSet vaults; // Dynamic storage pointer
    EnumerableSetLib.AddressSet assets; // Dynamic storage pointer
}
```
**Analysis**: 
- Base struct uses 2 slots + dynamic storage for sets
- Wastes 10 bytes in slot 1
- **Optimization**: Limited due to EnumerableSet structure

### 5. ModuleBaseTypes.StakeRequest
**Location**: `src/kStakingVault/types/ModuleBaseTypes.sol`
**Usage**: Storage (in BaseModuleStorage mapping)
**Current Layout**:
```solidity
struct StakeRequest {
    uint256 id;                  // 32 bytes, slot 0
    address user;                // 20 bytes, slot 1
    address recipient;           // 20 bytes, slot 2 (12 bytes wasted in slot 1)
    uint96 kTokenAmount;         // 12 bytes, slot 2
    uint96 minStkTokens;         // 12 bytes, slot 3 (8 bytes wasted in slot 2)
    uint64 requestTimestamp;     // 8 bytes, slot 3
    RequestStatus status;        // 1 byte, slot 3 (11 bytes wasted)
    uint256 batchId;            // 32 bytes, slot 4
}
```
**Analysis**: 
- Uses 5 slots (160 bytes total)
- Wastes 31 bytes total
- **Major optimization opportunity!**

**Optimized Layout**:
```solidity
struct StakeRequest {
    uint256 id;                  // 32 bytes, slot 0
    address user;                // 20 bytes, slot 1
    uint96 kTokenAmount;         // 12 bytes, slot 1 (packed)
    address recipient;           // 20 bytes, slot 2
    uint96 minStkTokens;         // 12 bytes, slot 2 (packed)
    uint64 requestTimestamp;     // 8 bytes, slot 3
    RequestStatus status;        // 1 byte, slot 3 (packed, 23 bytes free)
    uint256 batchId;            // 32 bytes, slot 4
}
```
**Result**: No reduction in slots but better packing (still 5 slots)

### 6. ModuleBaseTypes.UnstakeRequest
**Location**: `src/kStakingVault/types/ModuleBaseTypes.sol`
**Usage**: Storage (in BaseModuleStorage mapping)
**Current Layout**: Same as StakeRequest
**Analysis**: Same optimization opportunity as StakeRequest

### 7. kBaseStorage
**Location**: `src/base/kBase.sol`
**Usage**: Storage (base contract storage)
**Current Layout**:
```solidity
struct kBaseStorage {
    address registry;  // 20 bytes, slot 0
    bool initialized;  // 1 byte, slot 0
    bool paused;      // 1 byte, slot 0 (10 bytes wasted)
}
```
**Analysis**: 
- Uses 1 slot (32 bytes total)
- Wastes 10 bytes
- **Optimization**: Already well-packed

### 8. kAssetRouterStorage
**Location**: `src/kAssetRouter.sol`
**Usage**: Storage (main storage struct)
**Current Layout**:
```solidity
struct kAssetRouterStorage {
    uint256 totalPendingDeposits;  // 32 bytes, slot 0
    uint256 totalPendingRedeems;   // 32 bytes, slot 1
    mapping(...) vaultBatchBalances;
    mapping(...) vaultBalances;
    mapping(...) vaultRequestedShares;
}
```
**Analysis**: 
- Fixed fields use 2 slots
- No optimization needed for mappings
- Could use uint128 if values don't exceed 2^128-1

### 9. kBatchStorage
**Location**: `src/kBatch.sol`
**Usage**: Storage (main storage struct)
**Current Layout**:
```solidity
struct kBatchStorage {
    uint256 currentBatchId;   // 32 bytes, slot 0
    uint256 requestCounter;   // 32 bytes, slot 1
    mapping(...) batches;
}
```
**Analysis**: 
- Uses 2 slots for fixed fields
- Could potentially pack if batch IDs and request counts stay below uint128

### 10. kMinterStorage
**Location**: `src/kMinter.sol`
**Usage**: Storage (main storage struct)
**Current Layout**:
```solidity
struct kMinterStorage {
    uint256 requestCounter;             // 32 bytes, slot 0
    mapping(...) redeemRequests;
    mapping(...) userRequests;
}
```
**Analysis**: 
- Uses 1 slot for fixed field
- Well optimized

### 11. kRegistryStorage
**Location**: `src/kRegistry.sol`
**Usage**: Storage (main storage struct)
**Current Layout**: Contains only mappings and arrays
**Analysis**: No optimization opportunities for mappings/arrays

### 12. kTokenStorage
**Location**: `src/kToken.sol`
**Usage**: Storage (main storage struct)
**Current Layout**:
```solidity
struct kTokenStorage {
    bool isPaused;    // 1 byte, slot 0
    string _name;     // Dynamic storage
    string _symbol;   // Dynamic storage
    uint8 _decimals;  // 1 byte, slot 0 (30 bytes wasted)
}
```
**Analysis**: 
- Fixed fields use 1 slot with 30 bytes wasted
- Strings use separate storage slots
- **Optimization**: Already minimal for fixed fields

### 13. BaseModuleStorage
**Location**: `src/kStakingVault/modules/BaseModule.sol`
**Usage**: Storage (vault module storage)
**Current Layout**:
```solidity
struct BaseModuleStorage {
    bool initialized;        // 1 byte, slot 0
    bool paused;            // 1 byte, slot 0
    uint256 requestCounter; // 32 bytes, slot 1 (30 bytes wasted in slot 0)
    uint256 lastTotalAssets; // 32 bytes, slot 2
    uint128 dustAmount;     // 16 bytes, slot 3
    uint8 decimals;         // 1 byte, slot 3
    address underlyingAsset; // 20 bytes, slot 4 (15 bytes wasted in slot 3)
    address registry;       // 20 bytes, slot 5 (12 bytes wasted in slot 4)
    string name;            // Dynamic storage
    string symbol;          // Dynamic storage
    mapping(...) stakeRequests;
    mapping(...) unstakeRequests;
    mapping(...) userRequests;
}
```
**Analysis**: 
- Uses 6 slots for fixed fields
- Wastes 57 bytes total
- **Major optimization opportunity!**

**Optimized Layout**:
```solidity
struct BaseModuleStorage {
    bool initialized;        // 1 byte, slot 0
    bool paused;            // 1 byte, slot 0
    uint8 decimals;         // 1 byte, slot 0
    address underlyingAsset; // 20 bytes, slot 0
    address registry;       // 20 bytes, slot 1 (packed, 9 bytes free)
    uint128 dustAmount;     // 16 bytes, slot 1 (packed)
    uint256 requestCounter; // 32 bytes, slot 2
    uint256 lastTotalAssets; // 32 bytes, slot 3
    string name;            // Dynamic storage
    string symbol;          // Dynamic storage
    mapping(...) stakeRequests;
    mapping(...) unstakeRequests;
    mapping(...) userRequests;
}
```
**Result**: Reduced from 6 slots to 4 slots (saves 64 bytes)

## Summary of Optimization Opportunities

### High Priority (Storage Structs with Major Waste):

1. **kMinterTypes.RedeemRequest**: Can save 32 bytes per request (6 → 5 slots)
2. **BaseModuleStorage**: Can save 64 bytes (6 → 4 slots)
3. **ModuleBaseTypes.StakeRequest & UnstakeRequest**: Better packing (still 5 slots but less waste)

### Medium Priority:

1. **kAssetRouterTypes.Balances**: Could use uint128 if values permit
2. **kAssetRouterStorage**: Could pack totalPendingDeposits/Redeems as uint128
3. **kBatchStorage**: Could pack currentBatchId/requestCounter as uint128

### Low Priority (Already Optimized or Memory-Only):

1. **kAssetRouterTypes.InitParams**: Memory only, no optimization needed
2. **kBaseStorage**: Already well-packed (1 slot)
3. **kMinterStorage**: Already optimized (1 slot)
4. **kTokenStorage**: Minimal waste, strings dominate storage

## Recommendations

1. **Immediate Action**: Optimize RedeemRequest, StakeRequest, UnstakeRequest, and BaseModuleStorage structs
2. **Consider uint128**: For counter fields that won't exceed 2^128-1
3. **Pack Related Fields**: Group fields by size to minimize padding
4. **Document Limits**: When using smaller types (uint96, uint128), document maximum values

## Gas Savings Estimate

- Each optimized RedeemRequest saves ~5,000 gas on creation
- Each optimized StakeRequest/UnstakeRequest saves ~3,000 gas
- BaseModuleStorage optimization saves ~10,000 gas on initialization
- For high-volume operations, these savings compound significantly