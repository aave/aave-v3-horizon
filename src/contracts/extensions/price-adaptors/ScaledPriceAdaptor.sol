// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AggregatorInterface} from '../../dependencies/chainlink/AggregatorInterface.sol';
import {IScaledPriceAdaptor} from '../../interfaces/IScaledPriceAdaptor.sol';

/**
 * @title ScaledPriceAdaptor
 * @author Aave Labs
 * @dev Price Adaptor for Chainlink price feeds with non standard decimal USD feeds to 8 decimals.
 */
contract ScaledPriceAdaptor is IScaledPriceAdaptor {
  AggregatorInterface internal immutable _SOURCE;

  uint8 internal constant _BASE_DECIMALS = 8;
  bool internal immutable _SCALE_UP;
  uint256 internal immutable _SCALE;

  constructor(address source_) {
    _SOURCE = AggregatorInterface(source_);
    uint8 sourceDecimals = _SOURCE.decimals();
    _SCALE_UP = sourceDecimals < _BASE_DECIMALS;
    _SCALE = 10 ** (_SCALE_UP ? _BASE_DECIMALS - sourceDecimals : sourceDecimals - _BASE_DECIMALS);
  }

  /// @inheritdoc IScaledPriceAdaptor
  function latestAnswer() external view returns (int256) {
    return
      _SCALE_UP ? _SOURCE.latestAnswer() * int256(_SCALE) : _SOURCE.latestAnswer() / int256(_SCALE);
  }

  /// @inheritdoc IScaledPriceAdaptor
  function description() external view returns (string memory) {
    return string.concat(_SOURCE.description(), ' (USD Scaled)');
  }

  /// @inheritdoc IScaledPriceAdaptor
  function decimals() external pure returns (uint8) {
    return _BASE_DECIMALS;
  }

  /// @inheritdoc IScaledPriceAdaptor
  function scale() external view returns (bool, uint256) {
    return (_SCALE_UP, _SCALE);
  }

  /// @inheritdoc IScaledPriceAdaptor
  function source() external view returns (address) {
    return address(_SOURCE);
  }
}
