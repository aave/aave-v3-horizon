// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/StdStorage.sol';

import {IERC20Detailed} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {ConfiguratorInputTypes} from 'src/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol';
import {RwaATokenInstance} from 'src/contracts/instances/RwaATokenInstance.sol';
import {ATokenInstance} from 'src/contracts/instances/ATokenInstance.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IAToken, IERC20} from 'src/contracts/interfaces/IAToken.sol';
import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {IPool, DataTypes} from 'src/contracts/interfaces/IPool.sol';
import {ReserveConfiguration} from 'src/contracts/protocol/pool/PoolConfigurator.sol';
import {IAaveOracle} from 'src/contracts/interfaces/IAaveOracle.sol';
import {TestnetProcedures, MockRwaATokenInstance, MockATokenInstance} from 'tests/utils/TestnetProcedures.sol';

contract PoolRwaTests is TestnetProcedures {
  using stdStorage for StdStorage;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;

  function setUp() public virtual {
    initTestEnvironment();
  }

  function test_reverts_mintToTreasury() public {
    _seedLiquidity({token: tokenList.buidl, amount: 50_000e6, isRwa: true});
    _setReserveBorrowingAndReserveFactor(tokenList.buidl);

    // upgrade aBuidl to the standard aToken implementation, to be able to borrow
    _upgradeToStandardAToken();

    (, , address varDebtBuidl) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );

    vm.startPrank(bob);
    contracts.poolProxy.supply(tokenList.wbtc, 0.4e8, bob, 0);
    contracts.poolProxy.borrow(tokenList.buidl, 2000e6, 2, 0, bob);
    skip(30 days);
    contracts.poolProxy.repay(tokenList.buidl, IERC20Detailed(varDebtBuidl).balanceOf(bob), 2, bob);
    vm.stopPrank();

    // distribute fees to treasury
    address[] memory assets = new address[](1);
    assets[0] = tokenList.buidl;

    // upgrade aBuidl to the rwa aToken implementation, to test that mintToTreasury reverts
    _upgradeToRwaAToken();

    // expect call by matching the selector only
    vm.expectCall(rwaATokenList.aBuidl, abi.encodeWithSelector(IRwaAToken.mintToTreasury.selector));

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    contracts.poolProxy.mintToTreasury(assets);
  }

  function test_setUserUseReserveAsCollateral_false() public {
    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 1e6, alice, 0);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.ReserveUsedAsCollateralDisabled(tokenList.buidl, alice);

    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, false);
    vm.stopPrank();
  }

  function test_setUserUseReserveAsCollateral_true() public {
    test_setUserUseReserveAsCollateral_false();

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.ReserveUsedAsCollateralEnabled(tokenList.buidl, alice);

    vm.prank(alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
  }

  function test_noop_setUserUseReserveAsCollateral_true_when_already_is_activated() public {
    test_setUserUseReserveAsCollateral_true();

    vm.prank(alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
  }

  function test_reverts_setUserUseReserveAsCollateral_true_ltv_zero() public {
    test_setUserUseReserveAsCollateral_false();

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.configureReserveAsCollateral(tokenList.buidl, 0, 70_00, 105_00);

    vm.expectRevert(bytes(Errors.USER_IN_ISOLATION_MODE_OR_LTV_ZERO));

    vm.prank(alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
  }

  function test_reverts_setUserUseReserveAsCollateral_true_user_balance_zero() public {
    vm.expectRevert(bytes(Errors.UNDERLYING_BALANCE_ZERO));

    vm.prank(alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
  }

  function test_reverts_setUserUseReserveAsCollateral_true_reserve_inactive() public {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveActive(tokenList.buidl, false);

    // upgrade aBuidl to the standard aToken implementation, to be able to mint aTokens
    _upgradeToStandardAToken();

    vm.prank(report.poolProxy);
    IAToken(rwaATokenList.aBuidl).mint(alice, alice, 100e6, 1e27);

    // upgrade aBuidl to the rwa aToken implementation, to test that setUserUseReserveAsCollateral reverts
    _upgradeToRwaAToken();

    vm.expectRevert(bytes(Errors.RESERVE_INACTIVE));

    vm.prank(alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
  }

  function test_reverts_setUserUseReserveAsCollateral_true_reserve_paused() public {
    test_setUserUseReserveAsCollateral_false();

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReservePause(tokenList.buidl, true, 0);

    vm.expectRevert(bytes(Errors.RESERVE_PAUSED));

    vm.prank(alice);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
  }

  function test_reverts_setUserUseReserveAsCollateral_false_hf_lower_lqt() public {
    _seedLiquidity({token: tokenList.usdx, amount: 50_000e6, isRwa: false});

    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 500e6, alice, 0);
    contracts.poolProxy.borrow(tokenList.usdx, 100e6, 2, 0, alice);

    vm.expectRevert(bytes(Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD));
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, false);
    vm.stopPrank();
  }

  function test_dropReserve() public {
    (address pA, address pS, address pV) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );
    assertTrue(pA != address(0));
    assertTrue(pS == address(0));
    assertTrue(pV != address(0));

    vm.prank(report.poolConfiguratorProxy);
    contracts.poolProxy.dropReserve(tokenList.buidl);

    (address a, address s, address v) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );

    (
      uint256 decimals,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      uint256 reserveFactor,
      bool usageAsCollateralEnabled,
      bool borrowingEnabled,
      ,
      bool isActive,
      bool isFrozen
    ) = contracts.protocolDataProvider.getReserveConfigurationData(tokenList.buidl);

    assertEq(a, address(0));
    assertEq(s, address(0));
    assertEq(v, address(0));
    assertEq(decimals, 0);
    assertEq(ltv, 0);
    assertEq(liquidationThreshold, 0);
    assertEq(liquidationBonus, 0);
    assertEq(reserveFactor, 0);
    assertEq(usageAsCollateralEnabled, false);
    assertEq(borrowingEnabled, false);
    assertEq(isActive, false);
    assertEq(isFrozen, false);
  }

  function test_setLiquidationGracePeriod(uint40 liquidationGracePeriod) public {
    vm.prank(report.poolConfiguratorProxy);
    contracts.poolProxy.setLiquidationGracePeriod(tokenList.buidl, liquidationGracePeriod);

    assertEq(
      contracts.poolProxy.getLiquidationGracePeriod(tokenList.buidl),
      liquidationGracePeriod
    );
  }

  function test_setReserveInterestRateStrategyAddress() public {
    address updatedInterestsRateStrategy = _deployInterestRateStrategy();

    vm.prank(report.poolConfiguratorProxy);
    contracts.poolProxy.setReserveInterestRateStrategyAddress(
      tokenList.buidl,
      updatedInterestsRateStrategy
    );

    address newInterestRateStrategy = contracts.protocolDataProvider.getInterestRateStrategyAddress(
      tokenList.buidl
    );

    assertEq(newInterestRateStrategy, updatedInterestsRateStrategy);
  }

  function test_resetIsolationModeTotalDebt() public {
    _seedLiquidity({token: tokenList.usdx, amount: 50_000e6, isRwa: false});

    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setDebtCeiling(tokenList.buidl, 10_000);
    contracts.poolConfiguratorProxy.setBorrowableInIsolation(tokenList.usdx, true);
    vm.stopPrank();

    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 1000e6, alice, 0);
    contracts.poolProxy.setUserUseReserveAsCollateral(tokenList.buidl, true);
    contracts.poolProxy.borrow(tokenList.usdx, 10e6, 2, 0, alice);
    vm.stopPrank();

    assertGt(contracts.poolProxy.getReserveData(tokenList.buidl).isolationModeTotalDebt, 0);

    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setDebtCeiling(tokenList.buidl, 0);

    vm.expectEmit(report.poolProxy);
    emit IPool.IsolationModeTotalDebtUpdated(tokenList.buidl, 0);
    vm.stopPrank();

    vm.prank(report.poolConfiguratorProxy);
    contracts.poolProxy.resetIsolationModeTotalDebt(tokenList.buidl);

    assertEq(contracts.poolProxy.getReserveData(tokenList.buidl).isolationModeTotalDebt, 0);
  }

  function test_getters_getUserAccountData() public {
    _seedLiquidity({token: tokenList.usdx, amount: 50_000e6, isRwa: false});

    DataTypes.ReserveConfigurationMap memory conf = contracts.poolProxy.getConfiguration(
      tokenList.buidl
    );

    vm.startPrank(bob);
    contracts.poolProxy.supply(tokenList.buidl, 5000e6, bob, 0);
    contracts.poolProxy.borrow(tokenList.usdx, 2000e6, 2, 0, bob);
    vm.stopPrank();

    (
      uint256 totalCollateralBase,
      uint256 totalDebtBase,
      ,
      uint256 currentLiquidationThreshold,
      uint256 ltv,

    ) = contracts.poolProxy.getUserAccountData(bob);

    assertEq(totalCollateralBase, 5000e8);
    assertEq(totalDebtBase, 2000e8);
    assertEq(currentLiquidationThreshold, conf.getLiquidationThreshold());
    assertEq(ltv, conf.getLtv());
  }

  function test_setUserEmode() public {
    EModeCategoryInput memory ct = _genCategoryOne();
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setEModeCategory(ct.id, ct.ltv, ct.lt, ct.lb, ct.label);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.buidl, ct.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.ustb, ct.id, true);
    vm.stopPrank();
    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.UserEModeSet(alice, ct.id);

    vm.prank(alice);
    contracts.poolProxy.setUserEMode(ct.id);
  }

  function test_setUserEmode_twice() public {
    EModeCategoryInput memory ct1 = _genCategoryOne();
    EModeCategoryInput memory ct2 = _genCategoryTwo();
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setEModeCategory(ct1.id, ct1.ltv, ct1.lt, ct1.lb, ct1.label);
    contracts.poolConfiguratorProxy.setEModeCategory(ct2.id, ct2.ltv, ct2.lt, ct2.lb, ct2.label);

    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.buidl, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.ustb, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.buidl, ct2.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.wtgxx, ct2.id, true);
    vm.stopPrank();

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.UserEModeSet(alice, ct1.id);

    vm.prank(alice);
    contracts.poolProxy.setUserEMode(ct1.id);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.UserEModeSet(alice, ct2.id);

    vm.prank(alice);
    contracts.poolProxy.setUserEMode(ct2.id);
  }

  function test_setUserEmode_twice_inconsistent_category() public {
    _seedLiquidity({token: tokenList.usdx, amount: 1000e6, isRwa: false});

    EModeCategoryInput memory ct1 = _genCategoryOne();
    EModeCategoryInput memory ct2 = _genCategoryTwo();
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setEModeCategory(ct1.id, ct1.ltv, ct1.lt, ct1.lb, ct1.label);
    contracts.poolConfiguratorProxy.setEModeCategory(ct2.id, ct2.ltv, ct2.lt, ct2.lb, ct2.label);

    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.buidl, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.ustb, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetBorrowableInEMode(tokenList.usdx, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.buidl, ct2.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.wtgxx, ct2.id, true);
    vm.stopPrank();

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.UserEModeSet(alice, ct1.id);

    uint256 amount = 100e6;
    uint256 borrowAmount = 10e6;

    vm.startPrank(alice);
    contracts.poolProxy.setUserEMode(ct1.id);

    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);
    contracts.poolProxy.borrow(tokenList.usdx, borrowAmount, 2, 0, alice);

    vm.expectRevert(bytes(Errors.NOT_BORROWABLE_IN_EMODE));

    contracts.poolProxy.setUserEMode(ct2.id);
    vm.stopPrank();
  }

  function test_reverts_setUserEmode_0_bad_hf() public {
    _seedLiquidity({token: tokenList.usdx, amount: 1000e6, isRwa: false});

    EModeCategoryInput memory ct1 = _genCategoryOne();
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.setEModeCategory(ct1.id, ct1.ltv, ct1.lt, ct1.lb, ct1.label);

    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.buidl, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetCollateralInEMode(tokenList.usdx, ct1.id, true);
    contracts.poolConfiguratorProxy.setAssetBorrowableInEMode(tokenList.usdx, ct1.id, true);
    vm.stopPrank();

    vm.prank(alice);
    contracts.poolProxy.setUserEMode(ct1.id);

    uint256 amount = 100e6;
    uint256 borrowAmount = 70e6;

    vm.startPrank(alice);
    contracts.poolProxy.supply(tokenList.buidl, amount, alice, 0);
    contracts.poolProxy.borrow(tokenList.usdx, borrowAmount, 2, 0, alice);

    stdstore
      .target(IAaveOracle(report.aaveOracle).getSourceOfAsset(tokenList.buidl))
      .sig('_latestAnswer()')
      .checked_write(
        _calcPrice(IAaveOracle(report.aaveOracle).getAssetPrice(tokenList.buidl), 70_00)
      );

    vm.expectRevert(bytes(Errors.HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD));

    contracts.poolProxy.setUserEMode(0);
    vm.stopPrank();
  }

  function test_getVirtualUnderlyingBalance() public {
    _seedLiquidity({token: tokenList.buidl, amount: 1000e6, isRwa: true});

    uint256 virtualBalance = contracts.poolProxy.getVirtualUnderlyingBalance(tokenList.buidl);

    assertEq(IERC20(tokenList.buidl).balanceOf(rwaATokenList.aBuidl), virtualBalance);
    assertEq(1000e6, virtualBalance);
  }

  function _setReserveBorrowingAndReserveFactor(address token) internal {
    vm.startPrank(poolAdmin);
    // set buidl borrowing config
    contracts.poolConfiguratorProxy.setReserveBorrowing(token, true);
    contracts.poolConfiguratorProxy.setReserveFactor(token, 10_00);
    vm.stopPrank();
  }

  // upgrade aBuidl to the rwa aToken implementation
  function _upgradeToRwaAToken() internal {
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.updateAToken(
      ConfiguratorInputTypes.UpdateATokenInput({
        asset: tokenList.buidl,
        treasury: report.treasury,
        incentivesController: report.rewardsControllerProxy,
        name: 'aBuidl',
        symbol: 'aBuidl',
        implementation: address(new MockRwaATokenInstance(IPool(report.poolProxy))),
        params: abi.encode()
      })
    );
    vm.stopPrank();
  }

  // upgrade aBuidl to the standard aToken implementation
  function _upgradeToStandardAToken() internal {
    vm.startPrank(poolAdmin);
    contracts.poolConfiguratorProxy.updateAToken(
      ConfiguratorInputTypes.UpdateATokenInput({
        asset: tokenList.buidl,
        treasury: report.treasury,
        incentivesController: report.rewardsControllerProxy,
        name: 'aBuidl',
        symbol: 'aBuidl',
        implementation: address(new MockATokenInstance(IPool(report.poolProxy))),
        params: abi.encode()
      })
    );
    vm.stopPrank();
  }
}
