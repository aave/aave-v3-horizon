// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/contracts/protocol/libraries/types/DataTypes.sol';
import {MarketReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import {DeployHorizonPhaseOnePayload} from '../../scripts/misc/DeployHorizonPhaseOnePayload.sol';
import {ReserveConfiguration} from '../../src/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {EModeConfiguration} from '../../src/contracts/protocol/libraries/configuration/EModeConfiguration.sol';
import {PercentageMath} from '../../src/contracts/protocol/libraries/math/PercentageMath.sol';
import {IMetadataReporter} from '../../src/deployments/interfaces/IMetadataReporter.sol';
import {IRevenueSplitter} from '../../src/contracts/treasury/IRevenueSplitter.sol';
import {IDefaultInterestRateStrategyV2} from '../../src/contracts/interfaces/IDefaultInterestRateStrategyV2.sol';
import {IERC20Detailed} from '../../src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {IAccessControl} from '../../src/contracts/dependencies/openzeppelin/contracts/IAccessControl.sol';
import {AggregatorInterface} from '../../src/contracts/dependencies/chainlink/AggregatorInterface.sol';
import {IScaledPriceAdapter} from '../../src/contracts/interfaces/IScaledPriceAdapter.sol';
import {IAaveOracle} from '../../src/contracts/interfaces/IAaveOracle.sol';
import {IACLManager} from '../../src/contracts/interfaces/IACLManager.sol';
import {IAToken} from '../../src/contracts/interfaces/IAToken.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from '../../src/contracts/interfaces/IPoolConfigurator.sol';
import {Errors} from '../../src/contracts/protocol/libraries/helpers/Errors.sol';
import {ProxyHelpers} from '../utils/ProxyHelpers.sol';

abstract contract HorizonListingBaseTest is Test {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using EModeConfiguration for uint128;
  using PercentageMath for uint256;

  IPool internal pool;
  IRevenueSplitter internal revenueSplitter;
  IDefaultInterestRateStrategyV2 internal defaultInterestRateStrategy;
  address internal rwaATokenManager;
  address internal aTokenImpl;
  address internal rwaATokenImpl;
  address internal variableDebtTokenImpl;
  address internal poolAdmin;

  address internal alice = makeAddr('alice');
  address internal bob = makeAddr('bob');

  bytes32 internal constant ATOKEN_ADMIN_ROLE = keccak256('ATOKEN_ADMIN');

  struct DeploymentInfo {
    address pool;
    address revenueSplitter;
    address defaultInterestRateStrategy;
    address rwaATokenManager;
    address aTokenImpl;
    address rwaATokenImpl;
    address variableDebtTokenImpl;
    address poolAdmin;
  }

  struct TokenListingParams {
    bool isRwa;
    bool hasPriceAdapter;
    address oracle;
    address underlyingPriceFeed; // if no price adapter, this is the same as oracle
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
    uint256 initialDeposit;
  }

  struct EModeCategoryParams {
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    string label;
    address[] collateralAssets;
    address[] borrowableAssets;
  }

  function loadDeployment() internal virtual returns (DeploymentInfo memory);

  function initEnvironment() internal virtual {
    DeploymentInfo memory deploymentInfo = loadDeployment();
    pool = IPool(deploymentInfo.pool);
    revenueSplitter = IRevenueSplitter(deploymentInfo.revenueSplitter);
    defaultInterestRateStrategy = IDefaultInterestRateStrategyV2(
      deploymentInfo.defaultInterestRateStrategy
    );
    rwaATokenManager = deploymentInfo.rwaATokenManager;
    aTokenImpl = deploymentInfo.aTokenImpl;
    rwaATokenImpl = deploymentInfo.rwaATokenImpl;
    variableDebtTokenImpl = deploymentInfo.variableDebtTokenImpl;
    poolAdmin = deploymentInfo.poolAdmin;
  }

  function OPERATIONAL_MULTISIG_ADDRESS() external view virtual returns (address);
  function EMERGENCY_MULTISIG_ADDRESS() external view virtual returns (address);
  function AAVE_DAO_EXECUTOR_ADDRESS() external view virtual returns (address);
  function LISTING_EXECUTOR_ADDRESS() external view virtual returns (address);
  function DUST_BIN() external view virtual returns (address);

  function check_permissions() internal view {
    test_rwaATokenManager();
    test_listingExecutor(this.LISTING_EXECUTOR_ADDRESS());
    test_operationalMultisig(this.OPERATIONAL_MULTISIG_ADDRESS());
    test_emergencyMultisig(this.EMERGENCY_MULTISIG_ADDRESS());
    test_aaveDaoExecutor(this.AAVE_DAO_EXECUTOR_ADDRESS());
  }

  function test_listing(address token, TokenListingParams memory params) internal {
    test_getConfiguration(token, params);
    test_interestRateStrategy(token, params);
    test_aToken(token, params);
    test_variableDebtToken(token, params);
    test_priceFeed(token, params);
  }

  function test_eMode(uint8 eModeCategory, EModeCategoryParams memory params) internal {
    test_eMode_configuration(eModeCategory, params);
    test_eMode_collateralization(eModeCategory, params);
  }

  function test_rwaATokenManager() internal view {
    address aclManager = pool.ADDRESSES_PROVIDER().getACLManager();
    assertTrue(
      IAccessControl(aclManager).hasRole(ATOKEN_ADMIN_ROLE, rwaATokenManager),
      'rwaATokenManager should be aToken admin'
    );
  }

  function test_listingExecutor(address listingExecutor) private view {
    IACLManager aclManager = IACLManager(pool.ADDRESSES_PROVIDER().getACLManager());
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

  function test_operationalMultisig(address operationalMultisig) private view {
    IACLManager aclManager = IACLManager(pool.ADDRESSES_PROVIDER().getACLManager());
    assertFalse(
      aclManager.isPoolAdmin(operationalMultisig),
      'operationalMultisig should not be pool admin'
    );
    assertFalse(
      aclManager.isEmergencyAdmin(operationalMultisig),
      'operationalMultisig should not be emergency admin'
    );
    assertFalse(
      aclManager.isAssetListingAdmin(operationalMultisig),
      'operationalMultisig should not be asset listing admin'
    );
    assertTrue(
      aclManager.isRiskAdmin(operationalMultisig),
      'operationalMultisig should be risk admin'
    );
  }

  function test_emergencyMultisig(address emergencyMultisig) private view {
    IACLManager aclManager = IACLManager(pool.ADDRESSES_PROVIDER().getACLManager());
    assertTrue(aclManager.isPoolAdmin(emergencyMultisig), 'emergencyMultisig should be pool admin');
    assertTrue(
      aclManager.isEmergencyAdmin(emergencyMultisig),
      'emergencyMultisig should be emergency admin'
    );
    assertFalse(
      aclManager.isAssetListingAdmin(emergencyMultisig),
      'emergencyMultisig should not be asset listing admin'
    );
    assertFalse(
      aclManager.isRiskAdmin(emergencyMultisig),
      'emergencyMultisig should not be risk admin'
    );
  }

  function test_aaveDaoExecutor(address aaveDaoExecutor) private view {
    IACLManager aclManager = IACLManager(pool.ADDRESSES_PROVIDER().getACLManager());
    assertTrue(aclManager.isPoolAdmin(aaveDaoExecutor), 'aaveDaoExecutor should be pool admin');
    assertTrue(
      aclManager.isEmergencyAdmin(aaveDaoExecutor),
      'aaveDaoExecutor should be emergency admin'
    );
    assertFalse(
      aclManager.isAssetListingAdmin(aaveDaoExecutor),
      'aaveDaoExecutor should not be asset listing admin'
    );
    assertFalse(
      aclManager.isRiskAdmin(aaveDaoExecutor),
      'aaveDaoExecutor should not be risk admin'
    );
  }

  function test_getConfiguration(address token, TokenListingParams memory params) private view {
    DataTypes.ReserveConfigurationMap memory config = pool.getConfiguration(token);
    assertEq(config.getSupplyCap(), params.supplyCap, 'supplyCap');
    assertEq(config.getBorrowCap(), params.borrowCap, 'borrowCap');
    assertEq(config.getIsVirtualAccActive(), true, 'isVirtualAccActive');
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

  function test_interestRateStrategy(address token, TokenListingParams memory params) private view {
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

    if (params.initialDeposit > 0) {
      assertEq(
        IERC20Detailed(aToken).balanceOf(this.DUST_BIN()),
        params.initialDeposit,
        'initialDeposit'
      );
      assertEq(IERC20Detailed(aToken).totalSupply(), params.initialDeposit, 'aToken totalSupply');
    }

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

  function test_variableDebtToken(address token, TokenListingParams memory params) private view {
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

  function test_priceFeed(address token, TokenListingParams memory params) private view {
    IAaveOracle oracle = IAaveOracle(pool.ADDRESSES_PROVIDER().getPriceOracle());

    AggregatorInterface oracleSource = AggregatorInterface(oracle.getSourceOfAsset(token));
    assertEq(oracleSource.decimals(), 8, 'oracleSource.decimals');

    assertEq(address(oracleSource), params.oracle, 'oracleSource');

    AggregatorInterface priceFeed = oracleSource;
    if (params.hasPriceAdapter) {
      priceFeed = AggregatorInterface(IScaledPriceAdapter(address(oracleSource)).source());
      assertEq(
        priceFeed.latestAnswer() * int256(10 ** (8 - priceFeed.decimals())),
        oracleSource.latestAnswer(),
        'priceFeed.latestAnswer'
      );
    }

    assertEq(address(priceFeed), params.underlyingPriceFeed, 'priceFeed');
  }

  function test_eMode_configuration(
    uint8 eModeCategory,
    EModeCategoryParams memory params
  ) private view {
    assertEq(pool.getEModeCategoryCollateralConfig(eModeCategory).ltv, params.ltv, 'emode.ltv');
    assertEq(
      pool.getEModeCategoryCollateralConfig(eModeCategory).liquidationThreshold,
      params.liquidationThreshold,
      'emode.liquidationThreshold'
    );
    assertEq(
      pool.getEModeCategoryCollateralConfig(eModeCategory).liquidationBonus,
      params.liquidationBonus,
      'emode.liquidationBonus'
    );
    assertEq(pool.getEModeCategoryLabel(eModeCategory), params.label, 'emode.label');

    uint128 collateralBitmap = pool.getEModeCategoryCollateralBitmap(eModeCategory);
    uint128 recoveredCollateralBitmap = 0;
    for (uint256 i = 0; i < params.collateralAssets.length; i++) {
      uint256 reserveId = pool.getReserveData(params.collateralAssets[i]).id;
      assertEq(
        collateralBitmap.isReserveEnabledOnBitmap(reserveId),
        true,
        string.concat('emode.collateralAsset ', vm.toString(params.collateralAssets[i]))
      );
      recoveredCollateralBitmap = recoveredCollateralBitmap.setReserveBitmapBit(reserveId, true);
    }
    assertEq(collateralBitmap, recoveredCollateralBitmap, 'emode.collateralBitmap');

    uint128 borrowableBitmap = pool.getEModeCategoryBorrowableBitmap(eModeCategory);
    uint128 recoveredBorrowableBitmap = 0;
    for (uint256 i = 0; i < params.borrowableAssets.length; i++) {
      uint256 reserveId = pool.getReserveData(params.borrowableAssets[i]).id;
      assertEq(
        borrowableBitmap.isReserveEnabledOnBitmap(reserveId),
        true,
        string.concat('emode.borrowableAsset ', vm.toString(params.borrowableAssets[i]))
      );
      recoveredBorrowableBitmap = recoveredBorrowableBitmap.setReserveBitmapBit(reserveId, true);
    }
    assertEq(borrowableBitmap, recoveredBorrowableBitmap, 'emode.borrowableBitmap');
  }

  function test_eMode_collateralization(
    uint8 eModeCategory,
    EModeCategoryParams memory params
  ) private {
    address poolConfigurator = pool.ADDRESSES_PROVIDER().getPoolConfigurator();
    vm.prank(poolAdmin);
    IPoolConfigurator(poolConfigurator).setPoolPause(false);

    vm.prank(alice);
    pool.setUserEMode(eModeCategory);

    IAaveOracle oracle = IAaveOracle(pool.ADDRESSES_PROVIDER().getPriceOracle());
    for (uint256 i = 0; i < params.collateralAssets.length; i++) {
      uint256 amountInBaseCurrency = 1e6 * 1e8;

      uint256 supplyAmount = (amountInBaseCurrency *
        10 ** IERC20Detailed(params.collateralAssets[i]).decimals()) /
        oracle.getAssetPrice(params.collateralAssets[i]) +
        1;
      address collateralAsset = params.collateralAssets[i];
      deal(collateralAsset, alice, supplyAmount);

      vm.startPrank(alice);
      IERC20Detailed(collateralAsset).approve(address(pool), supplyAmount);
      pool.supply(collateralAsset, supplyAmount, alice, 0);
      vm.stopPrank();

      for (uint256 j = 0; j < params.borrowableAssets.length; j++) {
        address borrowAsset = params.borrowableAssets[j];
        uint256 borrowAmount = (amountInBaseCurrency.percentMul(params.ltv) *
          10 ** IERC20Detailed(borrowAsset).decimals()) /
          oracle.getAssetPrice(borrowAsset) -
          1;

        deal(borrowAsset, bob, borrowAmount);

        vm.startPrank(bob);
        IERC20Detailed(borrowAsset).approve(address(pool), borrowAmount);
        pool.supply(borrowAsset, borrowAmount, bob, 0);
        vm.stopPrank();

        vm.prank(alice);
        pool.borrow(borrowAsset, borrowAmount, 2, 0, alice);

        vm.startPrank(alice);
        IERC20Detailed(borrowAsset).approve(address(pool), borrowAmount);
        pool.repay(borrowAsset, borrowAmount, 2, alice);
        vm.stopPrank();

        vm.prank(bob);
        pool.withdraw(borrowAsset, borrowAmount, bob);
      }

      vm.prank(alice);
      pool.withdraw(collateralAsset, supplyAmount, alice);
    }
  }

  function assertEq(
    IDefaultInterestRateStrategyV2.InterestRateDataRay memory a,
    IDefaultInterestRateStrategyV2.InterestRateDataRay memory b
  ) internal pure {
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
  address internal constant GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant GHO_PRICE_FEED = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;

  address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

  address internal constant RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
  address internal constant RLUSD_PRICE_FEED = 0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A;

  address internal constant USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
  address internal constant USTB_PRICE_FEED = 0xde49c7B5C0E54b1624ED21C7D88bA6593d444Aa0;
  address internal constant USTB_PRICE_FEED_ADAPTER = 0x5Ae4D93B9b9626Dc3289e1Afb14b821FD3C95F44;

  address internal constant USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
  address internal constant USCC_PRICE_FEED = 0x19e2d716288751c5A59deaB61af012D5DF895962;
  address internal constant USCC_PRICE_FEED_ADAPTER = 0x14CB2E810Eb93b79363f489D45a972b609E47230;

  address internal constant USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
  address internal constant USYC_PRICE_FEED = 0xE8E65Fb9116875012F5990Ecaab290B3531DbeB9;

  address internal constant JTRSY_ADDRESS = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
  address internal constant JTRSY_PRICE_FEED = 0x23adce82907D20c509101E2Af0723A9e16224EFb;
  address internal constant JTRSY_PRICE_FEED_ADAPTER = 0xfAB6790E399f0481e1303167c655b3c39ee6e7A0;

  address internal constant JAAA_ADDRESS = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;
  address internal constant JAAA_PRICE_FEED = 0x1E41Ef40AC148706c114534E8192Ca608f80fC48;
  address internal constant JAAA_PRICE_FEED_ADAPTER = 0xF77f2537dba4ffD60f77fACdfB2c1706364fA03d;

  TokenListingParams internal GHO_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA GHO',
      aTokenSymbol: 'aHorRwaGHO',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt GHO',
      variableDebtTokenSymbol: 'variableDebtHorRwaGHO',
      isRwa: false,
      hasPriceAdapter: false,
      oracle: GHO_PRICE_FEED,
      underlyingPriceFeed: GHO_PRICE_FEED,
      supplyCap: 25_000_000,
      borrowCap: 22_500_000,
      reserveFactor: 10_00,
      enabledToBorrow: true,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 0,
      liquidationThreshold: 0,
      liquidationBonus: 0,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0.0475e27,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 100e18
    });

  TokenListingParams internal USDC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USDC',
      aTokenSymbol: 'aHorRwaUSDC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USDC',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSDC',
      isRwa: false,
      hasPriceAdapter: false,
      oracle: USDC_PRICE_FEED,
      underlyingPriceFeed: USDC_PRICE_FEED,
      supplyCap: 35_000_000,
      borrowCap: 31_500_000,
      reserveFactor: 10_00,
      enabledToBorrow: true,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 0,
      liquidationThreshold: 0,
      liquidationBonus: 0,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.9e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0.05e27,
        variableRateSlope2: 0.25e27
      }),
      initialDeposit: 100e6
    });

  TokenListingParams internal RLUSD_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA RLUSD',
      aTokenSymbol: 'aHorRwaRLUSD',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt RLUSD',
      variableDebtTokenSymbol: 'variableDebtHorRwaRLUSD',
      isRwa: false,
      hasPriceAdapter: false,
      oracle: RLUSD_PRICE_FEED,
      underlyingPriceFeed: RLUSD_PRICE_FEED,
      supplyCap: 35_000_000,
      borrowCap: 31_500_000,
      reserveFactor: 10_00,
      enabledToBorrow: true,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 0,
      liquidationThreshold: 0,
      liquidationBonus: 0,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.9e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0.05e27,
        variableRateSlope2: 0.25e27
      }),
      initialDeposit: 100e18
    });

  TokenListingParams internal USTB_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USTB',
      aTokenSymbol: 'aHorRwaUSTB',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USTB',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSTB',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: USTB_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: USTB_PRICE_FEED,
      supplyCap: 4_275_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 5,
      liquidationThreshold: 10,
      liquidationBonus: 100_00 + 3_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 0
    });

  EModeCategoryParams internal USTB_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 83_00,
      liquidationThreshold: 88_00,
      liquidationBonus: 100_00 + 3_00,
      label: 'USTB Stablecoins',
      collateralAssets: _toDynamicAddressArray(USTB_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS, GHO_ADDRESS)
    });

  EModeCategoryParams internal USTB_GHO_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 84_00,
      liquidationThreshold: 89_00,
      liquidationBonus: 100_00 + 3_00,
      label: 'USTB GHO',
      collateralAssets: _toDynamicAddressArray(USTB_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(GHO_ADDRESS)
    });

  TokenListingParams internal USCC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USCC',
      aTokenSymbol: 'aHorRwaUSCC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USCC',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSCC',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: USCC_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: USCC_PRICE_FEED,
      supplyCap: 1_395_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 5,
      liquidationThreshold: 10,
      liquidationBonus: 100_00 + 7_50,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 0
    });

  EModeCategoryParams internal USCC_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 72_00,
      liquidationThreshold: 79_00,
      liquidationBonus: 100_00 + 7_50,
      label: 'USCC Stablecoins',
      collateralAssets: _toDynamicAddressArray(USCC_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS, GHO_ADDRESS)
    });

  EModeCategoryParams internal USCC_GHO_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 73_00,
      liquidationThreshold: 80_00,
      liquidationBonus: 100_00 + 7_50,
      label: 'USCC GHO',
      collateralAssets: _toDynamicAddressArray(USCC_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(GHO_ADDRESS)
    });

  TokenListingParams internal USYC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USYC',
      aTokenSymbol: 'aHorRwaUSYC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USYC',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSYC',
      isRwa: true,
      hasPriceAdapter: false,
      oracle: USYC_PRICE_FEED,
      underlyingPriceFeed: USYC_PRICE_FEED,
      supplyCap: 25_580_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 5,
      liquidationThreshold: 10,
      liquidationBonus: 100_00 + 3_10,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 0
    });

  EModeCategoryParams internal USYC_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 85_00,
      liquidationThreshold: 89_00,
      liquidationBonus: 100_00 + 3_10,
      label: 'USYC Stablecoins',
      collateralAssets: _toDynamicAddressArray(USYC_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS, GHO_ADDRESS)
    });

  EModeCategoryParams internal USYC_GHO_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 86_00,
      liquidationThreshold: 90_00,
      liquidationBonus: 100_00 + 3_10,
      label: 'USYC GHO',
      collateralAssets: _toDynamicAddressArray(USYC_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(GHO_ADDRESS)
    });

  TokenListingParams internal JTRSY_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA JTRSY',
      aTokenSymbol: 'aHorRwaJTRSY',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt JTRSY',
      variableDebtTokenSymbol: 'variableDebtHorRwaJTRSY',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: JTRSY_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: JTRSY_PRICE_FEED,
      supplyCap: 22_010_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 5,
      liquidationThreshold: 10,
      liquidationBonus: 100_00 + 4_50,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 0
    });

  EModeCategoryParams internal JTRSY_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 77_00,
      liquidationThreshold: 83_00,
      liquidationBonus: 100_00 + 4_50,
      label: 'JTRSY Stablecoins',
      collateralAssets: _toDynamicAddressArray(JTRSY_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS, GHO_ADDRESS)
    });

  EModeCategoryParams internal JTRSY_GHO_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 78_00,
      liquidationThreshold: 84_00,
      liquidationBonus: 100_00 + 4_50,
      label: 'JTRSY GHO',
      collateralAssets: _toDynamicAddressArray(JTRSY_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(GHO_ADDRESS)
    });

  TokenListingParams internal JAAA_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA JAAA',
      aTokenSymbol: 'aHorRwaJAAA',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt JAAA',
      variableDebtTokenSymbol: 'variableDebtHorRwaJAAA',
      isRwa: true,
      hasPriceAdapter: true,
      oracle: JAAA_PRICE_FEED_ADAPTER,
      underlyingPriceFeed: JAAA_PRICE_FEED,
      supplyCap: 24_760_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 5,
      liquidationThreshold: 10,
      liquidationBonus: 100_00 + 9_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      }),
      initialDeposit: 0
    });

  EModeCategoryParams internal JAAA_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 71_00,
      liquidationThreshold: 78_00,
      liquidationBonus: 100_00 + 9_00,
      label: 'JAAA Stablecoins',
      collateralAssets: _toDynamicAddressArray(JAAA_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS, GHO_ADDRESS)
    });

  EModeCategoryParams internal JAAA_GHO_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 72_00,
      liquidationThreshold: 79_00,
      liquidationBonus: 100_00 + 9_00,
      label: 'JAAA GHO',
      collateralAssets: _toDynamicAddressArray(JAAA_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(GHO_ADDRESS)
    });

  function setUp() public virtual {
    vm.createSelectFork('mainnet');
    initEnvironment();
  }

  function test_permissions() public view {
    check_permissions();
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

  function test_eMode_USTB_Stablecoins() public virtual {
    test_eMode(1, USTB_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_USTB_GHO() public {
    test_eMode(2, USTB_GHO_EMODE_PARAMS);
  }

  function test_listing_USCC() public {
    test_listing(USCC_ADDRESS, USCC_TOKEN_LISTING_PARAMS);
  }

  function test_eMode_USCC_Stablecoins() public virtual {
    test_eMode(3, USCC_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_USCC_GHO() public {
    test_eMode(4, USCC_GHO_EMODE_PARAMS);
  }

  function test_listing_USYC() public {
    test_listing(USYC_ADDRESS, USYC_TOKEN_LISTING_PARAMS);
  }

  function test_eMode_USYC_Stablecoins() public virtual {
    test_eMode(5, USYC_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_USYC_GHO() public {
    test_eMode(6, USYC_GHO_EMODE_PARAMS);
  }

  function test_listing_JTRSY() public {
    test_listing(JTRSY_ADDRESS, JTRSY_TOKEN_LISTING_PARAMS);
  }

  function test_eMode_JTRSY_Stablecoins() public virtual {
    test_eMode(7, JTRSY_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_JTRSY_GHO() public {
    test_eMode(8, JTRSY_GHO_EMODE_PARAMS);
  }

  function test_listing_JAAA() public {
    test_listing(JAAA_ADDRESS, JAAA_TOKEN_LISTING_PARAMS);
  }

  function test_eMode_JAAA_Stablecoins() public virtual {
    test_eMode(9, JAAA_STABLECOINS_EMODE_PARAMS);
  }

  function test_eMode_JAAA_GHO() public {
    test_eMode(10, JAAA_GHO_EMODE_PARAMS);
  }

  function _toDynamicAddressArray(address a) private pure returns (address[] memory) {
    address[] memory array = new address[](1);
    array[0] = a;
    return array;
  }

  function _toDynamicAddressArray(
    address a,
    address b,
    address c
  ) private pure returns (address[] memory) {
    address[] memory array = new address[](3);
    array[0] = a;
    array[1] = b;
    array[2] = c;
    return array;
  }
}

/// forge-config: default.evm_version = "cancun"
contract HorizonPhaseOneListingTest is HorizonListingMainnetTest, Default {
  address public constant override OPERATIONAL_MULTISIG_ADDRESS = OPERATIONAL_MULTISIG;
  address public constant override EMERGENCY_MULTISIG_ADDRESS = EMERGENCY_MULTISIG;
  address public constant override AAVE_DAO_EXECUTOR_ADDRESS = AAVE_DAO_EXECUTOR;
  address public constant override LISTING_EXECUTOR_ADDRESS = PHASE_ONE_LISTING_EXECUTOR;
  address public constant override DUST_BIN = 0x31a0Ba3C2242a095dBF58A7C53751eCBd27dBA9b;

  address internal constant SUPERSTATE_ALLOWLIST_V2 = 0x02f1fA8B196d21c7b733EB2700B825611d8A38E5;
  uint256 internal constant SUPERSTATE_ROOT_ENTITY_ID = 1;
  address internal constant CENTRIFUGE_HOOK = 0x4737C3f62Cc265e786b280153fC666cEA2fBc0c0;
  address internal constant CENTRIFUGE_WARD = 0x09ab10a9c3E6Eac1d18270a2322B6113F4C7f5E8;
  uint8 internal constant CIRCLE_INVESTOR_SDYF_INTERNATIONAL_ROLE = 3;
  address internal constant CIRCLE_SET_USER_ROLE_AUTHORIZED_CALLER =
    0xDbE01f447040F78ccbC8Dfd101BEc1a2C21f800D;

  function loadDeployment() internal virtual override returns (DeploymentInfo memory) {
    string memory reportFilePath = run();

    IMetadataReporter metadataReporter = IMetadataReporter(
      _deployFromArtifacts('MetadataReporter.sol:MetadataReporter')
    );
    MarketReport memory marketReport = metadataReporter.parseMarketReport(reportFilePath);

    address horizonPhaseOneListing = new DeployHorizonPhaseOnePayload().run(reportFilePath);

    deal(GHO_ADDRESS, LISTING_EXECUTOR_ADDRESS, 100e18);
    deal(USDC_ADDRESS, LISTING_EXECUTOR_ADDRESS, 100e6);
    deal(RLUSD_ADDRESS, LISTING_EXECUTOR_ADDRESS, 100e18);

    vm.prank(EMERGENCY_MULTISIG);
    (bool success, ) = LISTING_EXECUTOR_ADDRESS.call(
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

    return
      DeploymentInfo({
        pool: marketReport.poolProxy,
        revenueSplitter: marketReport.revenueSplitter,
        defaultInterestRateStrategy: marketReport.defaultInterestRateStrategy,
        rwaATokenManager: marketReport.rwaATokenManager,
        aTokenImpl: marketReport.aToken,
        rwaATokenImpl: marketReport.rwaAToken,
        variableDebtTokenImpl: marketReport.variableDebtToken,
        poolAdmin: AAVE_DAO_EXECUTOR
      });
  }

  function initEnvironment() internal override {
    vm.skip(true);
    super.initEnvironment();

    whitelistSuperstateRwa(pool.getReserveAToken(USTB_ADDRESS));
    whitelistSuperstateRwa(pool.getReserveAToken(USCC_ADDRESS));
    whitelistSuperstateRwa(alice);

    whitelistUsycRwa(pool.getReserveAToken(USYC_ADDRESS));
    // if `msg.sender` is not `from` in `transferFrom` then the msg.sender must be whitelisted as well
    whitelistUsycRwa(address(pool));
    whitelistUsycRwa(alice);

    whitelistCentrifugeRwa(pool.getReserveAToken(JTRSY_ADDRESS));
    whitelistCentrifugeRwa(pool.getReserveAToken(JAAA_ADDRESS));
    whitelistCentrifugeRwa(alice);
  }

  function whitelistSuperstateRwa(address addressToWhitelist) internal {
    (bool success, bytes memory data) = SUPERSTATE_ALLOWLIST_V2.call(
      abi.encodeWithSignature('owner()')
    );
    require(success, 'Failed to call owner()');
    address owner = abi.decode(data, (address));

    vm.prank(owner);
    (success, ) = SUPERSTATE_ALLOWLIST_V2.call(
      abi.encodeWithSignature(
        'setEntityIdForAddress(uint256,address)',
        SUPERSTATE_ROOT_ENTITY_ID,
        addressToWhitelist
      )
    );
  }

  function whitelistCentrifugeRwa(address addressToWhitelist) internal {
    address restrictionManager = CENTRIFUGE_HOOK;

    (bool success, bytes memory data) = restrictionManager.call(abi.encodeWithSignature('root()'));
    require(success, 'Failed to call root()');
    address root = abi.decode(data, (address));

    vm.prank(CENTRIFUGE_WARD);
    (success, ) = root.call(abi.encodeWithSignature('endorse(address)', addressToWhitelist));
    require(success, 'Failed to call endorse()');
  }

  function whitelistUsycRwa(address addressToWhitelist) internal {
    (bool success, bytes memory data) = USYC_ADDRESS.call(abi.encodeWithSignature('authority()'));
    require(success, 'Failed to call authority()');
    address authority = abi.decode(data, (address));

    vm.prank(CIRCLE_SET_USER_ROLE_AUTHORIZED_CALLER);
    (success, ) = authority.call(
      abi.encodeWithSignature(
        'setUserRole(address,uint8,bool)',
        addressToWhitelist,
        CIRCLE_INVESTOR_SDYF_INTERNATIONAL_ROLE,
        true
      )
    );
    require(success, 'Failed to call setUserRole()');
  }
}

// contract HorizonListingForkTest is HorizonListingMainnetTest {
//   function loadDeployment() internal override returns (DeploymentInfo memory) {
//     return DeploymentInfo({
//       pool: , // todo
//       revenueSplitter: , // todo
//       defaultInterestRateStrategy: , // todo
//       rwaATokenManager: , // todo
//       aTokenImpl: , // todo
//       rwaATokenImpl: , // todo
//       variableDebtTokenImpl: , // todo
//       poolAdmin: , // todo
//     });
//   }
// }
