// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IRWAAToken
 * @author Aave
 * @notice Defines the basic interface for an RWAAToken.
 */
interface IRWAAToken {
  /**
   * @dev Moves `amount` tokens from `sender` to `recipient`. It does
   * not use any allowance mechanism, and is only callable by the
   * transfer role admin.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function forceTransfer(address from, address to, uint256 amount) external returns (bool);
}
