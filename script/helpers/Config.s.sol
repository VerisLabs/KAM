// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";

contract Config is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint64 chainSelector;
        address router;
        address rmnProxy;
        address tokenAdminRegistry;
        address registryModuleOwnerCustom;
        address link;
        uint256 confirmations;
        string nativeCurrencySymbol;
    }

    constructor() {
        if (block.chainid == 10) {
            activeNetworkConfig = getOptimismConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseConfig();
        }
    }

    function getOptimismConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory opConfig = NetworkConfig({
            chainSelector: 3_734_403_246_176_062_136,
            router: 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f,
            rmnProxy: 0x55b3FCa23EdDd28b1f5B4a3C7975f63EFd2d06CE,
            tokenAdminRegistry: 0x657c42abE4CD8aa731Aec322f871B5b90cf6274F,
            registryModuleOwnerCustom: 0xAFEd606Bd2CAb6983fC6F10167c98aaC2173D77f,
            link: 0x350a791Bfc2C21F9Ed5d10980Dad2e2638ffa7f6,
            confirmations: 2,
            nativeCurrencySymbol: "ETH"
        });
        return opConfig;
    }

    function getBaseConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory baseConfig = NetworkConfig({
            chainSelector: 15_971_525_489_660_198_786,
            router: 0x881e3A65B4d4a04dD529061dd0071cf975F58bCD,
            rmnProxy: 0xC842c69d54F83170C42C4d556B4F6B2ca53Dd3E8,
            tokenAdminRegistry: 0x6f6C373d09C07425BaAE72317863d7F6bb731e37,
            registryModuleOwnerCustom: 0xAFEd606Bd2CAb6983fC6F10167c98aaC2173D77f,
            link: 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196,
            confirmations: 2,
            nativeCurrencySymbol: "ETH"
        });
        return baseConfig;
    }

    function bytes32ToHexString(bytes32 _bytes) public pure returns (string memory) {
        bytes memory hexString = new bytes(64);
        bytes memory hexAlphabet = "0123456789abcdef";
        for (uint256 i = 0; i < 32; i++) {
            hexString[i * 2] = hexAlphabet[uint8(_bytes[i] >> 4)];
            hexString[i * 2 + 1] = hexAlphabet[uint8(_bytes[i] & 0x0f)];
        }
        return string(hexString);
    }
}