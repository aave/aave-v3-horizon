// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IRWAAToken
 * @author Aave
 * @notice Defines the basic interface for an RWAAToken.
 */
interface IRWAAToken {
  /**
   * @notice Transfers an amount of aTokens between two users.
   * @dev It checks for valid HF after the tranfer.
   * @dev Only callable by transfer role admin.
   * @param from The address to transfer from.
   * @param to The address to transfer to.
   * @param amount The amount to be transferred.
   * @return True if the transfer was successful, false otherwise.
   */
  function forceTransfer(address from, address to, uint256 amount) external returns (bool);
}
