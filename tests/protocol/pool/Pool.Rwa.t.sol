// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Detailed} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolRwaTests is TestnetProcedures {
  function setUp() public virtual {
    initTestEnvironment();

    vm.startPrank(poolAdmin);
    // set buidl borrowing config
    contracts.poolConfiguratorProxy.setReserveBorrowing(tokenList.buidl, true);
    contracts.poolConfiguratorProxy.setReserveFactor(tokenList.buidl, 10_00);
    // authorize & mint BUIDL to bob
    buidl.authorize(bob, true);
    buidl.mint(bob, 100_000e6);
    // authorize & mint BUIDL to carol
    buidl.authorize(carol, true);
    buidl.mint(carol, 100_000e6);
    // authorize & mint BUIDL to liquidityProvider
    buidl.authorize(liquidityProvider, true);
    buidl.mint(liquidityProvider, 100_000e6);
    vm.stopPrank();

    vm.prank(bob);
    buidl.approve(report.poolProxy, UINT256_MAX);
    vm.prank(carol);
    buidl.approve(report.poolProxy, UINT256_MAX);

    vm.startPrank(liquidityProvider);
    buidl.approve(report.poolProxy, UINT256_MAX);
    contracts.poolProxy.supply(tokenList.buidl, 50_000e6, liquidityProvider, 0);
    vm.stopPrank();
  }

  function test_reverts_mintToTreasury() public {
    (, , address varDebtBuidl) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );

    vm.startPrank(bob);
    contracts.poolProxy.supply(tokenList.wbtc, 0.4e8, bob, 0);
    contracts.poolProxy.borrow(tokenList.buidl, 2000e6, 2, 0, bob);
    skip(30 days);
    contracts.poolProxy.repay(tokenList.buidl, IERC20Detailed(varDebtBuidl).balanceOf(bob), 2, bob);
    vm.stopPrank();

    // distribute fees to treasury
    address[] memory assets = new address[](1);
    assets[0] = tokenList.buidl;

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    contracts.poolProxy.mintToTreasury(assets);
  }
}
