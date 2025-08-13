// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { ERC4626 } from "solady/tokens/ERC4626.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @title ERC7540 Request Type
/// @notice Represents a request in the ERC7540 standard
/// @dev This type is a simple wrapper around a uint256 value
type ERC7540_Request is uint256;

/// @title ERC7540 Filled Request Structure
/// @notice Holds information about a filled request
/// @dev This struct is used to store the assets and shares of a filled ERC7540 request
struct ERC7540_FilledRequest {
    uint256 assets; // The number of assets involved in the request
    uint256 shares; // The number of shares associated with the request
}

/// @title ERC7540 Library
/// @notice Library for handling ERC7540 requests and conversions
/// @dev This library provides utility functions for converting between assets and shares in ERC7540 requests
library ERC7540Lib {
    /// @notice Converts a given amount of assets to shares, rounding up
    /// @dev Uses full multiplication and division with rounding up
    /// @param self The filled request (ERC7540_FilledRequest) to operate on
    /// @param assets The amount of assets to convert to shares
    /// @return The equivalent amount of shares, rounded up
    function convertToSharesUp(ERC7540_FilledRequest memory self, uint256 assets) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDivUp(self.shares, assets, self.assets);
    }

    /// @notice Converts a given amount of assets to shares
    /// @dev Uses full multiplication and division without rounding
    /// @param self The filled request (ERC7540_FilledRequest) to operate on
    /// @param assets The amount of assets to convert to shares
    /// @return The equivalent amount of shares
    function convertToShares(ERC7540_FilledRequest memory self, uint256 assets) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDiv(self.shares, assets, self.assets);
    }

    /// @notice Converts a given amount of shares to assets
    /// @dev Uses full multiplication and division with rounding up
    /// @param self The filled request (ERC7540_FilledRequest) to operate on
    /// @param shares The amount of shares to convert to assets
    /// @return The equivalent amount of assets, rounded up
    function convertToAssets(ERC7540_FilledRequest memory self, uint256 shares) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDiv(self.assets, shares, self.shares);
    }

    /// @notice Converts a given amount of shares to assets, rounding up
    /// @dev Uses full multiplication and division with rounding up
    /// @param self The filled request (ERC7540_FilledRequest) to operate on
    /// @param shares The amount of shares to convert to assets
    /// @return The equivalent amount of assets, rounded up
    function convertToAssetsUp(ERC7540_FilledRequest memory self, uint256 shares) internal pure returns (uint256) {
        return FixedPointMathLib.fullMulDivUp(self.assets, shares, self.shares);
    }

    /// @notice Adds a value to an ERC7540_Request
    /// @dev Adds a uint256 value to the underlying uint256 of the ERC7540_Request
    /// @param self The ERC7540_Request to operate on
    /// @param x The value to add
    /// @return A new ERC7540_Request with the added value
    function add(ERC7540_Request self, uint256 x) internal pure returns (ERC7540_Request) {
        return ERC7540_Request.wrap(ERC7540_Request.unwrap(self) + x);
    }

    /// @notice Subtracts a value from an ERC7540_Request
    /// @dev Subtracts a uint256 value from the underlying uint256 of the ERC7540_Request
    /// @param self The ERC7540_Request to operate on
    /// @param x The value to subtract
    /// @return A new ERC7540_Request with the subtracted value
    function sub(ERC7540_Request self, uint256 x) internal pure returns (ERC7540_Request) {
        return ERC7540_Request.wrap(ERC7540_Request.unwrap(self) - x);
    }

    function sub0(ERC7540_Request self, uint256 x) internal pure returns (ERC7540_Request) {
        return ERC7540_Request.wrap(x > ERC7540_Request.unwrap(self) ? 0 : ERC7540_Request.unwrap(self) - x);
    }

    /// @notice Unwraps an ERC7540_Request to retrieve the underlying uint256 value
    /// @dev Retrieves the raw uint256 value wrapped by the ERC7540_Request
    /// @param self The ERC7540_Request to unwrap
    /// @return The raw uint256 value of the request
    function unwrap(ERC7540_Request self) internal pure returns (uint256) {
        return ERC7540_Request.unwrap(self);
    }
}

/// @notice Simple ERC7540 async Tokenized Vault implementation
/// @author Solthodox (https://github.com/Solthodox)
abstract contract ERC7540 is ERC4626 {
    using SafeTransferLib for address;
    using ERC7540Lib for ERC7540_Request;
    using ERC7540Lib for ERC7540_FilledRequest;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when `assets` tokens are deposited into the vault
    event DepositRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address source, uint256 assets
    );
    /// @dev Emitted when `shares` vault shares are redeemed
    event RedeemRequest(
        address indexed controller, address indexed owner, uint256 indexed requestId, address source, uint256 shares
    );

    /// @dev Emitted when a deposit request is fulfilled after being processed
    event FulfillDepositRequest(address indexed controller, uint256 assets, uint256 shares);

    /// @dev Emitted when a redeem request is fulfilled after being processed
    event FulfillRedeemRequest(address indexed controller, uint256 shares, uint256 assets);

    /// @dev Emitted when `controller` gives allowance to `operator`
    event OperatorSet(address indexed controller, address indexed operator, bool approved);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Thrown when an unauthorized address attempts to act as a controller
    error InvalidController();

    /// @notice Thrown when trying to deposit or interact with zero assets
    error InvalidZeroAssets();

    /// @notice Thrown when trying to redeem or interact with zero shares
    error InvalidZeroShares();

    /// @notice Thrown when trying to set an invalid operator, such as setting oneself as an operator
    error InvalidOperator();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Saves the ERC7540 deposit requests when calling `requestDeposit`
    mapping(address => ERC7540_Request) internal _pendingDepositRequest;

    /// @notice Saves the ERC7540 redeem requests when calling `requestRedeem`
    mapping(address => ERC7540_Request) internal _pendingRedeemRequest;

    /// @notice Saves the result of the deposit after the request has been processed
    mapping(address => ERC7540_FilledRequest) internal _claimableDepositRequest;

    /// @notice Saves the result of the redeem after the request has been processed
    mapping(address => ERC7540_FilledRequest) internal _claimableRedeemRequest;

    /// @notice ERC7540 operator approvals
    mapping(address controller => mapping(address operator => bool)) public isOperator;

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewDeposit(uint256 assets) public pure override returns (uint256 shares) {
        assets; // silence compiler warnings
        shares; // silence compiler warnings
        revert();
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewMint(uint256 shares) public pure override returns (uint256 assets) {
        shares; // silence compiler warnings
        assets; // silence compiler warnings
        revert();
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewWithdraw(uint256 assets) public pure override returns (uint256 shares) {
        assets; // silence compiler warnings
        shares; // silence compiler warnings
        revert();
    }

    /// @dev Preview functions for ERC-7540 vaults revert
    function previewRedeem(uint256 shares) public pure override returns (uint256 assets) {
        shares; // silence compiler warnings
        assets; // silence compiler warnings
        revert();
    }

    /// @dev The deposit amount is limited by the claimable deposit requests of the user
    function maxDeposit(address to) public view virtual override returns (uint256 assets) {
        return _claimableDepositRequest[to].assets;
    }

    /// @dev The mint amount is limited by the claimable deposit requests of the user
    function maxMint(address to) public view virtual override returns (uint256 shares) {
        return convertToShares(maxDeposit(to));
    }

    /// @dev The withdraw amount is limited by the claimable redeem requests of the user
    function maxWithdraw(address owner) public view virtual override returns (uint256 assets) {
        return convertToAssets(maxRedeem(owner));
    }

    /// @dev The redeem amount is limited by the claimable redeem requests of the user
    function maxRedeem(address owner) public view virtual override returns (uint256 shares) {
        return _claimableRedeemRequest[owner].shares;
    }

    /// @dev Transfers assets from sender into the Vault and submits a Request for asynchronous deposit.
    ///
    /// - MUST support ERC-20 approve / transferFrom on asset as a deposit Request flow.
    /// - MUST revert if all of assets cannot be requested for deposit.
    /// - owner MUST be msg.sender unless some unspecified explicit approval is given by the caller,
    ///    approval of ERC-20 tokens from owner to sender is NOT enough.
    ///
    /// @param assets the amount of deposit assets to transfer from owner
    /// @param controller the controller of the request who will be able to operate the request
    /// @param owner the source of the deposit assets
    ///
    /// NOTE: most implementations will require pre-approval of the Vault with the Vault's underlying asset token.
    function requestDeposit(
        uint256 assets,
        address controller,
        address owner
    )
        public
        virtual
        returns (uint256 requestId)
    {
        if (assets == 0) revert InvalidZeroAssets();
        requestId = _requestDeposit(assets, controller, owner, msg.sender);
    }

    /// @dev Assumes control of shares from sender into the Vault and submits a Request for asynchronous redeem.
    ///
    /// - MUST support a redeem Request flow where the control of shares is taken from sender directly
    ///   where msg.sender has ERC-20 approval over the shares of owner.
    /// - MUST revert if all of shares cannot be requested for redeem.
    ///
    /// @param shares the amount of shares to be redeemed to transfer from owner
    /// @param controller the controller of the request who will be able to operate the request
    /// @param owner the source of the shares to be redeemed
    ///
    /// NOTE: most implementations will require pre-approval of the Vault with the Vault's share token.
    function requestRedeem(
        uint256 shares,
        address controller,
        address owner
    )
        public
        virtual
        returns (uint256 requestId)
    {
        if (shares == 0) revert InvalidZeroShares();
        // If msg.sender is operator of owner, the transfer is executed as if
        // the sender is the owner, to bypass the allowance check
        address sender = isOperator[owner][msg.sender] ? owner : msg.sender;
        return _requestRedeem(shares, controller, sender, msg.sender);
    }

    /// @dev Mints shares Vault shares to receiver by claiming the Request of the controller.
    ///
    /// - MUST emit the Deposit event.
    /// - controller MUST equal msg.sender unless the controller has approved the msg.sender as an operator.
    function deposit(uint256 assets, address receiver) public virtual override returns (uint256 shares) {
        return deposit(assets, receiver, msg.sender);
    }

    /// @dev Mints shares Vault shares to receiver by claiming the Request of the controller.
    ///
    /// - MUST emit the Deposit event.
    /// - controller MUST equal msg.sender unless the controller has approved the msg.sender as an operator.
    function deposit(uint256 assets, address receiver, address controller) public virtual returns (uint256 shares) {
        _validateController(controller);
        if (assets > maxDeposit(controller)) revert DepositMoreThanMax();
        ERC7540_FilledRequest memory claimable = _claimableDepositRequest[controller];
        shares = claimable.convertToSharesUp(assets);
        (shares,) = _deposit(assets, shares, receiver, controller);
    }

    /// @dev Mints exactly shares Vault shares to receiver by claiming the Request of the controller.
    ///
    /// - MUST emit the Deposit event.
    /// - controller MUST equal msg.sender unless the controller has approved the msg.sender as an operator.
    function mint(uint256 shares, address receiver) public virtual override returns (uint256 assets) {
        return mint(shares, receiver, msg.sender);
    }

    /// @dev Mints exactly shares Vault shares to receiver by claiming the Request of the controller.
    ///
    /// - MUST emit the Deposit event.
    /// - controller MUST equal msg.sender unless the controller has approved the msg.sender as an operator.
    function mint(uint256 shares, address receiver, address controller) public virtual returns (uint256 assets) {
        _validateController(controller);
        if (shares > maxMint(controller)) revert MintMoreThanMax();
        ERC7540_FilledRequest memory claimable = _claimableDepositRequest[controller];
        assets = claimable.convertToAssetsUp(shares);
        (, assets) = _deposit(assets, shares, receiver, controller);
    }

    /// @notice Claims processed redemption request
    /// @dev Can only be called by controller or approved operator
    /// @param shares Amount of shares to redeem
    /// @param to Address to receive the assets
    /// @param controller Controller of the redemption request
    /// @return assets Amount of assets returned
    function redeem(uint256 shares, address to, address controller) public virtual override returns (uint256 assets) {
        if (shares > maxRedeem(controller)) revert RedeemMoreThanMax();
        _validateController(controller);
        ERC7540_FilledRequest memory claimable = _claimableRedeemRequest[controller];
        assets = claimable.convertToAssets(shares);
        (assets,) = _withdraw(assets, shares, to, controller);
    }

    /// @notice Claims processed redemption request for exact assets
    /// @dev Can only be called by controller or approved operator
    /// @param assets Exact amount of assets to withdraw
    /// @param to Address to receive the assets
    /// @param controller Controller of the redemption request
    /// @return shares Amount of shares burned
    function withdraw(
        uint256 assets,
        address to,
        address controller
    )
        public
        virtual
        override
        returns (uint256 shares)
    {
        if (assets > maxWithdraw(controller)) revert WithdrawMoreThanMax();
        _validateController(controller);
        ERC7540_FilledRequest memory claimable = _claimableRedeemRequest[controller];
        shares = claimable.convertToSharesUp(assets);
        (, shares) = _withdraw(assets, shares, to, controller);
    }

    /// @notice Returns the pending redemption request amount for a controller
    /// @param controller Address to check pending redemption for
    /// @return Amount of shares pending redemption
    function pendingRedeemRequest(address controller) public view virtual returns (uint256) {
        return _pendingRedeemRequest[controller].unwrap();
    }

    /// @notice Returns the pending deposit request amount for a controller
    /// @param controller Address to check pending deposit for
    /// @return Amount of assets pending deposit
    function pendingDepositRequest(address controller) public view virtual returns (uint256) {
        return _pendingDepositRequest[controller].unwrap();
    }

    /// @notice Returns the claimable deposit amount for a controller
    /// @param controller Address to check claimable deposit for
    /// @return Amount of assets available to claim
    function claimableDepositRequest(address controller) public view virtual returns (uint256) {
        return maxDeposit(controller);
    }

    /// @notice Returns the claimable redemption amount for a controller
    /// @param controller Address to check claimable redemption for
    /// @return Amount of shares available to claim
    function claimableRedeemRequest(address controller) public view virtual returns (uint256) {
        return maxRedeem(controller);
    }

    function _deposit(
        uint256 assets,
        uint256 shares,
        address receiver,
        address controller
    )
        internal
        virtual
        returns (uint256 sharesReturn, uint256 assetsReturn)
    {
        unchecked {
            _claimableDepositRequest[controller].assets -= assets;
            _claimableDepositRequest[controller].shares -= shares;
        }
        _mint(receiver, shares);
        /// @solidity memory-safe-assembly
        assembly {
            // Emit the {Deposit} event.
            mstore(0x00, assets)
            mstore(0x20, shares)
            let m := shr(96, not(0))
            log3(
                0x00,
                0x40,
                0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7,
                and(m, controller),
                and(m, receiver)
            )
        }
        return (shares, assets);
    }

    function _withdraw(
        uint256 assets,
        uint256 shares,
        address receiver,
        address controller
    )
        internal
        virtual
        returns (uint256 assetsReturn, uint256 sharesReturn)
    {
        unchecked {
            _claimableRedeemRequest[controller].assets -= assets;
            _claimableRedeemRequest[controller].shares -= shares;
        }
        asset().safeTransfer(receiver, assets);
        /// @solidity memory-safe-assembly
        assembly {
            // Emit the {Withdraw} event.
            mstore(0x00, assets)
            mstore(0x20, shares)
            let m := shr(96, not(0))
            log4(
                0x00,
                0x40,
                0xfbde797d201c681b91056529119e0b02407c7bb96a4a2c75c01fc9667232c8db,
                and(m, controller),
                and(m, receiver),
                and(m, controller)
            )
        }
        return (assets, shares);
    }

    function _requestDeposit(
        uint256 assets,
        address controller,
        address owner,
        address source
    )
        internal
        virtual
        returns (uint256 requestId)
    {
        source;
        asset().safeTransferFrom(source, address(this), assets);
        _pendingDepositRequest[controller] = _pendingDepositRequest[controller].add(assets);
        emit DepositRequest(controller, owner, requestId, source, assets);
        return 0;
    }

    function _requestRedeem(
        uint256 shares,
        address controller,
        address owner,
        address source
    )
        internal
        virtual
        returns (uint256 requestId)
    {
        source;
        _transfer(owner, address(this), shares);
        _pendingRedeemRequest[controller] = _pendingRedeemRequest[controller].add(shares);
        emit RedeemRequest(controller, owner, requestId, source, shares);
        return 0;
    }

    /// @dev Sets or removes an operator for the caller.
    ///
    /// @param operator The address of the operator.
    /// @param approved The approval status.
    /// @return success Whether the call was executed successfully or not
    function setOperator(address operator, bool approved) public returns (bool success) {
        if (msg.sender == operator) revert InvalidOperator();
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /// @dev Performs operator and controller permission checks
    function _validateController(address controller) private view {
        if (msg.sender != controller && !isOperator[controller][msg.sender]) revert InvalidController();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HOOKS TO OVERRIDE                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Hook that is called when processing a deposit request and make it claimable.
    function _fulfillDepositRequest(
        address controller,
        uint256 assetsFulfilled,
        uint256 sharesMinted
    )
        internal
        virtual
    {
        _pendingDepositRequest[controller] = _pendingDepositRequest[controller].sub(assetsFulfilled);
        _claimableDepositRequest[controller].assets += assetsFulfilled;
        _claimableDepositRequest[controller].shares += sharesMinted;
        emit FulfillDepositRequest(controller, assetsFulfilled, sharesMinted);
    }

    /// @dev Hook that is called when processing a redeem request and make it claimable.
    /// @dev It assumes user transferred its shares to the contract when requesting a redeem
    function _fulfillRedeemRequest(
        uint256 sharesFulfilled,
        uint256 assetsWithdrawn,
        address controller,
        bool strict
    )
        internal
        virtual
    {
        if (strict) {
            _pendingRedeemRequest[controller] = _pendingRedeemRequest[controller].sub(sharesFulfilled);
        } else {
            _pendingRedeemRequest[controller] = _pendingRedeemRequest[controller].sub0(sharesFulfilled);
        }
        _claimableRedeemRequest[controller].assets += assetsWithdrawn;
        _claimableRedeemRequest[controller].shares += sharesFulfilled;
        emit FulfillRedeemRequest(controller, sharesFulfilled, assetsWithdrawn);
    }
}