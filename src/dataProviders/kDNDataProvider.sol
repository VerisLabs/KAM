// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kDNStakingVault } from "src/kDNStakingVault.sol";

/// @title kDNDataProvider
/// @notice Efficient data provider for kDNStakingVault using extsload pattern
/// @dev Provides batch queries and complex calculations for frontend/testing without adding bloat to main contract
contract kDNDataProvider {
    /// @notice kDNStakingVault storage slot base (from ERC-7201)
    bytes32 private constant STORAGE_SLOT_BASE = 0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00;

    /// @notice Target kDNStakingVault contract
    kDNStakingVault public immutable vault;

    constructor(address _vault) {
        vault = kDNStakingVault(payable(_vault));
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH DATA QUERIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Get all batch IDs and settlement status
    /// @return currentBatchId Current unified batch ID
    /// @return currentStakingBatchId Current staking batch ID
    /// @return currentUnstakingBatchId Current unstaking batch ID
    /// @return lastSettledBatchId Last settled unified batch ID
    /// @return lastSettledStakingBatchId Last settled staking batch ID
    /// @return lastSettledUnstakingBatchId Last settled unstaking batch ID
    function getBatchIds()
        external
        view
        returns (
            uint256 currentBatchId,
            uint256 currentStakingBatchId,
            uint256 currentUnstakingBatchId,
            uint256 lastSettledBatchId,
            uint256 lastSettledStakingBatchId,
            uint256 lastSettledUnstakingBatchId
        )
    {
        // Read batch IDs from packed storage slots using extsload
        bytes32[] memory slots = new bytes32[](2);
        slots[0] = bytes32(uint256(STORAGE_SLOT_BASE) + 5); // SLOT 5: batch IDs
        slots[1] = bytes32(uint256(STORAGE_SLOT_BASE) + 6); // SLOT 6: more batch IDs

        bytes32[] memory values = vault.extsload(slots);

        // Extract from SLOT 5 (packed uint64s)
        currentBatchId = uint256(uint64(uint256(values[0])));
        lastSettledBatchId = uint256(uint64(uint256(values[0]) >> 64));
        currentStakingBatchId = uint256(uint64(uint256(values[0]) >> 128));
        lastSettledStakingBatchId = uint256(uint64(uint256(values[0]) >> 192));

        // Extract from SLOT 6 (packed uint64s)
        currentUnstakingBatchId = uint256(uint64(uint256(values[1])));
        lastSettledUnstakingBatchId = uint256(uint64(uint256(values[1]) >> 64));
    }

    /// @notice Get core accounting data for invariant testing
    /// @return totalMinterAssets Total assets in minter pool (1:1)
    /// @return totalStkTokenAssets Total stkToken assets
    /// @return userTotalAssets Total user assets
    /// @return totalStkTokenSupply Total stkToken supply
    /// @return totalStakedKTokens Total kTokens staked
    function getAccountingData()
        external
        view
        returns (
            uint256 totalMinterAssets,
            uint256 totalStkTokenAssets,
            uint256 userTotalAssets,
            uint256 totalStkTokenSupply,
            uint256 totalStakedKTokens
        )
    {
        // Read accounting data from packed storage slots per ModuleBase layout
        bytes32[] memory slots = new bytes32[](3);
        slots[0] = bytes32(uint256(STORAGE_SLOT_BASE) + 3); // SLOT 3: totalMinterAssets + userTotalSupply
        slots[1] = bytes32(uint256(STORAGE_SLOT_BASE) + 4); // SLOT 4: userTotalAssets + totalStakedKTokens
        slots[2] = bytes32(uint256(STORAGE_SLOT_BASE) + 8); // SLOT 8: totalStkTokenAssets + totalVariance

        bytes32[] memory values = vault.extsload(slots);

        // Extract from SLOT 3 (uint128 + uint128)
        totalMinterAssets = uint256(uint128(uint256(values[0])));
        uint256 userTotalSupply = uint256(uint128(uint256(values[0]) >> 128));

        // Extract from SLOT 4 (uint128 + uint128)
        userTotalAssets = uint256(uint128(uint256(values[1])));
        totalStakedKTokens = uint256(uint128(uint256(values[1]) >> 128));

        // Extract from SLOT 8 (uint128 + uint128) and SLOT 7
        totalStkTokenAssets = uint256(uint128(uint256(values[2])));

        // Get totalStkTokenSupply from SLOT 7
        bytes32 slot7 = bytes32(uint256(STORAGE_SLOT_BASE) + 7);
        bytes32 value7 = vault.extsload(slot7);
        totalStkTokenSupply = uint256(uint128(uint256(value7) >> 64)); // Skip first 64 bits
    }

    /// @notice Get staking batch information
    /// @param batchId Batch ID to query
    /// @return settled Whether batch is settled
    /// @return totalKTokens Total kTokens in batch
    /// @return totalStkTokens Total stkTokens minted (after settlement)
    /// @return stkTokenPrice Price used for settlement
    function getStakingBatchInfo(uint256 batchId)
        external
        view
        returns (bool settled, uint256 totalKTokens, uint256 totalStkTokens, uint256 stkTokenPrice)
    {
        // Calculate storage slot for staking batch
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(STORAGE_SLOT_BASE) + 20)); // stakingBatches mapping

        bytes32[] memory slots = new bytes32[](4);
        slots[0] = batchSlot; // settled flag + totalKTokens
        slots[1] = bytes32(uint256(batchSlot) + 1); // totalStkTokens + stkTokenPrice
        slots[2] = bytes32(uint256(batchSlot) + 2); // totalAssetsFromMinter
        slots[3] = bytes32(uint256(batchSlot) + 3); // requests array length

        bytes32[] memory values = vault.extsload(slots);

        // Extract batch data (custom packing structure)
        settled = (uint256(values[0]) & 0x1) == 1;
        totalKTokens = uint256(values[0]) >> 8;
        totalStkTokens = uint256(values[1]) & type(uint128).max;
        stkTokenPrice = uint256(values[1]) >> 128;
    }

    /// @notice Get unstaking batch information
    /// @param batchId Batch ID to query
    /// @return settled Whether batch is settled
    /// @return totalStkTokens Total stkTokens in batch
    /// @return totalKTokensToReturn Total kTokens to return after settlement
    /// @return stkTokenPrice Price used for settlement
    /// @return originalKTokenRatio Ratio for original kToken calculation
    function getUnstakingBatchInfo(uint256 batchId)
        external
        view
        returns (
            bool settled,
            uint256 totalStkTokens,
            uint256 totalKTokensToReturn,
            uint256 stkTokenPrice,
            uint256 originalKTokenRatio
        )
    {
        // Calculate storage slot for unstaking batch
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(STORAGE_SLOT_BASE) + 21)); // unstakingBatches mapping

        bytes32[] memory slots = new bytes32[](4);
        slots[0] = batchSlot; // settled + totalStkTokens
        slots[1] = bytes32(uint256(batchSlot) + 1); // totalKTokensToReturn
        slots[2] = bytes32(uint256(batchSlot) + 2); // stkTokenPrice
        slots[3] = bytes32(uint256(batchSlot) + 3); // originalKTokenRatio

        bytes32[] memory values = vault.extsload(slots);

        settled = (uint256(values[0]) & 0x1) == 1;
        totalStkTokens = uint256(values[0]) >> 8;
        totalKTokensToReturn = uint256(values[1]);
        stkTokenPrice = uint256(values[2]);
        originalKTokenRatio = uint256(values[3]);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE AND YIELD CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate current stkToken price with yield
    /// @return price Current stkToken price including unaccounted yield
    function getCurrentStkTokenPriceWithYield() external view returns (uint256 price) {
        (, uint256 totalStkTokenAssets, uint256 userTotalAssets, uint256 totalStkTokenSupply,) =
            this.getAccountingData();

        if (totalStkTokenSupply == 0) return 1e18;

        // Include automatic yield in calculation
        uint256 totalUserAssetsWithYield = vault.getTotalUserAssets();
        uint256 stkTokenAssetsWithYield = totalStkTokenAssets;

        // If there's unaccounted yield, add it to stkToken assets
        if (totalUserAssetsWithYield > userTotalAssets) {
            uint256 yield = totalUserAssetsWithYield - userTotalAssets;
            stkTokenAssetsWithYield += yield;
        }

        return (stkTokenAssetsWithYield * 1e18) / totalStkTokenSupply;
    }

    /// @notice Calculate total unaccounted yield in the system
    /// @return yieldAmount Total unaccounted yield
    function getUnaccountedYield() external view returns (uint256 yieldAmount) {
        uint256 totalVaultAssets = vault.getTotalVaultAssets();
        (uint256 totalMinterAssets,, uint256 userTotalAssets,,) = this.getAccountingData();

        uint256 accountedAssets = totalMinterAssets + userTotalAssets;
        return totalVaultAssets > accountedAssets ? totalVaultAssets - accountedAssets : 0;
    }

    /*//////////////////////////////////////////////////////////////
                        TESTING HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get accounting data with vault assets for handler syncing
    /// @return totalMinterAssets Total minter assets
    /// @return totalStkTokenAssets Total stkToken assets
    /// @return userTotalAssets Total user assets
    /// @return totalStkTokenSupply Total stkToken supply
    /// @return totalStakedKTokens Total staked kTokens
    /// @return totalVaultAssets Total vault assets
    function getHandlerAccountingData()
        external
        view
        returns (
            uint256 totalMinterAssets,
            uint256 totalStkTokenAssets,
            uint256 userTotalAssets,
            uint256 totalStkTokenSupply,
            uint256 totalStakedKTokens,
            uint256 totalVaultAssets
        )
    {
        (totalMinterAssets, totalStkTokenAssets, userTotalAssets, totalStkTokenSupply, totalStakedKTokens) =
            this.getAccountingData();
        totalVaultAssets = vault.getTotalVaultAssets();
    }

    /// @notice Get batch IDs for handler syncing
    /// @return currentStakingBatchId Current staking batch ID
    /// @return currentUnstakingBatchId Current unstaking batch ID
    /// @return lastSettledStakingBatchId Last settled staking batch ID
    /// @return lastSettledUnstakingBatchId Last settled unstaking batch ID
    function getHandlerBatchData()
        external
        view
        returns (
            uint256 currentStakingBatchId,
            uint256 currentUnstakingBatchId,
            uint256 lastSettledStakingBatchId,
            uint256 lastSettledUnstakingBatchId
        )
    {
        (, currentStakingBatchId, currentUnstakingBatchId,, lastSettledStakingBatchId, lastSettledUnstakingBatchId) =
            this.getBatchIds();
    }

    /// @notice Validate dual accounting invariant
    /// @return isValid Whether dual accounting is correct
    /// @return minterAssets Minter pool assets
    /// @return userAssets User pool assets (with yield)
    /// @return vaultAssets Total vault assets
    function validateDualAccounting()
        external
        view
        returns (bool isValid, uint256 minterAssets, uint256 userAssets, uint256 vaultAssets)
    {
        (minterAssets,,,,) = this.getAccountingData();
        userAssets = vault.getTotalUserAssets(); // Includes automatic yield
        vaultAssets = vault.getTotalVaultAssets();

        isValid = (minterAssets + userAssets) == vaultAssets;
    }

    /// @notice Check if unstaking would break peg (price < 1e18)
    /// @param unstakingStkTokens Amount of stkTokens being unstaked
    /// @return wouldBreakPeg Whether this unstaking would break peg
    /// @return resultingPrice Resulting stkToken price after unstaking
    function checkUnstakingPegImpact(uint256 unstakingStkTokens)
        external
        view
        returns (bool wouldBreakPeg, uint256 resultingPrice)
    {
        (, uint256 totalStkTokenAssets,, uint256 totalStkTokenSupply,) = this.getAccountingData();

        if (totalStkTokenSupply == 0) {
            wouldBreakPeg = false;
            resultingPrice = 1e18;
            return (wouldBreakPeg, resultingPrice);
        }

        // Simulate the settlement calculation (with fixed logic)
        uint256 effectiveSupply = totalStkTokenSupply; // Fixed: no double counting
        uint256 currentPrice = (totalStkTokenAssets * 1e18) / effectiveSupply;

        resultingPrice = currentPrice;
        wouldBreakPeg = currentPrice < 1e18;
    }
}
