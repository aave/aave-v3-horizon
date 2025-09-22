// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {LiquidationDataProvider} from '../../src/contracts/helpers/LiquidationDataProvider.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployLiquidationDataProvider is Script {
  function run(address pool, address addressesProvider) public returns (address) {
    vm.startBroadcast();
    LiquidationDataProvider liquidationDataProvider = new LiquidationDataProvider(
      pool,
      addressesProvider
    );
    vm.stopBroadcast();
    return address(liquidationDataProvider);
  }
}
