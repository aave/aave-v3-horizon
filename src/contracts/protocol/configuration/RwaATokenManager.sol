// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IRwaATokenManager} from 'src/contracts/interfaces/IRwaATokenManager.sol';
import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {AccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';

/**
 * @title RwaATokenManager
 * @author Aave
 * @notice Implementation of the RWA aToken manager
 * @dev Registry for RWA aTokens permissions
 */
contract RwaATokenManager is AccessControl, IRwaATokenManager {
  /// @inheritdoc IRwaATokenManager
  address public immutable override OWNER;

  /// @inheritdoc IRwaATokenManager
  bytes32 public constant override AUTHORIZED_ATOKEN_TRANSFER_ROLE =
    keccak256('AUTHORIZED_ATOKEN_TRANSFER_ROLE');

  constructor(address owner) {
    OWNER = owner;
    _setupRole(DEFAULT_ADMIN_ROLE, OWNER);
  }

  /// @inheritdoc IRwaATokenManager
  function grantATokenTransferRole(address aTokenAddress, address admin) external override {
    grantRole(getATokenTransferRole(aTokenAddress), admin);
  }

  /// @inheritdoc IRwaATokenManager
  function revokeATokenTransferRole(address aTokenAddress, address admin) external override {
    revokeRole(getATokenTransferRole(aTokenAddress), admin);
  }

  /// @inheritdoc IRwaATokenManager
  function transferRwaAToken(
    address rwaATokenAddress,
    address from,
    address to,
    uint256 amount
  ) external override onlyRole(getATokenTransferRole(rwaATokenAddress)) returns (bool) {
    return IRwaAToken(rwaATokenAddress).authorizedTransfer(from, to, amount);
  }

  /// @inheritdoc IRwaATokenManager
  function hasATokenTransferRole(
    address aTokenAddress,
    address admin
  ) external view override returns (bool) {
    return hasRole(getATokenTransferRole(aTokenAddress), admin);
  }

  /// @inheritdoc IRwaATokenManager
  function getATokenTransferRole(address aTokenAddress) public pure override returns (bytes32) {
    return keccak256(abi.encode(AUTHORIZED_ATOKEN_TRANSFER_ROLE, aTokenAddress));
  }
}
