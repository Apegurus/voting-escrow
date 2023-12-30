// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/Checkpoints.sol)
// This file was procedurally generated from scripts/generate/templates/Checkpoints.js.

pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev This library defines the `Trace*` struct, for checkpointing values as they change at different points in
 * time, and later looking up past values by block number. See {Votes} as an example.
 *
 * To create a history of checkpoints define a variable type `Checkpoints.Trace*` in your contract, and store a new
 * checkpoint for the current transaction block using the {push} function.
 */
library Checkpoints {
    /**
     * @dev A value was attempted to be inserted on a past checkpoint.
     */
    error CheckpointUnorderedInsertions();

    struct Trace {
        Checkpoint[] _checkpoints;
    }

    struct Point {
        int128 bias;
        int128 slope;
        uint256 permanent;
    }

    struct Checkpoint {
        uint48 _key;
        Point _value;
    }

    /**
     * @dev Pushes a (`key`, `value`) pair into a Trace so that it is stored as the checkpoint.
     *
     * Returns previous value and new value.
     *
     * IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint48).max` key set will disable the
     * library.
     */
    function push(Trace storage self, uint48 key, Point memory value) internal returns (Point memory, Point memory) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @dev Returns the value in the first (oldest) checkpoint with key greater or equal than the search key, or zero if
     * there is none.
     */
    function lowerLookup(Trace storage self, uint48 key) internal view returns (Point memory) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? _blannkPoint() : _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @dev Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     */
    function upperLookup(
        Trace storage self,
        uint48 key
    ) internal view returns (bool exists, uint48 _key, Point memory _value) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);

        exists = pos != 0;
        _value = exists ? _unsafeAccess(self._checkpoints, pos - 1)._value : _blannkPoint();
        _key = exists ? _unsafeAccess(self._checkpoints, pos - 1)._key : 0;
    }

    /**
     * @dev Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     *
     * NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
     * keys).
     */
    function upperLookupRecent(
        Trace storage self,
        uint48 key
    ) internal view returns (bool exists, uint48 _key, Point memory _value) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        exists = pos != 0;
        _value = exists ? _unsafeAccess(self._checkpoints, pos - 1)._value : _blannkPoint();
        _key = exists ? _unsafeAccess(self._checkpoints, pos - 1)._key : 0;
    }

    /**
     * @dev Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
     */
    function latest(Trace storage self) internal view returns (Point memory) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? _blannkPoint() : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and value
     * in the most recent checkpoint.
     */
    function latestCheckpoint(
        Trace storage self
    ) internal view returns (bool exists, uint48 _key, Point memory _value) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, _blannkPoint());
        } else {
            Checkpoint memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev Returns the number of checkpoint.
     */
    function length(Trace storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev Returns checkpoint at given position.
     */
    function at(Trace storage self, uint48 pos) internal view returns (Checkpoint memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
     * or by updating the last one.
     */
    function _insert(
        Checkpoint[] storage self,
        uint48 key,
        Point memory value
    ) private returns (Point memory, Point memory) {
        uint256 pos = self.length;

        if (pos > 0) {
            // Copying to memory is important here.
            Checkpoint memory last = _unsafeAccess(self, pos - 1);

            // Checkpoint keys must be non-decreasing.
            if (last._key > key) {
                revert CheckpointUnorderedInsertions();
            }

            // Update or push new checkpoint
            if (last._key == key) {
                _unsafeAccess(self, pos - 1)._value = value;
            } else {
                self.push(Checkpoint({_key: key, _value: value}));
            }
            return (last._value, value);
        } else {
            self.push(Checkpoint({_key: key, _value: value}));
            return (_blannkPoint(), value);
        }
    }

    /**
     * @dev Return the index of the last (most recent) checkpoint with key lower or equal than the search key, or `high`
     * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
     * `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(
        Checkpoint[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev Return the index of the first (oldest) checkpoint with key is greater or equal than the search key, or
     * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
     * exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(
        Checkpoint[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
     */
    function _unsafeAccess(Checkpoint[] storage self, uint256 pos) private view returns (Checkpoint storage result) {
        return self[pos];
    }

    /**
     * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
     */
    function _realUnsafeAccess(
        Checkpoint[] storage self,
        uint256 pos
    ) private pure returns (Checkpoint storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    function _blannkPoint() private pure returns (Point memory) {
        return Point({bias: 0, slope: 0, permanent: 0});
    }

    struct TraceAddress {
        CheckpointAddress[] _checkpoints;
    }

    struct CheckpointAddress {
        uint48 _key;
        address _value;
    }

    /**
     * @dev Pushes a (`key`, `value`) pair into a TraceAddress so that it is stored as the checkpoint.
     *
     * Returns previous value and new value.
     *
     * IMPORTANT: Never accept `key` as a user input, since an arbitrary `type(uint48).max` key set will disable the
     * library.
     */
    function push(TraceAddress storage self, uint48 key, address value) internal returns (address, address) {
        return _insert(self._checkpoints, key, value);
    }

    /**
     * @dev Returns the value in the first (oldest) checkpoint with key greater or equal than the search key, or zero if
     * there is none.
     */
    function lowerLookup(TraceAddress storage self, uint48 key) internal view returns (address) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _lowerBinaryLookup(self._checkpoints, key, 0, len);
        return pos == len ? address(0) : _unsafeAccess(self._checkpoints, pos)._value;
    }

    /**
     * @dev Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     */
    function upperLookup(TraceAddress storage self, uint48 key) internal view returns (address) {
        uint256 len = self._checkpoints.length;
        uint256 pos = _upperBinaryLookup(self._checkpoints, key, 0, len);
        return pos == 0 ? address(0) : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev Returns the value in the last (most recent) checkpoint with key lower or equal than the search key, or zero
     * if there is none.
     *
     * NOTE: This is a variant of {upperLookup} that is optimised to find "recent" checkpoint (checkpoints with high
     * keys).
     */
    function upperLookupRecent(TraceAddress storage self, uint48 key) internal view returns (address) {
        uint256 len = self._checkpoints.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - Math.sqrt(len);
            if (key < _unsafeAccess(self._checkpoints, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._checkpoints, key, low, high);

        return pos == 0 ? address(0) : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev Returns the value in the most recent checkpoint, or zero if there are no checkpoints.
     */
    function latest(TraceAddress storage self) internal view returns (address) {
        uint256 pos = self._checkpoints.length;
        return pos == 0 ? address(0) : _unsafeAccess(self._checkpoints, pos - 1)._value;
    }

    /**
     * @dev Returns whether there is a checkpoint in the structure (i.e. it is not empty), and if so the key and value
     * in the most recent checkpoint.
     */
    function latestCheckpoint(
        TraceAddress storage self
    ) internal view returns (bool exists, uint48 _key, address _value) {
        uint256 pos = self._checkpoints.length;
        if (pos == 0) {
            return (false, 0, address(0));
        } else {
            CheckpointAddress memory ckpt = _unsafeAccess(self._checkpoints, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev Returns the number of checkpoint.
     */
    function length(TraceAddress storage self) internal view returns (uint256) {
        return self._checkpoints.length;
    }

    /**
     * @dev Returns checkpoint at given position.
     */
    function at(TraceAddress storage self, uint48 pos) internal view returns (CheckpointAddress memory) {
        return self._checkpoints[pos];
    }

    /**
     * @dev Pushes a (`key`, `value`) pair into an ordered list of checkpoints, either by inserting a new checkpoint,
     * or by updating the last one.
     */
    function _insert(CheckpointAddress[] storage self, uint48 key, address value) private returns (address, address) {
        uint256 pos = self.length;

        if (pos > 0) {
            // Copying to memory is important here.
            CheckpointAddress memory last = _unsafeAccess(self, pos - 1);

            // Checkpoint keys must be non-decreasing.
            if (last._key > key) {
                revert CheckpointUnorderedInsertions();
            }

            // Update or push new checkpoint
            if (last._key == key) {
                _unsafeAccess(self, pos - 1)._value = value;
            } else {
                self.push(CheckpointAddress({_key: key, _value: value}));
            }
            return (last._value, value);
        } else {
            self.push(CheckpointAddress({_key: key, _value: value}));
            return (address(0), value);
        }
    }

    /**
     * @dev Return the index of the last (most recent) checkpoint with key lower or equal than the search key, or `high`
     * if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and exclusive
     * `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(
        CheckpointAddress[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev Return the index of the first (oldest) checkpoint with key is greater or equal than the search key, or
     * `high` if there is none. `low` and `high` define a section where to do the search, with inclusive `low` and
     * exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(
        CheckpointAddress[] storage self,
        uint48 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
     */
    function _unsafeAccess(
        CheckpointAddress[] storage self,
        uint256 pos
    ) private pure returns (CheckpointAddress storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }
}
