// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IERC20} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {DataTypes} from 'src/contracts/protocol/libraries/types/DataTypes.sol';
import {IPoolConfigurator} from 'src/contracts/interfaces/IPoolConfigurator.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolConfiguratorPendingLtvRwaTests is TestnetProcedures {
  function setUp() public {
    initTestEnvironment();
  }

  function test_freezeReserve_ltvSetTo0() public {
    // check current ltv
    (uint256 ltv, , , bool isFrozen) = _getReserveParams();

    assertTrue(ltv > 0);
    assertEq(isFrozen, false);

    // freeze reserve
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveFreeze(tokenList.buidl, true);

    // check ltv = 0
    (uint256 updatedltv, , , bool updatedIsFrozen) = _getReserveParams();
    assertEq(updatedltv, 0);
    assertEq(updatedIsFrozen, true);

    // check pending ltv is set
    uint256 pendingLtv = contracts.poolConfiguratorProxy.getPendingLtv(tokenList.buidl);

    assertEq(pendingLtv, ltv);
  }

  function test_unfreezeReserve_pendingSetToLtv() public {
    // check ltv
    (uint256 originalLtv, , , ) = _getReserveParams();

    // freeze reserve
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveFreeze(tokenList.buidl, true);

    // check ltv
    (uint256 ltv, , , bool isFrozen) = _getReserveParams();

    assertEq(ltv, 0);
    assertEq(isFrozen, true);

    // check pending ltv
    uint256 pendingLtv = contracts.poolConfiguratorProxy.getPendingLtv(tokenList.buidl);

    // unfreeze reserve
    contracts.poolConfiguratorProxy.setReserveFreeze(tokenList.buidl, false);

    // check ltv is set back
    (uint256 updatedLtv, , , bool updatedIsFrozen) = _getReserveParams();

    assertEq(updatedLtv, originalLtv);
    assertEq(updatedLtv, pendingLtv);
    assertEq(updatedIsFrozen, false);

    // check pending ltv is set to zero
    uint256 updatedPendingLtv = contracts.poolConfiguratorProxy.getPendingLtv(tokenList.buidl);

    assertEq(updatedPendingLtv, 0);

    vm.stopPrank();
  }

  // freeze reserve, set ltv, unfreeze reserve
  function test_setLtv_ltvSetPendingLtvSet(uint256 originalLtv, uint256 ltvToSet) public {
    uint256 liquidationThreshold = 86_00;
    uint256 liquidationBonus = 10_500;

    vm.assume(originalLtv > 0);
    vm.assume(originalLtv < liquidationThreshold);

    vm.assume(ltvToSet > 0);
    vm.assume(ltvToSet < liquidationThreshold);
    vm.assume(ltvToSet != originalLtv);

    // set original ltv
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.configureReserveAsCollateral(
      tokenList.buidl,
      originalLtv,
      liquidationThreshold,
      liquidationBonus
    );

    // freeze reserve
    contracts.poolConfiguratorProxy.setReserveFreeze(tokenList.buidl, true);

    // check pending ltv
    uint256 pendingLtv = contracts.poolConfiguratorProxy.getPendingLtv(tokenList.buidl);
    assertEq(pendingLtv, originalLtv);

    // expect events to be emitted
    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.PendingLtvChanged(tokenList.buidl, ltvToSet);

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.CollateralConfigurationChanged(
      tokenList.buidl,
      0,
      liquidationThreshold,
      liquidationBonus
    );

    // setLtv
    contracts.poolConfiguratorProxy.configureReserveAsCollateral(
      tokenList.buidl,
      ltvToSet,
      liquidationThreshold,
      liquidationBonus
    );

    // check ltv is still 0
    (uint256 ltv, , , ) = _getReserveParams();
    assertEq(ltv, 0);

    // check pending ltv
    uint256 updatedPendingLtv = contracts.poolConfiguratorProxy.getPendingLtv(tokenList.buidl);
    assertEq(updatedPendingLtv, ltvToSet);

    // unfreeze reserve
    contracts.poolConfiguratorProxy.setReserveFreeze(tokenList.buidl, false);

    // check ltv is set
    (uint256 updatedLtv, , , ) = _getReserveParams();
    assertEq(updatedLtv, ltvToSet);

    // check pending ltv is set to zero
    uint256 finalPendingLtv = contracts.poolConfiguratorProxy.getPendingLtv(tokenList.buidl);
    assertEq(finalPendingLtv, 0);

    vm.stopPrank();
  }

  function _getReserveParams() internal view returns (uint256, uint256, uint256, bool) {
    (
      ,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      ,
      ,
      ,
      ,
      ,
      bool isFrozen
    ) = contracts.protocolDataProvider.getReserveConfigurationData(tokenList.buidl);

    return (ltv, liquidationThreshold, liquidationBonus, isFrozen);
  }
}
