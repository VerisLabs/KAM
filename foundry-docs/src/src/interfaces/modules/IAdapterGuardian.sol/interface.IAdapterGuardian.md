# IAdapterGuardian
[Git Source](https://github.com/VerisLabs/KAM/blob/7810ef786f844ebd78831ee424b7ee896113d92b/src/interfaces/modules/IAdapterGuardian.sol)


## Functions
### setAdapterAllowedSelector

Set whether a selector is allowed for an adapter on a target contract

*Only callable by ADMIN_ROLE*


```solidity
function setAdapterAllowedSelector(
    address adapter,
    address target,
    uint8 targetType_,
    bytes4 selector,
    bool isAllowed
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`targetType_`|`uint8`||
|`selector`|`bytes4`|The function selector|
|`isAllowed`|`bool`|Whether the selector is allowed|


### setAdapterParametersChecker

Set a parameter checker for an adapter selector

*Only callable by ADMIN_ROLE*


```solidity
function setAdapterParametersChecker(
    address adapter,
    address target,
    bytes4 selector,
    address parametersChecker
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|
|`parametersChecker`|`address`|The parameter checker contract address (0x0 to remove)|


### authorizeAdapterCall

Check if an adapter is authorized to call a specific function on a target


```solidity
function authorizeAdapterCall(address target, bytes4 selector, bytes calldata params) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|
|`params`|`bytes`|The function parameters|


### isAdapterSelectorAllowed

Check if a selector is allowed for an adapter


```solidity
function isAdapterSelectorAllowed(address adapter, address target, bytes4 selector) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|Whether the selector is allowed|


### getAdapterParametersChecker

Get the parameter checker for an adapter selector


```solidity
function getAdapterParametersChecker(
    address adapter,
    address target,
    bytes4 selector
)
    external
    view
    returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|The adapter address|
|`target`|`address`|The target contract address|
|`selector`|`bytes4`|The function selector|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The parameter checker address (address(0) if none)|


### getAdapterTargets

Get the allowed targed to execute a transaction with


```solidity
function getAdapterTargets(address adapter) external view returns (address[] memory targets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|the adapter to get the targets from|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`targets`|`address[]`|an array of possible targes used by the adapter|


### getTargetType

Gets the type of an target


```solidity
function getTargetType(address target) external view returns (uint8);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`target`|`address`|The target address to check the type of|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|type An array of allowed target addresses for the adapter|


## Events
### AdapterRegistered
Emitted when an adapter is registered or unregistered


```solidity
event AdapterRegistered(address indexed adapter, bool registered);
```

### SelectorAllowed
Emitted when a selector is allowed or disallowed for an adapter


```solidity
event SelectorAllowed(address indexed adapter, address indexed target, bytes4 indexed selector, bool allowed);
```

### ParametersCheckerSet
Emitted when a parameter checker is set for an adapter selector


```solidity
event ParametersCheckerSet(
    address indexed adapter, address indexed target, bytes4 indexed selector, address parametersChecker
);
```

## Enums
### TargetType

```solidity
enum TargetType {
    METAVAULT,
    CUSTODIAL,
    TARGET_03,
    TARGET_04,
    TARGET_05,
    TARGET_06,
    TARGET_07,
    TARGET_08,
    TARGET_09,
    TARGET_10,
    TARGET_11,
    TARGET_12,
    TARGET_13,
    TARGET_14,
    TARGET_15,
    TARGET_16,
    TARGET_17,
    TARGET_18,
    TARGET_19,
    TARGET_20,
    TARGET_21,
    TARGET_22,
    TARGET_23,
    TARGET_24,
    TARGET_25,
    TARGET_26,
    TARGET_27,
    TARGET_28,
    TARGET_29,
    TARGET_30,
    TARGET_31,
    TARGET_32,
    TARGET_33,
    TARGET_34,
    TARGET_35,
    TARGET_36,
    TARGET_37,
    TARGET_38,
    TARGET_39,
    TARGET_40,
    TARGET_41,
    TARGET_42,
    TARGET_43,
    TARGET_44,
    TARGET_45,
    TARGET_46,
    TARGET_47,
    TARGET_48,
    TARGET_49,
    TARGET_50,
    TARGET_51,
    TARGET_52,
    TARGET_53,
    TARGET_54,
    TARGET_55,
    TARGET_56,
    TARGET_57,
    TARGET_58,
    TARGET_59,
    TARGET_60,
    TARGET_61,
    TARGET_62,
    TARGET_63,
    TARGET_64,
    TARGET_65,
    TARGET_66,
    TARGET_67,
    TARGET_68,
    TARGET_69,
    TARGET_70,
    TARGET_71,
    TARGET_72,
    TARGET_73,
    TARGET_74,
    TARGET_75,
    TARGET_76,
    TARGET_77,
    TARGET_78,
    TARGET_79,
    TARGET_80,
    TARGET_81,
    TARGET_82,
    TARGET_83,
    TARGET_84,
    TARGET_85,
    TARGET_86,
    TARGET_87,
    TARGET_88,
    TARGET_89,
    TARGET_90,
    TARGET_91,
    TARGET_92,
    TARGET_93,
    TARGET_94,
    TARGET_95,
    TARGET_96,
    TARGET_97,
    TARGET_98,
    TARGET_99,
    TARGET_100,
    TARGET_101,
    TARGET_102,
    TARGET_103,
    TARGET_104,
    TARGET_105,
    TARGET_106,
    TARGET_107,
    TARGET_108,
    TARGET_109,
    TARGET_110,
    TARGET_111,
    TARGET_112,
    TARGET_113,
    TARGET_114,
    TARGET_115,
    TARGET_116,
    TARGET_117,
    TARGET_118,
    TARGET_119,
    TARGET_120,
    TARGET_121,
    TARGET_122,
    TARGET_123,
    TARGET_124,
    TARGET_125,
    TARGET_126,
    TARGET_127,
    TARGET_128,
    TARGET_129,
    TARGET_130,
    TARGET_131,
    TARGET_132,
    TARGET_133,
    TARGET_134,
    TARGET_135,
    TARGET_136,
    TARGET_137,
    TARGET_138,
    TARGET_139,
    TARGET_140,
    TARGET_141,
    TARGET_142,
    TARGET_143,
    TARGET_144,
    TARGET_145,
    TARGET_146,
    TARGET_147,
    TARGET_148,
    TARGET_149,
    TARGET_150,
    TARGET_151,
    TARGET_152,
    TARGET_153,
    TARGET_154,
    TARGET_155,
    TARGET_156,
    TARGET_157,
    TARGET_158,
    TARGET_159,
    TARGET_160,
    TARGET_161,
    TARGET_162,
    TARGET_163,
    TARGET_164,
    TARGET_165,
    TARGET_166,
    TARGET_167,
    TARGET_168,
    TARGET_169,
    TARGET_170,
    TARGET_171,
    TARGET_172,
    TARGET_173,
    TARGET_174,
    TARGET_175,
    TARGET_176,
    TARGET_177,
    TARGET_178,
    TARGET_179,
    TARGET_180,
    TARGET_181,
    TARGET_182,
    TARGET_183,
    TARGET_184,
    TARGET_185,
    TARGET_186,
    TARGET_187,
    TARGET_188,
    TARGET_189,
    TARGET_190,
    TARGET_191,
    TARGET_192,
    TARGET_193,
    TARGET_194,
    TARGET_195,
    TARGET_196,
    TARGET_197,
    TARGET_198,
    TARGET_199,
    TARGET_200,
    TARGET_201,
    TARGET_202,
    TARGET_203,
    TARGET_204,
    TARGET_205,
    TARGET_206,
    TARGET_207,
    TARGET_208,
    TARGET_209,
    TARGET_210,
    TARGET_211,
    TARGET_212,
    TARGET_213,
    TARGET_214,
    TARGET_215,
    TARGET_216,
    TARGET_217,
    TARGET_218,
    TARGET_219,
    TARGET_220,
    TARGET_221,
    TARGET_222,
    TARGET_223,
    TARGET_224,
    TARGET_225,
    TARGET_226,
    TARGET_227,
    TARGET_228,
    TARGET_229,
    TARGET_230,
    TARGET_231,
    TARGET_232,
    TARGET_233,
    TARGET_234,
    TARGET_235,
    TARGET_236,
    TARGET_237,
    TARGET_238,
    TARGET_239,
    TARGET_240,
    TARGET_241,
    TARGET_242,
    TARGET_243,
    TARGET_244,
    TARGET_245,
    TARGET_246,
    TARGET_247,
    TARGET_248,
    TARGET_249,
    TARGET_250,
    TARGET_251,
    TARGET_252,
    TARGET_253,
    TARGET_254,
    TARGET_255
}
```

