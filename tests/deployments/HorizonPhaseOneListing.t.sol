// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/contracts/protocol/libraries/types/DataTypes.sol';
import {MarketReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import {DeployHorizonPhaseOnePayload} from '../../scripts/misc/DeployHorizonPhaseOnePayload.sol';
import {ReserveConfiguration} from '../../src/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {IRevenueSplitter} from '../../src/contracts/treasury/IRevenueSplitter.sol';
import {IDefaultInterestRateStrategyV2} from '../../src/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {IERC20Detailed} from '../../src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {AggregatorInterface} from '../../src/contracts/dependencies/chainlink/AggregatorInterface.sol';
import {IScaledPriceAdapter} from '../../src/contracts/interfaces/IScaledPriceAdapter.sol';
import {IAaveOracle} from '../../src/contracts/interfaces/IAaveOracle.sol';
import {IACLManager} from '../../src/contracts/interfaces/IACLManager.sol';
import {IAToken} from '../../src/contracts/interfaces/IAToken.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {Errors} from '../../src/contracts/protocol/libraries/helpers/Errors.sol';
import {ProxyHelpers} from '../utils/ProxyHelpers.sol';

abstract contract HorizonListingBaseTest is Test {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  IPool internal pool;
  IRevenueSplitter internal revenueSplitter;
  IDefaultInterestRateStrategyV2 internal defaultInterestRateStrategy;
  address internal aTokenImpl;
  address internal rwaATokenImpl;
  address internal variableDebtTokenImpl;

  struct TokenListingParams {
    bool isGho;
    bool isRwa;
    bool hasPriceAdapter;
    address underlyingPiceFeed; // not the scaled adapter (if any)
    string aTokenName;
    string aTokenSymbol;
    string variableDebtTokenName;
    string variableDebtTokenSymbol;
    uint256 supplyCap;
    uint256 borrowCap;
    uint256 reserveFactor;
    bool enabledToBorrow;
    bool borrowableInIsolation;
    bool withSiloedBorrowing;
    bool flashloanable;
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    uint256 debtCeiling;
    uint256 liqProtocolFee;
    IDefaultInterestRateStrategyV2.InterestRateDataRay interestRateData;
  }

  function initEnvironment(
    address pool_,
    address revenueSplitter_,
    address defaultInterestRateStrategy_,
    address aTokenImpl_,
    address rwaATokenImpl_,
    address variableDebtTokenImpl_
  ) internal virtual {
    pool = IPool(pool_);
    revenueSplitter = IRevenueSplitter(revenueSplitter_);
    defaultInterestRateStrategy = IDefaultInterestRateStrategyV2(defaultInterestRateStrategy_);
    aTokenImpl = aTokenImpl_;
    rwaATokenImpl = rwaATokenImpl_;
    variableDebtTokenImpl = variableDebtTokenImpl_;
  }

  function getListingExecutor() internal view virtual returns (address);

  function check_listingExecutor() internal {
    IACLManager aclManager = IACLManager(pool.ADDRESSES_PROVIDER().getACLManager());
    address listingExecutor = getListingExecutor();
    assertFalse(
      aclManager.isPoolAdmin(listingExecutor),
      'listingExecutor should not be pool admin'
    );
    assertFalse(
      aclManager.isEmergencyAdmin(listingExecutor),
      'listingExecutor should not be emergency admin'
    );
    assertTrue(
      aclManager.isAssetListingAdmin(listingExecutor),
      'listingExecutor should be asset listing admin'
    );
    assertTrue(aclManager.isRiskAdmin(listingExecutor), 'listingExecutor should be risk admin');
  }

  function test_getConfiguration(address token, TokenListingParams memory params) private {
    DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(token);
    assertEq(config.getSupplyCap(), params.supplyCap, 'supplyCap');
    assertEq(config.getBorrowCap(), params.borrowCap, 'borrowCap');
    assertEq(config.getIsVirtualAccActive(), !params.isGho, 'isVirtualAccActive');
    assertEq(config.getBorrowingEnabled(), params.enabledToBorrow, 'borrowingEnabled');
    assertEq(
      config.getBorrowableInIsolation(),
      params.borrowableInIsolation,
      'borrowableInIsolation'
    );
    assertEq(config.getSiloedBorrowing(), params.withSiloedBorrowing, 'siloedBorrowing');
    assertEq(config.getFlashLoanEnabled(), params.flashloanable, 'flashloanable');
    assertEq(config.getReserveFactor(), params.reserveFactor, 'reserveFactor');
    assertEq(config.getLtv(), params.ltv, 'ltv');
    assertEq(config.getLiquidationThreshold(), params.liquidationThreshold, 'liquidationThreshold');
    assertEq(config.getLiquidationBonus(), params.liquidationBonus, 'liquidationBonus');
    assertEq(config.getDebtCeiling(), params.debtCeiling, 'debtCeiling');
    assertEq(config.getLiquidationProtocolFee(), params.liqProtocolFee, 'liqProtocolFee');
    assertEq(config.getPaused(), true, 'paused');
  }

  function test_interestRateStrategy(address token, TokenListingParams memory params) private {
    assertEq(
      pool.getReserveData(token).interestRateStrategyAddress,
      address(defaultInterestRateStrategy),
      'interestRateStrategyAddress'
    );
    assertEq(defaultInterestRateStrategy.getInterestRateData(token), params.interestRateData);
  }

  function test_aToken(address token, TokenListingParams memory params) private {
    address aToken = pool.getReserveAToken(token);
    assertEq(IERC20Detailed(aToken).name(), params.aTokenName, 'aTokenName');
    assertEq(IERC20Detailed(aToken).symbol(), params.aTokenSymbol, 'aTokenSymbol');
    assertEq(
      IAToken(aToken).RESERVE_TREASURY_ADDRESS(),
      address(revenueSplitter),
      'reserveTreasuryAddress'
    );

    address currentATokenImpl = ProxyHelpers.getInitializableAdminUpgradeabilityProxyImplementation(
      vm,
      aToken
    );
    if (params.isRwa) {
      assertEq(currentATokenImpl, rwaATokenImpl, 'rwaATokenImpl');
      vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
      IAToken(aToken).approve(address(0), 0);
    } else {
      assertEq(currentATokenImpl, aTokenImpl, 'aTokenImpl');
      IAToken(aToken).approve(makeAddr('randomAddress'), 1);
    }
  }

  function test_variableDebtToken(address token, TokenListingParams memory params) private {
    address variableDebtToken = pool.getReserveVariableDebtToken(token);
    assertEq(
      IERC20Detailed(variableDebtToken).name(),
      params.variableDebtTokenName,
      'variableDebtTokenName'
    );
    assertEq(
      IERC20Detailed(variableDebtToken).symbol(),
      params.variableDebtTokenSymbol,
      'variableDebtTokenSymbol'
    );
    assertEq(
      ProxyHelpers.getInitializableAdminUpgradeabilityProxyImplementation(vm, variableDebtToken),
      variableDebtTokenImpl,
      'variableDebtTokenImpl'
    );
  }

  function test_priceFeed(address token, TokenListingParams memory params) private {
    IAaveOracle oracle = IAaveOracle(pool.ADDRESSES_PROVIDER().getPriceOracle());

    AggregatorInterface oracleSource = AggregatorInterface(oracle.getSourceOfAsset(token));
    assertEq(oracleSource.decimals(), 8, 'oracleSource.decimals');

    AggregatorInterface priceFeed = oracleSource;
    if (params.hasPriceAdapter) {
      priceFeed = AggregatorInterface(IScaledPriceAdapter(address(oracleSource)).source());
      assertEq(
        priceFeed.latestAnswer() * int256(10 ** (8 - priceFeed.decimals())),
        oracleSource.latestAnswer(),
        'priceFeed.latestAnswer'
      );
    }

    assertEq(address(priceFeed), params.underlyingPiceFeed, 'priceFeed');
  }

  function test_listing(address token, TokenListingParams memory params) internal {
    test_getConfiguration(token, params);
    test_interestRateStrategy(token, params);
    test_aToken(token, params);
    test_variableDebtToken(token, params);
    test_priceFeed(token, params);
  }

  function assertEq(
    IDefaultInterestRateStrategyV2.InterestRateDataRay memory a,
    IDefaultInterestRateStrategyV2.InterestRateDataRay memory b
  ) internal {
    assertEq(
      a.optimalUsageRatio,
      b.optimalUsageRatio,
      'assertEq(interestRateData): optimalUsageRatio'
    );
    assertEq(
      a.baseVariableBorrowRate,
      b.baseVariableBorrowRate,
      'assertEq(interestRateData): baseVariableBorrowRate'
    );
    assertEq(
      a.variableRateSlope1,
      b.variableRateSlope1,
      'assertEq(interestRateData): variableRateSlope1'
    );
    assertEq(
      a.variableRateSlope2,
      b.variableRateSlope2,
      'assertEq(interestRateData): variableRateSlope2'
    );
    assertEq(abi.encode(a), abi.encode(b), 'assertEq(interestRateData): all fields');
  }
}

abstract contract HorizonListingMainnetTest is HorizonListingBaseTest {
  address internal constant ADVANCED_MULTISIG = 0x4444dE8a4AA3401a3AEC584de87B0f21E3e601CA;
  address internal constant LISTING_EXECUTOR = 0xf046907a4371F7F027113bf751F3347459a08b71;

  address internal constant GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant GHO_PRICE_FEED = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;

  address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

  address internal constant RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
  address internal constant RLUSD_PRICE_FEED = 0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A;

  address internal constant USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
  address internal constant USTB_UNDERLYING_PRICE_FEED = 0x289B5036cd942e619E1Ee48670F98d214E745AAC;

  address internal constant USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
  address internal constant USCC_UNDERLYING_PRICE_FEED = 0xAfFd8F5578E8590665de561bdE9E7BAdb99300d9;

  address internal constant USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
  address internal constant USYC_UNDERLYING_PRICE_FEED = 0xE8E65Fb9116875012F5990Ecaab290B3531DbeB9;

  TokenListingParams internal GHO_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA GHO',
      aTokenSymbol: 'aHRwaGHO',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt GHO',
      variableDebtTokenSymbol: 'variableDebtHRwaGHO',
      isGho: true,
      isRwa: false,
      hasPriceAdapter: false,
      underlyingPiceFeed: GHO_PRICE_FEED,
      supplyCap: 5_000_000,
      borrowCap: 4_000_000,
      reserveFactor: 15_00,
      enabledToBorrow: true,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: true,
      ltv: 0,
      liquidationThreshold: 0,
      liquidationBonus: 0,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.92e27,
        baseVariableBorrowRate: 0.035e27,
        variableRateSlope1: 0.0125e27,
        variableRateSlope2: 0.35e27
      })
    });

  TokenListingParams internal USDC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USDC',
      aTokenSymbol: 'aHRwaUSDC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USDC',
      variableDebtTokenSymbol: 'variableDebtHRwaUSDC',
      isGho: false,
      isRwa: false,
      hasPriceAdapter: false,
      underlyingPiceFeed: USDC_PRICE_FEED,
      supplyCap: 5_000_000,
      borrowCap: 4_000_000,
      reserveFactor: 15_00,
      enabledToBorrow: true,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: true,
      ltv: 0,
      liquidationThreshold: 0,
      liquidationBonus: 0,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.925e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0.055e27,
        variableRateSlope2: 0.35e27
      })
    });

  TokenListingParams internal RLUSD_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA RLUSD',
      aTokenSymbol: 'aHRwaRLUSD',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt RLUSD',
      variableDebtTokenSymbol: 'variableDebtHRwaRLUSD',
      isGho: false,
      isRwa: false,
      hasPriceAdapter: false,
      underlyingPiceFeed: RLUSD_PRICE_FEED,
      supplyCap: 5_000_000,
      borrowCap: 4_000_000,
      reserveFactor: 15_00,
      enabledToBorrow: true,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: true,
      ltv: 0,
      liquidationThreshold: 0,
      liquidationBonus: 0,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.8e27,
        baseVariableBorrowRate: 0.04e27,
        variableRateSlope1: 0.025e27,
        variableRateSlope2: 0.5e27
      })
    });

  TokenListingParams internal USTB_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USTB',
      aTokenSymbol: 'aHRwaUSTB',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USTB',
      variableDebtTokenSymbol: 'variableDebtHRwaUSTB',
      isGho: false,
      isRwa: true,
      hasPriceAdapter: true,
      underlyingPiceFeed: USTB_UNDERLYING_PRICE_FEED,
      supplyCap: 3_000_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 75_00,
      liquidationThreshold: 80_00,
      liquidationBonus: 112_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  TokenListingParams internal USCC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USCC',
      aTokenSymbol: 'aHRwaUSCC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USCC',
      variableDebtTokenSymbol: 'variableDebtHRwaUSCC',
      isGho: false,
      isRwa: true,
      hasPriceAdapter: true,
      underlyingPiceFeed: USCC_UNDERLYING_PRICE_FEED,
      supplyCap: 3_000_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 75_00,
      liquidationThreshold: 80_00,
      liquidationBonus: 112_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  TokenListingParams internal USYC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USYC',
      aTokenSymbol: 'aHRwaUSYC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USYC',
      variableDebtTokenSymbol: 'variableDebtHRwaUSYC',
      isGho: false,
      isRwa: true,
      hasPriceAdapter: true,
      underlyingPiceFeed: USYC_UNDERLYING_PRICE_FEED,
      supplyCap: 3_000_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 75_00,
      liquidationThreshold: 80_00,
      liquidationBonus: 112_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  function setUp() public virtual {
    vm.createSelectFork('mainnet');
    (
      address _pool,
      address _revenueSplitter,
      address _defaultInterestRateStrategy,
      address _aToken,
      address _rwaAToken,
      address _variableDebtToken
    ) = loadDeployment();
    initEnvironment(
      _pool,
      _revenueSplitter,
      _defaultInterestRateStrategy,
      _aToken,
      _rwaAToken,
      _variableDebtToken
    );
  }

  function loadDeployment()
    internal
    virtual
    returns (address, address, address, address, address, address);

  function getListingExecutor() internal pure override returns (address) {
    return LISTING_EXECUTOR;
  }

  function test_listingExecutor() public {
    check_listingExecutor();
  }

  function test_listing_GHO() public {
    test_listing(GHO_ADDRESS, GHO_TOKEN_LISTING_PARAMS);
  }

  function test_listing_USDC() public {
    test_listing(USDC_ADDRESS, USDC_TOKEN_LISTING_PARAMS);
  }

  function test_listing_RLUSD() public {
    test_listing(RLUSD_ADDRESS, RLUSD_TOKEN_LISTING_PARAMS);
  }

  function test_listing_USTB() public {
    test_listing(USTB_ADDRESS, USTB_TOKEN_LISTING_PARAMS);
  }

  function test_listing_USCC() public {
    test_listing(USCC_ADDRESS, USCC_TOKEN_LISTING_PARAMS);
  }

  function test_listing_USYC() public {
    test_listing(USYC_ADDRESS, USYC_TOKEN_LISTING_PARAMS);
  }
}
contract HorizonPhaseOneListingTest is HorizonListingMainnetTest, Default {
  function loadDeployment()
    internal
    override
    returns (address, address, address, address, address, address)
  {
    string memory reportFilePath = run();

    IMetadataReporter metadataReporter = IMetadataReporter(
      _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    );
    MarketReport memory marketReport = metadataReporter.parseMarketReport(reportFilePath);

    address horizonPhaseOneListing = new DeployHorizonPhaseOnePayload().run(reportFilePath);

    vm.prank(ADVANCED_MULTISIG);
    (bool success, ) = getListingExecutor().call(
      abi.encodeWithSignature(
        'executeTransaction(address,uint256,string,bytes,bool)',
        address(horizonPhaseOneListing), // target
        0, // value
        'execute()', // signature
        '', // data
        true // withDelegatecall
      )
    );
    require(success, 'Failed to execute transaction');

    return (
      marketReport.poolProxy,
      marketReport.revenueSplitter,
      marketReport.defaultInterestRateStrategy,
      marketReport.aToken,
      marketReport.rwaAToken,
      marketReport.variableDebtToken
    );
  }
}

// contract HorizonListingForkTest is HorizonListingMainnetTest {
//   function loadDeployment() internal override returns (address, address, address, address, address, address) {
//     address _pool = ; // todo
//     address _revenueSplitter = ; // todo
//     address _defaultInterestRateStrategy = ; // todo
//     address _aToken = ; // todo
//     address _rwaAToken = ; // todo
//     address _variableDebtToken = ; // todo

//     return (_pool, _revenueSplitter, _defaultInterestRateStrategy, _aToken, _rwaAToken, _variableDebtToken);
//   }
// }
