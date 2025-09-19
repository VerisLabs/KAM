// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kMinterHandler } from "../handlers/kMinterHandler.t.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import { kStakingVaultHandler } from "../handlers/kStakingVaultHandler.t.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { IkStakingVault } from "src/interfaces/IkStakingVault.sol";
import { DeploymentBaseTest } from "test/utils/DeploymentBaseTest.sol";
import { console2 } from "forge-std/console2.sol";

abstract contract SetUp is StdInvariant, DeploymentBaseTest {
    using SafeTransferLib for address;

    kMinterHandler public minterHandler;
    kStakingVaultHandler public vaultHandler;

    function _setUp() internal {
        super.setUp();
    }

    function _setUpkStakingVaultHandlerAlpha() internal {
        address[] memory _minterActors = _getMinterActors();
        address[] memory _vaultActors = _getVaultActors();
        vaultHandler = new kStakingVaultHandler(
            address(alphaVault),
            address(assetRouter),
            address(vaultAdapter4),
            address(vaultAdapter1),
            getUSDC(),
            address(kUSD),
            users.relayer,
            _minterActors,
            _vaultActors
        );
        targetContract(address(vaultHandler));
        bytes4[] memory selectors = vaultHandler.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(vaultHandler), selectors: selectors }));
        vm.label(address(vaultHandler), "kStakingVaultHandler");
    }

    function _setUpkMinterHandler() internal {
        address[] memory _minterActors = _getMinterActors();
        minterHandler = new kMinterHandler(
            address(minter),
            address(assetRouter),
            address(vaultAdapter1),
            getUSDC(),
            address(kUSD),
            users.relayer,
            _minterActors
        );
        targetContract(address(minterHandler));
        bytes4[] memory selectors = minterHandler.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(minterHandler), selectors: selectors }));
        vm.label(address(minterHandler), "kMinterHandler");
    }

    function _getMinterActors() internal returns (address[] memory) {
        address[] memory _actors = new address[](4);
        _actors[0] = address(users.institution);
        _actors[1] = address(users.institution2);
        _actors[2] = address(users.institution3);
        _actors[3] = address(users.institution4);
        return _actors;
    }

    function _getVaultActors() internal returns (address[] memory) {
        address[] memory _actors = new address[](3);
        _actors[0] = address(users.alice);
        _actors[1] = address(users.bob);
        _actors[2] = address(users.charlie);
        return _actors;
    }

    function _setUpInstitutionalMint() internal {
        address[] memory minters = _getMinterActors();
        uint256 amount = 10_000_000 * 10 ** 6;
        address token = getUSDC();
        for(uint256 i = 0; i < minters.length; i++) {
            vm.startPrank(minters[i]);
            console2.log("Minting", minters[i]);
            console2.log("Balance", token.balanceOf(minters[i]));
            token.safeApprove(address(minter), amount);
            minter.mint(token, minters[i], amount);
            vm.stopPrank();
        }

        vm.startPrank(users.relayer);
        bytes32 batchId = minter.getBatchId(token);

        minter.closeBatch(batchId, true);
       
        bytes32 proposalId = assetRouter.proposeSettleBatch(token, address(minter), batchId, amount * minters.length, 0, 0);
        assetRouter.executeSettleBatch(proposalId);
        vm.stopPrank();
    }
}
