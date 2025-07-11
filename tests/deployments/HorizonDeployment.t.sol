// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test, console2 as console} from 'forge-std/Test.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import {MarketReport, ContractsReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {MarketReportUtils} from '../../src/deployments/contracts/utilities/MarketReportUtils.sol';
import {HorizonInput} from '../../src/deployments/inputs/HorizonInput.sol';
import {DeployAaveV3MarketBatchedBase} from '../../scripts/misc/DeployAaveV3MarketBatchedBase.sol';
import {Roles, MarketConfig, DeployFlags, MarketReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {MarketInput} from '../../src/deployments/inputs/MarketInput.sol';

contract ExposedHorizonInput is HorizonInput {
    function getMarketInput(address sender) external pure returns (Roles memory roles, MarketConfig memory config, DeployFlags memory flags, MarketReport memory report) {
        return _getMarketInput(sender);
    }
}

contract TestHorizonInput is MarketInput {
    address public immutable testDeployer;
    ExposedHorizonInput public horizonInput;

    constructor(address deployer_) {
        testDeployer = deployer_;
        horizonInput = new ExposedHorizonInput();
    }

    function _getMarketInput(address sender) internal pure override returns (Roles memory roles, MarketConfig memory config, DeployFlags memory flags, MarketReport memory report) {
        return _cast(_getMarketInputView)(sender);
    }

    function _getMarketInputView(address sender) internal view returns (Roles memory roles, MarketConfig memory config, DeployFlags memory flags, MarketReport memory report) {
        roles = Roles({
            marketOwner: testDeployer,
            poolAdmin: testDeployer,
            emergencyAdmin: testDeployer,
            rwaATokenManagerAdmin: testDeployer
        });
        (, config, flags, report) = horizonInput.getMarketInput(sender);
    }

    function _cast(
        function(address sender) view returns (Roles memory, MarketConfig memory, DeployFlags memory, MarketReport memory) f
    ) internal pure returns (function(address sender) pure returns (Roles memory, MarketConfig memory, DeployFlags memory, MarketReport memory) f2) {
        assembly {
        f2 := f
        }
    }
}

contract TestDefault is DeployAaveV3MarketBatchedBase, TestHorizonInput {
    constructor(address deployer) TestHorizonInput(deployer) {}
}

contract HorizonDeploymentTest is Test {
    MarketReport internal marketReport;
    ContractsReport internal contracts;

    function setUp() public {
        console.log('deployer', address(this));
        Default defaultContract = Default(address(new TestDefault(address(this))));
        string memory reportFilePath = defaultContract.run();

        marketReport = abi.decode(vm.parseJson(reportFilePath), (MarketReport));
        contracts = MarketReportUtils.toContractsReport(marketReport);
    }

    function test_metadata() public {
        assertEq(contracts.poolAddressesProvider.getMarketId(), 'Horizon RWA Market');
    }
}