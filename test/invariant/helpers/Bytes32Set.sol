// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

struct Bytes32Set {
    bytes32[] values;
    mapping(bytes32 => bool) saved;
    mapping(bytes32 => uint256) index;
}

library LibBytes32Set {
    function add(Bytes32Set storage s, bytes32 value) internal {
        if (!s.saved[value]) {
            uint256 i = count(s);
            s.values.push(value);
            s.saved[value] = true;
            s.index[value] = i;
        }
    }

    function remove(Bytes32Set storage s, bytes32 value) internal {
        if (!contains(s, value)) revert();
        uint256 _count = count(s);

        uint256 lastIndex = _count - 1;
        uint256 index = s.index[value];
        bytes32 temp = s.values[lastIndex];

        s.values[index] = temp;
        s.values[lastIndex] = value;
        s.values.pop();

        s.saved[value] = false;
        s.index[temp] = index;
    }

    function contains(Bytes32Set storage s, bytes32 value) internal view returns (bool) {
        return s.saved[value];
    }

    function count(Bytes32Set storage s) internal view returns (uint256) {
        return s.values.length;
    }

    function rand(Bytes32Set storage s, uint256 seed) internal view returns (bytes32) {
        if (s.values.length > 0) {
            return s.values[seed % s.values.length];
        } else {
            return bytes32(0);
        }
    }

    function forEach(Bytes32Set storage s, function(bytes32) external func) internal {
        for (uint256 i; i < s.values.length; ++i) {
            func(s.values[i]);
        }
    }

    function at(Bytes32Set storage s, uint256 index) internal view returns (bytes32) {
        return s.values[index];
    }

    function reduce(
        Bytes32Set storage s,
        uint256 acc,
        function(uint256, bytes32) external returns (uint256) func
    )
        internal
        returns (uint256)
    {
        for (uint256 i; i < s.values.length; ++i) {
            acc = func(acc, s.values[i]);
        }
        return acc;
    }
}
