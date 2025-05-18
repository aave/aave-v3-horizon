// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {VariableDebtTokenEventsTests} from 'tests/protocol/tokenization/VariableDebtToken.t.sol';

contract VariableDebtTokenEventsRwaTests is VariableDebtTokenEventsTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx', 3);
  }

  /// @dev skipping this tests, borrowing is not supported for RWA aTokens
  function test_balanceOf() public override {}

  /// @dev skipping this tests, borrowing is not supported for RWA aTokens
  function test_scaledBalanceOf() public override {}

  /// @dev skipping this tests, borrowing is not supported for RWA aTokens
  function test_totalScaledSupply() public override {}

  /// @dev skipping this tests, borrowing is not supported for RWA aTokens
  function test_totalSupply() public override {}
}
