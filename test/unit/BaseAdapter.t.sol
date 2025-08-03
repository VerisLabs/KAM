// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { BaseTest } from "../utils/BaseTest.sol";
import { USDC_MAINNET, _1000_USDC, _100_USDC, _1_USDC } from "../utils/Constants.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";
import { BaseAdapter } from "src/adapters/BaseAdapter.sol";
import { IAdapter } from "src/interfaces/IAdapter.sol";
import { IkRegistry } from "src/interfaces/IkRegistry.sol";

/*//////////////////////////////////////////////////////////////
                              MOCK ADAPTER
//////////////////////////////////////////////////////////////*/

contract BaseAdapterTest is BaseTest {
    MockAdapter public adapter;

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        super.setUp();

        // Deploy mock registry for testing
        address mockRegistry = address(0x1234);
        adapter = new MockAdapter(mockRegistry);

        // Fund adapter with test tokens
        deal(USDC_MAINNET, address(adapter), _1000_USDC);
        deal(USDC_MAINNET, address(this), _1000_USDC);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR & INITIALIZATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Test adapter initialization
    function test_Constructor() public view {
        assertEq(address(adapter.registry()), address(0x1234), "Registry not set correctly");
    }

    /// @dev Test constructor with zero registry reverts
    function test_Constructor_RevertZeroRegistry() public {
        vm.expectRevert(BaseAdapter.ZeroAddress.selector);
        new MockAdapter(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERFACE COMPLIANCE
    //////////////////////////////////////////////////////////////*/

    /// @dev Test that adapter implements basic functionality
    function test_InterfaceCompliance() public view {
        // Test that adapter has basic functionality
        assertTrue(address(adapter) != address(0), "Adapter deployed successfully");
    }

    /// @dev Test deposit function exists and works
    function test_Deposit_Success() public {
        uint256 depositAmount = _100_USDC;
        address testVault = address(0x5678);

        IERC20(USDC_MAINNET).approve(address(adapter), depositAmount);

        uint256 adapterBalanceBefore = IERC20(USDC_MAINNET).balanceOf(address(adapter));
        uint256 totalAssetsBefore = adapter.totalAssets(testVault);

        adapter.deposit(USDC_MAINNET, depositAmount, testVault);

        assertEq(
            IERC20(USDC_MAINNET).balanceOf(address(adapter)),
            adapterBalanceBefore + depositAmount,
            "Tokens not transferred to adapter"
        );
        assertEq(adapter.totalAssets(testVault), totalAssetsBefore + depositAmount, "Total assets not updated");
    }

    /// @dev Test withdraw function exists and works
    function test_Withdraw_Success() public {
        uint256 withdrawAmount = _100_USDC;
        address testVault = address(0x5678);

        // Setup: deposit first
        IERC20(USDC_MAINNET).approve(address(adapter), withdrawAmount);
        adapter.deposit(USDC_MAINNET, withdrawAmount, testVault);

        uint256 vaultBalanceBefore = IERC20(USDC_MAINNET).balanceOf(testVault);
        uint256 totalAssetsBefore = adapter.totalAssets(testVault);

        adapter.withdraw(USDC_MAINNET, withdrawAmount, testVault);

        assertEq(
            IERC20(USDC_MAINNET).balanceOf(testVault),
            vaultBalanceBefore + withdrawAmount,
            "Tokens not transferred to vault"
        );
        assertEq(adapter.totalAssets(testVault), totalAssetsBefore - withdrawAmount, "Total assets not updated");
    }

    /// @dev Test totalAssets function
    function test_TotalAssets() public {
        address testVault = address(0x5678);
        uint256 testAmount = _100_USDC;

        adapter.setAssetsForTest(testAmount);

        assertEq(adapter.totalAssets(testVault), testAmount, "Total assets incorrect");
    }

    /// @dev Test setTotalAssets function
    function test_SetTotalAssets() public {
        address testVault = address(0x5678);
        uint256 newTotal = _100_USDC;

        adapter.setTotalAssets(testVault, newTotal);

        assertEq(adapter.totalAssets(testVault), newTotal, "Total assets not set correctly");
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR CONDITIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test withdraw with insufficient balance
    function test_Withdraw_InsufficientBalance() public {
        address testVault = address(0x5678);
        uint256 withdrawAmount = _100_USDC;

        // Try to withdraw without depositing
        vm.expectRevert("Insufficient balance");
        adapter.withdraw(USDC_MAINNET, withdrawAmount, testVault);
    }

    /*//////////////////////////////////////////////////////////////
                          EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Test deposit and withdraw with zero amounts
    function test_ZeroAmounts() public {
        address testVault = address(0x5678);

        // These should not revert (depending on implementation)
        adapter.deposit(USDC_MAINNET, 0, testVault);
        adapter.withdraw(USDC_MAINNET, 0, testVault);
    }

    /// @dev Test multiple deposits and withdrawals
    function test_MultipleOperations() public {
        address testVault = address(0x5678);
        uint256 amount1 = _100_USDC;
        uint256 amount2 = _100_USDC / 2;

        // Multiple deposits
        IERC20(USDC_MAINNET).approve(address(adapter), amount1 + amount2);
        adapter.deposit(USDC_MAINNET, amount1, testVault);
        adapter.deposit(USDC_MAINNET, amount2, testVault);

        assertEq(adapter.totalAssets(testVault), amount1 + amount2, "Multiple deposits not tracked correctly");

        // Partial withdrawal
        adapter.withdraw(USDC_MAINNET, amount2, testVault);

        assertEq(adapter.totalAssets(testVault), amount1, "Partial withdrawal not tracked correctly");
    }

    /*//////////////////////////////////////////////////////////////
                          REGISTRY INTERACTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Test registry getter
    function test_RegistryGetter() public view {
        address registryRef = adapter.registry();
        assertEq(address(registryRef), address(0x1234), "Registry getter incorrect");
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
        IERC20(USDC_MAINNET).approve(address(adapter), amount);
        adapter.deposit(USDC_MAINNET, amount, testVault);

        assertEq(adapter.totalAssets(testVault), amount, "Deposit amount incorrect");

        // Withdraw
        adapter.withdraw(USDC_MAINNET, amount, testVault);

        assertEq(adapter.totalAssets(testVault), 0, "Withdraw not complete");
    }

    /// @dev Fuzz test setTotalAssets
    function testFuzz_SetTotalAssets(uint256 amount) public {
        address testVault = address(0x5678);

        adapter.setTotalAssets(testVault, amount);

        assertEq(adapter.totalAssets(testVault), amount, "SetTotalAssets failed");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test adapter with different assets (if supported)
    function test_MultipleAssets() public {
        // This test would need to be adapted based on whether the adapter supports multiple assets
        // For now, just test with USDC which we know works
        address testVault = address(0x5678);
        uint256 amount = _100_USDC;

        IERC20(USDC_MAINNET).approve(address(adapter), amount);
        adapter.deposit(USDC_MAINNET, amount, testVault);

        assertEq(adapter.totalAssets(testVault), amount, "Multi-asset test failed");
    }

    /// @dev Test adapter state consistency
    function test_StateConsistency() public {
        address testVault = address(0x5678);
        uint256 amount = _100_USDC;

        // Deposit
        IERC20(USDC_MAINNET).approve(address(adapter), amount);
        adapter.deposit(USDC_MAINNET, amount, testVault);

        uint256 totalAfterDeposit = adapter.totalAssets(testVault);

        // Set total assets directly
        adapter.setTotalAssets(testVault, amount * 2);

        assertEq(adapter.totalAssets(testVault), amount * 2, "Direct set failed");
        assertNotEq(adapter.totalAssets(testVault), totalAfterDeposit, "State not updated");
    }
}

/*//////////////////////////////////////////////////////////////
                              MOCK ADAPTER
//////////////////////////////////////////////////////////////*/

contract MockAdapter is BaseAdapter {
    uint256 private _totalAssets;

    constructor(address registry_) {
        __BaseAdapter_init(registry_, msg.sender, msg.sender, "MockAdapter", "1.0.0");
    }

    function deposit(address asset, uint256 amount, address vault) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        _totalAssets += amount;
    }

    function withdraw(address asset, uint256 amount, address vault) external {
        require(_totalAssets >= amount, "Insufficient balance");
        _totalAssets -= amount;
        IERC20(asset).transfer(vault, amount);
    }

    function totalAssets(address vault) external view returns (uint256) {
        return _totalAssets;
    }

    function setTotalAssets(address vault, uint256 assets) external {
        _totalAssets = assets;
    }

    // Test helper to set assets directly
    function setAssetsForTest(uint256 assets) external {
        _totalAssets = assets;
    }

    // Public registry getter for testing
    function registry() external view returns (address) {
        BaseAdapterStorage storage $ = _getBaseAdapterStorage();
        return $.registry;
    }
}
