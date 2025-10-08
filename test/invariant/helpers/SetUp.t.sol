// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { kMinterHandler } from "../handlers/kMinterHandler.t.sol";

import { kStakingVaultHandler } from "../handlers/kStakingVaultHandler.t.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";

import { console2 } from "forge-std/console2.sol";

import { IkStakingVault } from "kam/src/interfaces/IkStakingVault.sol";
import { DeploymentBaseTest } from "kam/test/utils/DeploymentBaseTest.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

abstract contract SetUp is StdInvariant, DeploymentBaseTest {
    using SafeTransferLib for address;

    bool useMinter;
    kMinterHandler public minterHandler;
    kStakingVaultHandler public vaultHandlerDeltaNeutral;
    kStakingVaultHandler public vaultHandlerAlpha;
    kStakingVaultHandler public vaultHandlerBeta;
    uint16 public constant PERFORMANCE_FEE = 2000; // 20%
    uint16 public constant MANAGEMENT_FEE = 100; // 1%

    function _setUp() internal {
        super.setUp();
    }

    function _setUpVaultFees(IkStakingVault vault) internal {
        vm.startPrank(users.admin);
        vault.setPerformanceFee(PERFORMANCE_FEE);
        vault.setManagementFee(MANAGEMENT_FEE);
        vm.stopPrank();
    }

    function _setUpkStakingVaultHandlerDeltaNeutral() internal {
        address[] memory _minterActors = _getMinterActors();
        address[] memory _vaultActors = _getVaultActors();
        vaultHandlerDeltaNeutral = new kStakingVaultHandler(
            address(dnVault),
            address(assetRouter),
            address(DNVaultAdapterUSDC),
            address(minterAdapterUSDC),
            tokens.usdc,
            address(kUSD),
            users.relayer,
            _minterActors,
            _vaultActors,
            useMinter ? address(minterHandler) : address(0)
        );
        targetContract(address(vaultHandlerDeltaNeutral));
        bytes4[] memory selectors = vaultHandlerDeltaNeutral.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(vaultHandlerDeltaNeutral), selectors: selectors }));
        vm.label(address(vaultHandlerDeltaNeutral), "kStakingVaultHandlerDeltaNeutral");
    }

    function _setUpkStakingVaultHandlerAlpha() internal {
        address[] memory _minterActors = _getMinterActors();
        address[] memory _vaultActors = _getVaultActors();
        vaultHandlerAlpha = new kStakingVaultHandler(
            address(alphaVault),
            address(assetRouter),
            address(ALPHAVaultAdapterUSDC),
            address(minterAdapterUSDC),
            tokens.usdc,
            address(kUSD),
            users.relayer,
            _minterActors,
            _vaultActors,
            useMinter ? address(minterHandler) : address(0)
        );
        targetContract(address(vaultHandlerAlpha));
        bytes4[] memory selectors = vaultHandlerAlpha.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(vaultHandlerAlpha), selectors: selectors }));
        vm.label(address(vaultHandlerAlpha), "kStakingVaultHandlerAlpha");
    }

    function _setUpkStakingVaultHandlerBeta() internal {
        address[] memory _minterActors = _getMinterActors();
        address[] memory _vaultActors = _getVaultActors();
        vaultHandlerBeta = new kStakingVaultHandler(
            address(betaVault),
            address(assetRouter),
            address(BETHAVaultAdapterUSDC),
            address(minterAdapterUSDC),
            tokens.usdc,
            address(kUSD),
            users.relayer,
            _minterActors,
            _vaultActors,
            useMinter ? address(minterHandler) : address(0)
        );
        targetContract(address(vaultHandlerBeta));
        bytes4[] memory selectors = vaultHandlerBeta.getEntryPoints();
        targetSelector(FuzzSelector({ addr: address(vaultHandlerBeta), selectors: selectors }));
        vm.label(address(vaultHandlerBeta), "kStakingVaultHandlerBeta");
    }

    function _setUpkMinterHandler() internal {
        address[] memory _minterActors = _getMinterActors();
        minterHandler = new kMinterHandler(
            address(minter),
            address(assetRouter),
            address(minterAdapterUSDC),
            tokens.usdc,
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
        uint256 totalAmount = amount * minters.length;
        address token = tokens.usdc;
        for (uint256 i = 0; i < minters.length; i++) {
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

        bytes32 proposalId = assetRouter.proposeSettleBatch(token, address(minter), batchId, totalAmount, 0, 0);
        assetRouter.executeSettleBatch(proposalId);
        vm.stopPrank();
        if (useMinter) {
            minterHandler.set_kMinter_actualAdapterBalance(totalAmount);
            minterHandler.set_kMinter_expectedAdapterBalance(totalAmount);
            minterHandler.set_kMinter_actualAdapterTotalAssets(totalAmount);
            minterHandler.set_kMinter_expectedAdapterTotalAssets(totalAmount);
            minterHandler.set_kMinter_actualTotalLockedAssets(totalAmount);
            minterHandler.set_kMinter_expectedTotalLockedAssets(totalAmount);
        }
    }
}
