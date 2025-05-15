// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IPoolConfigurator} from 'src/contracts/interfaces/IPoolConfigurator.sol';
import 'tests/utils/TestnetProcedures.sol';

contract PoolConfiguratorLiquidationFeeRwaTests is TestnetProcedures {
  function setUp() public {
    initTestEnvironment();
  }

  function test_setLiquidationFee() public {
    uint256 previousFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.LiquidationProtocolFeeChanged(tokenList.buidl, previousFee, 3000);

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setLiquidationProtocolFee(tokenList.buidl, 3000);

    uint256 currentFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);
    assertEq(currentFee, 3000);
  }

  function test_setLiquidationFee_100() public {
    uint256 previousFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.LiquidationProtocolFeeChanged(tokenList.buidl, previousFee, 10000);

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setLiquidationProtocolFee(tokenList.buidl, 10000);

    uint256 currentFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);
    assertEq(currentFee, 10000);
  }

  function test_revert_setLiquidationFee_gt_100() public {
    uint256 previousFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);

    vm.expectRevert(bytes(Errors.INVALID_LIQUIDATION_PROTOCOL_FEE));

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setLiquidationProtocolFee(tokenList.buidl, 10001);

    uint256 currentFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);
    assertEq(currentFee, previousFee);
  }

  function test_revert_setLiquidationFee_unauthorized() public {
    uint256 previousFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);

    vm.expectRevert(bytes(Errors.CALLER_NOT_RISK_OR_POOL_ADMIN));

    vm.prank(bob);
    contracts.poolConfiguratorProxy.setLiquidationProtocolFee(tokenList.buidl, 2200);

    uint256 currentFee = contracts.protocolDataProvider.getLiquidationProtocolFee(tokenList.buidl);
    assertEq(currentFee, previousFee);
  }
}
