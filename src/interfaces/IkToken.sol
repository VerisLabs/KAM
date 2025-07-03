// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IkToken {
    /*//////////////////////////////////////////////////////////////
                            CORE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isPaused() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setPaused(bool _isPaused) external;

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function grantAdminRole(address admin) external;
    function revokeAdminRole(address admin) external;
    function grantEmergencyRole(address emergency) external;
    function revokeEmergencyRole(address emergency) external;
    function grantMinterRole(address minter) external;
    function revokeMinterRole(address minter) external;

    /*//////////////////////////////////////////////////////////////
                        CONTRACT INFO
    //////////////////////////////////////////////////////////////*/

    function contractName() external pure returns (string memory);
    function contractVersion() external pure returns (string memory);
}
