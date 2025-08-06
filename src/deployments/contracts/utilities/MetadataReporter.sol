// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';
import '../../interfaces/IMarketReportTypes.sol';
import {IMetadataReporter} from '../../interfaces/IMetadataReporter.sol';

contract MetadataReporter is IMetadataReporter {
  using stdJson for string;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  function writeJsonReportMarket(
    MarketReport memory report
  ) external returns (string memory filePath) {
    string memory factoryV3Commit;
    string memory factoryV3Branch;

    string memory timestamp = getTimestamp();
    (factoryV3Commit, factoryV3Branch) = getGitModuleVersion();

    string memory jsonReport = 'market-report';

    vm.serializeString(jsonReport, 'aave-v3-factory-commit', factoryV3Commit);
    vm.serializeString(jsonReport, 'aave-v3-factory-branch', factoryV3Branch);
    vm.serializeAddress(
      jsonReport,
      'poolAddressesProviderRegistry',
      report.poolAddressesProviderRegistry
    );
    vm.serializeAddress(jsonReport, 'poolAddressesProvider', report.poolAddressesProvider);
    vm.serializeAddress(jsonReport, 'poolProxy', report.poolProxy);
    vm.serializeAddress(jsonReport, 'poolImplementation', report.poolImplementation);
    vm.serializeAddress(jsonReport, 'poolConfiguratorProxy', report.poolConfiguratorProxy);
    vm.serializeAddress(
      jsonReport,
      'poolConfiguratorImplementation',
      report.poolConfiguratorImplementation
    );
    vm.serializeAddress(jsonReport, 'aaveOracle', report.aaveOracle);
    vm.serializeAddress(jsonReport, 'treasury', report.treasury);
    vm.serializeAddress(jsonReport, 'revenueSplitter', report.revenueSplitter);
    vm.serializeAddress(jsonReport, 'dustBin', report.dustBin);
    vm.serializeAddress(jsonReport, 'wrappedTokenGateway', report.wrappedTokenGateway);
    vm.serializeAddress(jsonReport, 'walletBalanceProvider', report.walletBalanceProvider);
    vm.serializeAddress(jsonReport, 'uiIncentiveDataProvider', report.uiIncentiveDataProvider);
    vm.serializeAddress(jsonReport, 'uiPoolDataProvider', report.uiPoolDataProvider);
    vm.serializeAddress(jsonReport, 'treasuryImplementation', report.treasuryImplementation);
    vm.serializeAddress(jsonReport, 'emptyImplementation', report.emptyImplementation);
    vm.serializeAddress(jsonReport, 'l2Encoder', report.l2Encoder);
    vm.serializeAddress(jsonReport, 'aToken', report.aToken);
    vm.serializeAddress(jsonReport, 'rwaAToken', report.rwaAToken);
    vm.serializeAddress(jsonReport, 'variableDebtToken', report.variableDebtToken);
    vm.serializeAddress(jsonReport, 'rwaATokenManager', report.rwaATokenManager);
    vm.serializeAddress(jsonReport, 'emissionManager', report.emissionManager);
    vm.serializeAddress(
      jsonReport,
      'rewardsControllerImplementation',
      report.rewardsControllerImplementation
    );
    vm.serializeAddress(jsonReport, 'rewardsControllerProxy', report.rewardsControllerProxy);
    vm.serializeAddress(jsonReport, 'aclManager', report.aclManager);
    vm.serializeAddress(jsonReport, 'protocolDataProvider', report.protocolDataProvider);

    vm.serializeAddress(
      jsonReport,
      'paraSwapLiquiditySwapAdapter',
      report.paraSwapLiquiditySwapAdapter
    );
    vm.serializeAddress(
      jsonReport,
      'paraSwapWithdrawSwapAdapter',
      report.paraSwapWithdrawSwapAdapter
    );
    vm.serializeAddress(
      jsonReport,
      'defaultInterestRateStrategy',
      report.defaultInterestRateStrategy
    );
    vm.serializeAddress(jsonReport, 'priceOracleSentinel', report.priceOracleSentinel);
    vm.serializeAddress(jsonReport, 'configEngine', report.configEngine);
    vm.serializeAddress(
      jsonReport,
      'staticATokenFactoryImplementation',
      report.staticATokenFactoryImplementation
    );
    vm.serializeAddress(jsonReport, 'staticATokenFactoryProxy', report.staticATokenFactoryProxy);
    vm.serializeAddress(
      jsonReport,
      'staticATokenImplementation',
      report.staticATokenImplementation
    );
    vm.serializeAddress(jsonReport, 'transparentProxyFactory', report.transparentProxyFactory);

    string memory output = vm.serializeAddress(
      jsonReport,
      'paraSwapRepayAdapter',
      report.paraSwapRepayAdapter
    );

    filePath = string.concat('./reports/', timestamp, '-market-deployment.json');
    vm.writeJson(output, filePath);
  }

  function parseMarketReport(
    string memory reportFilePath
  ) external view returns (MarketReport memory report) {
    string memory json = vm.readFile(reportFilePath);
    report.poolAddressesProviderRegistry = json.readAddress('.poolAddressesProviderRegistry');
    report.poolAddressesProvider = json.readAddress('.poolAddressesProvider');
    report.poolProxy = json.readAddress('.poolProxy');
    report.poolImplementation = json.readAddress('.poolImplementation');
    report.poolConfiguratorProxy = json.readAddress('.poolConfiguratorProxy');
    report.poolConfiguratorImplementation = json.readAddress('.poolConfiguratorImplementation');
    report.protocolDataProvider = json.readAddress('.protocolDataProvider');
    report.aaveOracle = json.readAddress('.aaveOracle');
    report.defaultInterestRateStrategy = json.readAddress('.defaultInterestRateStrategy');
    report.priceOracleSentinel = json.readAddress('.priceOracleSentinel');
    report.aclManager = json.readAddress('.aclManager');
    report.treasury = json.readAddress('.treasury');
    report.treasuryImplementation = json.readAddress('.treasuryImplementation');
    report.wrappedTokenGateway = json.readAddress('.wrappedTokenGateway');
    report.walletBalanceProvider = json.readAddress('.walletBalanceProvider');
    report.uiIncentiveDataProvider = json.readAddress('.uiIncentiveDataProvider');
    report.uiPoolDataProvider = json.readAddress('.uiPoolDataProvider');
    report.paraSwapLiquiditySwapAdapter = json.readAddress('.paraSwapLiquiditySwapAdapter');
    report.paraSwapRepayAdapter = json.readAddress('.paraSwapRepayAdapter');
    report.paraSwapWithdrawSwapAdapter = json.readAddress('.paraSwapWithdrawSwapAdapter');
    report.l2Encoder = json.readAddress('.l2Encoder');
    report.aToken = json.readAddress('.aToken');
    report.rwaAToken = json.readAddress('.rwaAToken');
    report.variableDebtToken = json.readAddress('.variableDebtToken');
    report.emissionManager = json.readAddress('.emissionManager');
    report.rewardsControllerImplementation = json.readAddress('.rewardsControllerImplementation');
    report.rewardsControllerProxy = json.readAddress('.rewardsControllerProxy');
    report.configEngine = json.readAddress('.configEngine');
    report.transparentProxyFactory = json.readAddress('.transparentProxyFactory');
    report.staticATokenFactoryImplementation = json.readAddress(
      '.staticATokenFactoryImplementation'
    );
    report.staticATokenFactoryProxy = json.readAddress('.staticATokenFactoryProxy');
    report.staticATokenImplementation = json.readAddress('.staticATokenImplementation');
    report.revenueSplitter = json.readAddress('.revenueSplitter');
    report.dustBin = json.readAddress('.dustBin');
    report.emptyImplementation = json.readAddress('.emptyImplementation');
    report.rwaATokenManager = json.readAddress('.rwaATokenManager');
  }

  function writeJsonReportLibraryBatch1(LibrariesReport memory libraries) external {
    string memory factoryV3Commit;
    string memory factoryV3Branch;

    string memory timestamp = getTimestamp();
    (factoryV3Commit, factoryV3Branch) = getGitModuleVersion();

    string memory jsonReport = 'lib-report-1';

    vm.serializeAddress(jsonReport, 'borrowLogic', libraries.borrowLogic);
    vm.serializeAddress(jsonReport, 'bridgeLogic', libraries.bridgeLogic);
    vm.serializeAddress(jsonReport, 'configuratorLogic', libraries.configuratorLogic);

    string memory output = vm.serializeAddress(jsonReport, 'eModeLogic', libraries.eModeLogic);

    vm.writeJson(output, string.concat('./reports/', timestamp, '-library-1-deployment.json'));
  }

  function writeJsonReportLibraryBatch2(LibrariesReport memory libraries) external {
    string memory factoryV3Commit;
    string memory factoryV3Branch;

    string memory timestamp = getTimestamp();
    (factoryV3Commit, factoryV3Branch) = getGitModuleVersion();

    string memory jsonReport = 'lib-report-2';

    vm.serializeAddress(jsonReport, 'flashLoanLogic', libraries.flashLoanLogic);
    vm.serializeAddress(jsonReport, 'liquidationLogic', libraries.liquidationLogic);
    vm.serializeAddress(jsonReport, 'poolLogic', libraries.poolLogic);

    string memory output = vm.serializeAddress(jsonReport, 'supplyLogic', libraries.supplyLogic);

    vm.writeJson(output, string.concat('./reports/', timestamp, '-library-2-deployment.json'));
  }

  function getTimestamp() public returns (string memory result) {
    string[] memory command = new string[](3);

    command[0] = 'bash';
    command[1] = '-c';
    command[2] = 'response="$(date +%s)"; cast abi-encode "response(string)" $response;';
    bytes memory timestamp = vm.ffi(command);
    (result) = abi.decode(timestamp, (string));

    return result;
  }

  function getGitModuleVersion() public returns (string memory commit, string memory branch) {
    string[] memory commitCommand = new string[](3);
    string[] memory branchCommand = new string[](3);

    commitCommand[0] = 'bash';
    commitCommand[1] = '-c';
    commitCommand[
      2
    ] = 'response="$(echo -n $(git rev-parse HEAD))"; cast abi-encode "response(string)" "$response"';

    bytes memory commitResponse = vm.ffi(commitCommand);

    (commit) = abi.decode(commitResponse, (string));

    branchCommand[0] = 'bash';
    branchCommand[1] = '-c';
    branchCommand[
      2
    ] = 'response="$(echo -n $(git branch --show-current))"; cast abi-encode "response(string)" "$response"';

    bytes memory response = vm.ffi(branchCommand);

    (branch) = abi.decode(response, (string));

    return (commit, branch);
  }
}
