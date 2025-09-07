# KAM Protocol - Users Flow (Retail)

This document explains the complete retail user flow through the KAM protocol, detailing each function call, state change, and interaction between contracts in the happy path scenario. Users interact with kStakingVault to stake kTokens and earn yield through share tokens.

## Flow 1: User Stakes kTokens

### Function: `kStakingVault.requestStake(address to, uint256 kTokensAmount)`

**What happens internally:**

1. **Pause and Access Checks**
   - `kStakingVault` calls `_checkNotPaused()` to ensure vault is operational
   - No specific role required for retail users

2. **Amount Validation**
   - Verifies `kTokensAmount > 0`
   - Reverts with `KSTAKINGVAULT_ZERO_AMOUNT` if zero

3. **Batch State Check**
   - Calls `_getBatchId()` to get current active batch
   - Calls `_isBatchClosed(batchId)` to verify batch accepts new requests
   - Reverts with `KSTAKINGVAULT_VAULT_CLOSED` if batch is closed

4. **kToken Transfer**
   - `kStakingVault` calls `kToken.safeTransferFrom(msg.sender, address(this), kTokensAmount)`
   - User's kTokens are now held by the vault

5. **Request ID Generation**
   - Generates unique requestId using internal counter and user data
   - `requestId = keccak256(abi.encode(msg.sender, kTokensAmount, block.timestamp, counter++))`

6. **Request Storage**
   - Creates `StakeRequest` struct with:
     - `user: msg.sender`
     - `amount: kTokensAmount`
     - `timestamp: block.timestamp`
     - `batchId: currentBatchId`
     - `recipient: to`
     - `status: RequestStatus.PENDING`
   - Stores in `stakeRequests[requestId]`
   - Adds to user's request set: `userRequests[msg.sender].add(requestId)`

7. **Pending Stake Tracking**
   - Updates total pending stake: `totalPendingStake += amount`
   - Tracks kTokens waiting for batch settlement

8. **Asset Transfer Coordination**
   - `kStakingVault` calls `kAssetRouter.kAssetTransfer(kMinter, address(this), underlyingAsset, amount, batchId)`
   - Moves underlying assets from kMinter's pool to this vault's batch

9. **Event Emission**
   - `kStakingVault` emits `StakeRequestCreated(requestId, msg.sender, kToken, amount, to, batchId)`

**Result State:**
- User's kTokens held by vault
- Stake request stored with PENDING status
- Total pending stake updated
- Underlying assets moved from kMinter to vault batch

## Flow 2: User Requests Unstaking

### Function: `kStakingVault.requestUnstake(address to, uint256 stkTokenAmount)`

**What happens internally:**

1. **Pause and Balance Checks**
   - `kStakingVault` calls `_checkNotPaused()`
   - Verifies user balance: `balanceOf(msg.sender) >= stkTokenAmount`
   - Reverts with `KSTAKINGVAULT_INSUFFICIENT_BALANCE` if insufficient

2. **Amount Validation**
   - Verifies `stkTokenAmount > 0`
   - Reverts with `KSTAKINGVAULT_ZERO_AMOUNT` if zero

3. **Batch State Check**
   - Gets current batch: `batchId = _getBatchId()`
   - Verifies batch is open: `!_isBatchClosed(batchId)`

4. **stkToken Transfer to Contract**
   - `kStakingVault` calls `_transfer(msg.sender, address(this), stkTokenAmount)`
   - User's stkTokens are held by contract (not burned yet)
   - This keeps share price stable during batch processing
   - Total supply unchanged until claim time

5. **Request ID Generation**
   - Generates unique requestId using internal counter
   - `requestId = keccak256(abi.encode(msg.sender, stkTokenAmount, block.timestamp, counter++))`

6. **Request Storage**
   - Creates `UnstakeRequest` struct with:
     - `user: msg.sender`
     - `stkTokenAmount: stkTokenAmount`
     - `timestamp: block.timestamp`
     - `batchId: currentBatchId`
     - `recipient: to`
     - `status: RequestStatus.PENDING`
   - Stores in `unstakeRequests[requestId]`
   - Adds to user's request set: `userRequests[msg.sender].add(requestId)`

7. **kAssetRouter Coordination**
   - `kStakingVault` calls `kAssetRouter.kSharesRequestPush(address(this), stkTokenAmount, batchId)`

8. **kAssetRouter Processing** (inside kSharesRequestPush):
   - Updates virtual shares: `virtualBalances[vault].pendingWithdrawals += stkTokenAmount`
   - Records batch operation for settlement processing

9. **Event Emission**
   - `kStakingVault` emits `UnstakeRequestCreated(requestId, msg.sender, stkTokenAmount, to, batchId)`

**Result State:**
- User's stkTokens held by contract (not burned yet)
- Unstake request stored with PENDING status  
- Virtual balances updated for batch settlement
- Request queued for batch processing (kToken amount determined at claim time)

## Flow 3: Batch Processing and Settlement

### Batch Closure: `kStakingVault.closeBatch(bytes32 batchId, bool create)`

**What happens internally:**

1. **Access Control**
   - Only `RELAYER_ROLE` can close batches
   - Calls `registry.isRelayer(msg.sender)` for validation

2. **Batch Validation**
   - Verifies batch exists: `batchInfo[batchId].isActive == true`
   - Confirms batch is not already closed: `!batchInfo[batchId].isClosed`

3. **Batch State Update**
   - Sets `batchInfo[batchId].isClosed = true`
   - Sets `batchInfo[batchId].closedTimestamp = block.timestamp`
   - Prevents new stake/unstake requests for this batch

4. **New Batch Creation** (if create = true):
   - Generates new batchId using current timestamp and block number
   - Sets `currentBatchId = newBatchId`
   - Initializes: `batchInfo[newBatchId].isActive = true`

5. **Event Emission**
   - Emits `BatchClosed(batchId)`

### Settlement Execution: `kStakingVault.settleBatch(bytes32 batchId)`

**What happens internally:**

1. **Access Control**
   - Only kAssetRouter can call: `_checkRouter(msg.sender)`
   - Validates batch is closed but not settled

2. **Batch State Update**
   - Sets `batches[batchId].isSettled = true`

3. **Share Price Snapshot**
   - Captures current share price: `batches[batchId].sharePrice = _sharePrice()`
   - Captures current net share price: `batches[batchId].netSharePrice = _netSharePrice()`
   - These prices are used for all claims in this batch

4. **Event Emission**
   - Emits `BatchSettled(batchId)`

### Batch Receiver Creation: `kStakingVault.createBatchReceiver(bytes32 batchId)`

**What happens internally:**

1. **Access Control**
   - Only kAssetRouter can call: `_checkRouter(msg.sender)`

2. **Receiver Check**
   - If receiver already exists, returns existing address

3. **Clone Deployment**
   - Uses `OptimizedLibClone.clone(receiverImplementation)` to deploy minimal proxy
   - Sets `batches[batchId].batchReceiver = receiver`

4. **Initialization**
   - Calls `kBatchReceiver(receiver).initialize(batchId, underlyingAsset)`

5. **Event Emission**
   - Emits `BatchReceiverCreated(receiver, batchId)`

**Result State:**
- Batch closed and settled with share prices captured
- Ready for individual claim processing
- BatchReceiver created separately when needed

## Flow 4: User Claims Staked Shares

### Function: `kStakingVault.claimStakedShares(bytes32 batchId, bytes32 requestId)`

**What happens internally:**

1. **Request Validation**
   - Retrieves `stakeRequests[requestId]`
   - Verifies `request.status == RequestStatus.PENDING`
   - Confirms `request.batchId == batchId`
   - Validates caller authorization (user or recipient)

2. **Batch Settlement Check**
   - Calls `isBatchSettled(batchId)` to verify batch is settled
   - Reverts with `VAULTCLAIMS_BATCH_NOT_SETTLED` if not ready

3. **Share Price Calculation**
   - Gets net share price from batch: `netSharePrice = batches[batchId].netSharePrice`  
   - This was set during batch settlement
   - Validates share price is not zero

4. **stkToken Amount Calculation**
   - Calculates stkTokens to mint: `stkTokensToMint = request.kTokenAmount * 10^decimals / netSharePrice`
   - Uses full precision math for accurate calculation

5. **Accounting Updates**
   - Reduces pending stake: `totalPendingStake -= request.kTokenAmount`
   - Removes from user tracking: `userRequests[msg.sender].remove(requestId)`

6. **stkToken Minting**
   - `kStakingVault` calls `_mint(request.user, stkTokensToMint)`
   - Updates total supply and user balance

7. **Request Cleanup**
   - Sets `request.status = RequestStatus.CLAIMED`

8. **Event Emission**
   - Emits `StakingSharesClaimed(batchId, requestId, request.user, stkTokensToMint)`

**Result State:**
- User receives stkTokens based on settlement-time net share price
- Stake request completed and removed from tracking
- Total pending stake reduced, total supply increased

## Flow 5: User Claims Unstaked Assets

### Function: `kStakingVault.claimUnstakedAssets(bytes32 batchId, bytes32 requestId)`

**What happens internally:**

1. **Request Validation**
   - Retrieves `unstakeRequests[requestId]`
   - Verifies `request.status == RequestStatus.PENDING`
   - Confirms `request.batchId == batchId`
   - Validates caller is authorized

2. **Batch Settlement Check**
   - Calls `isBatchSettled(batchId)` 
   - Reverts if batch not settled

3. **Batch Receiver Retrieval**
   - Gets receiver address: `batchReceiver = getBatchReceiver(batchId)`
   - Verifies receiver exists and is initialized

4. **Share Price Retrieval**
   - Gets settlement share price: `sharePrice = batches[batchId].sharePrice`
   - Gets net share price: `netSharePrice = batches[batchId].netSharePrice`  
   - These were calculated during batch settlement

5. **kToken Amount Calculation**
   - Calculates gross kTokens: `totalKTokensGross = request.stkTokenAmount * sharePrice / 1e18`
   - Calculates net kTokens: `totalKTokensNet = request.stkTokenAmount * netSharePrice / 1e18`
   - Calculates fees: `fees = totalKTokensGross - totalKTokensNet`

6. **stkToken Burning**
   - `kStakingVault` calls `_burn(address(this), request.stkTokenAmount)`
   - Burns the stkTokens held by contract since unstake request
   - Updates total supply: `totalSupply() -= request.stkTokenAmount`

7. **Asset Distribution**
   - Transfers fees to treasury: `kToken.safeTransfer(treasury, fees)`
   - Transfers net kTokens to user: `kToken.safeTransfer(request.user, totalKTokensNet)`

8. **Request Cleanup**
   - Sets `request.status = RequestStatus.CLAIMED`
   - Request tracking cleanup handled internally

9. **Event Emission**
   - Emits `UnstakingAssetsClaimed(batchId, requestId, request.user, totalKTokensNet)`
   - Emits `KTokenUnstaked(request.user, request.stkTokenAmount, totalKTokensNet)`

**Result State:**
- User receives net kTokens (yield minus fees)
- stkTokens permanently burned from total supply
- Treasury receives fees from the unstaking
- Unstake request completed

## Flow 6: Share Price Calculation and Yield Distribution

### Function: `kStakingVault.sharePrice()` (via ReaderModule)

**What happens internally:**

1. **Total Assets Calculation**
   - Calls `totalAssets()` to get current assets under management
   - Includes assets in external strategies via adapters
   - Accounts for pending deposits and withdrawals

2. **Total Supply Check**
   - Gets `totalSupply()` of outstanding stkTokens
   - If zero supply, returns base price (1e18)

3. **Share Price Formula**
   - Calculates: `sharePrice = totalAssets * 1e18 / totalSupply`
   - Represents kTokens per stkToken exchange rate

4. **Fee Impact**
   - Management fees reduce total assets over time
   - Performance fees taken on yield above hurdle rate
   - Both reduce share price for existing holders

### Function: `kStakingVault.totalAssets()` (via ReaderModule)

**What happens internally:**

1. **Virtual Balance Query**
   - Calls `kAssetRouter.getVirtualBalance(address(this), underlyingAsset)`
   - Gets current virtual balance including pending operations

2. **Adapter Asset Query**
   - For each registered adapter, calls `adapter.totalAssets(address(this), underlyingAsset)`
   - Sums assets deployed in external yield strategies

3. **Fee Calculation**
   - Calls `computeLastBatchFees()` to get accumulated fees
   - Deducts management and performance fees from total

4. **Net Assets**
   - Returns `totalGrossAssets - totalFees`
   - This represents net assets available to shareholders

**Result State:**
- Accurate share price reflecting current yield and fees
- Total assets accounting for all deployed capital
- Foundation for fair batch settlement pricing

## Flow 7: Emergency Operations

### Pause/Unpause: `kStakingVault.pause()` / `kStakingVault.unpause()`

**What happens internally:**

1. **Access Control**
   - Only `EMERGENCY_ADMIN_ROLE` can pause/unpause
   - Calls `registry.isEmergencyAdmin(msg.sender)`

2. **State Change**
   - Sets `paused = true/false` in base storage
   - All state-changing functions check `_checkNotPaused()`

3. **Operation Impact**
   - Paused: No new stake/unstake requests accepted
   - Unpaused: Normal operations resume

### Fee Updates: `kStakingVault.setManagementFee(uint16 fee)`

**What happens internally:**

1. **Access Control**
   - Only `ADMIN_ROLE` can update fees
   - Calls `registry.isAdmin(msg.sender)`

2. **Fee Validation**
   - Verifies `fee <= MAX_MANAGEMENT_FEE` (typically 500 bps)
   - Reverts with `VAULTFEES_FEE_EXCEEDS_MAXIMUM` if too high

3. **Fee Update**
   - Sets `managementFee = fee` in basis points
   - Takes effect for next fee calculation period

This technical flow shows exactly how retail users interact with kStakingVault through the complete staking lifecycle, from initial stake requests to final asset claims.