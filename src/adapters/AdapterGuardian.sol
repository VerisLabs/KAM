// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MultiFacetProxy } from "src/base/MultiFacetProxy.sol";
import { Initializable } from "src/vendor/Initializable.sol";
import { UUPSUpgradeable } from "src/vendor/UUPSUpgradeable.sol";
import { OptimizedOwnableRoles } from "src/libraries/OptimizedOwnableRoles.sol";

interface IParametersChecker {
    function canCall(address target, bytes4 selector, bytes calldata params) external view returns (bool);
}

contract AdapterGuardian is Initializable, UUPSUpgradeable, OptimizedOwnableRoles {

    struct AdapterGuardianStorage {
        mapping(address => mapping(bytes4 => bool)) allowedSelectors;
        mapping(address => mapping(bytes4 => address)) parametersChecker;
    }

    // keccak256(abi.encode(uint256(keccak256("kam.storage.AdapterGuardian")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ADAPTERGUARDIAN_STORAGE_LOCATION = 0xe5611243dee8bdd60a5124e5e57bd61750c6e30e3ce6df4e896dba698ed88900;

    /// @notice Retrieves the AdapterGuardian storage struct from its designated storage slot
    /// @return $ The AdapterGuardianStorage struct reference for state modifications
    function _getAdapterGuardianStorage() private pure returns (AdapterGuardianStorage storage $) {
        assembly {
            $.slot := ADAPTERGUARDIAN_STORAGE_LOCATION
        }
    }

    /// @notice Initializes the AdapterGuardian contract
    /// @param registry_ Address of the registry contract
    function initialize(address registry_) external initializer {
        _checkZeroAddress(registry_);
        OptimizedOwnableRolesStorage storage $ = _getOptimizedOwnableRolesStorage();
        $owner = msg.sender;
        emit ContractInitialized(registry_);
    }

    /// @notice Disables initializers to prevent implementation contract initialization
    constructor() {
        _disableInitializers();
    }

    function canCall(address target, bytes4 selector, bytes calldata params) public view returns (bool) {
        AdapterGuardianStorage storage $ = _getAdapterGuardianStorage();
        if (!$allowedSelectors[target][selector]) return false;
        address parametersChecker = $parametersChecker[target][selector];
        if (parametersChecker == address(0)) return true;
        return IParametersChecker(parametersChecker).canCall(target, selector, params);
    }

    function setAllowedSelector(address target, bytes4 selector, bool allowed) external {
        _checkOwner();
        AdapterGuardianStorage storage $ = _getAdapterGuardianStorage();
        $allowedSelectors[target][selector] = allowed;
    }

    function setParametersChecker(address target, bytes4 selector, address parametersChecker) external {
        _checkOwner();
        AdapterGuardianStorage storage $ = _getAdapterGuardianStorage();
        $parametersChecker[target][selector] = parametersChecker;
    }
}