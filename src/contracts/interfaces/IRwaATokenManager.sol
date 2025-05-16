// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IRwaATokenManager
 * @author Aave
 * @notice Defines the basic interface for the RWA aToken manager
 */
interface IRwaATokenManager {
  /**
   * @dev Grants authorized transfer admin role for an RWA aToken to an address
   * @param aTokenAddress The address of the RWA aToken
   * @param admin The address of the new RWA aToken transfer admin
   */
  function grantATokenTransferRole(address aTokenAddress, address admin) external;

  /**
   * @dev Revokes the authorized transfer admin role for an RWA aToken from an address
   * @param aTokenAddress The address of the RWA aToken
   * @param admin The address of the RWA aToken transfer admin to be revoked
   */
  function revokeATokenTransferRole(address aTokenAddress, address admin) external;

  /**
   * @dev Performs an authorized transfer of RWA aTokens from one address to another
   * @param rwaATokenAddress The address of the RWA aToken
   * @param from The address from which the RWA aTokens are transferred
   * @param to The address that will receive the RWA aTokens
   * @param amount The amount of RWA aTokens to transfer
   * @return True if the transfer was successful, false otherwise
   */
  function transferRwaAToken(
    address rwaATokenAddress,
    address from,
    address to,
    uint256 amount
  ) external returns (bool);

  /**
   * @dev The owner of the RWA aToken manager.
   */
  function OWNER() external view returns (address);

  /**
   * @dev Checks if an address has the RWA aToken transfer admin role
   * @param aTokenAddress The address of the RWA aToken
   * @param admin The address to check
   * @return True if the given address has the RWA aToken transfer admin role, false otherwise
   */
  function hasATokenTransferRole(address aTokenAddress, address admin) external view returns (bool);

  /**
   * @notice Returns the identifier of the AuthorizedATokenTransfer role
   * @return The id of the AuthorizedATokenTransfer role
   */
  function AUTHORIZED_ATOKEN_TRANSFER_ROLE() external pure returns (bytes32);

  /**
   * @dev Returns the role required to transfer the RWA aToken
   * @param aTokenAddress The address of the RWA aToken
   * @return The role required to transfer the RWA aToken
   */
  function getATokenTransferRole(address aTokenAddress) external pure returns (bytes32);
}
