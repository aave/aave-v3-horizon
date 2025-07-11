// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MarketReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {HorizonPhaseOneListing} from '../../src/deployments/inputs/HorizonPhaseOneListing.sol';
import {Script} from 'forge-std/Script.sol';

contract ConfigureHorizonPhaseOne is Script {
    function run(string memory reportPath) public {
        MarketReport memory report = abi.decode(vm.parseJson(reportPath), (MarketReport));

        // Configure Horizon Phase One Listing
        vm.startBroadcast();
        HorizonPhaseOneListing horizonInitialListing = new HorizonPhaseOneListing(report);
        horizonInitialListing.ACL_MANAGER().addPoolAdmin(address(horizonInitialListing));
        horizonInitialListing.execute();
        vm.stopBroadcast();
    }
}