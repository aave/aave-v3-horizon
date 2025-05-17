// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolEModeTests} from 'tests/protocol/pool/Pool.Emode.sol';

contract PoolEModeRwaTests is PoolEModeTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx', 2);
  }

  function test_liquidations_shouldApplyEModeLBForEmodeAssets(uint256 amount) public override {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setLiquidationProtocolFee(tokenList.usdx, 0);

    super.test_liquidations_shouldApplyEModeLBForEmodeAssets(amount);
  }

  function test_setUserEMode_shouldAllowSwitchingIfNoBorrows(uint8 eMode) public override {
    _upgradeToRwaAToken(tokenList.wbtc, 'aWbtc', 2);
    _upgradeToRwaAToken(tokenList.weth, 'aWeth', 2);
    super.test_setUserEMode_shouldAllowSwitchingIfNoBorrows(eMode);
  }
}
