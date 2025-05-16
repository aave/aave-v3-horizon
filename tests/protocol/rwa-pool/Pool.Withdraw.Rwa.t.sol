// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IPool} from 'src/contracts/interfaces/IPool.sol';
import {IAToken, IERC20} from 'src/contracts/interfaces/IAToken.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolWithdrawRwaTests is TestnetProcedures {
  function setUp() public {
    initTestEnvironment();
  }

  function test_full_withdraw() public {
    uint256 amount = 142e6;
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.warp(block.timestamp + 10 days);

    uint256 amountToWithdraw = IAToken(rwaATokenList.aBuidl).balanceOf(alice);
    uint256 balanceBefore = IERC20(tokenList.buidl).balanceOf(alice);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.ReserveUsedAsCollateralDisabled(tokenList.buidl, alice);
    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.Withdraw(tokenList.buidl, alice, alice, amountToWithdraw);

    contracts.poolProxy.withdraw(tokenList.buidl, amountToWithdraw, alice);
    vm.stopPrank();

    assertEq(IERC20(tokenList.buidl).balanceOf(alice), balanceBefore + amountToWithdraw);
    assertEq(IAToken(rwaATokenList.aBuidl).balanceOf(alice), 0);
  }

  function test_partial_withdraw() public {
    uint256 amount = 142e6;
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.warp(block.timestamp + 10 days);

    uint256 amountToWithdraw = IAToken(rwaATokenList.aBuidl).balanceOf(alice);
    uint256 balanceBefore = IERC20(tokenList.buidl).balanceOf(alice);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.ReserveUsedAsCollateralDisabled(tokenList.buidl, alice);
    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.Withdraw(tokenList.buidl, alice, alice, amountToWithdraw);

    contracts.poolProxy.withdraw(tokenList.buidl, type(uint256).max, alice);
    vm.stopPrank();

    assertEq(IERC20(tokenList.buidl).balanceOf(alice), balanceBefore + amountToWithdraw);
  }

  function test_full_withdraw_to() public {
    uint256 amount = 142e6;
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.warp(block.timestamp + 10 days);

    uint256 amountToWithdraw = IAToken(rwaATokenList.aBuidl).balanceOf(alice);
    uint256 balanceBefore = IERC20(tokenList.buidl).balanceOf(bob);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.ReserveUsedAsCollateralDisabled(tokenList.buidl, alice);
    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.Withdraw(tokenList.buidl, alice, bob, amountToWithdraw);

    contracts.poolProxy.withdraw(tokenList.buidl, type(uint256).max, bob);
    vm.stopPrank();

    assertEq(IERC20(tokenList.buidl).balanceOf(bob), balanceBefore + amountToWithdraw);
    assertEq(IAToken(rwaATokenList.aBuidl).balanceOf(alice), 0);
  }

  function test_withdraw_not_enabled_as_collateral() public {
    uint256 amount = 142e6;
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.ReserveUsedAsCollateralDisabled(tokenList.buidl, alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, false);

    vm.warp(block.timestamp + 10 days);

    uint256 amountToWithdraw = IAToken(rwaATokenList.aBuidl).balanceOf(alice);
    uint256 balanceBefore = IERC20(tokenList.buidl).balanceOf(alice);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.Withdraw(tokenList.buidl, alice, alice, amountToWithdraw);

    contracts.poolProxy.withdraw(tokenList.buidl, type(uint256).max, alice);
    vm.stopPrank();

    assertEq(IERC20(tokenList.buidl).balanceOf(alice), balanceBefore + amountToWithdraw);
    assertEq(IAToken(rwaATokenList.aBuidl).balanceOf(alice), 0);
  }

  function test_reverts_withdraw_invalidAmount() public {
    uint256 amount = 142e6;
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.expectRevert(bytes(Errors.INVALID_AMOUNT));

    contracts.poolProxy.withdraw(tokenList.buidl, 0, alice);
    vm.stopPrank();
  }

  function test_reverts_withdraw_to_atoken() public {
    uint256 amount = 142e6;
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.expectRevert(bytes(Errors.WITHDRAW_TO_ATOKEN));

    contracts.poolProxy.withdraw(tokenList.buidl, amount, rwaATokenList.aBuidl);
    vm.stopPrank();
  }

  // function test_Reverts_withdraw_transferred_funds() public {
  //   uint256 amount = 142e6;
  //   _seedLiquidity({token: tokenList.usdx, amount: amount, isRwa: false});

  //   vm.prank(poolAdmin);
  //   contracts.poolConfiguratorProxy.setReserveBorrowing(tokenList.buidl, true);

  //   vm.startPrank(alice);
  //   contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);
  //   contracts.poolProxy.borrow(tokenList.usdx, amount, 2, 0, alice);
  //   assertEq(IERC20(tokenList.buidl).balanceOf(rwaATokenList.aBuidl), amount);

  //   IERC20(tokenList.buidl).transfer(rwaATokenList.aBuidl, amount);

  //   contracts.poolProxy.withdraw(tokenList.buidl, amount, alice);

  //   vm.expectRevert(stdError.arithmeticError);
  //   contracts.poolProxy.withdraw(tokenList.buidl, 1, alice);
  //   vm.stopPrank();
  // }

  function test_reverts_withdraw_invalidBalance() public {
    uint256 amount = 142e6;
    vm.startPrank(carol);
    contracts.poolProxy.supply(tokenList.buidl, amount, carol, 0);

    vm.expectRevert(bytes(Errors.NOT_ENOUGH_AVAILABLE_USER_BALANCE));

    contracts.poolProxy.withdraw(tokenList.buidl, 200e6, alice);
    vm.stopPrank();
  }

  function test_reverts_withdraw_reserveInactive() public {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveActive(tokenList.buidl, false);

    vm.prank(report.poolProxy);
    IAToken(rwaATokenList.aBuidl).mint(alice, alice, 1000e6, 1e27);

    vm.expectRevert(bytes(Errors.RESERVE_INACTIVE));

    vm.prank(alice);
    contracts.poolProxy.withdraw(tokenList.buidl, 1000e6, alice);
  }

  function test_reverts_withdraw_reservePaused() public {
    uint256 amount = 142e6;
    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReservePause(tokenList.buidl, true, 0);

    vm.expectRevert(bytes(Errors.RESERVE_PAUSED));

    vm.prank(alice);
    contracts.poolProxy.withdraw(tokenList.buidl, 122, alice);
  }

  function test_reverts_withdraw_hf_lt_lqt() public {
    _seedLiquidity({token: tokenList.usdx, amount: 8000e6, isRwa: false});

    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 10_000e6, alice, 0);
    vm.warp(block.timestamp + 1 days);
    contracts.poolProxy.borrow(tokenList.usdx, 8000e6, 2, 0, alice);
    vm.stopPrank();

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.configureReserveAsCollateral(
      tokenList.buidl,
      10_00,
      20_00,
      105_00
    );

    vm.expectRevert(bytes(Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD));

    vm.prank(alice);
    contracts.poolProxy.withdraw(tokenList.buidl, 50e6, alice);
  }
}
