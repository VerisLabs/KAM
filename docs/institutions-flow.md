# KAM Protocol - Institutions Flow

This document explains the complete institutional flow through the KAM protocol, detailing each function call, state change, and interaction between contracts in the happy path scenario.

## Flow 1: Institution Mints kTokens

### Function: `kMinter.mint(address asset, address to, uint256 amount)`

**What happens internally:**

1. **Access Control Check**
   - `kMinter` calls `registry.isInstitution(msg.sender)` 
   - Reverts if caller lacks `INSTITUTION_ROLE`

2. **Asset Validation** 
   - `kMinter` calls `registry.assetToKToken(asset)` to get kToken address
   - Reverts if asset is not registered in protocol

3. **Asset Transfer**
   - `kMinter` executes `asset.safeTransferFrom(msg.sender, router, amount)`
   - Institution's assets are transferred directly to kAssetRouter

4. **Get Target Vault**
   - `kMinter` calls `registry.getVaultByAssetAndType(asset, VaultType.DN)` 
   - Retrieves the DN vault that handles this asset

5. **Get Current Batch**
   - `kMinter` calls `vault.getBatchId()` to get the active batch ID
   - This batch will receive the deposited assets

6. **Asset Router Integration**
   - `kMinter` calls `kAssetRouter.kAssetPush(asset, amount, batchId)`
   - Note: Assets were already transferred directly from user to router in step 2

7. **kAssetRouter Processing** (inside kAssetPush):
   - Updates batch deposit tracking: `vaultBatchBalances[kMinter][batchId].deposited += amount`
   - Emits `AssetsPushed(kMinter, amount)` event
   - No actual asset transfers - just accounting updates

8. **kToken Minting**
   - `kMinter` calls `kToken.mint(to, amount)` 
   - New kTokens are minted 1:1 with deposited assets
   - `kMinter` updates `totalLockedAssets[asset] += amount`

9. **Event Emission**
   - `kMinter` emits `Minted(to, amount, batchId)`

**Result State:**

- Institution holds `amount` kTokens
- DN vault holds `amount` underlying assets in current batch
- Virtual balances updated in kAssetRouter
- Assets ready for yield generation strategies

## Flow 2: Institution Requests Redemption

### Function: `kMinter.requestRedeem(address asset, address to, uint256 amount)`

**What happens internally:**

1. **Asset Validation**
   - `kMinter` calls `registry.assetToKToken(asset)` to verify asset support
   - Gets kToken address for the underlying asset

2. **kToken Escrow**
   - `kMinter` executes `kToken.safeTransferFrom(msg.sender, address(this), amount)`
   - kTokens are now held in escrow by kMinter (not burned yet)

3. **Request ID Generation**
   - `kMinter` increments `requestCounter++`
   - Generates unique requestId: `keccak256(abi.encode(msg.sender, asset, amount, block.timestamp, requestCounter))`

4. **Get Target Vault and Batch**
   - `kMinter` calls `registry.getVaultByAssetAndType(asset, VaultType.DN)`
   - `kMinter` calls `vault.getBatchId()` for current batch

5. **Request Storage**
   - Creates `RedeemRequest` struct with:
     - `user: msg.sender`
     - `amount: amount` 
     - `asset: asset`
     - `requestTimestamp: block.timestamp`
     - `status: RequestStatus.PENDING`
     - `batchId: batchId`
     - `recipient: to`
   - Stores in `redeemRequests[requestId]`
   - Adds to `userRequests[to].add(requestId)`

6. **Asset Router Coordination**
   - `kMinter` calls `kAssetRouter.kAssetRequestPull(asset, vault, amount, batchId)`

7. **kAssetRouter Processing** (inside kAssetRequestPull):
   - Updates batch requested tracking: `vaultBatchBalances[kMinter][batchId].requested += amount`
   - Creates batch receiver: `vault.createBatchReceiver(batchId)`
   - Emits `AssetsRequestPulled(kMinter, asset, batchReceiver, amount)` event

8. **Event Emission**
   - `kMinter` emits `RedeemRequestCreated(requestId, msg.sender, kToken, amount, to, batchId)`

**Result State:**

- kTokens escrowed in kMinter contract
- Redemption request stored with PENDING status  
- Virtual balances updated with pending withdrawal
- Request queued for batch processing

## Flow 3: Batch Settlement Process

### Batch Closure: `vault.closeBatch(bytes32 batchId, bool create)`

**What happens internally:**

1. **Access Control**
   - Only `RELAYER_ROLE` can close batches
   - `vault` calls `registry.isRelayer(msg.sender)`

2. **Batch State Update**
   - Sets `batchInfo[batchId].isClosed = true`
   - Sets `batchInfo[batchId].closedTimestamp = block.timestamp`

3. **New Batch Creation** (if create = true):
   - Generates new batchId: `keccak256(abi.encode(block.timestamp, block.number))`
   - Sets `currentBatchId = newBatchId`
   - Initializes new batch: `batchInfo[newBatchId].isActive = true`

### Settlement Proposal: `kAssetRouter.proposeSettleBatch(...)`

**What happens internally:**

1. **Parameter Validation**
   - Verifies batch exists and is closed
   - Validates `totalAssets`, `netted`, `yield` calculations
   - Ensures no existing proposal for this batch

2. **Proposal Storage**
   - Creates `SettlementProposal` with:
     - `vault: vault`
     - `asset: asset` 
     - `batchId: batchId`
     - `totalAssets: totalAssets`
     - `nettedAmount: netted`
     - `yieldAmount: yield`
     - `isProfit: profit`
     - `proposedTimestamp: block.timestamp`
     - `status: ProposalStatus.PENDING`

3. **Cooldown Timer**
   - Proposal enters cooldown period (1-24 hours based on amount)
   - Cannot be executed until `block.timestamp >= proposedTimestamp + cooldownPeriod`

### Settlement Execution: `kAssetRouter.executeSettleBatch(address vault, bytes32 batchId)`

**What happens internally:**

1. **Proposal Validation**
   - Retrieves settlement proposal for batch
   - Verifies cooldown period has elapsed
   - Confirms proposal status is PENDING

2. **Batch Receiver Creation**
   - `vault` calls `createBatchReceiver(batchId)`
   - Deploys minimal proxy using CREATE2 with salt
   - `batchReceiver.initialize(batchId, asset)` sets batch parameters

3. **Asset Calculation and Transfer**
   - Calculates final settlement amounts based on yield/losses
   - `vault` transfers settlement assets to batch receiver
   - Updates virtual balances: `virtualBalances[vault][asset].settledAssets += settledAmount`

4. **Batch Settlement**
   - `vault` calls `settleBatch(batchId)` 
   - Sets `batchInfo[batchId].isSettled = true`
   - Sets `batchInfo[batchId].settledTimestamp = block.timestamp`
   - Records `batchInfo[batchId].batchReceiver = receiverAddress`

5. **Proposal Cleanup**
   - Updates proposal status: `proposals[batchId].status = ProposalStatus.EXECUTED`
   - Emits `BatchSettled(batchId)` event

**Result State:**

- Batch is closed and settled
- BatchReceiver deployed and holds settlement assets
- Ready for individual redemption execution

## Flow 4: Institution Executes Redemption

### Function: `kMinter.redeem(bytes32 requestId)`

**What happens internally:**

1. **Request Validation**
   - Retrieves `redeemRequests[requestId]`
   - Verifies `request.status == RequestStatus.PENDING`
   - Confirms `msg.sender == request.user`

2. **Batch Settlement Check**
   - Gets vault for request asset: `registry.getVaultByAssetAndType(request.asset, VaultType.DN)`
   - Calls `vault.isBatchSettled(request.batchId)`
   - Reverts if batch not yet settled

3. **Batch Receiver Retrieval**
   - `vault.getBatchReceiver(request.batchId)` returns receiver address
   - Validates receiver exists and is properly initialized

4. **Asset Distribution**
   - `kMinter` calls `batchReceiver.pullAssets(request.recipient, request.amount, request.batchId)`

5. **BatchReceiver Processing** (inside pullAssets):
   - Validates caller is kMinter: `require(msg.sender == kMinter)`
   - Validates batchId matches: `require(batchId == storedBatchId)`
   - Transfers assets: `asset.safeTransfer(receiver, amount)`

6. **kToken Burning**
   - `kMinter` calls `kToken.burn(address(this), request.amount)`
   - Escrowed kTokens are permanently destroyed
   - Updates `totalLockedAssets[request.asset] -= request.amount`

7. **Request Cleanup**
   - Sets `request.status = RequestStatus.REDEEMED`
   - Removes from user requests: `userRequests[request.user].remove(requestId)`
   - Deletes request: `delete redeemRequests[requestId]`

8. **Event Emission**
   - `kMinter` emits `Redeemed(requestId)`

**Result State:**

- Institution receives underlying assets (including yield)
- kTokens permanently burned
- Redemption request completed and cleaned up
- Total locked assets accounting updated

## Flow 5: Request Cancellation (Optional)

### Function: `kMinter.cancelRequest(bytes32 requestId)`

**What happens when institution cancels before batch settlement:**

1. **Request Validation**
   - Retrieves `redeemRequests[requestId]`
   - Verifies `request.status == RequestStatus.PENDING`
   - Confirms `msg.sender == request.user`

2. **Batch State Check**
   - Gets vault: `registry.getVaultByAssetAndType(request.asset, VaultType.DN)`
   - Calls `vault.isBatchClosed(request.batchId)` and `vault.isBatchSettled(request.batchId)`
   - Reverts if batch is closed or settled

3. **kToken Return**
   - `kMinter` calls `kToken.safeTransfer(request.user, request.amount)`
   - Returns escrowed kTokens to institution

4. **Virtual Balance Update**
   - `kMinter` calls `kAssetRouter.kAssetRequestPull()` with negative amount to reverse the withdrawal request
   - Updates `virtualBalances[vault][asset].pendingWithdrawals -= amount`

5. **Request Cleanup**
   - Sets `request.status = RequestStatus.CANCELLED`
   - Removes from tracking: `userRequests[request.user].remove(requestId)`
   - Deletes request: `delete redeemRequests[requestId]`

6. **Event Emission**
   - `kMinter` emits `Cancelled(requestId)`

**Result State:**

- Institution receives kTokens back
- Redemption request cancelled and removed
- Virtual balances adjusted to remove withdrawal

This technical flow shows exactly how institutions interact with the protocol through function calls and state changes across all major contracts
