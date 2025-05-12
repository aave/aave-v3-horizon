// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IAccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/IAccessControl.sol';
import {IncentivizedERC20} from 'src/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import {SafeCast} from 'src/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {IERC20} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {AToken} from 'src/contracts/protocol/tokenization/AToken.sol';
import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {IPool} from 'src/contracts/interfaces/IPool.sol';

abstract contract RwaAToken is AToken, IRwaAToken {
  using SafeCast for uint256;

  bytes32 public constant ATOKEN_TRANSFER_ROLE = keccak256('ATOKEN_TRANSFER_ROLE');

  /**
   * @dev Constructor.
   * @param pool The address of the Pool contract
   */
  constructor(IPool pool) AToken(pool) {
    // Intentionally left blank
  }

  /// @inheritdoc IRwaAToken
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual override(AToken, IRwaAToken) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IRwaAToken
  function approve(
    address spender,
    uint256 amount
  ) external virtual override(IERC20, IncentivizedERC20, IRwaAToken) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IRwaAToken
  function increaseAllowance(
    address spender,
    uint256 addedValue
  ) external virtual override(IncentivizedERC20, IRwaAToken) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IRwaAToken
  function decreaseAllowance(
    address spender,
    uint256 subtractedValue
  ) external virtual override(IncentivizedERC20, IRwaAToken) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IRwaAToken
  function transfer(
    address recipient,
    uint256 amount
  ) external virtual override(IERC20, IncentivizedERC20, IRwaAToken) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IRwaAToken
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external virtual override(IERC20, IncentivizedERC20, IRwaAToken) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IRwaAToken
  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) public virtual override(AToken, IRwaAToken) {
    require(to == _treasury, Errors.RECIPIENT_NOT_TREASURY);
    super.transferOnLiquidation(from, to, value);
  }

  /// @inheritdoc IRwaAToken
  function forceTransfer(
    address from,
    address to,
    uint256 amount
  ) external virtual override returns (bool) {
    require(
      IAccessControl(_addressesProvider.getACLManager()).hasRole(ATOKEN_TRANSFER_ROLE, msg.sender),
      Errors.CALLER_NOT_ATOKEN_TRANSFER_ADMIN
    );

    _transfer(from, to, amount.toUint128());
    return true;
  }
}
