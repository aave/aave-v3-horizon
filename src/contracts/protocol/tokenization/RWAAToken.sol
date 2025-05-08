// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {AccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {IncentivizedERC20} from 'src/contracts/protocol/tokenization/base/IncentivizedERC20.sol';
import {SafeCast} from 'src/contracts/dependencies/openzeppelin/contracts/SafeCast.sol';
import {IERC20} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {AToken} from 'src/contracts/protocol/tokenization/AToken.sol';
import {IAToken} from 'src/contracts/interfaces/IAToken.sol';
import {IPool} from 'src/contracts/interfaces/IPool.sol';

abstract contract RWAAToken is AToken {
  using SafeCast for uint256;

  bytes32 public constant ATOKEN_TRANSFER_ROLE = keccak256('ATOKEN_TRANSFER_ROLE');

  /**
   * @dev Only AToken Transfer Admin can call functions marked by this modifier.
   */
  modifier onlyATokenTransferAdmin() {
    AccessControl aclManager = AccessControl(_addressesProvider.getACLManager());
    require(
      aclManager.hasRole(ATOKEN_TRANSFER_ROLE, msg.sender),
      Errors.CALLER_NOT_ATOKEN_TRANSFER_ADMIN
    );
    _;
  }

  modifier onlyTreasuryRecipient(address recipient) {
    require(recipient == _treasury, Errors.RECIPIENT_NOT_TREASURY);
    _;
  }

  /**
   * @dev Constructor.
   * @param pool The address of the Pool contract
   * @param name The name of the token
   * @param symbol The symbol of the token
   */
  constructor(IPool pool, string memory name, string memory symbol) AToken(pool, name, symbol) {
    // Intentionally left blank
  }

  /// @inheritdoc AToken
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external virtual override {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IERC20
  function approve(
    address spender,
    uint256 amount
  ) external virtual override(IERC20, IncentivizedERC20) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IncentivizedERC20
  function increaseAllowance(
    address spender,
    uint256 addedValue
  ) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IncentivizedERC20
  function decreaseAllowance(
    address spender,
    uint256 subtractedValue
  ) external virtual override returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IERC20
  function transfer(
    address recipient,
    uint256 amount
  ) external virtual override(IERC20, IncentivizedERC20) returns (bool) {
    revert(Errors.OPERATION_NOT_SUPPORTED);
  }

  /// @inheritdoc IERC20
  /// @dev transferFrom is available only for AToken Transfer Admin
  /// @dev the function is overridden such that it does not rely on allowances
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external virtual override(IERC20, IncentivizedERC20) onlyATokenTransferAdmin returns (bool) {
    _transfer(sender, recipient, amount.toUint128());
  }

  /// @inheritdoc IAToken
  function transferOnLiquidation(
    address from,
    address to,
    uint256 value
  ) public virtual override onlyTreasuryRecipient(to) {
    super.transferOnLiquidation(from, to, value);
  }
}
