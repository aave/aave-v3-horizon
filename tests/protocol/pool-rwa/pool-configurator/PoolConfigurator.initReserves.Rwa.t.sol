// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolConfiguratorInitReservesTests} from 'tests/protocol/pool/pool-configurator/PoolConfigurator.initReserves.t.sol';

contract PoolConfiguratorInitReservesRwaTests is PoolConfiguratorInitReservesTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx', 2);
  }
}
