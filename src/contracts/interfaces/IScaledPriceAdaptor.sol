// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

interface IScaledPriceAdaptor {
  /**
   * @dev Units and direction used to scale answer to base decimals of 8.
   * @dev Looses price precision when scaling down by log10(scaleUnits).
   * @return scaleUp Whether to scale up or down.
   * @return scaleUnits The units to scale by.
   */
  function scale() external view returns (bool scaleUp, uint256 scaleUnits);

  /**
   * @dev The decimals of price adaptor.
   */
  function decimals() external view returns (uint8);

  /**
   * @dev Underlying chainlink price source.
   */
  function source() external view returns (address);

  /**
   * @dev Description of price adaptor.
   */
  function description() external view returns (string memory);

  /**
   * @dev Scaled `latestAnswer` from chainlink price feed.
   * @dev Looses price precision when scaling down by log10(scaleUnits).
   */
  function latestAnswer() external view returns (int256);
}
