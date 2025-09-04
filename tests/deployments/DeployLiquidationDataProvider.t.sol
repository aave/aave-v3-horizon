// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {DeployLiquidationDataProvider} from '../../scripts/misc/DeployLiquidationDataProvider.sol';
import {ILiquidationDataProvider} from '../../src/contracts/helpers/interfaces/ILiquidationDataProvider.sol';

contract DeployLiquidationDataProviderTest is Test {
  DeployLiquidationDataProvider internal deployLiquidationDataProvider;
  ILiquidationDataProvider internal liquidationDataProvider;

  function setUp() public {
    deployLiquidationDataProvider = new DeployLiquidationDataProvider();
    liquidationDataProvider = ILiquidationDataProvider(deployLiquidationDataProvider.run());
  }

  function test_deployLiquidationDataProvider() public {
    assertEq(address(liquidationDataProvider.POOL()), deployLiquidationDataProvider.POOL());
    assertEq(
      address(liquidationDataProvider.ADDRESSES_PROVIDER()),
      deployLiquidationDataProvider.ADDRESSES_PROVIDER()
    );
  }
}
