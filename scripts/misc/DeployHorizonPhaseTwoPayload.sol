// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveV3HorizonEthereum} from 'tests/horizon/utils/AaveV3HorizonEthereum.sol';
import {HorizonPhaseTwoListing} from 'src/deployments/inputs/HorizonPhaseTwoListing.sol';
import {AaveV3HelpersBatchOne} from 'src/deployments/projects/aave-v3-batched/batches/AaveV3HelpersBatchOne.sol';
import {AaveV3ConfigEngine} from 'src/contracts/extensions/v3-config-engine/AaveV3ConfigEngine.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployHorizonPhaseTwoPayload is Script {
  function run() public returns (address) {
    vm.startBroadcast();
    AaveV3HelpersBatchOne helpersBatchOne = new AaveV3HelpersBatchOne(
      AaveV3HorizonEthereum.POOL,
      AaveV3HorizonEthereum.POOL_CONFIGURATOR,
      AaveV3HorizonEthereum.DEFAULT_INTEREST_RATE_STRATEGY,
      AaveV3HorizonEthereum.AAVE_ORACLE,
      AaveV3HorizonEthereum.REWARDS_CONTROLLER,
      AaveV3HorizonEthereum.REVENUE_SPLITTER,
      AaveV3HorizonEthereum.ATOKEN_IMPLEMENTATION,
      AaveV3HorizonEthereum.VARIABLE_DEBT_TOKEN_IMPLEMENTATION
    );

    HorizonPhaseTwoListing horizonPhaseTwoListing = new HorizonPhaseTwoListing(
      helpersBatchOne.getConfigEngineReport().configEngine
    );
    vm.stopBroadcast();

    return address(horizonPhaseTwoListing);
  }
}
