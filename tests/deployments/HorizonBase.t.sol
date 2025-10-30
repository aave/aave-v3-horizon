// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {console2 as console} from 'forge-std/console2.sol';

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
import {IERC20Detailed, IERC20} from '../../src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
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

import {AaveV3EthereumHorizonCustom} from '../horizon/utils/AaveV3EthereumHorizonCustom.sol';
import {AaveV3EthereumHorizon, AaveV3EthereumHorizonAssets} from 'aave-address-book/AaveV3EthereumHorizon.sol';

abstract contract HorizonBaseTest is Test {
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

  function initEnvironment() internal virtual {
    pool = IPool(address(AaveV3EthereumHorizon.POOL));
    revenueSplitter = IRevenueSplitter(address(AaveV3EthereumHorizon.COLLECTOR));
    defaultInterestRateStrategy = IDefaultInterestRateStrategyV2(
      AaveV3EthereumHorizonAssets.GHO_INTEREST_RATE_STRATEGY
    );
    aTokenImpl = AaveV3EthereumHorizon.DEFAULT_A_TOKEN_IMPL;
    variableDebtTokenImpl = AaveV3EthereumHorizon.DEFAULT_VARIABLE_DEBT_TOKEN_IMPL;
    rwaATokenImpl = AaveV3EthereumHorizonCustom.RWA_ATOKEN_IMPLEMENTATION;
  }

  function test_listing(address token, TokenListingParams memory params) internal virtual {
    test_getConfiguration(token, params);
    test_interestRateStrategy(token, params);
    test_aToken(token, params);
    test_variableDebtToken(token, params);
    test_priceFeed(token, params);
  }

  function test_eMode(
    uint8 eModeCategory,
    EModeCategoryParams memory params,
    bool dealCollateral
  ) internal {
    test_eMode_configuration(eModeCategory, params);
    test_eMode_collateralization(eModeCategory, params, true);
  }

  function test_getConfiguration(address token, TokenListingParams memory params) internal view {
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
    assertEq(config.getPaused(), false, 'paused');
  }

  function test_interestRateStrategy(
    address token,
    TokenListingParams memory params
  ) internal view {
    assertEq(
      pool.getReserveData(token).interestRateStrategyAddress,
      address(defaultInterestRateStrategy),
      'interestRateStrategyAddress'
    );
    assertEq(defaultInterestRateStrategy.getInterestRateData(token), params.interestRateData);
  }

  function test_aToken(address token, TokenListingParams memory params) internal {
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
    EModeCategoryParams memory params,
    bool dealCollateral
  ) internal {
    address poolConfigurator = pool.ADDRESSES_PROVIDER().getPoolConfigurator();

    vm.prank(alice);
    pool.setUserEMode(eModeCategory);

    IAaveOracle oracle = IAaveOracle(pool.ADDRESSES_PROVIDER().getPriceOracle());
    for (uint256 i = 0; i < params.collateralAssets.length; i++) {
      uint256 amountInBaseCurrency = 1e5 * 1e8;

      uint256 supplyAmount = (amountInBaseCurrency *
        10 ** IERC20Detailed(params.collateralAssets[i]).decimals()) /
        oracle.getAssetPrice(params.collateralAssets[i]) +
        1;
      address collateralAsset = params.collateralAssets[i];
      if (dealCollateral) {
        deal(collateralAsset, alice, supplyAmount);
      }

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

  function test_nonEMode_collateralization(
    address token,
    TokenListingParams memory params,
    address[] memory borrowableAssets,
    bool dealCollateral
  ) internal {
    address poolConfigurator = pool.ADDRESSES_PROVIDER().getPoolConfigurator();

    IAaveOracle oracle = IAaveOracle(pool.ADDRESSES_PROVIDER().getPriceOracle());
    uint256 amountInBaseCurrency = 1e5 * 1e8;

    uint256 supplyAmount = (amountInBaseCurrency * 10 ** IERC20Detailed(token).decimals()) /
      oracle.getAssetPrice(token) +
      1;

    if (dealCollateral) {
      deal(token, alice, supplyAmount);
    }

    vm.startPrank(alice);
    IERC20Detailed(token).approve(address(pool), supplyAmount);
    pool.supply(token, supplyAmount, alice, 0);
    vm.stopPrank();

    for (uint256 j = 0; j < borrowableAssets.length; j++) {
      address borrowAsset = borrowableAssets[j];
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
    pool.withdraw(token, supplyAmount, alice);
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

  // check current emode category label is empty so it can be overridden
  function _checkExistingEModeCategory(uint8 eModeCategory) internal virtual {
    DataTypes.EModeCategoryLegacy memory eModeCategoryData = pool.getEModeCategoryData(
      eModeCategory
    );
    assertEq(eModeCategoryData.label, '', 'EMode category does not exist');
  }

  function _toDynamicAddressArray(address a) internal pure returns (address[] memory) {
    address[] memory array = new address[](1);
    array[0] = a;
    return array;
  }

  function _toDynamicAddressArray(address a, address b) internal pure returns (address[] memory) {
    address[] memory array = new address[](2);
    array[0] = a;
    array[1] = b;
    return array;
  }

  function _toDynamicAddressArray(
    address a,
    address b,
    address c
  ) internal pure returns (address[] memory) {
    address[] memory array = new address[](3);
    array[0] = a;
    array[1] = b;
    array[2] = c;
    return array;
  }
}
