// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {PoolWithdrawTests} from 'tests/protocol/pool/Pool.Withdraw.t.sol';

contract PoolWithdrawRwaTests is PoolWithdrawTests {
  function setUp() public override {
    super.setUp();
    _upgradeToRwaAToken(tokenList.wbtc, 'aWbtc', 2);
    _upgradeToRwaAToken(tokenList.weth, 'aWeth', 2);
    _upgradeToRwaAToken(tokenList.usdx, 'aUsdx', 2);
  }

  /// @dev overwriting to make usdx a standard aToken: test is borrowing usdx
  function test_Reverts_withdraw_transferred_funds() public override {
    _upgradeToStandardAToken(tokenList.usdx, 'aUsdx', 3);
    super.test_Reverts_withdraw_transferred_funds();
  }

  /// @dev overwriting to make usdx a standard aToken: test is borrowing usdx
  function test_reverts_withdraw_hf_lt_lqt() public override {
    _upgradeToStandardAToken(tokenList.usdx, 'aUsdx', 3);
    super.test_reverts_withdraw_hf_lt_lqt();
  }
}
