// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from '../../src/contracts/dependencies/openzeppelin/contracts/Ownable.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {Test} from 'forge-std/Test.sol';

abstract contract HorizonDeploymentBaseTest is Test {
  IPoolAddressesProvider internal poolAddressesProvider;
  IPoolAddressesProviderRegistry internal poolAddressesProviderRegistry;
  IAaveOracle internal aaveOracle;
  IWrappedTokenGatewayV3 internal wrappedTokenGateway;
  IPool internal poolProxy;
  ICollector internal treasury;
  IRevenueSplitter internal revenueSplitter;
  IDefaultInterestRateStrategyV2 internal defaultInterestRateStrategy;
  IEmissionManager internal emissionManager;
  IRewardsController internal rewardsControllerProxy;

  address internal poolAdmin;
  MarketConfig internal config;

  struct HorizonDeployment {
    address poolAddressesProvider;
    address poolAddressesProviderRegistry;
    address aaveOracle;
    address wrappedTokenGateway;
    address poolProxy;
    address treasury;
    address revenueSplitter;
    address defaultInterestRateStrategy;
    address emissionManager;
    address rewardsControllerProxy;
  }

  function initEnvironment(
    HorizonDeployment memory deployment,
    address poolAdmin_,
    MarketConfig memory config_
  ) internal {
    poolAddressesProvider = IPoolAddressesProvider(deployment.poolAddressesProvider);
    poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(
      deployment.poolAddressesProviderRegistry
    );
    aaveOracle = IAaveOracle(deployment.aaveOracle);
    wrappedTokenGateway = IWrappedTokenGatewayV3(deployment.wrappedTokenGateway);
    poolProxy = IPool(deployment.poolProxy);
    treasury = ICollector(deployment.treasury);
    revenueSplitter = IRevenueSplitter(deployment.revenueSplitter);
    defaultInterestRateStrategy = IDefaultInterestRateStrategyV2(
      deployment.defaultInterestRateStrategy
    );
    emissionManager = IEmissionManager(deployment.emissionManager);
    rewardsControllerProxy = IRewardsController(deployment.rewardsControllerProxy);
    poolAdmin = poolAdmin_;
    config = config_;
  }

  function test_HorizonInput() public {
    assertEq(poolAddressesProvider.getMarketId(), config.marketId);
    assertEq(
      poolAddressesProviderRegistry.getAddressesProviderAddressById(config.providerId),
      address(poolAddressesProvider)
    );
    assertEq(aaveOracle.BASE_CURRENCY_UNIT(), 10 ** config.oracleDecimals);
    assertEq(address(wrappedTokenGateway.WETH()), config.wrappedNativeToken);
    assertEq(poolProxy.FLASHLOAN_PREMIUM_TOTAL(), config.flashLoanPremiumTotal);
    assertEq(poolProxy.FLASHLOAN_PREMIUM_TO_PROTOCOL(), config.flashLoanPremiumToProtocol);
    assertEq(treasury.isFundsAdmin(poolAdmin), true);
    assertEq(revenueSplitter.RECIPIENT_A(), address(treasury));
    assertEq(revenueSplitter.RECIPIENT_B(), config.treasuryPartner);
    assertEq(revenueSplitter.SPLIT_PERCENTAGE_RECIPIENT_A(), config.treasurySplitPercent);
  }

  function test_RewardsController() public {
    assertEq(rewardsControllerProxy.EMISSION_MANAGER(), address(emissionManager));
    assertEq(Ownable(address(emissionManager)).owner(), poolAdmin);
  }
}

abstract contract HorizonDeploymentMainnetTest is HorizonDeploymentBaseTest {
  function setUp() public virtual {
    vm.createSelectFork('mainnet');
  }
}

contract HorizonDeploymentTest is HorizonDeploymentMainnetTest, Default {
  function setUp() public virtual override {
    super.setUp();

    string memory reportFilePath = run();
    IMetadataReporter metadataReporter = IMetadataReporter(
      _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    );
    MarketReport memory marketReport = metadataReporter.parseMarketReport(reportFilePath);

    HorizonDeployment memory deployment = HorizonDeployment({
      poolAddressesProvider: marketReport.poolAddressesProvider,
      poolAddressesProviderRegistry: marketReport.poolAddressesProviderRegistry,
      aaveOracle: marketReport.aaveOracle,
      wrappedTokenGateway: marketReport.wrappedTokenGateway,
      poolProxy: marketReport.poolProxy,
      treasury: marketReport.treasury,
      revenueSplitter: marketReport.revenueSplitter,
      defaultInterestRateStrategy: marketReport.defaultInterestRateStrategy,
      emissionManager: marketReport.emissionManager,
      rewardsControllerProxy: marketReport.rewardsControllerProxy
    });

    (Roles memory roles, MarketConfig memory config, , ) = _getMarketInput(address(0));
    initEnvironment(deployment, roles.poolAdmin, config);
  }
}

// contract HorizonDeploymentForkTest is HorizonDeploymentMainnetTest, HorizonInput {
//   function setUp() public {
//     super.setUp();

//     HorizonDeployment memory deployment = HorizonDeployment({
//       poolAddressesProvider: , // todo
//       poolAddressesProviderRegistry: , // todo
//       aaveOracle: , // todo
//       wrappedTokenGateway: , // todo
//       poolProxy: , // todo
//       treasury: , // todo
//       revenueSplitter: , // todo
//       defaultInterestRateStrategy: , // todo
//       emissionManager: , // todo
//       rewardsController: , // todo
//     });

//     (Roles memory roles, MarketConfig memory config, ,) = _getMarketInput(address(0));
//     initEnvironment(deployment, roles.poolAdmin, config);
//   }
// }
