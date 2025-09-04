// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {LiquidationDataProvider} from '../../src/contracts/helpers/LiquidationDataProvider.sol';
import {Script} from 'forge-std/Script.sol';

contract DeployLiquidationDataProvider is Script {
  address public constant POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
  address public constant ADDRESSES_PROVIDER = 0x5D39E06b825C1F2B80bf2756a73e28eFAA128ba0;

  function run() public returns (address) {
    vm.startBroadcast();
    LiquidationDataProvider liquidationDataProvider = new LiquidationDataProvider(
      POOL,
      ADDRESSES_PROVIDER
    );
    vm.stopBroadcast();
    return address(liquidationDataProvider);
  }
}
