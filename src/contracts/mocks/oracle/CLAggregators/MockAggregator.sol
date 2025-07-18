// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MockAggregator {
  int256 public _latestAnswer;

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  constructor(int256 initialAnswer) {
    _latestAnswer = initialAnswer;
    emit AnswerUpdated(initialAnswer, 0, block.timestamp);
  }

  function latestAnswer() external view returns (int256) {
    return _latestAnswer;
  }

  function getTokenType() external pure returns (uint256) {
    return 1;
  }

  function decimals() external view virtual returns (uint8) {
    return 8;
  }
}
