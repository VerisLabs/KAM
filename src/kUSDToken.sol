// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { BurnMintERC677 } from "chainlink/contracts/src/v0.8/shared/token/ERC677/BurnMintERC677.sol";

/**
 * @title kUSD
 * @notice Implementation of the kUSD token contract extending BurnMintERC677
 * @dev This contract extends Chainlink's BurnMintERC677 for CCT compatibility
 */
contract kUSD is BurnMintERC677 {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the contract is paused
    error Paused();
    /// @notice Thrown when the caller is not the owner or the CCIP admin
    error NotOwnerOrCCIPAdmin();
    /// @notice Thrown when the address is the zero address
    error ZeroAddressNotAllowed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Whether the contract is paused
    bool public paused;

    /// @notice The CCIP admin address
    address public ccipAdmin;

    /// @notice Minimum amount for transactions
    uint256 public minAmount = 1e18; // 1 Ether

    /// @notice Maximum amount for transactions
    uint256 public maxAmount = 1_000e18; // 1K Ether

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CCIPAdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event IsPaused(address account);
    event IsNotPaused(address account);
    event LimitsUpdated(uint256 minAmount, uint256 maxAmount);
    event MaxSlippageUpdated(uint256 maxSlippage);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwnerOrCCIPAdmin() {
        if (msg.sender != owner() || msg.sender != ccipAdmin) revert NotOwnerOrCCIPAdmin();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 maxSupply_,
        uint256 preMint,
        address minter
    )
        BurnMintERC677(name_, symbol_, decimals_, maxSupply_)
    {
        ccipAdmin = msg.sender;

        // Pre-mint initial supply if requested
        if (preMint > 0) {
            _mint(minter, preMint);
        }

        // Grant minting and burning roles to minter
        grantMintRole(minter);
        grantBurnRole(minter);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the CCIP admin address
     * @return The current CCIP admin address
     */
    function getCCIPAdmin() external view returns (address) {
        return ccipAdmin;
    }

    /**
     * @notice Transfer CCIP admin role to new address
     * @param newAdmin Address of new admin
     */
    function transferCCIPAdmin(address newAdmin) external onlyOwner {
        if(newAdmin == address(0)) revert ZeroAddressNotAllowed();
        address oldAdmin = ccipAdmin;
        ccipAdmin = newAdmin;
        emit CCIPAdminTransferred(oldAdmin, newAdmin);
    }

    /**
     * @notice Pause the contract
     */
    function pause() external onlyOwner {
        paused = true;
        emit IsPaused(msg.sender);
    }

    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyOwner {
        paused = false;
        emit IsNotPaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL OVERRIDES
    //////////////////////////////////////////////////////////////*/

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        if (paused) revert Paused();
        super._beforeTokenTransfer(from, to, amount);
    }
}