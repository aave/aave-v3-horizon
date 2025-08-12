// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from '../../src/contracts/dependencies/openzeppelin/contracts/Ownable.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {HorizonInput} from '../../src/deployments/inputs/HorizonInput.sol';
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
    HorizonDeployment memory deployment_,
    address poolAdmin_,
    MarketConfig memory config_
  ) internal {
    poolAddressesProvider = IPoolAddressesProvider(deployment_.poolAddressesProvider);
    poolAddressesProviderRegistry = IPoolAddressesProviderRegistry(
      deployment_.poolAddressesProviderRegistry
    );
    aaveOracle = IAaveOracle(deployment_.aaveOracle);
    wrappedTokenGateway = IWrappedTokenGatewayV3(deployment_.wrappedTokenGateway);
    poolProxy = IPool(deployment_.poolProxy);
    treasury = ICollector(deployment_.treasury);
    revenueSplitter = IRevenueSplitter(deployment_.revenueSplitter);
    defaultInterestRateStrategy = IDefaultInterestRateStrategyV2(
      deployment_.defaultInterestRateStrategy
    );
    emissionManager = IEmissionManager(deployment_.emissionManager);
    rewardsControllerProxy = IRewardsController(deployment_.rewardsControllerProxy);
    poolAdmin = poolAdmin_;
    config = config_;
  }

  function test_HorizonInput() public view {
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

  function test_RewardsController() public view {
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
//   function setUp() public virtual override {
//     super.setUp();

//     HorizonDeployment memory deployment = HorizonDeployment({
//       poolAddressesProvider: 0x5D39E06b825C1F2B80bf2756a73e28eFAA128ba0,
//       poolAddressesProviderRegistry: 0xE35Ee1C82fdf6524834e1Ef6Af7820bf6B1fbf0D,
//       aaveOracle: 0x985BcfAB7e0f4EF2606CC5b64FC1A16311880442,
//       wrappedTokenGateway: 0x973195fB8F67F5B0afe7beDB2A02cec829d89991,
//       poolProxy: 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8,
//       treasury: 0x0B4e1dE1300D6C0a6c7Fbec63823281aCafeE0Cf,
//       revenueSplitter: 0xE5E6091073a9EcaCD8611d0D4A843464ebf3D2F8,
//       defaultInterestRateStrategy: 0x87593272C06f4FC49EC2942eBda0972d2F1Ab521,
//       emissionManager: 0xC2201708289b2C6A1d461A227A7E5ee3e7fE9A2F,
//       rewardsControllerProxy: 0x1D5D386a90CEA8AcEa9fa75389e97CF5F1AE21D3
//     });

//     (Roles memory roles, MarketConfig memory config, ,) = _getMarketInput(address(0));
//     initEnvironment(deployment, roles.poolAdmin, config);
//   }
// }
