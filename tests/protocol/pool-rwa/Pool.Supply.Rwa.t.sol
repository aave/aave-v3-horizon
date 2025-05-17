// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolSupplyTests} from 'tests/protocol/pool/Pool.Supply.t.sol';

contract PoolSupplyRwaTests is PoolSupplyTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.wbtc, 'aWbtc', 2);
    _upgradeToRwaAToken(tokenList.weth, 'aWeth', 2);
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx', 2);
  }

  function test_first_supply_on_behalf() public override {
    _upgradeToStandardAToken(tokenList.wbtc, 'aWbtc', 3);
  }
}
