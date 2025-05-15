// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {AccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {IRwaATokenManager} from 'src/contracts/interfaces/IRwaATokenManager.sol';

/**
 * @title RwaATokenManager
 * @author Aave
 * @notice Implementation of the RWA aToken manager
 * @dev Registry for RWA aTokens permissions and the authorized address to perform
 * @dev authorized transfers of RWA aTokens.
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
  function addATokenTransferRole(address aTokenAddress, address admin) external override {
    grantRole(getATokenTransferRole(aTokenAddress), admin);
  }

  /// @inheritdoc IRwaATokenManager
  function transferRWAAToken(
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
