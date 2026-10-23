// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveV3EthereumHorizonCustom} from 'tests/horizon/utils/AaveV3EthereumHorizonCustom.sol';
import {HorizonPhaseTwoListing} from 'src/deployments/inputs/HorizonPhaseTwoListing.sol';
import {AaveV3HelpersBatchOne} from 'src/deployments/projects/aave-v3-batched/batches/AaveV3HelpersBatchOne.sol';
import {AaveV3ConfigEngine} from 'src/contracts/extensions/v3-config-engine/AaveV3ConfigEngine.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployHorizonPhaseTwoPayload is Script {
  function run() public returns (address, address) {
    vm.startBroadcast();
    AaveV3HelpersBatchOne helpersBatchOne = new AaveV3HelpersBatchOne(
      AaveV3EthereumHorizonCustom.POOL,
      AaveV3EthereumHorizonCustom.POOL_CONFIGURATOR,
      AaveV3EthereumHorizonCustom.DEFAULT_INTEREST_RATE_STRATEGY,
      AaveV3EthereumHorizonCustom.AAVE_ORACLE,
      AaveV3EthereumHorizonCustom.REWARDS_CONTROLLER,
      AaveV3EthereumHorizonCustom.REVENUE_SPLITTER,
      AaveV3EthereumHorizonCustom.ATOKEN_IMPL,
      AaveV3EthereumHorizonCustom.VARIABLE_DEBT_TOKEN_IMPL
    );

    HorizonPhaseTwoListing horizonPhaseTwoListing = new HorizonPhaseTwoListing(
      helpersBatchOne.getConfigEngineReport().configEngine
    );
    vm.stopBroadcast();

    return (address(helpersBatchOne), address(horizonPhaseTwoListing));
  }
}
