// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kBaseRoles } from "src/base/kBaseRoles.sol";
//import { REGISTRYREADERMODULE_UNAUTHORIZED } from "src/errors/Errors.sol";
import { IModule } from "src/interfaces/modules/IModule.sol";
import { IProcessRouterModule } from "src/interfaces/IProcessRouterModule.sol";

/// @title ProcessRouterModule
/// @notice Module for reading the registry
/// @dev Inherits from kBaseRoles for role-based access control
contract ProcessRouterModule is IModule, IProcessRouterModule, kBaseRoles {
    
    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Storage structure for AdapterGuardianModule using ERC-7201 namespaced storage pattern
    /// @dev This structure maintains adapter permissions and parameter checkers
    /// @custom:storage-location erc7201:kam.storage.AdapterGuardianModule
    struct ProcessRouterModuleStorage {
        /// @dev proccessId to target
        mapping(bytes32 => address[]) processIdToTargets;
        /// @dev processId to selector
        mapping(bytes32 => bytes4[]) processIdToSelectors;
    }

        // keccak256(abi.encode(uint256(keccak256("kam.storage.ProcessRouterModule")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PROCESSROUTERMODULE_STORAGE_LOCATION =
        0x554e3a023a6cce752a6c1cc2237cde172425f8630dbeddd5526e9dc09c304100;

    /// @notice Retrieves the ProcessRouterModule storage struct from its designated storage slot
    /// @dev Uses ERC-7201 namespaced storage pattern to access the storage struct at a deterministic location.
    /// This approach prevents storage collisions in upgradeable contracts and allows safe addition of new
    /// storage variables in future upgrades without affecting existing storage layout.
    /// @return $ The AdapterGuardianModuleStorage struct reference for state modifications
    function _getProcessRouterModuleStorage() private pure returns (ProcessRouterModuleStorage storage $) {
        assembly {
            $.slot := PROCESSROUTERMODULE_STORAGE_LOCATION
        }
    }

    /*//////////////////////////////////////////////////////////////
                              MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProcessRouterModule
    function setProcessId(bytes32 processId, address[] memory targets, bytes4[] memory selectors_) external {
        ProcessRouterModuleStorage storage $ = _getProcessRouterModuleStorage();
        $.processIdToTargets[processId] = targets;
        $.processIdToSelectors[processId] = selectors_;
    }

    /// @inheritdoc IProcessRouterModule
    function getProcess(bytes32 processId) external view returns (address[] memory targets, bytes4[] memory selectors_) {
        ProcessRouterModuleStorage storage $ = _getProcessRouterModuleStorage();
        targets = $.processIdToTargets[processId];
        selectors_ = $.processIdToSelectors[processId];
    }

    /// @inheritdoc IProcessRouterModule
    function getfunctionSelector(string memory functionSignature) external pure returns (bytes4 selector) {
        selector = bytes4(abi.encodeWithSignature(functionSignature));
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE SELECTORS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IModule
    function selectors() external pure returns (bytes4[] memory moduleSelectors) {
        moduleSelectors = new bytes4[](3);
        moduleSelectors[0] = this.setProcessId.selector;
        moduleSelectors[1] = this.getProcess.selector;
        moduleSelectors[2] = this.getfunctionSelector.selector;
    }
}
