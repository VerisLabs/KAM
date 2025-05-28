// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableRoles} from "../lib/solady/src/auth/OwnableRoles.sol";
import {UUPSUpgradeable} from "../lib/solady/src/utils/UUPSUpgradeable.sol";
import {Initializable} from "../lib/solady/src/utils/Initializable.sol";
import {ReentrancyGuard} from "../lib/solady/src/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "../lib/solady/src/utils/SafeTransferLib.sol";
import {ECDSA} from "../lib/solady/src/utils/ECDSA.sol";
import {EIP712} from "../lib/solady/src/utils/EIP712.sol";
import {IkUSDToken} from "./Interfaces/IkUSDToken.sol";

/**
 * @title KAMManager
 * @notice Main protocol entry point for kUSD Protocol with EIP-712 signatures
 * @dev UUPS upgradeable, Solady-optimized, EIP-712 signature validation
 */
contract KAMManager is OwnableRoles, UUPSUpgradeable, Initializable, ReentrancyGuard, EIP712 {
    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/
    /// @notice Reporter role (position updates)
    uint256 public constant REPORTER_ROLE = _ROLE_0;
    /// @notice Emergency role (pause/withdraw)
    uint256 public constant EMERGENCY_ROLE = _ROLE_1;
    /// @notice Gatekeeper role (disable operations)
    uint256 public constant GATEKEEPER_ROLE = _ROLE_2;
    /// @notice Signer role (order validation)
    uint256 public constant SIGNER_ROLE = _ROLE_3;

    /*//////////////////////////////////////////////////////////////
                            EIP-712 CONSTANTS
    //////////////////////////////////////////////////////////////*/
    /// @notice EIP-712 domain name
    string private constant DOMAIN_NAME = "KAMManager";
    /// @notice EIP-712 domain version
    string private constant DOMAIN_VERSION = "1";
    
    /// @notice Order struct typehash
    bytes32 private constant ORDER_TYPEHASH = keccak256(
        "Order(address beneficiary,address asset,uint256 assetAmount,uint256 kusdAmount,uint256 price,uint256 nonce,uint256 expiry,uint256 mpcAmount,uint256 metaAmount)"
    );

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Order struct for EIP-712 signatures (backend-driven allocation, on-chain addresses)
    struct Order {
        address beneficiary;    // Who receives the tokens/assets
        address asset;         // Which asset (USDC, ETH, BTC, etc.)
        uint256 assetAmount;   // Total amount of asset
        uint256 kusdAmount;    // Amount of kUSD
        uint256 price;         // Price used for conversion (18 decimals)
        uint256 nonce;         // Prevent replay attacks
        uint256 expiry;        // Order expiration timestamp
        uint256 mpcAmount;     // Amount to send to MPC wallet
        uint256 metaAmount;    // Amount to send to MetaVault
    }

    /// @notice Asset configuration struct
    struct AssetConfig {
        uint256 maxPerBlock;
        uint256 instantLimit;
        bool supported;
        address mpcWallet;
        address metaVault;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Asset not supported
    error AssetNotSupported(address asset);
    /// @notice Invalid signature
    error InvalidSignature();
    /// @notice Order expired
    error OrderExpired(uint256 expiry, uint256 current);
    /// @notice Nonce already used
    error NonceAlreadyUsed(uint256 nonce);
    /// @notice Exceeds max limit
    error ExceedsMaxLimit(uint256 amount, uint256 limit);
    /// @notice Protocol is paused
    error ProtocolIsPaused();
    /// @notice Operations disabled
    error OperationsAreDisabled();
    /// @notice Invalid address
    error InvalidAddress();
    /// @notice Invalid percent configuration
    error InvalidPercentConfig();
    /// @notice Zero allocation error
    error ZeroAllocation();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event OrderExecuted(bytes32 indexed orderHash, address indexed beneficiary, address indexed asset, uint256 assetAmount, uint256 kusdAmount);
    event ProtocolPaused(address indexed by);
    event ProtocolUnpaused(address indexed by);
    event OperationsDisabled(address indexed by);
    event OperationsEnabled(address indexed by);
    event SupportedAssetAdded(address indexed asset, uint256 maxPerBlock, uint256 instantLimit);
    event AssetConfigUpdated(address indexed asset, uint256 maxPerBlock, uint256 instantLimit);
    event PositionsUpdated(address indexed asset, uint256 mpcBalance, uint256 metaBalance, uint256 yield);
    event YieldDistributed(address indexed asset, uint256 amount);
    event EmergencyWithdraw(address indexed asset, uint256 amount, address indexed to);
    event Initialized(address indexed initialOwner, address indexed _kusdToken, address indexed _kusdVault);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice Protocol pause state
    bool public paused;
    /// @notice Operations disabled state (by gatekeeper)
    bool public operationsDisabled;
    /// @notice kUSD token contract
    address public kusdToken;
    /// @notice kUSD vault contract
    address public kusdVault;

    /// @notice Mapping of supported assets to their configs
    mapping(address => AssetConfig) public assetConfigs;
    /// @notice User nonces for replay protection
    mapping(address => uint256) public nonces;
    /// @notice Used order hashes
    mapping(bytes32 => bool) public usedOrderHashes;
    /// @notice Array of supported assets
    address[] public supportedAssets;

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Reverts if protocol is paused
    modifier notPaused() {
        if (paused) revert ProtocolIsPaused();
        _;
    }

    /// @notice Reverts if operations are disabled
    modifier operationsEnabled() {
        if (operationsDisabled) revert OperationsAreDisabled();
        _;
    }

    /// @notice Validates order expiry
    modifier validateExpiry(uint256 expiry) {
        if (block.timestamp > expiry) revert OrderExpired(expiry, block.timestamp);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              INITIALIZER
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializer for upgradeable pattern
    function initialize(
        address initialOwner,
        address _kusdToken,
        address _kusdVault
    ) external initializer {
        _initializeOwner(initialOwner);
        if (_kusdToken == address(0) || _kusdVault == address(0)) revert InvalidAddress();
        kusdToken = _kusdToken;
        kusdVault = _kusdVault;
        paused = false;
        operationsDisabled = false;
        emit Initialized(initialOwner, _kusdToken, _kusdVault);
    }

    /*//////////////////////////////////////////////////////////////
                        EIP-712 IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the domain separator
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @notice Calculate order hash for EIP-712
    function getOrderHash(Order calldata order) public view returns (bytes32) {
        return _hashTypedData(keccak256(abi.encode(
            ORDER_TYPEHASH,
            order.beneficiary,
            order.asset,
            order.assetAmount,
            order.kusdAmount,
            order.price,
            order.nonce,
            order.expiry,
            order.mpcAmount,
            order.metaAmount
        )));
    }

    /// @notice Validate signature against order
    function _validateSignature(Order calldata order, bytes calldata signature) internal view {
        bytes32 orderHash = getOrderHash(order);
        address recovered = orderHash.recover(signature);
        if (!hasAnyRole(recovered, SIGNER_ROLE)) revert InvalidSignature();
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Mint kUSD with EIP-712 signed order (backend-driven allocation, on-chain addresses)
    function mintKUSD(Order calldata order, bytes calldata signature)
        external
        nonReentrant
        notPaused
        operationsEnabled
        validateExpiry(order.expiry)
    {
        AssetConfig storage config = assetConfigs[order.asset];
        
        if (!config.supported) revert AssetNotSupported(order.asset);
        if (order.assetAmount > config.instantLimit) revert ExceedsMaxLimit(order.assetAmount, config.instantLimit);
        if (order.mpcAmount + order.metaAmount != order.assetAmount) revert InvalidPercentConfig();
        if (order.mpcAmount == 0 && order.metaAmount == 0) revert ZeroAllocation();
        if (order.kusdAmount == 0) revert ZeroAllocation();

        _validateSignature(order, signature);
        bytes32 orderHash = getOrderHash(order);
        
        if (usedOrderHashes[orderHash]) revert NonceAlreadyUsed(order.nonce);
        usedOrderHashes[orderHash] = true;
        
        if (order.mpcAmount > 0) {
            SafeTransferLib.safeTransferFrom(order.asset, msg.sender, config.mpcWallet, order.mpcAmount);
        }
        if (order.metaAmount > 0) {
            SafeTransferLib.safeTransferFrom(order.asset, msg.sender, config.metaVault, order.metaAmount);
        }
        
        IkUSDToken(kusdToken).mint(order.beneficiary, order.kusdAmount);
        
        emit OrderExecuted(orderHash, order.beneficiary, order.asset, order.assetAmount, order.kusdAmount);
    }

    /// @notice Redeem kUSD with EIP-712 signed order
    /// @dev Only KAM backend can create valid signatures
    function redeemKUSD(Order calldata order, bytes calldata signature)
        external
        nonReentrant
        notPaused
        operationsEnabled
        validateExpiry(order.expiry)
    {
        // Validate asset support
        if (!assetConfigs[order.asset].supported) revert AssetNotSupported(order.asset);
        
        // Validate signature
        _validateSignature(order, signature);
        
        // Check order hash not used
        bytes32 orderHash = getOrderHash(order);
        if (usedOrderHashes[orderHash]) revert NonceAlreadyUsed(order.nonce);
        usedOrderHashes[orderHash] = true;
        
        // Burn kUSD from msg.sender (placeholder - will call kUSDToken.burn)
        IkUSDToken(kusdToken).burn(msg.sender, order.kusdAmount);
        
        // Transfer asset to beneficiary
        SafeTransferLib.safeTransfer(order.asset, order.beneficiary, order.assetAmount);
        
        emit OrderExecuted(orderHash, order.beneficiary, order.asset, order.assetAmount, order.kusdAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Add a new supported asset
    function addSupportedAsset(
        address asset,
        uint256 maxPerBlock,
        uint256 instantLimit,
        address mpcWallet,
        address metaVault
    ) external onlyOwner {
        if (asset == address(0)) revert AssetNotSupported(asset);
        if (assetConfigs[asset].supported) revert AssetNotSupported(asset);
        if (mpcWallet == address(0) || metaVault == address(0)) revert InvalidAddress();
        assetConfigs[asset] = AssetConfig({
            maxPerBlock: maxPerBlock,
            instantLimit: instantLimit,
            supported: true,
            mpcWallet: mpcWallet,
            metaVault: metaVault
        });
        supportedAssets.push(asset);
        emit SupportedAssetAdded(asset, maxPerBlock, instantLimit);
    }

    /// @notice Update asset configuration
    function updateAssetConfig(
        address asset,
        uint256 maxPerBlock,
        uint256 instantLimit,
        address mpcWallet,
        address metaVault
    ) external onlyOwner {
        if (!assetConfigs[asset].supported) revert AssetNotSupported(asset);
        if (mpcWallet == address(0) || metaVault == address(0)) revert InvalidAddress();
        AssetConfig storage config = assetConfigs[asset];
        config.maxPerBlock = maxPerBlock;
        config.instantLimit = instantLimit;
        config.mpcWallet = mpcWallet;
        config.metaVault = metaVault;
        emit AssetConfigUpdated(asset, maxPerBlock, instantLimit);
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY CONTROLS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emergency pause (EMERGENCY_ROLE)
    function emergencyPause() external onlyRoles(EMERGENCY_ROLE) {
        paused = true;
        emit ProtocolPaused(msg.sender);
    }

    /// @notice Emergency unpause (Owner only)
    function emergencyUnpause() external onlyOwner {
        paused = false;
        emit ProtocolUnpaused(msg.sender);
    }

    /// @notice Disable operations (GATEKEEPER_ROLE - like Ethena)
    function disableOperations() external onlyRoles(GATEKEEPER_ROLE) {
        operationsDisabled = true;
        emit OperationsDisabled(msg.sender);
    }

    /// @notice Enable operations (Owner only)
    function enableOperations() external onlyOwner {
        operationsDisabled = false;
        emit OperationsEnabled(msg.sender);
    }

    /// @notice Emergency withdraw assets
    function emergencyWithdraw(address asset, uint256 amount)
        external
        onlyRoles(EMERGENCY_ROLE)
    {
        SafeTransferLib.safeTransfer(asset, msg.sender, amount);
        emit EmergencyWithdraw(asset, amount, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get all supported assets
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        UUPS UPGRADE
    //////////////////////////////////////////////////////////////*/
    /// @notice UUPS upgrade authorization
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                        EIP-712 SETUP
    //////////////////////////////////////////////////////////////*/
    /// @notice Domain name for EIP-712
    function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
        return (DOMAIN_NAME, DOMAIN_VERSION);
    }
}