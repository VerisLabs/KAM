// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "../../src/kUSDToken.sol";
import "forge-std/Script.sol";

contract DeployKUSD is Script {

    // Deploy kUSD token
    uint8 public constant DECIMALS = 18;
    string public constant NAME = "Keyrock USD";
    string public constant SYMBOL = "kUSD";
    uint256 public constant MAX_SUPPLY = type(uint256).max;
    uint256 public constant PRE_MINT = 0;
    address public burnerMinter;

    function run() external {
        // Load deployer private key from environment variables
        burnerMinter = vm.envAddress("BURNER_MINTER_ADDRESS");

        vm.startBroadcast();

        kUSD token = new kUSD(NAME, SYMBOL, DECIMALS, MAX_SUPPLY, PRE_MINT, burnerMinter);

        console.log("kUSD Deployment Addresses:");
        console.log("kUSD:", address(token));
        console.log("MinterAndBurner:", burnerMinter);

        vm.stopBroadcast();
    }
}