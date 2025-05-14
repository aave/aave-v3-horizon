// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Detailed} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {ConfiguratorInputTypes} from 'src/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {RwaATokenInstance} from 'src/contracts/instances/RwaATokenInstance.sol';
import {ATokenInstance} from 'src/contracts/instances/ATokenInstance.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {IPool} from 'src/contracts/interfaces/IPool.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract MockATokenInstance is ATokenInstance {
  constructor(IPool pool) ATokenInstance(pool) {}

  function getRevision() internal pure virtual override returns (uint256) {
    return 2;
  }
}

contract MockRwaATokenInstance is RwaATokenInstance {
  constructor(IPool pool) RwaATokenInstance(pool) {}

  function getRevision() internal pure virtual override returns (uint256) {
    return 3;
  }
}

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

  function test_reverts_mintToTreasury() public {
    // upgrade aBuild to the standard aToken implementation, to be able to borrow
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.updateAToken(
      ConfiguratorInputTypes.UpdateATokenInput({
        asset: tokenList.buidl,
        treasury: report.treasury,
        incentivesController: report.rewardsControllerProxy,
        name: 'aBuidl',
        symbol: 'aBuidl',
        implementation: address(new MockATokenInstance(IPool(report.poolProxy))),
        params: abi.encode()
      })
    );
    vm.stopPrank();

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

    // upgrade aBuild to the rwa aToken implementation, to test that mintToTreasury reverts
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.updateAToken(
      ConfiguratorInputTypes.UpdateATokenInput({
        asset: tokenList.buidl,
        treasury: report.treasury,
        incentivesController: report.rewardsControllerProxy,
        name: 'aBuidl',
        symbol: 'aBuidl',
        implementation: address(new MockRwaATokenInstance(IPool(report.poolProxy))),
        params: abi.encode()
      })
    );
    vm.stopPrank();

    // expect call by matching the selector only
    vm.expectCall(rwaATokenList.aBuidl, abi.encodeWithSelector(IRwaAToken.mintToTreasury.selector));

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    contracts.poolProxy.mintToTreasury(assets);
  }
}
