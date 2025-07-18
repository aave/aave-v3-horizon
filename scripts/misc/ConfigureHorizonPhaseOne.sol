// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MarketReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {HorizonPhaseOneListing} from '../../src/deployments/inputs/HorizonPhaseOneListing.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {DeployUtils} from '../../src/deployments/contracts/utilities/DeployUtils.sol';
import {HorizonInput} from '../../src/deployments/inputs/HorizonInput.sol';
import {Script} from 'forge-std/Script.sol';

contract ConfigureHorizonPhaseOne is Script, DeployUtils, HorizonInput {
  function run(string memory reportPath) public returns (address) {
    IMetadataReporter metadataReporter = IMetadataReporter(
      _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    );
    MarketReport memory report = metadataReporter.parseMarketReport(reportPath);

    vm.startBroadcast();
    HorizonPhaseOneListing horizonInitialListing = new HorizonPhaseOneListing(report);
    vm.stopBroadcast();

    return address(horizonInitialListing);
  }
}
