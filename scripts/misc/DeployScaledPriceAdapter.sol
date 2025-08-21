// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ScaledPriceAdapter} from '../../src/contracts/extensions/price-adapters/ScaledPriceAdapter.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployScaledPriceAdapter is Script {
  function run(address source) public returns (address) {
    vm.startBroadcast();
    ScaledPriceAdapter scaledPriceAdapter = new ScaledPriceAdapter(source);
    vm.stopBroadcast();
    return address(scaledPriceAdapter);
  }
}
