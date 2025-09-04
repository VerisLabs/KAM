// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest } from "../utils/BaseTest.sol";
import { USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import { CustodialAdapter } from "src/adapters/CustodialAdapter.sol";

import {
    ADAPTER_INVALID_REGISTRY,
    CUSTODIAL_INVALID_CUSTODIAL_ADDRESS,
    CUSTODIAL_VAULT_DESTINATION_NOT_SET,
    CUSTODIAL_WRONG_ROLE,
    CUSTODIAL_ZERO_AMOUNT
} from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

contract CustodialAdapterTest is BaseTest {
    CustodialAdapter public adapter;
    address public adapterImpl;
    address public mockRegistry;
    address public testVault;
    address public custodialAddress;
    address public mockAssetRouter;

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        enableMainnetFork();
        super.setUp();

        mockRegistry = address(0x1234);
        mockAssetRouter = address(0x5678);
        testVault = address(0x9ABC);
        custodialAddress = address(0xDEF0);

        // Deploy implementation
        adapterImpl = address(new CustodialAdapter());

        // Deploy proxy and initialize
        address proxy = Clones.clone(adapterImpl);
        adapter = CustodialAdapter(proxy);

        // Initialize with mock registry
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isAdmin.selector, address(this)), abi.encode(true));

        vm.mockCall(
            mockRegistry, abi.encodeWithSelector(IkRegistry.getContractById.selector), abi.encode(mockAssetRouter)
        );

        adapter.initialize(mockRegistry);

        // Fund test addresses
        deal(USDC_MAINNET, address(this), _1000_USDC);
        deal(USDC_MAINNET, address(adapter), _1000_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful initialization
    function test_Initialize_Success() public {
        // Deploy new proxy for testing
        address newProxy = Clones.clone(adapterImpl);
        CustodialAdapter newAdapter = CustodialAdapter(newProxy);

        newAdapter.initialize(mockRegistry);

        assertEq(newAdapter.registry(), mockRegistry, "Registry not set correctly");
        assertEq(newAdapter.name(), "CustodialAdapter", "Name not set correctly");
        assertEq(newAdapter.version(), "1.0.0", "Version not set correctly");
    }

    /// @dev Test initialization with zero registry reverts
    function test_Initialize_ZeroRegistry() public {
        address newProxy = Clones.clone(adapterImpl);
        CustodialAdapter newAdapter = CustodialAdapter(newProxy);

        vm.expectRevert(bytes(ADAPTER_INVALID_REGISTRY));
        newAdapter.initialize(address(0));
    }

    /// @dev Test double initialization reverts
    function test_Initialize_AlreadyInitialized() public {
        vm.expectRevert();
        adapter.initialize(mockRegistry);
    }

    /*//////////////////////////////////////////////////////////////
                    VAULT DESTINATION MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test setting vault destination successfully
    function test_SetVaultDestination_Success() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        assertEq(adapter.getVaultDestination(testVault), custodialAddress, "Vault destination not set");
    }

    /// @dev Test setting vault destination with zero vault reverts
    function test_SetVaultDestination_ZeroVault() public {
        vm.expectRevert(bytes(CUSTODIAL_INVALID_CUSTODIAL_ADDRESS));
        adapter.setVaultDestination(address(0), custodialAddress);
    }

    /// @dev Test setting vault destination with zero custodial address reverts
    function test_SetVaultDestination_ZeroCustodialAddress() public {
        vm.expectRevert(bytes(CUSTODIAL_INVALID_CUSTODIAL_ADDRESS));
        adapter.setVaultDestination(testVault, address(0));
    }

    /// @dev Test updating existing vault destination
    function test_SetVaultDestination_UpdateExisting() public {
        address firstCustodial = address(0xAAAA);
        address secondCustodial = address(0xBBBB);

        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        // Set initial destination
        adapter.setVaultDestination(testVault, firstCustodial);
        assertEq(adapter.getVaultDestination(testVault), firstCustodial, "First destination not set");

        // Update destination
        adapter.setVaultDestination(testVault, secondCustodial);
        assertEq(adapter.getVaultDestination(testVault), secondCustodial, "Second destination not set");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT OPERATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful deposit
    function test_Deposit_Success() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        uint256 depositAmount = _100_USDC;

        vm.startPrank(mockAssetRouter);

        adapter.deposit(USDC_MAINNET, depositAmount, testVault);

        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), depositAmount, "Virtual balance not updated");

        vm.stopPrank();
    }

    /// @dev Test deposit without vault destination reverts
    function test_Deposit_NoVaultDestination() public {
        uint256 depositAmount = _100_USDC;

        vm.startPrank(mockAssetRouter);
        vm.expectRevert(bytes(CUSTODIAL_VAULT_DESTINATION_NOT_SET));
        adapter.deposit(USDC_MAINNET, depositAmount, testVault);
        vm.stopPrank();
    }

    /// @dev Test deposit with zero amount reverts
    function test_Deposit_ZeroAmount() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        vm.startPrank(mockAssetRouter);
        vm.expectRevert(bytes(CUSTODIAL_ZERO_AMOUNT));
        adapter.deposit(USDC_MAINNET, 0, testVault);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM OPERATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test successful redeem
    function test_Redeem_Success() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        uint256 depositAmount = _100_USDC;
        uint256 redeemAmount = _100_USDC / 2;

        vm.startPrank(mockAssetRouter);

        // Deposit first
        adapter.deposit(USDC_MAINNET, depositAmount, testVault);

        // Then redeem
        adapter.redeem(USDC_MAINNET, redeemAmount, testVault);

        assertEq(
            adapter.totalVirtualAssets(testVault, USDC_MAINNET), depositAmount - redeemAmount, "Redeem not tracked"
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        TOTAL ASSETS MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test setting total assets
    function test_SetTotalAssets_Success() public {
        uint256 totalAssets = _1000_USDC;

        vm.startPrank(mockAssetRouter);
        adapter.setTotalAssets(testVault, USDC_MAINNET, totalAssets);
        vm.stopPrank();

        assertEq(adapter.totalAssets(testVault, USDC_MAINNET), totalAssets, "Total assets not set");
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test totalEstimatedAssets returns custodial address balance
    function test_TotalEstimatedAssets() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        uint256 custodialBalance = _100_USDC;
        deal(USDC_MAINNET, custodialAddress, custodialBalance);

        assertEq(adapter.totalEstimatedAssets(testVault, USDC_MAINNET), custodialBalance, "Estimated assets incorrect");
    }

    /// @dev Test view functions with unset values
    function test_ViewFunctions_UnsetValues() public view {
        assertEq(adapter.getVaultDestination(testVault), address(0), "Unset vault destination should be zero");
        assertEq(adapter.totalAssets(testVault, USDC_MAINNET), 0, "Unset total assets should be zero");
        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), 0, "Unset virtual assets should be zero");
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test non-admin cannot set vault destinations
    function test_AccessControl_NonAdminSetVault() public {
        vm.mockCall(
            mockRegistry, abi.encodeWithSelector(IkRegistry.isAdmin.selector, address(0xBEEF)), abi.encode(false)
        );

        address nonAdmin = address(0xBEEF);

        vm.startPrank(nonAdmin);
        vm.expectRevert(bytes(CUSTODIAL_WRONG_ROLE));
        adapter.setVaultDestination(testVault, custodialAddress);
        vm.stopPrank();
    }

    /// @dev Test non-kAssetRouter cannot call deposit/redeem
    function test_AccessControl_NonKAssetRouter() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);
        address nonRouter = address(0xBEEF);

        vm.startPrank(nonRouter);

        vm.expectRevert(bytes(CUSTODIAL_WRONG_ROLE));
        adapter.deposit(USDC_MAINNET, _100_USDC, testVault);

        vm.expectRevert(bytes(CUSTODIAL_WRONG_ROLE));
        adapter.redeem(USDC_MAINNET, _100_USDC, testVault);

        vm.expectRevert(bytes(CUSTODIAL_WRONG_ROLE));
        adapter.setTotalAssets(testVault, USDC_MAINNET, _1000_USDC);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION WORKFLOW TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test complete deposit/redeem workflow
    function test_CompleteWorkflow() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        uint256 initialDeposit = _100_USDC;
        uint256 additionalDeposit = _100_USDC / 2;
        uint256 redeemAmount = _100_USDC / 4;
        uint256 finalTotal = _1000_USDC;

        vm.startPrank(mockAssetRouter);

        // Step 1: Initial deposit
        adapter.deposit(USDC_MAINNET, initialDeposit, testVault);
        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), initialDeposit, "Initial deposit failed");

        // Step 2: Additional deposit
        adapter.deposit(USDC_MAINNET, additionalDeposit, testVault);
        uint256 expectedVirtual = initialDeposit + additionalDeposit;
        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), expectedVirtual, "Additional deposit failed");

        // Step 3: Partial redeem
        adapter.redeem(USDC_MAINNET, redeemAmount, testVault);
        expectedVirtual -= redeemAmount;
        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), expectedVirtual, "Redeem failed");

        // Step 4: Set total assets
        adapter.setTotalAssets(testVault, USDC_MAINNET, finalTotal);
        assertEq(adapter.totalAssets(testVault, USDC_MAINNET), finalTotal, "Set total assets failed");

        // Verify virtual assets unchanged
        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), expectedVirtual, "Virtual assets corrupted");

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASES & FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test boundary values
    function test_BoundaryValues() public {
        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        vm.startPrank(mockAssetRouter);

        // Test maximum uint256 value
        uint256 maxValue = type(uint256).max;
        adapter.setTotalAssets(testVault, USDC_MAINNET, maxValue);
        assertEq(adapter.totalAssets(testVault, USDC_MAINNET), maxValue, "Max value not handled");

        // Test 1 wei
        adapter.deposit(USDC_MAINNET, 1, testVault);
        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), 1, "1 wei not handled");

        vm.stopPrank();
    }

    /// @dev Fuzz test deposit amounts
    function testFuzz_DepositAmounts(uint128 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= _1000_USDC);

        vm.mockCall(mockRegistry, abi.encodeWithSelector(IkRegistry.isVault.selector, testVault), abi.encode(true));

        adapter.setVaultDestination(testVault, custodialAddress);

        vm.startPrank(mockAssetRouter);
        adapter.deposit(USDC_MAINNET, amount, testVault);
        vm.stopPrank();

        assertEq(adapter.totalVirtualAssets(testVault, USDC_MAINNET), amount, "Fuzz deposit failed");
    }

    /// @dev Fuzz test total assets values
    function testFuzz_TotalAssetsValues(uint256 assets) public {
        vm.startPrank(mockAssetRouter);
        adapter.setTotalAssets(testVault, USDC_MAINNET, assets);
        vm.stopPrank();

        assertEq(adapter.totalAssets(testVault, USDC_MAINNET), assets, "Fuzz total assets failed");
    }
}
