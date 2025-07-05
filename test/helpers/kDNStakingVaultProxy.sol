// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { LibClone } from "solady/utils/LibClone.sol";

/// @title kDNStakingVaultProxy
/// @notice Helper contract to deploy kDNStakingVault via minimal proxy for testing
contract kDNStakingVaultProxy {
    using LibClone for address;

    /// @notice Deploy a minimal proxy of kDNStakingVault and initialize it
    /// @param implementation The kDNStakingVault implementation address
    /// @param initData The initialization data
    /// @return proxy The address of the deployed proxy
    function deployAndInitialize(address implementation, bytes memory initData) external returns (address proxy) {
        // Deploy minimal proxy
        proxy = implementation.clone();

        // Initialize the proxy
        (bool success, bytes memory returnData) = proxy.call(initData);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            } else {
                revert("Initialization failed");
            }
        }

        return proxy;
    }

    /// @notice Deploy a minimal proxy with deterministic address
    /// @param implementation The kDNStakingVault implementation address
    /// @param salt The salt for deterministic deployment
    /// @param initData The initialization data
    /// @return proxy The address of the deployed proxy
    function deployDeterministicAndInitialize(
        address implementation,
        bytes32 salt,
        bytes memory initData
    )
        external
        returns (address proxy)
    {
        // Deploy minimal proxy with deterministic address
        proxy = implementation.cloneDeterministic(salt);

        // Initialize the proxy
        (bool success, bytes memory returnData) = proxy.call(initData);
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    let returnDataSize := mload(returnData)
                    revert(add(32, returnData), returnDataSize)
                }
            } else {
                revert("Initialization failed");
            }
        }

        return proxy;
    }
}
