// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// Simple debug calculation
contract DebugUnstaking {
    uint256 private constant PRECISION = 1e18; // 18 decimal precision
    
    function calculateSplit() external pure returns (
        uint256 currentStkTokenPrice,
        uint256 totalAssetsValue,
        uint256 split,
        bool isValid
    ) {
        // Values from the test trace
        uint256 totalStkTokenAssets = 1000000 * 1e6; // 1M USDC after staking settlement
        uint256 totalStkTokenSupply = 1000000 * 1e6; // 1M stkTokens minted
        uint256 totalStkTokensUnstaked = 100000 * 1e6; // 100K stkTokens being unstaked
        uint256 totalKTokensToReturn = 100000 * 1e6; // 100K kTokens to return
        uint256 totalYieldToMinter = 0; // No yield
        
        // Calculate current price (line 634)
        currentStkTokenPrice = totalStkTokenSupply == 0 
            ? PRECISION 
            : (totalStkTokenAssets * PRECISION) / totalStkTokenSupply;
            
        // Calculate total assets value (line 637)
        totalAssetsValue = (totalStkTokensUnstaked * currentStkTokenPrice) / PRECISION;
        
        // Calculate split
        split = totalKTokensToReturn + totalYieldToMinter;
        
        // Check validity (line 640)
        isValid = (split == totalAssetsValue);
        
        return (currentStkTokenPrice, totalAssetsValue, split, isValid);
    }
}