// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolRepayTests} from 'tests/protocol/pool/Pool.Repay.t.sol';

contract PoolRepayRwaTests is PoolRepayTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.wbtc, 'aWbtc');
    _upgradeToRwaAToken(tokenList.weth, 'aWeth');
  }

  function test_reverts_borrow_invalidAmount() public override {
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx');
    super.test_reverts_borrow_invalidAmount();
  }

  function test_reverts_borrow_reserveInactive() public override {
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx');
    super.test_reverts_borrow_reserveInactive();
  }

  function test_reverts_borrow_reservePaused() public override {
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx');
    super.test_reverts_borrow_reservePaused();
  }

  function test_reverts_repay_no_debt() public override {
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx');
    super.test_reverts_repay_no_debt();
  }
}
