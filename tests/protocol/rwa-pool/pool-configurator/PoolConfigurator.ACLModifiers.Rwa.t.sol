// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {ConfiguratorInputTypes} from 'src/contracts/protocol/pool/PoolConfigurator.sol';
import {TestnetProcedures, TestVars} from 'tests/utils/TestnetProcedures.sol';

contract PoolConfiguratorACLModifiersRwaTest is TestnetProcedures {
  function setUp() public {
    initTestEnvironment();
  }

  function test_reverts_notAdmin_dropReserve(address caller) public {
    vm.assume(
      !contracts.aclManager.isPoolAdmin(caller) &&
        caller != address(contracts.poolAddressesProvider)
    );

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));

    vm.prank(caller);
    contracts.poolConfiguratorProxy.dropReserve(tokenList.buidl);
  }

  function test_reverts_notAdmin_setReserveActive(address caller) public {
    vm.assume(
      !contracts.aclManager.isPoolAdmin(caller) &&
        caller != address(contracts.poolAddressesProvider)
    );

    vm.expectRevert(bytes(Errors.CALLER_NOT_POOL_ADMIN));

    vm.prank(caller);
    contracts.poolConfiguratorProxy.setReserveActive(tokenList.buidl, true);
  }
}
