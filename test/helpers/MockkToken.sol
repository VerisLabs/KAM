// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ERC20 } from "solady/tokens/ERC20.sol";

/// @title MockkToken
/// @notice Mock kToken implementation for testing
contract MockkToken is ERC20, OwnableRoles {
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    bool private _isPaused;

    uint256 public constant MINTER_ROLE = _ROLE_2;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _initializeOwner(msg.sender);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external onlyRoles(MINTER_ROLE) {
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRoles(MINTER_ROLE) {
        _burn(from, amount);
        emit Burned(from, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyRoles(MINTER_ROLE) {
        uint256 allowed = allowance(from, msg.sender);
        if (allowed != type(uint256).max) {
            _approve(from, msg.sender, allowed - amount);
        }
        _burn(from, amount);
        emit Burned(from, amount);
    }

    function grantRole(uint256 role, address account) external onlyOwner {
        _grantRoles(account, role);
    }

    function revokeRole(uint256 role, address account) external onlyOwner {
        _removeRoles(account, role);
    }

    function isPaused() external view returns (bool) {
        return _isPaused;
    }

    function setPaused(bool paused) external onlyOwner {
        _isPaused = paused;
    }
}
