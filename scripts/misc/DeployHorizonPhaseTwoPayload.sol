// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveV3EthereumHorizonCustom} from 'tests/horizon/utils/AaveV3EthereumHorizonCustom.sol';
import {AaveV3EthereumHorizon, AaveV3EthereumHorizonAssets} from 'aave-address-book/AaveV3EthereumHorizon.sol';
import {HorizonPhaseTwoListing} from 'src/deployments/inputs/HorizonPhaseTwoListing.sol';
import {AaveV3HelpersBatchOne} from 'src/deployments/projects/aave-v3-batched/batches/AaveV3HelpersBatchOne.sol';
import {AaveV3ConfigEngine} from 'src/contracts/extensions/v3-config-engine/AaveV3ConfigEngine.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployHorizonPhaseTwoPayload is Script {
  function run() public returns (address, address) {
    vm.startBroadcast();
    AaveV3HelpersBatchOne helpersBatchOne = new AaveV3HelpersBatchOne(
      address(AaveV3EthereumHorizon.POOL),
      address(AaveV3EthereumHorizon.POOL_CONFIGURATOR),
      address(AaveV3EthereumHorizonAssets.GHO_INTEREST_RATE_STRATEGY),
      address(AaveV3EthereumHorizon.ORACLE),
      address(AaveV3EthereumHorizon.DEFAULT_INCENTIVES_CONTROLLER),
      address(AaveV3EthereumHorizon.COLLECTOR),
      address(AaveV3EthereumHorizon.DEFAULT_A_TOKEN_IMPL),
      address(AaveV3EthereumHorizon.DEFAULT_VARIABLE_DEBT_TOKEN_IMPL)
    );

    address configEngine = helpersBatchOne.getConfigEngineReport().configEngine;

    HorizonPhaseTwoListing horizonPhaseTwoListing = new HorizonPhaseTwoListing(configEngine);
    vm.stopBroadcast();

    return (configEngine, address(horizonPhaseTwoListing));
  }
}
