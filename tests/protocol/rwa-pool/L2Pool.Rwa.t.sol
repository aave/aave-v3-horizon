// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {IAaveOracle} from 'src/contracts/interfaces/IAaveOracle.sol';
import {L2Encoder} from 'src/contracts/helpers/L2Encoder.sol';
import {IL2Pool} from 'src/contracts/interfaces/IL2Pool.sol';
import {IReserveInterestRateStrategy} from 'src/contracts/interfaces/IReserveInterestRateStrategy.sol';
import {BorrowLogic} from 'src/contracts/protocol/libraries/logic/BorrowLogic.sol';
import {LiquidationLogic} from 'src/contracts/protocol/libraries/logic/LiquidationLogic.sol';
import {TestnetERC20} from 'src/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {TestnetProcedures} from '../../utils/TestnetProcedures.sol';
import {PoolRwaTests, DataTypes, Errors, IERC20, IPool} from './Pool.Rwa.t.sol';
import {EIP712SigUtils} from '../../utils/EIP712SigUtils.sol';

/// @dev All Pool.Rwa.t.sol tests are run as L2Pool via inheriting PoolRwaTests
contract L2PoolRwaTests is PoolRwaTests {
  using stdStorage for StdStorage;

  IPool internal pool;
  IL2Pool internal l2Pool;
  L2Encoder internal l2Encoder;

  function setUp() public override {
    initL2TestEnvironment();

    pool = IPool(report.poolProxy);
    l2Pool = IL2Pool(report.poolProxy);
    l2Encoder = L2Encoder(report.l2Encoder);
  }

  function test_l2_supply() public {
    bytes32 encodedInput = l2Encoder.encodeSupplyParams(tokenList.buidl, 1e6, 0);

    vm.expectEmit(report.poolProxy);
    emit IPool.Supply(tokenList.buidl, alice, alice, 1e6, 0);

    vm.prank(alice);
    l2Pool.supply(encodedInput);
  }

  function test_l2_supply_permit(uint128 userPk, uint128 supplyAmount) public {
    vm.assume(userPk != 0);
    vm.assume(supplyAmount != 0);
    address user = vm.addr(userPk);

    vm.startPrank(poolAdmin);
    buidl.authorize(user, true);
    buidl.mint(user, supplyAmount);
    vm.stopPrank();

    EIP712SigUtils.Permit memory permit = EIP712SigUtils.Permit({
      owner: user,
      spender: address(contracts.poolProxy),
      value: supplyAmount,
      nonce: 0,
      deadline: block.timestamp + 1 days
    });
    bytes32 digest = EIP712SigUtils.getTypedDataHash(
      permit,
      bytes(TestnetERC20(tokenList.buidl).name()),
      bytes('1'),
      tokenList.buidl
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    vm.expectEmit(report.poolProxy);
    emit IPool.ReserveUsedAsCollateralEnabled(tokenList.buidl, user);
    vm.expectEmit(report.poolProxy);
    emit IPool.Supply(tokenList.buidl, user, user, supplyAmount, 0);

    (bytes32 encodedInput1, bytes32 encodedInput2, bytes32 encodedInput3) = l2Encoder
      .encodeSupplyWithPermitParams(tokenList.buidl, permit.value, 0, permit.deadline, v, r, s);

    vm.prank(user);
    l2Pool.supplyWithPermit(encodedInput1, encodedInput2, encodedInput3);
  }

  function test_l2_withdraw() public {
    test_l2_supply();

    bytes32 encodedInput = l2Encoder.encodeWithdrawParams(tokenList.buidl, UINT256_MAX);
    vm.expectEmit(report.poolProxy);
    emit IPool.Withdraw(tokenList.buidl, alice, alice, 1e6);

    vm.prank(alice);
    l2Pool.withdraw(encodedInput);
  }

  function test_l2_partial_withdraw() public {
    test_l2_supply();

    bytes32 encodedInput = l2Encoder.encodeWithdrawParams(tokenList.buidl, 0.5e6);
    vm.expectEmit(report.poolProxy);
    emit IPool.Withdraw(tokenList.buidl, alice, alice, 0.5e6);

    vm.prank(alice);
    l2Pool.withdraw(encodedInput);
  }

  function test_l2_borrow() public {
    _seedLiquidity({token: tokenList.usdx, amount: 100_000e6, isRwa: false});

    test_l2_supply();

    bytes32 encodedInput = l2Encoder.encodeBorrowParams(tokenList.usdx, 0.2e6, 2, 0);

    vm.expectEmit(address(contracts.poolProxy));
    emit IPool.Borrow(
      tokenList.usdx,
      alice,
      alice,
      0.2e6,
      DataTypes.InterestRateMode(2),
      _calculateInterestRates(0.2e6, tokenList.usdx),
      0
    );

    vm.prank(alice);
    l2Pool.borrow(encodedInput);
  }

  function test_l2_repay() public {
    test_l2_borrow();

    bytes32 encodedInput = l2Encoder.encodeRepayParams(tokenList.usdx, UINT256_MAX, 2);

    vm.prank(alice);
    l2Pool.repay(encodedInput);
  }

  function test_l2_repay_permit(
    uint128 userPk,
    uint128 supplyAmount,
    uint128 underlyingBalance,
    uint128 borrowAmount,
    uint128 repayAmount
  ) public {
    vm.assume(userPk != 0);
    underlyingBalance = uint128(bound(underlyingBalance, 2, type(uint120).max));
    supplyAmount = uint128(bound(supplyAmount, 2, underlyingBalance));
    borrowAmount = uint128(bound(borrowAmount, 1, supplyAmount / 2));
    repayAmount = uint128(bound(repayAmount, 1, borrowAmount));

    _seedLiquidity({token: tokenList.usdx, amount: borrowAmount, isRwa: false});

    address user = vm.addr(userPk);

    vm.startPrank(poolAdmin);
    buidl.authorize(user, true);
    buidl.mint(user, underlyingBalance);
    vm.stopPrank();

    vm.startPrank(user);
    buidl.approve(address(contracts.poolProxy), supplyAmount);
    pool.supply(tokenList.buidl, supplyAmount, user, 0);
    pool.borrow(tokenList.usdx, borrowAmount, 2, 0, user);
    vm.warp(block.timestamp + 10 days);

    EIP712SigUtils.Permit memory permit = EIP712SigUtils.Permit({
      owner: user,
      spender: address(contracts.poolProxy),
      value: repayAmount,
      nonce: 0,
      deadline: block.timestamp + 1 days
    });
    bytes32 digest = EIP712SigUtils.getTypedDataHash(
      permit,
      bytes(TestnetERC20(tokenList.usdx).name()),
      bytes('1'),
      tokenList.usdx
    );

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, digest);

    vm.expectEmit(report.poolProxy);
    emit IPool.Repay(tokenList.usdx, user, user, permit.value, false);

    (bytes32 encodedInput1, bytes32 encodedInput2, bytes32 encodedInput3) = l2Encoder
      .encodeRepayWithPermitParams(tokenList.usdx, permit.value, 2, permit.deadline, v, r, s);

    l2Pool.repayWithPermit(encodedInput1, encodedInput2, encodedInput3);
    vm.stopPrank();
  }

  function test_l2_repay_atokens() public {
    test_l2_borrow();
    bytes32 encodedInput = l2Encoder.encodeRepayWithATokensParams(tokenList.usdx, UINT256_MAX, 2);

    _supplyUsdx(); // supply usdx so that alice has aTokens to repay with

    vm.prank(alice);
    l2Pool.repayWithATokens(encodedInput);
  }

  function test_l2_set_user_collateral() public {
    test_l2_supply();

    bytes32 encodedInput = l2Encoder.encodeSetUserUseReserveAsCollateral(tokenList.buidl, false);
    vm.prank(alice);
    l2Pool.setUserUseReserveAsCollateral(encodedInput);
  }

  function test_l2_liquidationCall() public {
    vm.startPrank(carol);

    pool.supply(tokenList.buidl, 100_000e6, carol, 0);
    pool.supply(tokenList.usdx, 100_000e6, carol, 0);

    vm.stopPrank();
    vm.startPrank(alice);

    pool.supply(tokenList.buidl, 30_000e6, alice, 0);
    pool.borrow(tokenList.usdx, 20_500e6, 2, 0, alice);
    vm.warp(block.timestamp + 30 days);
    pool.borrow(tokenList.usdx, 1000e6, 2, 0, alice);
    vm.warp(block.timestamp + 30 days);

    vm.stopPrank();

    stdstore
      .target(IAaveOracle(report.aaveOracle).getSourceOfAsset(tokenList.buidl))
      .sig('_latestAnswer()')
      .checked_write(
        _calcPrice(IAaveOracle(report.aaveOracle).getAssetPrice(tokenList.buidl), 30_00)
      );

    vm.expectEmit(true, true, true, false, address(contracts.poolProxy));
    emit LiquidationLogic.LiquidationCall(tokenList.buidl, tokenList.usdx, alice, 0, 0, bob, false);

    (bytes32 encodedInput1, bytes32 encodedInput2) = l2Encoder.encodeLiquidationCall(
      tokenList.buidl,
      tokenList.usdx,
      alice,
      UINT256_MAX,
      false
    );

    // Liquidate
    vm.prank(bob);
    l2Pool.liquidationCall(encodedInput1, encodedInput2);
  }

  function _supplyUsdx() internal {
    bytes32 encodedInput = l2Encoder.encodeSupplyParams(tokenList.usdx, 1000e6, 0);

    vm.prank(alice);
    l2Pool.supply(encodedInput);
  }

  // TODO: l2 permit tests to match base
}
