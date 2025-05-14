// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolBorrowRwaTests is TestnetProcedures {
  function setUp() public {
    initTestEnvironment();

    vm.startPrank(poolAdmin);
    // set buidl borrowing config
    contracts.poolConfiguratorProxy.setReserveBorrowing(tokenList.buidl, true);
    // authorize & mint BUIDL to bob
    buidl.authorize(bob, true);
    buidl.mint(bob, 100_000e6);
    // authorize & mint BUIDL to liquidityProvider
    buidl.authorize(liquidityProvider, true);
    buidl.mint(liquidityProvider, 100_000e6);
    vm.stopPrank();

    vm.prank(bob);
    buidl.approve(report.poolProxy, UINT256_MAX);

    vm.startPrank(liquidityProvider);
    buidl.approve(report.poolProxy, UINT256_MAX);
    contracts.poolProxy.supply(tokenList.buidl, 50_000e6, liquidityProvider, 0);
    vm.stopPrank();
  }

  function test_reverts_borrow_TransferUnderlyingTo_OperationNotSupported() public {
    vm.prank(bob);
    contracts.poolProxy.supply(tokenList.wbtc, 0.4e8, bob, 0);

    vm.expectCall(
      rwaATokenList.aBuidl,
      abi.encodeCall(IRwaAToken.transferUnderlyingTo, (bob, 2000e6))
    );

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));

    vm.prank(bob);
    contracts.poolProxy.borrow(tokenList.buidl, 2000e6, 2, 0, bob);
  }
}
