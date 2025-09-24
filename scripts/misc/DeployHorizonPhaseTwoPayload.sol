// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {HorizonPhaseTwoListing} from '../../src/deployments/inputs/HorizonPhaseTwoListing.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployHorizonPhaseTwoPayload is Script {
  function run() public returns (address) {
    vm.startBroadcast();
    HorizonPhaseTwoListing horizonPhaseTwoListing = new HorizonPhaseTwoListing();
    vm.stopBroadcast();

    return address(horizonPhaseTwoListing);
  }
}
