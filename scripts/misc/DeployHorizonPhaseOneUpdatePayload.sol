// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {HorizonPhaseOneUpdate} from '../../src/deployments/inputs/HorizonPhaseOneUpdate.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployHorizonPhaseOneUpdatePayload is Script {
  address public constant CONFIG_ENGINE = 0x366D1e3F41Ad5CC699bb8FC0B41323C68d895E2c; // horizon

  function run() public returns (address) {
    vm.startBroadcast();
    HorizonPhaseOneUpdate horizonPhaseOneUpdate = new HorizonPhaseOneUpdate(CONFIG_ENGINE);
    vm.stopBroadcast();

    return address(horizonPhaseOneUpdate);
  }
}
