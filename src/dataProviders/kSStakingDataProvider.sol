// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { kSStakingVault } from "src/kSStakingVault.sol";
import { DataTypes } from "src/types/DataTypes.sol";

/// @title kSStakingDataProvider
/// @notice Comprehensive data provider for kSStakingVault contract using extsload pattern
/// @dev Provides staking data, user positions, asset flows, and yield analytics for frontend/testing
contract kSStakingDataProvider {
    using FixedPointMathLib for uint256;

    /// @notice kSStakingVault storage slot base (from ERC-7201 - same as BaseVaultStorage)
    bytes32 private constant STORAGE_SLOT_BASE = 0x9d5c7e4b8f3a2d1e6f9c8b7a6d5e4f3c2b1a0e9d8c7b6a5f4e3d2c1b0a9e8d00;

    /// @notice Target kSStakingVault contract
    kSStakingVault public immutable vault;

    constructor(address _vault) {
        vault = kSStakingVault(payable(_vault));
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH DATA QUERIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Get comprehensive staking and unstaking batch data
    /// @return currentStakingBatchId Current staking batch ID
    /// @return currentUnstakingBatchId Current unstaking batch ID
    /// @return lastSettledStakingBatchId Last settled staking batch ID
    /// @return lastSettledUnstakingBatchId Last settled unstaking batch ID
    function getBatchData()
        external
        view
        returns (
            uint256 currentStakingBatchId,
            uint256 currentUnstakingBatchId,
            uint256 lastSettledStakingBatchId,
            uint256 lastSettledUnstakingBatchId
        )
    {
        // Read batch IDs from packed storage slots using extsload
        bytes32[] memory slots = new bytes32[](2);
        slots[0] = bytes32(uint256(STORAGE_SLOT_BASE) + 5); // SLOT 5: batch IDs
        slots[1] = bytes32(uint256(STORAGE_SLOT_BASE) + 6); // SLOT 6: more batch IDs

        bytes32[] memory values = vault.extsload(slots);

        // Extract from SLOT 5 (packed uint64s) - skip unified batch IDs
        currentStakingBatchId = uint256(uint64(uint256(values[0]) >> 128));
        lastSettledStakingBatchId = uint256(uint64(uint256(values[0]) >> 192));

        // Extract from SLOT 6 (packed uint64s)
        currentUnstakingBatchId = uint256(uint64(uint256(values[1])));
        lastSettledUnstakingBatchId = uint256(uint64(uint256(values[1]) >> 64));
    }

    /// @notice Get detailed staking batch information
    /// @param batchId Staking batch ID to query
    /// @return settled Whether the batch has been settled
    /// @return stkTokenPrice Price used for settlement
    /// @return totalStkTokens Total stkTokens minted in this batch
    /// @return totalAssetsFromMinter Total assets transferred from minter
    function getStakingBatchInfo(uint256 batchId)
        external
        view
        returns (bool settled, uint256 stkTokenPrice, uint256 totalStkTokens, uint256 totalAssetsFromMinter)
    {
        // Calculate staking batch mapping slot
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(STORAGE_SLOT_BASE) + 103));

        // Read staking batch data
        bytes32[] memory slots = new bytes32[](4);
        slots[0] = batchSlot; // settled
        slots[1] = bytes32(uint256(batchSlot) + 1); // stkTokenPrice
        slots[2] = bytes32(uint256(batchSlot) + 2); // totalStkTokens
        slots[3] = bytes32(uint256(batchSlot) + 3); // totalAssetsFromMinter

        bytes32[] memory values = vault.extsload(slots);

        settled = uint256(values[0]) != 0;
        stkTokenPrice = uint256(values[1]);
        totalStkTokens = uint256(values[2]);
        totalAssetsFromMinter = uint256(values[3]);
    }

    /// @notice Get detailed unstaking batch information
    /// @param batchId Unstaking batch ID to query
    /// @return settled Whether the batch has been settled
    /// @return stkTokenPrice Price used for settlement
    /// @return totalKTokensToReturn Total kTokens to return to users
    /// @return originalKTokenRatio Ratio of original kTokens to stkTokens
    function getUnstakingBatchInfo(uint256 batchId)
        external
        view
        returns (bool settled, uint256 stkTokenPrice, uint256 totalKTokensToReturn, uint256 originalKTokenRatio)
    {
        // Calculate unstaking batch mapping slot
        bytes32 batchSlot = keccak256(abi.encode(batchId, uint256(STORAGE_SLOT_BASE) + 105));

        // Read unstaking batch data
        bytes32[] memory slots = new bytes32[](4);
        slots[0] = batchSlot; // settled
        slots[1] = bytes32(uint256(batchSlot) + 1); // stkTokenPrice
        slots[2] = bytes32(uint256(batchSlot) + 2); // totalKTokensToReturn
        slots[3] = bytes32(uint256(batchSlot) + 3); // originalKTokenRatio

        bytes32[] memory values = vault.extsload(slots);

        settled = uint256(values[0]) != 0;
        stkTokenPrice = uint256(values[1]);
        totalKTokensToReturn = uint256(values[2]);
        originalKTokenRatio = uint256(values[3]);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET & ACCOUNTING DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get comprehensive accounting data (moved functions)
    /// @return totalMinterAssets Assets in minter pool (should be 0 for strategy vault)
    /// @return totalStkTokenAssets Assets backing stkTokens
    /// @return totalStkTokenSupply Total stkToken supply
    /// @return userTotalSupply Total user shares
    /// @return userTotalAssets Total user assets
    function getAccountingData()
        external
        view
        returns (
            uint256 totalMinterAssets,
            uint256 totalStkTokenAssets,
            uint256 totalStkTokenSupply,
            uint256 userTotalSupply,
            uint256 userTotalAssets
        )
    {
        // Read accounting data from packed storage slots
        bytes32[] memory slots = new bytes32[](4);
        slots[0] = bytes32(uint256(STORAGE_SLOT_BASE) + 3); // SLOT 3: totalMinterAssets + userTotalSupply
        slots[1] = bytes32(uint256(STORAGE_SLOT_BASE) + 4); // SLOT 4: userTotalAssets + totalStakedKTokens
        slots[2] = bytes32(uint256(STORAGE_SLOT_BASE) + 7); // SLOT 7: totalStkTokenSupply
        slots[3] = bytes32(uint256(STORAGE_SLOT_BASE) + 8); // SLOT 8: totalStkTokenAssets

        bytes32[] memory values = vault.extsload(slots);

        // Extract packed values
        totalMinterAssets = uint256(uint128(uint256(values[0])));
        userTotalSupply = uint256(uint128(uint256(values[0]) >> 128));

        userTotalAssets = uint256(uint128(uint256(values[1])));
        // totalStakedKTokens = uint256(uint128(uint256(values[1]) >> 128)); // Not needed for return

        totalStkTokenSupply = uint256(uint128(uint256(values[2])));
        totalStkTokenAssets = uint256(uint128(uint256(values[3])));
    }

    /// @notice Get current stkToken pricing data (moved from main contract)
    /// @return price Current stkToken price in underlying assets
    /// @return totalAssets Total underlying assets in vault
    /// @return totalSupply Total stkToken supply
    function getStkTokenPricing() external view returns (uint256 price, uint256 totalAssets, uint256 totalSupply) {
        totalAssets = vault.getTotalVaultAssets();
        totalSupply = vault.totalSupply();

        if (totalSupply == 0) {
            price = 1e18; // 1:1 initial price
        } else {
            price = totalAssets.divWad(totalSupply);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        USER POSITION DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get comprehensive user staking position (moved functions)
    /// @param user User address to query
    /// @return stkTokenBalance User's stkToken balance (moved from getStkTokenBalance)
    /// @return originalKTokens Original kTokens staked by user
    /// @return currentValue Current value of user's position
    /// @return unrealizedYield Unrealized yield (current value - original kTokens)
    function getUserStakingPosition(address user)
        external
        view
        returns (uint256 stkTokenBalance, uint256 originalKTokens, uint256 currentValue, uint256 unrealizedYield)
    {
        stkTokenBalance = vault.balanceOf(user);

        // Get original kTokens from storage
        bytes32 userSlot = keccak256(abi.encode(user, uint256(STORAGE_SLOT_BASE) + 109));
        bytes32 originalValue = vault.extsload(userSlot);
        originalKTokens = uint256(originalValue);

        // Calculate current value
        if (stkTokenBalance > 0) {
            (uint256 price,,) = this.getStkTokenPricing();
            currentValue = stkTokenBalance.mulWad(price);
            unrealizedYield = currentValue > originalKTokens ? currentValue - originalKTokens : 0;
        }
    }

    /// @notice Get total staked kTokens data (moved from getTotalStkTokens)
    /// @return totalStkTokens Total stkTokens in circulation (same as totalSupply)
    /// @return totalOriginalKTokens Total original kTokens staked
    /// @return totalCurrentValue Current total value of all positions
    /// @return totalUnrealizedYield Total unrealized yield across all users
    function getTotalStakingData()
        external
        view
        returns (
            uint256 totalStkTokens,
            uint256 totalOriginalKTokens,
            uint256 totalCurrentValue,
            uint256 totalUnrealizedYield
        )
    {
        totalStkTokens = vault.totalSupply();

        // Get total staked kTokens from storage
        bytes32 slot4 = bytes32(uint256(STORAGE_SLOT_BASE) + 4);
        bytes32 value = vault.extsload(slot4);
        totalOriginalKTokens = uint256(uint128(uint256(value) >> 128));

        totalCurrentValue = vault.getTotalVaultAssets();
        totalUnrealizedYield = totalCurrentValue > totalOriginalKTokens ? totalCurrentValue - totalOriginalKTokens : 0;
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET FLOW & STRATEGY DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get inter-vault asset flow data
    /// @return kDNVault Address of connected kDNStakingVault
    /// @return totalAllocatedFromDN Total assets allocated from DN vault
    /// @return currentVaultBalance Current underlying asset balance
    /// @return netAssetFlow Net flow between vaults
    function getAssetFlowData()
        external
        view
        returns (address kDNVault, uint256 totalAllocatedFromDN, uint256 currentVaultBalance, int256 netAssetFlow)
    {
        // Get totalAllocatedFromDN from slot 12 (lower 128 bits)
        bytes32 slot12 = bytes32(uint256(STORAGE_SLOT_BASE) + 12);
        bytes32 value12 = vault.extsload(slot12);
        totalAllocatedFromDN = uint256(uint128(uint256(value12)));

        // Get kDNVault address from slot 13 (lower 160 bits)
        bytes32 slot13 = bytes32(uint256(STORAGE_SLOT_BASE) + 13);
        bytes32 value13 = vault.extsload(slot13);
        kDNVault = address(uint160(uint256(value13)));

        currentVaultBalance = vault.getTotalVaultAssets();
        netAssetFlow = int256(currentVaultBalance) - int256(totalAllocatedFromDN);
    }

    /// @notice Get strategy yield and performance metrics
    /// @return totalYieldGenerated Total yield generated by strategy operations
    /// @return yieldRate Current yield rate (annualized estimate)
    /// @return lastYieldUpdate Timestamp of last yield distribution
    /// @return strategyPerformance Strategy performance vs 1:1 backing
    function getYieldData()
        external
        view
        returns (uint256 totalYieldGenerated, uint256 yieldRate, uint256 lastYieldUpdate, uint256 strategyPerformance)
    {
        (,, uint256 totalCurrentValue, uint256 totalUnrealizedYield) = this.getTotalStakingData();

        totalYieldGenerated = totalUnrealizedYield;

        // Simplified yield rate calculation (would need more sophisticated tracking in production)
        yieldRate = totalCurrentValue > 0 ? totalUnrealizedYield.divWad(totalCurrentValue) : 0;

        lastYieldUpdate = block.timestamp; // Simplified
        strategyPerformance = totalCurrentValue; // Simplified metric
    }

    /*//////////////////////////////////////////////////////////////
                        VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validate strategy vault accounting integrity
    /// @return isValid Whether accounting is correct
    /// @return vaultAssets Total vault assets
    /// @return backedAssets Total assets backing user positions
    /// @return excessAssets Excess assets (potential yield)
    function validateStrategyAccounting()
        external
        view
        returns (bool isValid, uint256 vaultAssets, uint256 backedAssets, uint256 excessAssets)
    {
        vaultAssets = vault.getTotalVaultAssets();
        (, uint256 totalOriginalKTokens,,) = this.getTotalStakingData();

        backedAssets = totalOriginalKTokens;
        excessAssets = vaultAssets > backedAssets ? vaultAssets - backedAssets : 0;

        // Strategy vault should have assets >= original kTokens staked
        isValid = vaultAssets >= backedAssets;
    }

    /// @notice Check asset flow health between vaults
    /// @return isHealthy Whether asset flows are healthy
    /// @return allocationRatio Ratio of allocated vs total DN minter assets
    /// @return utilizationRate Strategy vault utilization rate
    function checkAssetFlowHealth()
        external
        view
        returns (bool isHealthy, uint256 allocationRatio, uint256 utilizationRate)
    {
        (,, uint256 currentBalance,) = this.getAssetFlowData();
        (, uint256 totalOriginalKTokens,,) = this.getTotalStakingData();

        utilizationRate = totalOriginalKTokens > 0 ? currentBalance.divWad(totalOriginalKTokens) : 0;
        allocationRatio = 1e18; // Simplified - would need DN vault data for accurate calculation

        // Healthy if utilization is reasonable (between 80% and 120%)
        isHealthy = utilizationRate >= 0.8e18 && utilizationRate <= 1.2e18;
    }

    /*//////////////////////////////////////////////////////////////
                        CONTRACT METADATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Get contract metadata (moved from main contract)
    /// @return name Contract name
    /// @return version Contract version
    function getContractMetadata() external pure returns (string memory name, string memory version) {
        name = "kSStakingVault";
        version = "1.0.0";
    }

    /// @notice Get total user assets data (moved from main contract)
    /// @return userTotalAssets Total assets in user pool
    /// @return userTotalSupply Total user share supply
    /// @return assetPerShare Assets per share ratio
    function getTotalUserAssetsData()
        external
        view
        returns (uint256 userTotalAssets, uint256 userTotalSupply, uint256 assetPerShare)
    {
        // Get userTotalAssets from storage since we removed the function
        (,,,, userTotalAssets) = this.getAccountingData();
        userTotalSupply = vault.totalSupply();

        assetPerShare = userTotalSupply > 0 ? userTotalAssets.divWad(userTotalSupply) : 1e18;
    }

    /// @notice Get kDN vault address (moved from main contract)
    /// @return kDNVault Address of connected kDNStakingVault
    function getKDNVaultAddress() external view returns (address kDNVault) {
        // The address is in SLOT 13 due to struct packing:
        // SLOT 12: uint128 totalAllocatedToStrategies (16 bytes) + padding
        // SLOT 13: address kSStakingVault (20 bytes) + uint96 reserved6 (12 bytes)
        bytes32 slot13 = bytes32(uint256(STORAGE_SLOT_BASE) + 13);
        bytes32 value = vault.extsload(slot13);
        kDNVault = address(uint160(uint256(value))); // kSStakingVault address in lower 160 bits
    }
}
