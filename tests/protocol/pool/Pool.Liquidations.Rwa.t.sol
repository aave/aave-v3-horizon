// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {UserConfiguration} from 'src/contracts/protocol/libraries/configuration/UserConfiguration.sol';
import {AccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {LiquidationLogic} from 'src/contracts/protocol/libraries/logic/LiquidationLogic.sol';
import {IERC20Detailed} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol';
import {DataTypes} from 'src/contracts/protocol/libraries/types/DataTypes.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {AggregatorInterface} from 'src/contracts/dependencies/chainlink/AggregatorInterface.sol';
import {RWAAToken} from 'src/contracts/protocol/tokenization/RWAAToken.sol';
import {LiquidationDataProvider} from 'src/contracts/helpers/LiquidationDataProvider.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolLiquidationsRwaTests is TestnetProcedures {
  using UserConfiguration for DataTypes.UserConfigurationMap;

  struct RwaTokenInfo {
    address rwaToken;
    address rwaAToken;
    address user;
    address liquidator;
  }

  struct LiquidationCheck {
    address user;
    address supplyToken;
    uint256 supplyAmount;
    address borrowToken;
    uint256 borrowAmount;
    uint256 timeToSkip;
    uint256 liquidationAmount;
    bool receiveAToken;
    address priceImpactToken;
    int256 priceImpactPercent;
    address liquidator;
    bytes expectedRevertData;
    bool expectFullLiquidation;
  }

  address david;
  address internal aTokenTransferAdmin;

  RwaTokenInfo[] internal rwaTokenInfos;

  LiquidationDataProvider internal liquidationDataProvider;

  function setUp() public {
    initTestEnvironment();

    liquidationDataProvider = new LiquidationDataProvider(
      address(contracts.poolProxy),
      address(contracts.poolAddressesProvider)
    );

    aTokenTransferAdmin = makeAddr('ATOKEN_TRANSFER_ADMIN_1');

    (address aBuidlAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );
    address buidlLiquidator = makeAddr('BUIDL_LIQUIDATOR_1');

    (address aWtgxxAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.wtgxx
    );
    address wtgxxLiquidator = makeAddr('WTGXX_LIQUIDATOR_1');

    (address aUstbAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.ustb
    );
    address ustbLiquidator = makeAddr('USTB_LIQUIDATOR_1');

    vm.startPrank(poolAdmin);
    // authorize & mint BUIDL to alice
    buidl.authorize(alice, true);
    buidl.mint(alice, 100000e6);
    // authorize & mint USTB to bob
    ustb.authorize(bob, true);
    ustb.mint(bob, 10000e6);
    // authorize & mint WTGXX to carol
    wtgxx.authorize(carol, true);
    wtgxx.mint(carol, 100000e18);
    // grant Transfer Role to the aToken Transfer Admin
    AccessControl(aclManagerAddress).grantRole(
      keccak256('ATOKEN_TRANSFER_ROLE'),
      aTokenTransferAdmin
    );
    // authorize aBUIDL to hold BUIDL
    buidl.authorize(aBuidlAddress, true);
    // authorize aUSTB to hold USTB
    ustb.authorize(aUstbAddress, true);
    // authorize aWTGXX to hold WTGXX
    wtgxx.authorize(aWtgxxAddress, true);
    // authorize the BUIDL Liquidator to hold BUIDL
    buidl.authorize(buidlLiquidator, true);
    // authorize the USTB Liquidator to hold USTB
    ustb.authorize(ustbLiquidator, true);
    // authorize the WTGXX Liquidator to hold WTGXX
    wtgxx.authorize(wtgxxLiquidator, true);
    // mint USDX to liquidators
    usdx.mint(buidlLiquidator, 100000e6);
    usdx.mint(ustbLiquidator, 100000e6);
    usdx.mint(wtgxxLiquidator, 100000e6);
    vm.stopPrank();

    vm.prank(alice);
    buidl.approve(report.poolProxy, UINT256_MAX);

    vm.prank(bob);
    ustb.approve(report.poolProxy, UINT256_MAX);

    vm.prank(carol);
    wtgxx.approve(report.poolProxy, UINT256_MAX);

    // supply 100000 USDX such that users can borrow USDX against RWAs
    david = makeAddr('david');
    vm.prank(poolAdmin);
    usdx.mint(david, 100000e6);
    vm.startPrank(david);
    usdx.approve(report.poolProxy, UINT256_MAX);
    contracts.poolProxy.supply(tokenList.usdx, 100000e6, david, 0);
    vm.stopPrank();

    vm.prank(buidlLiquidator);
    usdx.approve(report.poolProxy, UINT256_MAX);
    vm.prank(ustbLiquidator);
    usdx.approve(report.poolProxy, UINT256_MAX);
    vm.prank(wtgxxLiquidator);
    usdx.approve(report.poolProxy, UINT256_MAX);

    rwaTokenInfos.push(
      RwaTokenInfo({
        rwaToken: tokenList.buidl,
        rwaAToken: aBuidlAddress,
        user: alice,
        liquidator: buidlLiquidator
      })
    );

    rwaTokenInfos.push(
      RwaTokenInfo({
        rwaToken: tokenList.ustb,
        rwaAToken: aUstbAddress,
        user: bob,
        liquidator: ustbLiquidator
      })
    );

    rwaTokenInfos.push(
      RwaTokenInfo({
        rwaToken: tokenList.wtgxx,
        rwaAToken: aWtgxxAddress,
        user: carol,
        liquidator: wtgxxLiquidator
      })
    );
  }

  function _mockPrice(address token, int256 priceImpactPercent) internal {
    int256 currentPrice = int256(contracts.aaveOracle.getAssetPrice(token));
    int256 priceDelta = (currentPrice * priceImpactPercent) / 100_00;
    int256 newPrice = currentPrice + priceDelta;
    assertGe(newPrice, 0, 'new price should be non-negative');

    address priceFeed = contracts.aaveOracle.getSourceOfAsset(token);
    vm.mockCall(
      priceFeed,
      abi.encodeCall(AggregatorInterface.latestAnswer, ()),
      abi.encode(int256(newPrice))
    );
  }

  function getRewardTokenBalance(
    address user,
    address underlyingToken,
    bool receiveAToken
  ) internal view returns (uint256) {
    address rewardToken = underlyingToken;
    if (receiveAToken) {
      (address aToken, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
        underlyingToken
      );
      rewardToken = aToken;
    }

    return IERC20Detailed(rewardToken).balanceOf(user);
  }

  function _checkLiquidation(
    LiquidationCheck memory input
  ) internal returns (LiquidationDataProvider.LiquidationInfo memory liquidationInfo) {
    vm.startPrank(input.user);
    contracts.poolProxy.supply(input.supplyToken, input.supplyAmount, input.user, 0);
    contracts.poolProxy.borrow(input.borrowToken, input.borrowAmount, 2, 0, input.user);
    vm.stopPrank();

    skip(input.timeToSkip);
    _mockPrice(input.priceImpactToken, input.priceImpactPercent);

    uint256 liquidatorBalanceBefore = getRewardTokenBalance(
      input.liquidator,
      input.supplyToken,
      input.receiveAToken
    );

    if (input.expectedRevertData.length != 0) {
      vm.expectRevert(input.expectedRevertData);
    } else {
      liquidationInfo = liquidationDataProvider.getLiquidationInfo({
        user: input.user,
        collateralAsset: input.supplyToken,
        debtAsset: input.borrowToken,
        debtLiquidationAmount: input.liquidationAmount
      });

      vm.expectEmit(address(contracts.poolProxy));
      emit LiquidationLogic.LiquidationCall(
        input.supplyToken,
        input.borrowToken,
        input.user,
        liquidationInfo.maxDebtToLiquidate,
        liquidationInfo.maxCollateralToLiquidate,
        input.liquidator,
        input.receiveAToken
      );
    }
    vm.prank(input.liquidator);
    contracts.poolProxy.liquidationCall({
      collateralAsset: input.supplyToken,
      debtAsset: input.borrowToken,
      user: input.user,
      debtToCover: input.liquidationAmount,
      receiveAToken: input.receiveAToken
    });

    // post-liquidation checks
    if (input.expectedRevertData.length == 0) {
      // check that the liquidator received the correct amount of collateral
      assertEq(
        getRewardTokenBalance(input.liquidator, input.supplyToken, input.receiveAToken),
        liquidatorBalanceBefore + liquidationInfo.maxCollateralToLiquidate
      );

      // check partial/full liquidation
      uint256 debtLeft = IERC20Detailed(
        contracts.poolProxy.getReserveVariableDebtToken(input.borrowToken)
      ).balanceOf(input.user);
      if (input.expectFullLiquidation) {
        assertEq(debtLeft, 0, 'Debt was not fully liquidated');
      } else {
        assertGt(debtLeft, 0, 'Debt was not partially liquidated');
      }

      // check bad debt was cleared, if any
      (uint256 totalCollateralInBaseCurrency, , , , , ) = contracts.poolProxy.getUserAccountData(
        input.user
      );
      if (totalCollateralInBaseCurrency == 0) {
        assertFalse(
          contracts.poolProxy.getUserConfiguration(input.user).isBorrowingAny(),
          'Bad debt was not cleared'
        );
      }
    }
  }

  function _getTokenAmount(
    address token,
    uint256 amountInBaseCurrency
  ) internal view returns (uint256) {
    uint256 tokenUnits = 10 ** IERC20Detailed(token).decimals();
    uint256 tokenPrice = contracts.aaveOracle.getAssetPrice(token);
    return (amountInBaseCurrency * tokenUnits) / tokenPrice;
  }

  /// @dev Supply token price drops, which makes user fully liquidatable.
  /// It is a small liquidation (under the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  function test_liquidation_fuzz_SupplyTokenPriceDrop_Full_SmallLiquidation_GoodHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // 85% price drop -> supply = $1500
    // aim for 0.98 health at liquidation time -> $1500 * 0.86 / 0.98 = ~$1316.32
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 10000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 1316.32e6,
        timeToSkip: 0,
        liquidationAmount: 1316.32e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: -85_00,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertLt(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLt(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGt(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Supply token price drops, which makes user fully liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is bad (below the 0.95 close factor threshold).
  function test_liquidation_fuzz_SupplyTokenPriceDrop_Full_BigLiquidation_BadHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // 75% price drop -> supply = $2500
    // aim for ~0.94 health at liquidation time -> $2500 * 0.86 / 0.94 = ~$2287.23
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 10000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 2287.23e6,
        timeToSkip: 0,
        liquidationAmount: 2287.23e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: -75_00,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLe(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Supply token price drops, which makes user fully liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is bad (below the 0.95 close factor threshold).
  /// User is partially liquidated due to limited liquidator power.
  function test_liquidation_fuzz_SupplyTokenPriceDrop_Partial_BigLiquidation_BadHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // 75% price drop -> supply = $2500
    // aim for ~0.94 health at liquidation time -> $2500 * 0.86 / 0.94 = ~$2287.23
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 10000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 2287.23e6,
        timeToSkip: 0,
        // liquidator can only provide 1000 usdx
        liquidationAmount: 1000e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: -75_00,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: false
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLe(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Supply token price drops, which makes user half liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  function test_liquidation_fuzz_SupplyTokenPriceDrop_Partial_BigLiquidation_GoodHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // 75% price drop -> supply = $2500
    // aim for ~0.98 health at liquidation time -> $2500 * 0.86 / 0.98 = ~$2193.87
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 10000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 2193.87e6,
        timeToSkip: 0,
        liquidationAmount: 2193.87e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: -75_00,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: false
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGt(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow token price increases, which makes user fully liquidatable.
  /// It is a small liquidation (under the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  function test_liquidation_fuzz_BorrowTokenPriceIncrease_Full_SmallLiquidation_GoodHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // aim for ~0.98 health at liquidation time -> $100 * 0.86 / 0.98 = ~$87.75
    // 87.75 / 82.5 = ~1.063 -> ~6.3% price increase in borrow token
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 100e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 82.5e6,
        timeToSkip: 0,
        liquidationAmount: 82.5e6,
        receiveAToken: false,
        priceImpactToken: tokenList.usdx,
        priceImpactPercent: 6_30,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertLt(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLt(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGt(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow token price increases, which makes user fully liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is bad (below the 0.95 close factor threshold).
  function test_liquidation_fuzz_BorrowTokenPriceIncrease_Full_BigLiquidation_BadHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // aim for ~0.9 health at liquidation time -> $5000 * 0.86 / 0.9 = ~$4777.77
    // 4777.77 / 4000 = ~1.194 -> ~19.4% price increase in borrow token
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 5000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 4000e6,
        timeToSkip: 0,
        liquidationAmount: 4000e6,
        receiveAToken: false,
        priceImpactToken: tokenList.usdx,
        priceImpactPercent: 19_40,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLe(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow token price increases, which makes user fully liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is bad (below the 0.95 close factor threshold).
  /// User is partially liquidated due to limited liquidator power.
  function test_liquidation_fuzz_BorrowTokenPriceIncrease_Partial_BigLiquidation_BadHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // aim for ~0.9 health at liquidation time -> $5000 * 0.86 / 0.9 = ~$4777.77
    // 4777.77 / 4000 = ~1.194 -> ~19.4% price increase in borrow token
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 5000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 4000e6,
        timeToSkip: 0,
        // liquidator can only provide 4000 usdx
        liquidationAmount: 4000e6,
        receiveAToken: false,
        priceImpactToken: tokenList.usdx,
        priceImpactPercent: 19_40,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLe(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow token price increases, which makes user half liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  function test_liquidation_fuzz_Borrow_TokenPriceIncrease_Partial_BigLiquidation_GoodHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // aim for ~0.98 health at liquidation time -> $5000 * 0.86 / 0.98 = ~$4387.75
    // 4387.75 / 4000 = ~1.096 -> ~9.6% price increase in borrow token
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 5000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 4000e6,
        timeToSkip: 0,
        liquidationAmount: 4000e6,
        receiveAToken: false,
        priceImpactToken: tokenList.usdx,
        priceImpactPercent: 9_60,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: false
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGt(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow interest accrues, which makes user fully liquidatable.
  /// It is a small liquidation (under the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  function test_liquidation_fuzz_BorrowInterestAccrued_Full_SmallLiquidation_GoodHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // david withdraw 95000 USDX -> 5000 USDX are still supplied
    vm.prank(david);
    contracts.poolProxy.withdraw(tokenList.usdx, 95000e6, david);

    // borrow 1125 USDX -> utilization ratio for slope 1 is 22.5%/45% = 50% -> borrow rate is 2%
    // after 8 years, borrow debt = ~1125 * (1 + 0.02/31536000) ^ (8 * 31536000) = ~1320.2
    // health factor = 1500 * 0.86 / 1320.2 = 97.7%
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 1500e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 1125e6,
        timeToSkip: 8 * 365 days,
        liquidationAmount: 1321e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: 0,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertLt(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLt(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGt(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow interest accrues, which makes user fully liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is bad (below the 0.95 close factor threshold).
  function test_liquidation_fuzz_BorrowInterestAccrued_Full_BigLiquidation_BadHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // david withdraw 50000 USDX -> 50000 USDX are still supplied
    vm.prank(david);
    contracts.poolProxy.withdraw(tokenList.usdx, 50000e6, david);

    // borrow 11250 USDX -> utilization ratio for slope 1 is 22.5%/45% = 50% -> borrow rate is 2%
    // after 10 years, borrow debt = ~11250 * (1 + 0.02/31536000) ^ (10 * 31536000) = ~13740.78
    // health factor = 15000 * 0.86 / 13740.78 = 93.8%
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 15000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 11250e6,
        timeToSkip: 10 * 365 days,
        liquidationAmount: 13741e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: 0,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: true
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLe(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow interest accrues, which makes user fully liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is bad (below the 0.95 close factor threshold).
  /// User is partially liquidated due to limited liquidator power.
  function test_liquidation_fuzz_BorrowInterestAccrued_Partial_BigLiquidation_BadHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // david withdraw 50000 USDX -> 50000 USDX are still supplied
    vm.prank(david);
    contracts.poolProxy.withdraw(tokenList.usdx, 50000e6, david);

    // borrow 11250 USDX -> utilization ratio for slope 1 is 22.5%/45% = 50% -> borrow rate is 2%
    // after 10 years, borrow debt = ~11250 * (1 + 0.02/31536000) ^ (10 * 31536000) = ~13740.78
    // health factor = 15000 * 0.86 / 13740.78 = 93.8%
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 15000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 11250e6,
        timeToSkip: 10 * 365 days,
        // liquidator can only provide 12000 usdx
        liquidationAmount: 12000e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: 0,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: false
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertLe(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Borrow interest accrues, which makes user half liquidatable.
  /// It is a big liquidation (over the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  function test_liquidation_fuzz_BorrowInterestAccrued_Partial_BigLiquidation_GoodHealth(
    uint256 rwaTokenIndex
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    // david withdraw 50000 USDX -> 50000 USDX are still supplied
    vm.prank(david);
    contracts.poolProxy.withdraw(tokenList.usdx, 50000e6, david);

    // borrow 11250 USDX -> utilization ratio for slope 1 is 22.5%/45% = 50% -> borrow rate is 2%
    // after 8 years, borrow debt = ~11250 * (1 + 0.02/31536000) ^ (8 * 31536000) = ~13201.99
    // health factor = 15000 * 0.86 / 13201.99 = 97.7%
    LiquidationDataProvider.LiquidationInfo memory liquidationInfo = _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 15000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 11250e6,
        timeToSkip: 8 * 365 days,
        liquidationAmount: 13202e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: 0,
        liquidator: rwaTokenInfos[rwaTokenIndex].liquidator,
        expectedRevertData: new bytes(0),
        expectFullLiquidation: false
      })
    );

    assertGe(
      liquidationInfo.collateralInfo.collateralBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGe(
      liquidationInfo.debtInfo.debtBalanceInBaseCurrency,
      LiquidationLogic.MIN_BASE_MAX_CLOSE_FACTOR_THRESHOLD
    );
    assertGt(liquidationInfo.userInfo.healthFactor, LiquidationLogic.CLOSE_FACTOR_HF_THRESHOLD);
  }

  /// @dev Supply token price drops, which makes user fully liquidatable.
  /// It is a small liquidation (under the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  /// Liquidator opts for aToken instead of native token.
  function test_liquidation_fuzz_revertsWith_OnlyTreasuryRecipient(
    uint256 rwaTokenIndex,
    address liquidator
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    vm.assume(liquidator != report.treasury);

    // 85% price drop -> supply = $1500
    // aim for ~0.98 health at liquidation time -> $1500 * 0.86 / 0.98 = ~$1316.32
    _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 10000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 1316.32e6,
        timeToSkip: 0,
        liquidationAmount: 1316.32e6,
        receiveAToken: true,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: -85_00,
        liquidator: liquidator,
        expectedRevertData: bytes(Errors.RECIPIENT_NOT_TREASURY),
        expectFullLiquidation: false
      })
    );
  }

  function test_liquidation_revertsWith_OnlyTreasuryRecipient() public {
    for (uint256 i = 0; i < rwaTokenInfos.length; i++) {
      test_liquidation_fuzz_revertsWith_OnlyTreasuryRecipient(i, rwaTokenInfos[i].liquidator);
    }
  }

  /// @dev Supply token price drops, which makes user fully liquidatable.
  /// It is a small liquidation (under the $2000 base value threshold),
  /// and health factor is good (above the 0.95 close factor threshold).
  /// Liquidator is not authorized to hold the RWA token.
  function test_liquidation_fuzz_revertsWith_UnauthorizedRwaHolder(
    uint256 rwaTokenIndex,
    address liquidator
  ) public {
    rwaTokenIndex = bound(rwaTokenIndex, 0, rwaTokenInfos.length - 1);

    vm.assume(liquidator != rwaTokenInfos[rwaTokenIndex].liquidator);
    vm.assume(liquidator != rwaTokenInfos[rwaTokenIndex].user);
    vm.assume(liquidator != rwaTokenInfos[rwaTokenIndex].rwaAToken);

    // 85% price drop -> supply = $1500
    // aim for ~0.98 health at liquidation time -> $1500 * 0.86 / 0.98 = ~$1316.32
    _checkLiquidation(
      LiquidationCheck({
        user: rwaTokenInfos[rwaTokenIndex].user,
        supplyToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        supplyAmount: _getTokenAmount(rwaTokenInfos[rwaTokenIndex].rwaToken, 10000e8),
        borrowToken: tokenList.usdx,
        borrowAmount: 1316.32e6,
        timeToSkip: 0,
        liquidationAmount: 1316.32e6,
        receiveAToken: false,
        priceImpactToken: rwaTokenInfos[rwaTokenIndex].rwaToken,
        priceImpactPercent: -85_00,
        liquidator: liquidator,
        expectedRevertData: bytes('UNAUTHORIZED_RWA_HOLDER'),
        expectFullLiquidation: false
      })
    );
  }

  function test_liquidation_revertsWith_UnauthorizedRwaHolder() public {
    test_liquidation_fuzz_revertsWith_UnauthorizedRwaHolder(0, rwaTokenInfos[1].liquidator);
    test_liquidation_fuzz_revertsWith_UnauthorizedRwaHolder(1, rwaTokenInfos[0].liquidator);
    test_liquidation_fuzz_revertsWith_UnauthorizedRwaHolder(2, rwaTokenInfos[0].liquidator);
  }
}
