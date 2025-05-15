// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IERC20} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {IPoolConfigurator} from 'src/contracts/interfaces/IPoolConfigurator.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolConfiguratorSupplyCapRwaTests is TestnetProcedures {
  uint256 constant MAX_SUPPLY_CAP = 68719476735;

  function setUp() public {
    initTestEnvironment();
  }

  function _setSupplyCapAction(address admin, address token, uint256 amount) internal {
    (, uint256 previousCap) = contracts.protocolDataProvider.getReserveCaps(token);
    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.SupplyCapChanged(token, previousCap, amount);

    vm.prank(admin);
    contracts.poolConfiguratorProxy.setSupplyCap(token, amount);

    (, uint256 newCap) = contracts.protocolDataProvider.getReserveCaps(token);
    assertEq(newCap, amount, 'Cap should match cap amount passed by argument');
  }

  function test_default_supplyCap_zero() public view {
    (, uint256 supplyCapUsdx) = contracts.protocolDataProvider.getReserveCaps(tokenList.buidl);
    assertEq(supplyCapUsdx, 0, 'Default supply cap should be zero');
  }

  function test_reverts_unauthorized_setSupplyCap() public {
    vm.expectRevert(bytes(Errors.CALLER_NOT_RISK_OR_POOL_ADMIN));

    vm.prank(bob);
    contracts.poolConfiguratorProxy.setSupplyCap(tokenList.buidl, 10);
  }

  function test_setSupplyCap() public {
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 10);
  }

  function test_supply_lt_cap() public {
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 4000);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 1250e6, alice, 0);

    assertEq(
      IERC20(rwaATokenList.aBuidl).balanceOf(alice),
      1250e6,
      'Alice balance should match supply amount'
    );
  }

  function test_supply_eq_cap() public {
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 6000);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 6000e6, alice, 0);

    assertEq(
      IERC20(rwaATokenList.aBuidl).balanceOf(alice),
      6000e6,
      'Alice balance should match supply amount'
    );
  }

  function test_setSupplyCap_them_setBorrowCap_zero() public {
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 100);
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 0);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 5000e6, alice, 0);

    assertEq(
      IERC20(rwaATokenList.aBuidl).balanceOf(alice),
      5000e6,
      'Alice supplied balance should match supply amount'
    );
  }

  function test_multiple_setSupplyCap() public {
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 100);
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 4000);
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 20000);
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 6000);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 5000e6, alice, 0);

    assertEq(
      IERC20(rwaATokenList.aBuidl).balanceOf(alice),
      5000e6,
      'Alice supplied balance should match supply amount'
    );
  }

  function test_reverts_supply_gt_cap() public {
    _setSupplyCapAction(poolAdmin, tokenList.buidl, 5000);

    vm.expectRevert(bytes(Errors.SUPPLY_CAP_EXCEEDED));
    vm.prank(bob);
    contracts.poolProxy.supply(tokenList.buidl, 6000e6, bob, 0);
  }

  function test_reverts_setSupplyCap_gt_max_cap() public {
    vm.expectRevert(bytes(Errors.INVALID_SUPPLY_CAP));

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setSupplyCap(tokenList.buidl, MAX_SUPPLY_CAP + 1);
  }
}
