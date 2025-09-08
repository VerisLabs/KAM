// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

interface IkRegistry {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    enum VaultType {
        MINTER,
        DN,
        ALPHA,
        BETA,
        GAMMA,
        DELTA,
        EPSILON,
        ZETA,
        ETA,
        THETA,
        IOTA,
        KAPPA,
        LAMBDA,
        MU,
        NU,
        XI,
        OMICRON,
        PI,
        RHO,
        SIGMA,
        TAU,
        UPSILON,
        PHI,
        CHI,
        PSI,
        OMEGA,
        VAULT_27,
        VAULT_28,
        VAULT_29,
        VAULT_30,
        VAULT_31,
        VAULT_32,
        VAULT_33,
        VAULT_34,
        VAULT_35,
        VAULT_36,
        VAULT_37,
        VAULT_38,
        VAULT_39,
        VAULT_40,
        VAULT_41,
        VAULT_42,
        VAULT_43,
        VAULT_44,
        VAULT_45,
        VAULT_46,
        VAULT_47,
        VAULT_48,
        VAULT_49,
        VAULT_50,
        VAULT_51,
        VAULT_52,
        VAULT_53,
        VAULT_54,
        VAULT_55,
        VAULT_56,
        VAULT_57,
        VAULT_58,
        VAULT_59,
        VAULT_60,
        VAULT_61,
        VAULT_62,
        VAULT_63,
        VAULT_64,
        VAULT_65,
        VAULT_66,
        VAULT_67,
        VAULT_68,
        VAULT_69,
        VAULT_70,
        VAULT_71,
        VAULT_72,
        VAULT_73,
        VAULT_74,
        VAULT_75,
        VAULT_76,
        VAULT_77,
        VAULT_78,
        VAULT_79,
        VAULT_80,
        VAULT_81,
        VAULT_82,
        VAULT_83,
        VAULT_84,
        VAULT_85,
        VAULT_86,
        VAULT_87,
        VAULT_88,
        VAULT_89,
        VAULT_90,
        VAULT_91,
        VAULT_92,
        VAULT_93,
        VAULT_94,
        VAULT_95,
        VAULT_96,
        VAULT_97,
        VAULT_98,
        VAULT_99,
        VAULT_100,
        VAULT_101,
        VAULT_102,
        VAULT_103,
        VAULT_104,
        VAULT_105,
        VAULT_106,
        VAULT_107,
        VAULT_108,
        VAULT_109,
        VAULT_110,
        VAULT_111,
        VAULT_112,
        VAULT_113,
        VAULT_114,
        VAULT_115,
        VAULT_116,
        VAULT_117,
        VAULT_118,
        VAULT_119,
        VAULT_120,
        VAULT_121,
        VAULT_122,
        VAULT_123,
        VAULT_124,
        VAULT_125,
        VAULT_126,
        VAULT_127,
        VAULT_128,
        VAULT_129,
        VAULT_130,
        VAULT_131,
        VAULT_132,
        VAULT_133,
        VAULT_134,
        VAULT_135,
        VAULT_136,
        VAULT_137,
        VAULT_138,
        VAULT_139,
        VAULT_140,
        VAULT_141,
        VAULT_142,
        VAULT_143,
        VAULT_144,
        VAULT_145,
        VAULT_146,
        VAULT_147,
        VAULT_148,
        VAULT_149,
        VAULT_150,
        VAULT_151,
        VAULT_152,
        VAULT_153,
        VAULT_154,
        VAULT_155,
        VAULT_156,
        VAULT_157,
        VAULT_158,
        VAULT_159,
        VAULT_160,
        VAULT_161,
        VAULT_162,
        VAULT_163,
        VAULT_164,
        VAULT_165,
        VAULT_166,
        VAULT_167,
        VAULT_168,
        VAULT_169,
        VAULT_170,
        VAULT_171,
        VAULT_172,
        VAULT_173,
        VAULT_174,
        VAULT_175,
        VAULT_176,
        VAULT_177,
        VAULT_178,
        VAULT_179,
        VAULT_180,
        VAULT_181,
        VAULT_182,
        VAULT_183,
        VAULT_184,
        VAULT_185,
        VAULT_186,
        VAULT_187,
        VAULT_188,
        VAULT_189,
        VAULT_190,
        VAULT_191,
        VAULT_192,
        VAULT_193,
        VAULT_194,
        VAULT_195,
        VAULT_196,
        VAULT_197,
        VAULT_198,
        VAULT_199,
        VAULT_200,
        VAULT_201,
        VAULT_202,
        VAULT_203,
        VAULT_204,
        VAULT_205,
        VAULT_206,
        VAULT_207,
        VAULT_208,
        VAULT_209,
        VAULT_210,
        VAULT_211,
        VAULT_212,
        VAULT_213,
        VAULT_214,
        VAULT_215,
        VAULT_216,
        VAULT_217,
        VAULT_218,
        VAULT_219,
        VAULT_220,
        VAULT_221,
        VAULT_222,
        VAULT_223,
        VAULT_224,
        VAULT_225,
        VAULT_226,
        VAULT_227,
        VAULT_228,
        VAULT_229,
        VAULT_230,
        VAULT_231,
        VAULT_232,
        VAULT_233,
        VAULT_234,
        VAULT_235,
        VAULT_236,
        VAULT_237,
        VAULT_238,
        VAULT_239,
        VAULT_240,
        VAULT_241,
        VAULT_242,
        VAULT_243,
        VAULT_244,
        VAULT_245,
        VAULT_246,
        VAULT_247,
        VAULT_248,
        VAULT_249,
        VAULT_250,
        VAULT_251,
        VAULT_252,
        VAULT_253,
        VAULT_254,
        VAULT_255
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event SingletonContractSet(bytes32 indexed id, address indexed contractAddress);
    event VaultRegistered(address indexed vault, address indexed asset, VaultType indexed vaultType);
    event VaultRemoved(address indexed vault);
    event AssetRegistered(address indexed asset, address indexed kToken);
    event AssetSupported(address indexed asset);
    event AdapterRegistered(address indexed vault, address indexed adapter);
    event AdapterRemoved(address indexed vault, address indexed adapter);
    event KTokenDeployed(address indexed kTokenContract, string name_, string symbol_, uint8 decimals_);
    event KTokenImplementationSet(address indexed implementation);
    event RescuedAssets(address indexed asset, address indexed to, uint256 amount);
    event RescuedETH(address indexed asset, uint256 amount);
    event TreasurySet(address indexed treasury);
    event HurdleRateSet(address indexed asset, uint16 hurdleRate);

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setSingletonContract(bytes32 id, address contractAddress) external payable;
    function registerAsset(
        string memory name,
        string memory symbol,
        address asset,
        bytes32 id,
        uint256 maxMintPerBatch,
        uint256 maxRedeemPerBatch
    )
        external
        payable
        returns (address);
    function registerVault(address vault, VaultType type_, address asset) external payable;
    function registerAdapter(address vault, address adapter) external payable;
    function removeAdapter(address vault, address adapter) external payable;
    function grantInstitutionRole(address institution_) external payable;
    function grantVendorRole(address vendor_) external payable;
    function grantRelayerRole(address relayer_) external payable;
    function getContractById(bytes32 id) external view returns (address);
    function getAssetById(bytes32 id) external view returns (address);
    function getAllAssets() external view returns (address[] memory);
    function getCoreContracts() external view returns (address kMinter, address kAssetRouter);
    function getVaultsByAsset(address asset) external view returns (address[] memory);
    function getVaultByAssetAndType(address asset, uint8 vaultType) external view returns (address);
    function getVaultType(address vault) external view returns (uint8);
    function isAdmin(address user) external view returns (bool);
    function isEmergencyAdmin(address user) external view returns (bool);
    function isGuardian(address user) external view returns (bool);
    function isRelayer(address user) external view returns (bool);
    function isInstitution(address user) external view returns (bool);
    function isVendor(address user) external view returns (bool);
    function isAsset(address asset) external view returns (bool);
    function isVault(address vault) external view returns (bool);
    function getAdapters(address vault) external view returns (address[] memory);
    function isAdapterRegistered(address vault, address adapter) external view returns (bool);
    function getVaultAssets(address vault) external view returns (address[] memory);
    function assetToKToken(address asset) external view returns (address);
    function getTreasury() external view returns (address);
    function setHurdleRate(address asset, uint16 hurdleRate) external payable;
    function getHurdleRate(address asset) external view returns (uint16);
    function setAssetBatchLimits(
        address asset,
        uint256 maxMintPerBatch_,
        uint256 maxRedeemPerBatch_
    )
        external
        payable;
    function getMaxMintPerBatch(address asset) external view returns (uint256);
    function getMaxRedeemPerBatch(address asset) external view returns (uint256);
}
