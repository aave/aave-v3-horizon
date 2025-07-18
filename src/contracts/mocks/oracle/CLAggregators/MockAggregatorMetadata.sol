// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {MockAggregator} from './MockAggregator.sol';

contract MockAggregatorMetadata is MockAggregator {
  uint8 internal immutable _DECIMALS;

  constructor(int256 initialAnswer_, uint8 decimals_) MockAggregator(initialAnswer_) {
    _DECIMALS = decimals_;
  }

  function decimals() external view override returns (uint8) {
    return _DECIMALS;
  }
}
