// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test, Vm} from 'forge-std/Test.sol';
import {DataTypes} from '../../src/contracts/protocol/libraries/types/DataTypes.sol';
import {MarketReport} from '../../src/deployments/interfaces/IMarketReportTypes.sol';
import {Default} from '../../scripts/DeployAaveV3MarketBatched.sol';
import {DeployHorizonPhaseOnePayload} from '../../scripts/misc/DeployHorizonPhaseOnePayload.sol';
import {ReserveConfiguration} from '../../src/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {EModeConfiguration} from '../../src/contracts/protocol/libraries/configuration/EModeConfiguration.sol';
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
  using EModeConfiguration for uint128;

  IPool internal pool;
  IRevenueSplitter internal revenueSplitter;
  IDefaultInterestRateStrategyV2 internal defaultInterestRateStrategy;
  address internal aTokenImpl;
  address internal rwaATokenImpl;
  address internal variableDebtTokenImpl;

  struct TokenListingParams {
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

  struct EModeCategoryParams {
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    string label;
    address[] collateralAssets;
    address[] borrowableAssets;
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

  function test_eModeCategory(uint8 eModeCategory, EModeCategoryParams memory params) internal {
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
  address internal constant EMERGENCY_MULTISIG = 0x13B57382c36BAB566E75C72303622AF29E27e1d3;
  address internal constant LISTING_EXECUTOR = 0x09e8E1408a68778CEDdC1938729Ea126710E7Dda;

  address internal constant GHO_ADDRESS = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
  address internal constant GHO_PRICE_FEED = 0xD110cac5d8682A3b045D5524a9903E031d70FCCd;

  address internal constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address internal constant USDC_PRICE_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

  address internal constant RLUSD_ADDRESS = 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD;
  address internal constant RLUSD_PRICE_FEED = 0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A;

  address internal constant USTB_ADDRESS = 0x43415eB6ff9DB7E26A15b704e7A3eDCe97d31C4e;
  address internal constant USTB_PRICE_FEED = 0xde49c7B5C0E54b1624ED21C7D88bA6593d444Aa0;

  address internal constant USCC_ADDRESS = 0x14d60E7FDC0D71d8611742720E4C50E7a974020c;
  address internal constant USCC_PRICE_FEED = 0x19e2d716288751c5A59deaB61af012D5DF895962;

  address internal constant USYC_ADDRESS = 0x136471a34f6ef19fE571EFFC1CA711fdb8E49f2b;
  address internal constant USYC_PRICE_FEED = 0xE8E65Fb9116875012F5990Ecaab290B3531DbeB9;

  address internal constant JTRSY_ADDRESS = 0x8c213ee79581Ff4984583C6a801e5263418C4b86;
  address internal constant JTRSY_PRICE_FEED = 0x23adce82907D20c509101E2Af0723A9e16224EFb;

  address internal constant JAAA_ADDRESS = 0x5a0F93D040De44e78F251b03c43be9CF317Dcf64;
  address internal constant JAAA_PRICE_FEED = 0x1E41Ef40AC148706c114534E8192Ca608f80fC48;

  TokenListingParams internal GHO_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA GHO',
      aTokenSymbol: 'aHorRwaGHO',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt GHO',
      variableDebtTokenSymbol: 'variableDebtHorRwaGHO',
      isRwa: false,
      hasPriceAdapter: false,
      underlyingPiceFeed: GHO_PRICE_FEED,
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
      })
    });

  TokenListingParams internal USDC_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USDC',
      aTokenSymbol: 'aHorRwaUSDC',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USDC',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSDC',
      isRwa: false,
      hasPriceAdapter: false,
      underlyingPiceFeed: USDC_PRICE_FEED,
      supplyCap: 35_000_000,
      borrowCap: 31_500_000,
      reserveFactor: 15_00,
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
        variableRateSlope2: 0.15e27
      })
    });

  TokenListingParams internal RLUSD_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA RLUSD',
      aTokenSymbol: 'aHorRwaRLUSD',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt RLUSD',
      variableDebtTokenSymbol: 'variableDebtHorRwaRLUSD',
      isRwa: false,
      hasPriceAdapter: false,
      underlyingPiceFeed: RLUSD_PRICE_FEED,
      supplyCap: 35_000_000,
      borrowCap: 31_500_000,
      reserveFactor: 15_00,
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
        variableRateSlope2: 0.15e27
      })
    });

  TokenListingParams internal USTB_TOKEN_LISTING_PARAMS =
    TokenListingParams({
      aTokenName: 'Aave Horizon RWA USTB',
      aTokenSymbol: 'aHorRwaUSTB',
      variableDebtTokenName: 'Aave Horizon RWA Variable Debt USTB',
      variableDebtTokenSymbol: 'variableDebtHorRwaUSTB',
      isRwa: true,
      hasPriceAdapter: true,
      underlyingPiceFeed: USTB_PRICE_FEED,
      supplyCap: 46_090_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 10,
      liquidationThreshold: 50,
      liquidationBonus: 100_00 + 3_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  EModeCategoryParams internal USTB_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 83_00,
      liquidationThreshold: 88_00,
      liquidationBonus: 100_00 + 3_00,
      label: 'USTB Stablecoins',
      collateralAssets: _toDynamicAddressArray(USTB_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS)
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
      underlyingPiceFeed: USCC_PRICE_FEED,
      supplyCap: 15_400_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 10,
      liquidationThreshold: 50,
      liquidationBonus: 100_00 + 7_50,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  EModeCategoryParams internal USCC_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 72_00,
      liquidationThreshold: 79_00,
      liquidationBonus: 100_00 + 7_50,
      label: 'USCC Stablecoins',
      collateralAssets: _toDynamicAddressArray(USCC_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS)
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
      underlyingPiceFeed: USYC_PRICE_FEED,
      supplyCap: 28_050_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 10,
      liquidationThreshold: 50,
      liquidationBonus: 100_00 + 3_10,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  EModeCategoryParams internal USYC_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 85_00,
      liquidationThreshold: 89_00,
      liquidationBonus: 100_00 + 3_10,
      label: 'USYC Stablecoins',
      collateralAssets: _toDynamicAddressArray(USYC_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS)
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
      underlyingPiceFeed: JTRSY_PRICE_FEED,
      supplyCap: 23_650_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 10,
      liquidationThreshold: 50,
      liquidationBonus: 100_00 + 4_50,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  EModeCategoryParams internal JTRSY_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 77_00,
      liquidationThreshold: 83_00,
      liquidationBonus: 100_00 + 4_50,
      label: 'JTRSY Stablecoins',
      collateralAssets: _toDynamicAddressArray(JTRSY_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS)
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
      underlyingPiceFeed: JAAA_PRICE_FEED,
      supplyCap: 24_640_000,
      borrowCap: 0,
      reserveFactor: 0,
      enabledToBorrow: false,
      borrowableInIsolation: false,
      withSiloedBorrowing: false,
      flashloanable: false,
      ltv: 10,
      liquidationThreshold: 50,
      liquidationBonus: 100_00 + 9_00,
      debtCeiling: 0,
      liqProtocolFee: 0,
      interestRateData: IDefaultInterestRateStrategyV2.InterestRateDataRay({
        optimalUsageRatio: 0.99e27,
        baseVariableBorrowRate: 0,
        variableRateSlope1: 0,
        variableRateSlope2: 0
      })
    });

  EModeCategoryParams internal JAAA_STABLECOINS_EMODE_PARAMS =
    EModeCategoryParams({
      ltv: 71_00,
      liquidationThreshold: 78_00,
      liquidationBonus: 100_00 + 9_00,
      label: 'JAAA Stablecoins',
      collateralAssets: _toDynamicAddressArray(JAAA_ADDRESS),
      borrowableAssets: _toDynamicAddressArray(USDC_ADDRESS, RLUSD_ADDRESS)
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
    test_eModeCategory(1, USTB_STABLECOINS_EMODE_PARAMS);
    test_eModeCategory(2, USTB_GHO_EMODE_PARAMS);
  }

  function test_listing_USCC() public {
    test_listing(USCC_ADDRESS, USCC_TOKEN_LISTING_PARAMS);
    test_eModeCategory(3, USCC_STABLECOINS_EMODE_PARAMS);
    test_eModeCategory(4, USCC_GHO_EMODE_PARAMS);
  }

  function test_listing_USYC() public {
    test_listing(USYC_ADDRESS, USYC_TOKEN_LISTING_PARAMS);
    test_eModeCategory(5, USYC_STABLECOINS_EMODE_PARAMS);
    test_eModeCategory(6, USYC_GHO_EMODE_PARAMS);
  }

  function test_listing_JTRSY() public {
    test_listing(JTRSY_ADDRESS, JTRSY_TOKEN_LISTING_PARAMS);
    test_eModeCategory(7, JTRSY_STABLECOINS_EMODE_PARAMS);
    test_eModeCategory(8, JTRSY_GHO_EMODE_PARAMS);
  }

  function test_listing_JAAA() public {
    test_listing(JAAA_ADDRESS, JAAA_TOKEN_LISTING_PARAMS);
    test_eModeCategory(9, JAAA_STABLECOINS_EMODE_PARAMS);
    test_eModeCategory(10, JAAA_GHO_EMODE_PARAMS);
  }

  function loadDeployment()
    internal
    virtual
    returns (address, address, address, address, address, address);

  function getListingExecutor() internal pure override returns (address) {
    return LISTING_EXECUTOR;
  }

  function _toDynamicAddressArray(address a) private pure returns (address[] memory) {
    address[] memory array = new address[](1);
    array[0] = a;
    return array;
  }

  function _toDynamicAddressArray(address a, address b) private pure returns (address[] memory) {
    address[] memory array = new address[](2);
    array[0] = a;
    array[1] = b;
    return array;
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

    vm.prank(EMERGENCY_MULTISIG);
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
