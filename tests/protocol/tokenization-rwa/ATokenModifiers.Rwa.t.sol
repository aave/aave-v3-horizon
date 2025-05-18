// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ATokenModifiersTests} from 'tests/protocol/tokenization/ATokenModifiers.t.sol';

contract ATokenModifiersRwaTests is ATokenModifiersTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx', 2);
  }

  /// @dev skipping this test, transfers on liquidation are not supported for RWA aTokens
  function test_revert_notAdmin_transferOnLiquidation() public override {}

  /// @dev skipping this test, transfers of underlying are not supported for RWA aTokens
  function test_revert_notAdmin_transferUnderlyingTo() public override {}
}
