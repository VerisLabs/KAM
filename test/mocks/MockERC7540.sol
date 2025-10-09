// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC7540 } from "kam/src/interfaces/IERC7540.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title MockERC7540
/// @notice Mock implementation of ERC7540 vault for testing
contract MockERC7540 is IERC7540, ERC20 {
    using SafeTransferLib for address;

    address private immutable _asset;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    mapping(address => uint256) private _pendingDepositRequests;
    mapping(address => uint256) private _pendingRedeemRequests;
    mapping(address => uint256) private _claimableDepositRequests;
    mapping(address => uint256) private _claimableRedeemRequests;
    mapping(address => mapping(address => bool)) private _operators;
    uint256 private _requestCounter;

    constructor(address asset_, string memory name_, string memory symbol_, uint8 decimals_) {
        _asset = asset_;
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view override(ERC20, IERC7540) returns (string memory) {
        return _name;
    }

    function symbol() public view override(ERC20, IERC7540) returns (string memory) {
        return _symbol;
    }

    function decimals() public view override(ERC20, IERC7540) returns (uint8) {
        return _decimals;
    }

    function balanceOf(address owner) public view override(ERC20, IERC7540) returns (uint256) {
        return super.balanceOf(owner);
    }

    function approve(address spender, uint256 amount) public override(ERC20, IERC7540) returns (bool) {
        return super.approve(spender, amount);
    }

    function allowance(address owner, address spender) public view override(ERC20, IERC7540) returns (uint256) {
        return super.allowance(owner, spender);
    }

    function transferFrom(
        address owner,
        address spender,
        uint256 amount
    )
        public
        override(ERC20, IERC7540)
        returns (bool)
    {
        return super.transferFrom(owner, spender, amount);
    }

    function transfer(address to, uint256 amount) public override(ERC20, IERC7540) returns (bool) {
        return super.transfer(to, amount);
    }

    function totalSupply() public view override(ERC20, IERC7540) returns (uint256) {
        return super.totalSupply();
    }

    function asset() external view override returns (address) {
        return _asset;
    }

    function totalAssets() external view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToAssets(uint256 shares) external pure override returns (uint256) {
        return shares; // 1:1 for simplicity in mock
    }

    function convertToShares(uint256 assets) external pure override returns (uint256) {
        return assets; // 1:1 for simplicity in mock
    }

    function setOperator(address operator, bool approved) external override {
        _operators[msg.sender][operator] = approved;
    }

    function isOperator(address controller, address operator) external view override returns (bool) {
        return _operators[controller][operator];
    }

    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    )
        external
        override
        returns (uint256 requestId)
    {
        require(owner == msg.sender || _operators[owner][msg.sender], "Not authorized");

        // Transfer assets from owner to vault
        _asset.safeTransferFrom(owner, address(this), assets);

        _pendingDepositRequests[controller] += assets;
        _claimableDepositRequests[controller] += assets; // Auto-approve in mock

        requestId = ++_requestCounter;
    }

    function deposit(uint256 assets, address to) external override returns (uint256 shares) {
        return _deposit(assets, to, msg.sender);
    }

    function deposit(uint256 assets, address to, address controller) external override returns (uint256 shares) {
        return _deposit(assets, to, controller);
    }

    function _deposit(uint256 assets, address to, address controller) internal returns (uint256 shares) {
        require(_claimableDepositRequests[controller] >= assets, "Insufficient claimable deposit");

        _claimableDepositRequests[controller] -= assets;
        _pendingDepositRequests[controller] -= assets;

        shares = assets; // 1:1 conversion
        _mint(to, shares);
    }

    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    )
        external
        override
        returns (uint256 requestId)
    {
        require(owner == msg.sender || _operators[owner][msg.sender], "Not authorized");
        require(balanceOf(owner) >= shares, "Insufficient balance");

        // Transfer shares from owner to vault (burn them)
        _burn(owner, shares);

        _pendingRedeemRequests[controller] += shares;
        _claimableRedeemRequests[controller] += shares; // Auto-approve in mock

        requestId = ++_requestCounter;
    }

    function redeem(uint256 shares, address receiver, address controller) external override returns (uint256 assets) {
        require(_claimableRedeemRequests[controller] >= shares, "Insufficient claimable redeem");

        _claimableRedeemRequests[controller] -= shares;
        _pendingRedeemRequests[controller] -= shares;

        assets = shares; // 1:1 conversion
        _asset.safeTransfer(receiver, assets);
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address controller
    )
        external
        override
        returns (uint256 shares)
    {
        shares = assets; // 1:1 conversion
        require(_claimableRedeemRequests[controller] >= shares, "Insufficient claimable redeem");

        _claimableRedeemRequests[controller] -= shares;
        _pendingRedeemRequests[controller] -= shares;

        _asset.safeTransfer(receiver, assets);
    }

    function pendingRedeemRequest(address controller) external view override returns (uint256) {
        return _pendingRedeemRequests[controller];
    }

    function claimableRedeemRequest(address controller) external view override returns (uint256) {
        return _claimableRedeemRequests[controller];
    }

    function pendingProcessedShares(address) external pure override returns (uint256) {
        return 0; // Not used in mock
    }

    function pendingDepositRequest(address controller) external view override returns (uint256) {
        return _pendingDepositRequests[controller];
    }

    function claimableDepositRequest(address controller) external view override returns (uint256) {
        return _claimableDepositRequests[controller];
    }

    function lastRedeem(address) external pure override returns (uint256) {
        return 0; // Not used in mock
    }

    function lastDeposit(address) external pure returns (uint256) {
        return 0; // Not used in mock
    }
}
