// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AccessControl} from '../dependencies/openzeppelin/contracts/AccessControl.sol';
import {IRwaAToken} from '../interfaces/IRwaAToken.sol';
import {IRwaATokenManager} from '../interfaces/IRwaATokenManager.sol';
import {IPoolAddressesProvider} from '../interfaces/IPoolAddressesProvider.sol';
import {IPool} from '../interfaces/IPool.sol';

/**
 * @title RwaATokenManager
 * @author Aave
 * @notice Implementation of the RWA aToken Manager, allowing transfer permissions to be granted individually for each RWA aToken.
 * @dev Requires the ATokenAdmin role on the Aave V3 Pool.
 */
contract RwaATokenManager is AccessControl, IRwaATokenManager {
  /// @inheritdoc IRwaATokenManager
  IPool public immutable POOL;

  /// @inheritdoc IRwaATokenManager
  bytes32 public constant AUTHORIZED_TRANSFER_ROLE = keccak256('AUTHORIZED_TRANSFER');

  /**
   * @dev Constructor
   * @param owner The address of the default admin role
   * @param addressesProvider The address of the PoolAddressesProvider of Aave V3 Pool
   */
  constructor(address owner, address addressesProvider) {
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
    POOL = IPool(IPoolAddressesProvider(addressesProvider).getPool());
  }

  /// @inheritdoc IRwaATokenManager
  function grantAuthorizedTransferRole(address asset, address account) external override {
    grantRole(getAuthorizedTransferRole(asset), account);
  }

  /// @inheritdoc IRwaATokenManager
  function revokeAuthorizedTransferRole(address asset, address account) external override {
    revokeRole(getAuthorizedTransferRole(asset), account);
  }

  /// @inheritdoc IRwaATokenManager
  function transferRwaAToken(
    address asset,
    address from,
    address to,
    uint256 amount
  ) external override onlyRole(getAuthorizedTransferRole(asset)) returns (bool) {
    address aToken = _getAToken(asset);
    return IRwaAToken(aToken).authorizedTransfer(from, to, amount);
  }

  /// @inheritdoc IRwaATokenManager
  function hasAuthorizedTransferRole(
    address asset,
    address account
  ) external view override returns (bool) {
    return hasRole(getAuthorizedTransferRole(asset), account);
  }

  /// @inheritdoc IRwaATokenManager
  function getAuthorizedTransferRole(address asset) public view override returns (bytes32) {
    return keccak256(abi.encode(AUTHORIZED_TRANSFER_ROLE, _getAToken(asset)));
  }

  /**
   * @dev Reverts if the asset does not have a valid aToken
   * @param asset The address of the asset for which to get the aToken
   * @return The address of the aToken for the given asset
   */
  function _getAToken(address asset) internal view returns (address) {
    address aToken = POOL.getReserveAToken(asset);
    require(aToken != address(0), 'INVALID_RESERVE');
    return aToken;
  }
}
