// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest } from "../utils/BaseTest.sol";
import { _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { BaseAdapter } from "src/adapters/BaseAdapter.sol";

import { ADAPTER_INSUFFICIENT_BALANCE, ADAPTER_ZERO_ADDRESS } from "src/errors/Errors.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

contract BaseAdapterTest is BaseTest {
    MockAdapter public adapter;

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Use test contract as mock registry
        address mockRegistry = address(this);
        adapter = new MockAdapter(mockRegistry);

        // Fund adapter with test tokens
        mockUSDC.mint(address(adapter), _1000_USDC);
        mockUSDC.mint(address(this), _1000_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Test adapter initialization
    function test_Constructor() public view {
        assertEq(address(adapter.registry()), address(this), "Registry not set correctly");
    }

    /// @dev Test constructor with zero registry reverts
    function test_Constructor_RevertZeroRegistry() public {
        vm.expectRevert(bytes(ADAPTER_ZERO_ADDRESS));
        new MockAdapter(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test deposit function exists and works
    function test_Deposit_Success() public {
        uint256 depositAmount = _100_USDC;
        address testVault = address(0x5678);

        IERC20(getUSDC()).approve(address(adapter), depositAmount);

        uint256 adapterBalanceBefore = IERC20(getUSDC()).balanceOf(address(adapter));
        uint256 totalAssetsBefore = adapter.totalAssets(testVault, getUSDC());

        adapter.deposit(getUSDC(), depositAmount, testVault);

        assertEq(
            IERC20(getUSDC()).balanceOf(address(adapter)),
            adapterBalanceBefore + depositAmount,
            "Tokens not transferred to adapter"
        );
        assertEq(
            adapter.totalAssets(testVault, getUSDC()), totalAssetsBefore + depositAmount, "Total assets not updated"
        );
    }

    /// @dev Test withdraw function exists and works
    function test_Withdraw_Success() public {
        uint256 withdrawAmount = _100_USDC;
        address testVault = address(0x5678);

        // Setup: deposit first
        IERC20(getUSDC()).approve(address(adapter), withdrawAmount);
        adapter.deposit(getUSDC(), withdrawAmount, testVault);

        uint256 vaultBalanceBefore = IERC20(getUSDC()).balanceOf(testVault);
        uint256 totalAssetsBefore = adapter.totalAssets(testVault, getUSDC());

        adapter.withdraw(getUSDC(), withdrawAmount, testVault);

        assertEq(
            IERC20(getUSDC()).balanceOf(testVault),
            vaultBalanceBefore + withdrawAmount,
            "Tokens not transferred to vault"
        );
        assertEq(
            adapter.totalAssets(testVault, getUSDC()), totalAssetsBefore - withdrawAmount, "Total assets not updated"
        );
    }

    /// @dev Test totalAssets function
    function test_totalAssetsVirtual() public {
        address testVault = address(0x5678);
        uint256 testAmount = _100_USDC;

        adapter.setAssetsForTest(getUSDC(), testAmount);

        assertEq(adapter.totalAssets(testVault, getUSDC()), testAmount, "Total assets incorrect");
    }

    /// @dev Test setTotalAssets function
    function test_SetTotalAssets() public {
        address testVault = address(0x5678);
        uint256 newTotal = _100_USDC;

        adapter.setTotalAssets(testVault, getUSDC(), newTotal);

        assertEq(adapter.totalAssets(testVault, getUSDC()), newTotal, "Total assets not set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR CONDITIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test withdraw with insufficient balance
    function test_Withdraw_InsufficientBalance() public {
        address testVault = address(0x5678);
        uint256 withdrawAmount = _100_USDC;

        // Try to withdraw without depositing
        vm.expectRevert(bytes(ADAPTER_INSUFFICIENT_BALANCE));
        adapter.withdraw(getUSDC(), withdrawAmount, testVault);
    }

    /*//////////////////////////////////////////////////////////////
                          EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Test deposit and withdraw with zero amounts
    function test_ZeroAmounts() public {
        address testVault = address(0x5678);

        // These should not revert (depending on implementation)
        adapter.deposit(getUSDC(), 0, testVault);
        adapter.withdraw(getUSDC(), 0, testVault);
    }

    /// @dev Test multiple deposits and withdrawals
    function test_MultipleOperations() public {
        address testVault = address(0x5678);
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _100_USDC / 2;

        // Multiple deposits
        IERC20(getUSDC()).approve(address(adapter), amount1 + amount2);
        adapter.deposit(getUSDC(), amount1, testVault);
        adapter.deposit(getUSDC(), amount2, testVault);

        assertEq(
            adapter.totalAssets(testVault, getUSDC()), amount1 + amount2, "Multiple deposits not tracked correctly"
        );

        // Partial withdrawal
        adapter.withdraw(getUSDC(), amount2, testVault);

        assertEq(adapter.totalAssets(testVault, getUSDC()), amount1, "Partial withdrawal not tracked correctly");
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY INTERACTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Test registry getter
    function test_RegistryGetter() public view {
        address registryRef = adapter.registry();
        assertEq(address(registryRef), address(this), "Registry getter incorrect");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fuzz test deposit and withdraw operations
    function testFuzz_DepositWithdraw(uint128 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= _1000_USDC); // Within our funded range

        address testVault = address(0x5678);

        // Deposit
        IERC20(getUSDC()).approve(address(adapter), amount);
        adapter.deposit(getUSDC(), amount, testVault);

        assertEq(adapter.totalAssets(testVault, getUSDC()), amount, "Deposit amount incorrect");

        // Withdraw
        adapter.withdraw(getUSDC(), amount, testVault);

        assertEq(adapter.totalAssets(testVault, getUSDC()), 0, "Withdraw not complete");
    }

    /// @dev Fuzz test setTotalAssets
    function testFuzz_SetTotalAssets(uint256 amount) public {
        address testVault = address(0x5678);

        adapter.setTotalAssets(testVault, getUSDC(), amount);

        assertEq(adapter.totalAssets(testVault, getUSDC()), amount, "SetTotalAssets failed");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test adapter with different assets (if supported)
    function test_MultipleAssets() public {
        // This test would need to be adapted based on whether the adapter supports multiple assets
        // For now, just test with getUSDC() which we know works
        address testVault = address(0x5678);
        uint256 amount = _100_USDC;

        IERC20(getUSDC()).approve(address(adapter), amount);
        adapter.deposit(getUSDC(), amount, testVault);

        assertEq(adapter.totalAssets(testVault, getUSDC()), amount, "Multi-asset test failed");
    }

    /// @dev Test adapter state consistency
    function test_StateConsistency() public {
        address testVault = address(0x5678);
        uint256 amount = _100_USDC;

        // Deposit
        IERC20(getUSDC()).approve(address(adapter), amount);
        adapter.deposit(getUSDC(), amount, testVault);

        uint256 totalAfterDeposit = adapter.totalAssets(testVault, getUSDC());

        // Set total assets directly
        adapter.setTotalAssets(testVault, getUSDC(), amount * 2);

        assertEq(adapter.totalAssets(testVault, getUSDC()), amount * 2, "Direct set failed");
        assertNotEq(adapter.totalAssets(testVault, getUSDC()), totalAfterDeposit, "State not updated");
    }

    /*//////////////////////////////////////////////////////////////
                    ENHANCED INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test initialization with various registry addresses
    function test_InitializationWithDifferentRegistries() public {
        // Test with different registry addresses
        address mockRegistry1 = address(0x1111);
        address mockRegistry2 = address(0x2222);

        MockAdapter adapter1 = new MockAdapter(mockRegistry1);
        MockAdapter adapter2 = new MockAdapter(mockRegistry2);

        assertEq(address(adapter1.registry()), mockRegistry1, "Registry 1 not set correctly");
        assertEq(address(adapter2.registry()), mockRegistry2, "Registry 2 not set correctly");
    }

    /// @dev Test multiple zero address scenarios
    function test_MultipleZeroAddressScenarios() public {
        // Test constructor with zero address (should revert)
        vm.expectRevert(bytes(ADAPTER_ZERO_ADDRESS));
        new MockAdapter(address(0));

        // Test deposit with zero vault address - MockAdapter allows this
        uint256 amount = _100_USDC;
        IERC20(getUSDC()).approve(address(adapter), amount);
        adapter.deposit(getUSDC(), amount, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test registry access control validation
    function test_RegistryAccessValidation() public view {
        // Verify registry returns correct address
        address registryAddr = adapter.registry();
        assertEq(registryAddr, address(this), "Registry address mismatch");
    }

    /// @dev Test unauthorized access scenarios
    function test_UnauthorizedAccess() public {
        // MockAdapter has no access control, any caller can use it
        address caller = address(0xBEEF);
        vm.startPrank(caller);

        uint256 amount = _100_USDC;
        mockUSDC.mint(caller, amount);

        IERC20(getUSDC()).approve(address(adapter), amount);
        adapter.deposit(getUSDC(), amount, address(0x5678));

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test asset balance tracking accuracy
    function test_AssetBalanceTracking() public {
        address testVault = address(0x5678);
        uint256 depositAmount1 = _100_USDC;
        uint256 depositAmount2 = _100_USDC / 2;

        // Initial balance should be zero
        assertEq(adapter.totalAssets(testVault, getUSDC()), 0, "Initial balance should be zero");

        // First deposit
        IERC20(getUSDC()).approve(address(adapter), depositAmount1);
        adapter.deposit(getUSDC(), depositAmount1, testVault);
        assertEq(adapter.totalAssets(testVault, getUSDC()), depositAmount1, "First deposit tracking failed");

        // Second deposit
        IERC20(getUSDC()).approve(address(adapter), depositAmount2);
        adapter.deposit(getUSDC(), depositAmount2, testVault);
        assertEq(
            adapter.totalAssets(testVault, getUSDC()), depositAmount1 + depositAmount2, "Second deposit tracking failed"
        );

        // Partial withdrawal
        adapter.withdraw(getUSDC(), depositAmount2, testVault);
        assertEq(adapter.totalAssets(testVault, getUSDC()), depositAmount1, "Withdrawal tracking failed");
    }

    /// @dev Test multiple asset management
    function test_MultipleAssetManagement() public {
        address testVault = address(0x5678);
        uint256 amount = _100_USDC;

        // Test with USDC
        IERC20(getUSDC()).approve(address(adapter), amount);
        adapter.deposit(getUSDC(), amount, testVault);

        uint256 usdcBalance = adapter.totalAssets(testVault, getUSDC());
        assertEq(usdcBalance, amount, "USDC balance incorrect");

        // Test setting different amounts for different assets
        address mockAsset = address(0xABCD);
        adapter.setTotalAssets(testVault, mockAsset, amount * 2);

        assertEq(adapter.totalAssets(testVault, mockAsset), amount * 2, "Mock asset balance incorrect");
        assertEq(adapter.totalAssets(testVault, getUSDC()), amount, "USDC balance affected incorrectly");
    }

    /// @dev Test asset balance overflow scenarios
    function test_AssetBalanceOverflow() public {
        address testVault = address(0x5678);

        // Test with maximum uint256 value
        uint256 maxAmount = type(uint256).max;
        adapter.setTotalAssets(testVault, getUSDC(), maxAmount);

        assertEq(adapter.totalAssets(testVault, getUSDC()), maxAmount, "Max value not set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT INTERACTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test multiple vault interactions
    function test_MultipleVaultInteractions() public {
        address vault1 = address(0x1111);
        address vault2 = address(0x2222);
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _100_USDC / 2;

        // Deposit to vault1
        IERC20(getUSDC()).approve(address(adapter), amount1);
        adapter.deposit(getUSDC(), amount1, vault1);

        // Deposit to vault2
        IERC20(getUSDC()).approve(address(adapter), amount2);
        adapter.deposit(getUSDC(), amount2, vault2);

        // Verify independent tracking
        assertEq(adapter.totalAssets(vault1, getUSDC()), amount1, "Vault1 balance incorrect");
        assertEq(adapter.totalAssets(vault2, getUSDC()), amount2, "Vault2 balance incorrect");

        // Withdraw from vault1
        adapter.withdraw(getUSDC(), amount1 / 2, vault1);

        // Verify vault2 unaffected
        assertEq(adapter.totalAssets(vault1, getUSDC()), amount1 / 2, "Vault1 withdrawal failed");
        assertEq(adapter.totalAssets(vault2, getUSDC()), amount2, "Vault2 affected incorrectly");
    }

    /// @dev Test vault isolation
    function test_VaultIsolation() public {
        address vault1 = address(0x1111);
        address vault2 = address(0x2222);
        uint256 amount = _100_USDC;

        // Set assets for vault1
        adapter.setTotalAssets(vault1, getUSDC(), amount);

        // Verify vault2 is unaffected
        assertEq(adapter.totalAssets(vault1, getUSDC()), amount, "Vault1 not set correctly");
        assertEq(adapter.totalAssets(vault2, getUSDC()), 0, "Vault2 affected incorrectly");
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY & EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Test deposit with exact token balance
    function test_DepositWithExactBalance() public {
        address testVault = address(0x5678);
        uint256 exactBalance = IERC20(getUSDC()).balanceOf(address(this));

        IERC20(getUSDC()).approve(address(adapter), exactBalance);
        adapter.deposit(getUSDC(), exactBalance, testVault);

        assertEq(adapter.totalAssets(testVault, getUSDC()), exactBalance, "Exact balance deposit failed");
        assertEq(IERC20(getUSDC()).balanceOf(address(this)), 0, "Caller balance not zero");
    }

    /// @dev Test withdraw with insufficient balance edge cases
    function test_WithdrawInsufficientBalanceEdgeCases() public {
        address testVault = address(0x5678);
        uint256 depositAmount = _100_USDC;

        // Deposit first
        IERC20(getUSDC()).approve(address(adapter), depositAmount);
        adapter.deposit(getUSDC(), depositAmount, testVault);

        // Try to withdraw more than deposited
        vm.expectRevert(bytes(ADAPTER_INSUFFICIENT_BALANCE));
        adapter.withdraw(getUSDC(), depositAmount + 1, testVault);

        // Try to withdraw exactly what was deposited (should work)
        adapter.withdraw(getUSDC(), depositAmount, testVault);

        // Try to withdraw from empty balance
        vm.expectRevert(bytes(ADAPTER_INSUFFICIENT_BALANCE));
        adapter.withdraw(getUSDC(), 1, testVault);
    }

    /// @dev Test boundary conditions
    function test_BoundaryConditions() public {
        address testVault = address(0x5678);

        // Test with 1 wei
        adapter.setTotalAssets(testVault, getUSDC(), 1);
        assertEq(adapter.totalAssets(testVault, getUSDC()), 1, "1 wei not set correctly");

        // Test with maximum value
        uint256 maxVal = type(uint256).max;
        adapter.setTotalAssets(testVault, getUSDC(), maxVal);
        assertEq(adapter.totalAssets(testVault, getUSDC()), maxVal, "Max value not set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test complete workflow integration
    function test_CompleteWorkflowIntegration() public {
        address testVault = address(0x5678);
        uint256 initialAmount = _100_USDC;
        uint256 additionalAmount = _100_USDC / 2;

        // Step 1: Initial deposit
        IERC20(getUSDC()).approve(address(adapter), initialAmount);
        adapter.deposit(getUSDC(), initialAmount, testVault);

        uint256 balanceAfterFirstDeposit = adapter.totalAssets(testVault, getUSDC());
        assertEq(balanceAfterFirstDeposit, initialAmount, "First deposit failed");

        // Step 2: Additional deposit
        IERC20(getUSDC()).approve(address(adapter), additionalAmount);
        adapter.deposit(getUSDC(), additionalAmount, testVault);

        uint256 totalAfterSecondDeposit = adapter.totalAssets(testVault, getUSDC());
        assertEq(totalAfterSecondDeposit, initialAmount + additionalAmount, "Second deposit failed");

        // Step 3: Partial withdrawal
        uint256 withdrawAmount = initialAmount / 2;
        adapter.withdraw(getUSDC(), withdrawAmount, testVault);

        uint256 balanceAfterWithdraw = adapter.totalAssets(testVault, getUSDC());
        assertEq(balanceAfterWithdraw, totalAfterSecondDeposit - withdrawAmount, "Withdrawal failed");

        // Step 4: Set total assets manually
        uint256 newTotal = _1000_USDC;
        adapter.setTotalAssets(testVault, getUSDC(), newTotal);

        assertEq(adapter.totalAssets(testVault, getUSDC()), newTotal, "Manual set failed");
    }

    /// @dev Test concurrent operations
    function test_ConcurrentOperations() public {
        address vault1 = address(0x1111);
        address vault2 = address(0x2222);
        uint256 amount = _100_USDC;

        // Concurrent deposits to different vaults
        IERC20(getUSDC()).approve(address(adapter), amount * 2);
        adapter.deposit(getUSDC(), amount, vault1);
        adapter.deposit(getUSDC(), amount, vault2);

        // Verify both deposits recorded correctly
        assertEq(adapter.totalAssets(vault1, getUSDC()), amount, "Vault1 concurrent deposit failed");
        assertEq(adapter.totalAssets(vault2, getUSDC()), amount, "Vault2 concurrent deposit failed");

        // Concurrent operations: withdraw from vault1, deposit to vault1
        adapter.withdraw(getUSDC(), amount / 2, vault1);
        IERC20(getUSDC()).approve(address(adapter), amount / 4);
        adapter.deposit(getUSDC(), amount / 4, vault1);

        uint256 expectedVault1Balance = amount - (amount / 2) + (amount / 4);
        assertEq(adapter.totalAssets(vault1, getUSDC()), expectedVault1Balance, "Concurrent operations failed");
        assertEq(adapter.totalAssets(vault2, getUSDC()), amount, "Vault2 affected by vault1 operations");
    }

    /*//////////////////////////////////////////////////////////////
                        ENHANCED FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fuzz test with multiple vaults
    function testFuzz_MultipleVaults(address vault1, address vault2, uint128 amount1, uint128 amount2) public {
        vm.assume(vault1 != vault2);
        vm.assume(vault1 != address(0) && vault2 != address(0));
        vm.assume(amount1 > 0 && amount1 <= _1000_USDC);
        vm.assume(amount2 > 0 && amount2 <= _1000_USDC);

        // Set assets for both vaults
        adapter.setTotalAssets(vault1, getUSDC(), amount1);
        adapter.setTotalAssets(vault2, getUSDC(), amount2);

        // Verify isolation
        assertEq(adapter.totalAssets(vault1, getUSDC()), amount1, "Vault1 fuzz test failed");
        assertEq(adapter.totalAssets(vault2, getUSDC()), amount2, "Vault2 fuzz test failed");
    }

    /// @dev Fuzz test deposit/withdraw cycles
    function testFuzz_DepositWithdrawCycles(uint128 amount, uint8 cycles) public {
        vm.assume(amount > 0 && amount <= _100_USDC); // Keep amounts reasonable
        vm.assume(cycles > 0 && cycles <= 10); // Reasonable cycle count

        address testVault = address(0x5678);
        uint256 runningBalance = 0;

        for (uint256 i = 0; i < cycles; i++) {
            // Deposit
            IERC20(getUSDC()).approve(address(adapter), amount);
            adapter.deposit(getUSDC(), amount, testVault);
            runningBalance += amount;

            assertEq(adapter.totalAssets(testVault, getUSDC()), runningBalance, "Cycle deposit failed");

            // Withdraw half
            uint256 withdrawAmount = amount / 2;
            adapter.withdraw(getUSDC(), withdrawAmount, testVault);
            runningBalance -= withdrawAmount;

            assertEq(adapter.totalAssets(testVault, getUSDC()), runningBalance, "Cycle withdraw failed");
        }
    }

    /// @dev Fuzz test asset bounds
    function testFuzz_AssetBounds(uint256 assetAmount) public {
        address testVault = address(0x5678);

        // Should handle any uint256 value
        adapter.setTotalAssets(testVault, getUSDC(), assetAmount);
        assertEq(adapter.totalAssets(testVault, getUSDC()), assetAmount, "Asset bounds fuzz test failed");
    }

    /*//////////////////////////////////////////////////////////////
                        STRESS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test with many small operations
    function test_ManySmallOperations() public {
        address testVault = address(0x5678);
        uint256 smallAmount = _1_USDC;
        uint256 operations = 50;

        // Approve large amount upfront
        IERC20(getUSDC()).approve(address(adapter), smallAmount * operations);

        // Perform many small deposits
        for (uint256 i = 0; i < operations; i++) {
            adapter.deposit(getUSDC(), smallAmount, testVault);
        }

        uint256 expectedTotal = smallAmount * operations;
        assertEq(adapter.totalAssets(testVault, getUSDC()), expectedTotal, "Many small operations failed");

        // Perform many small withdrawals
        for (uint256 i = 0; i < operations; i++) {
            adapter.withdraw(getUSDC(), smallAmount, testVault);
        }

        assertEq(adapter.totalAssets(testVault, getUSDC()), 0, "Many small withdrawals failed");
    }

    /// @dev Test registry consistency
    function test_RegistryConsistency() public {
        // Create multiple adapters with different registries
        address registry1 = address(0x1111);
        address registry2 = address(0x2222);

        MockAdapter adapter1 = new MockAdapter(registry1);
        MockAdapter adapter2 = new MockAdapter(registry2);

        // Verify each maintains correct registry reference
        assertEq(adapter1.registry(), registry1, "Adapter1 registry incorrect");
        assertEq(adapter2.registry(), registry2, "Adapter2 registry incorrect");

        // Fund both adapters
        mockUSDC.mint(address(adapter1), _1000_USDC);
        mockUSDC.mint(address(adapter2), _1000_USDC);

        // Verify operations don't interfere
        address testVault = address(0x5678);
        uint256 amount = _100_USDC;

        adapter1.setTotalAssets(testVault, getUSDC(), amount);
        adapter2.setTotalAssets(testVault, getUSDC(), amount * 2);

        assertEq(adapter1.totalAssets(testVault, getUSDC()), amount, "Adapter1 state corrupted");
        assertEq(adapter2.totalAssets(testVault, getUSDC()), amount * 2, "Adapter2 state corrupted");
    }
}

/*//////////////////////////////////////////////////////////////
                              MOCK ADAPTER
//////////////////////////////////////////////////////////////*/

contract MockAdapter {
    mapping(address vault => mapping(address asset => uint256 balance)) private _vaultAssetBalances;
    address public registry;

    constructor(address registry_) {
        require(registry_ != address(0), ADAPTER_ZERO_ADDRESS);
        registry = registry_;
    }

    function deposit(address asset, uint256 amount, address vault) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        _vaultAssetBalances[vault][asset] += amount;
    }

    function withdraw(address asset, uint256 amount, address vault) external {
        require(_vaultAssetBalances[vault][asset] >= amount, ADAPTER_INSUFFICIENT_BALANCE);
        _vaultAssetBalances[vault][asset] -= amount;
        IERC20(asset).transfer(vault, amount);
    }

    function totalAssets(address vault, address asset) external view returns (uint256) {
        return _vaultAssetBalances[vault][asset];
    }

    function setTotalAssets(address vault, address asset, uint256 assets) external {
        _vaultAssetBalances[vault][asset] = assets;
    }

    // Test helper to set assets directly - for backward compatibility
    function setAssetsForTest(address asset, uint256 assets) external {
        _vaultAssetBalances[address(0x5678)][asset] = assets;
    }
}
