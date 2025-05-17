// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolDeficitTests} from 'tests/protocol/pool/Pool.Deficit.sol';

contract PoolDeficitRwaTests is PoolDeficitTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.wbtc, 'aWbtc', 2);
  }

  function test_reverts_eliminateReserveDeficit_reserve_not_in_deficit(
    address coverageAdmin
  ) public override {
    _upgradeToRwaAToken(tokenList.usdx, 'usdx', 2);
    super.test_reverts_eliminateReserveDeficit_reserve_not_in_deficit(coverageAdmin);
  }
}
