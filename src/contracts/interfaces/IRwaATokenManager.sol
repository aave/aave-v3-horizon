// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPool} from './IPool.sol';

/**
 * @title IRwaATokenManager
 * @author Aave
 * @notice Defines the basic interface for the RWA aToken manager
 */
interface IRwaATokenManager {
  /**
   * @notice Grants the authorized transfer role for a specific RWA aToken to a designated account.
   * @param asset The address of the RWA asset
   * @param account The address of the account to which permission is granted
   */
  function grantAuthorizedTransferRole(address asset, address account) external;

  /**
   * @notice Revokes the authorized transfer role for a specific RWA aToken from a designated account.
   * @param asset The address of the RWA asset
   * @param account  The address of the account to which permission is revoked
   */
  function revokeAuthorizedTransferRole(address asset, address account) external;

  /**
   * @notice Performs an authorized transfer of RWA aTokens from one account to another
   * @param asset The address of the RWA asset
   * @param from The address from which the RWA aTokens are transferred
   * @param to The address that will receive the RWA aTokens
   * @param amount The amount of RWA aTokens to transfer
   * @return True if the transfer was successful, false otherwise
   */
  function transferRwaAToken(
    address asset,
    address from,
    address to,
    uint256 amount
  ) external returns (bool);

  /**
   * @notice Returns whether the account holds the authorized transfer role for a specific RWA aToken
   * @param asset The address of the RWA asset
   * @param account The address of the account
   * @return True if the given address has the authorized transfer role for the RWA aToken, false otherwise
   */
  function hasAuthorizedTransferRole(address asset, address account) external view returns (bool);

  /**
   * @notice Returns the identifier of the AuthorizedTransfer role
   * @return The id of the AuthorizedTransfer role
   */
  function AUTHORIZED_TRANSFER_ROLE() external pure returns (bytes32);

  /**
   * @notice The pool associated with the RwaATokenManager
   * @return The pool address
   */
  function POOL() external view returns (IPool);

  /**
   * @notice Returns the role id required to perform transfers of the specified RWA aToken
   * @param asset The address of the RWA asset
   * @return The bytes32 identifier of the role required to transfer the RWA aToken
   */
  function getAuthorizedTransferRole(address asset) external view returns (bytes32);
}
