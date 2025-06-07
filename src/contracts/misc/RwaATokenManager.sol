// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IRwaAToken} from '../interfaces/IRwaAToken.sol';
import {IRwaATokenManager} from '../interfaces/IRwaATokenManager.sol';

import {AccessControl} from '../dependencies/openzeppelin/contracts/AccessControl.sol';
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
  bytes32 public constant override AUTHORIZED_TRANSFER_ROLE = keccak256('AUTHORIZED_TRANSFER');

  IPool public immutable pool;

  /**
   * @dev Constructor
   * @param owner The address of the default admin role
   */
  constructor(IPoolAddressesProvider poolAddressesProvider, address owner) {
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
    pool = IPool(poolAddressesProvider.getPool());
  }

  /// @inheritdoc IRwaATokenManager
  function grantAuthorizedTransferRole(address reserveAddress, address account) external override {
    grantRole(getAuthorizedTransferRole(reserveAddress), account);
  }

  /// @inheritdoc IRwaATokenManager
  function revokeAuthorizedTransferRole(address reserveAddress, address account) external override {
    revokeRole(getAuthorizedTransferRole(reserveAddress), account);
  }

  /// @inheritdoc IRwaATokenManager
  function hasAuthorizedTransferRole(
    address reserveAddress,
    address account
  ) external view override returns (bool) {
    return hasRole(getAuthorizedTransferRole(reserveAddress), account);
  }

  /// @inheritdoc IRwaATokenManager
  function transferRwaAToken(
    address reserveAddress,
    address from,
    address to,
    uint256 amount
  ) external override onlyRole(getAuthorizedTransferRole(reserveAddress)) returns (bool) {
    address aTokenAddress = _getATokenAddress(reserveAddress);
    emit TransferRwaAToken(msg.sender, aTokenAddress, from, to, amount);
    return IRwaAToken(aTokenAddress).authorizedTransfer(from, to, amount);
  }

  /// @inheritdoc IRwaATokenManager
  function getAuthorizedTransferRole(
    address reserveAddress
  ) public view override returns (bytes32) {
    return keccak256(abi.encode(AUTHORIZED_TRANSFER_ROLE, _getATokenAddress(reserveAddress)));
  }

  function _getATokenAddress(address reserveAddress) internal view returns (address) {
    address aTokenAddress = pool.getReserveAToken(reserveAddress);
    require(aTokenAddress != address(0), 'Invalid aToken address');
    return aTokenAddress;
  }
}
