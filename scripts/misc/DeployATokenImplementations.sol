// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
  AaveV3TokensProcedure
} from '../../src/deployments/contracts/procedures/AaveV3TokensProcedure.sol';
import {ATokenInstance} from '../../src/contracts/instances/ATokenInstance.sol';
import {RwaATokenInstance} from '../../src/contracts/instances/RwaATokenInstance.sol';
import {AaveV3HorizonEthereum} from '../../tests/horizon/utils/AaveV3HorizonEthereum.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployATokenImplementations is Script, AaveV3TokensProcedure {
  function run() public returns (address, address) {
    vm.startBroadcast();
    (address aToken, address rwaAToken) = _deployAaveV3ATokensImplementations(
      AaveV3HorizonEthereum.POOL
    );
    vm.stopBroadcast();
    return (aToken, rwaAToken);
  }
}
