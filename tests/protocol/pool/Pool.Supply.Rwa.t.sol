// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';
import {AccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {IAToken, IERC20} from 'src/contracts/interfaces/IAToken.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {TestnetERC20} from 'src/contracts/mocks/testnet-helpers/TestnetERC20.sol';
import {EIP712SigUtils} from 'tests/utils/EIP712SigUtils.sol';
import {SupplyLogic} from 'src/contracts/protocol/libraries/logic/SupplyLogic.sol';

contract PoolSupplyRwaTests is TestnetProcedures {
  address internal aUSDX;
  address internal aBuidl;
  address aTokenTransferAdmin;

  function setUp() public {
    initTestEnvironment();

    aTokenTransferAdmin = makeAddr('ATOKEN_TRANSFER_ADMIN_1');

    (aUSDX, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(tokenList.usdx);
    (aBuidl, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(tokenList.buidl);

    vm.startPrank(poolAdmin);
    // authorize & mint BUIDL to alice
    buidl.authorize(alice, true);
    buidl.mint(alice, 100000e6);
    // grant Transfer Role to the aToken Transfer Admin
    AccessControl(aclManagerAddress).grantRole(
      keccak256('ATOKEN_TRANSFER_ROLE'),
      aTokenTransferAdmin
    );
    // authorize aBUIDL contract to hold BUIDL
    buidl.authorize(aBuidl, true);
    vm.stopPrank();

    vm.prank(alice);
    buidl.approve(report.poolProxy, UINT256_MAX);
  }

  function test_first_supply() public {
    test_fuzz_first_supply(1e6);
  }

  function test_fuzz_first_supply(uint256 supplyAmount) public {
    uint256 underlyingBalanceBefore = IERC20(tokenList.buidl).balanceOf(alice);
    supplyAmount = bound(supplyAmount, 1, underlyingBalanceBefore);

    vm.expectEmit(report.poolProxy);
    emit SupplyLogic.ReserveUsedAsCollateralEnabled(tokenList.buidl, alice);
    vm.expectEmit(report.poolProxy);
    emit SupplyLogic.Supply(tokenList.buidl, alice, alice, supplyAmount, 0);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, supplyAmount, alice, 0);

    assertEq(IERC20(tokenList.buidl).balanceOf(alice), underlyingBalanceBefore - supplyAmount);
    assertEq(IAToken(aBuidl).scaledBalanceOf(alice), supplyAmount);
  }

  // supply fails because onBehalfOf is not supported
  function test_reverts_supply_onBehalfOfNotSupported() public {
    test_fuzz_reverts_supply_onBehalfOfNotSupported({supplyAmount: 1e6, onBehalfOf: bob});
  }

  // fuzz - supply fails because onBehalfOf is not supported
  function test_fuzz_reverts_supply_onBehalfOfNotSupported(
    uint256 supplyAmount,
    address onBehalfOf
  ) public {
    supplyAmount = bound(supplyAmount, 1, IERC20(tokenList.buidl).balanceOf(alice));
    vm.assume(onBehalfOf != alice && onBehalfOf != aBuidl);

    vm.expectRevert(bytes(Errors.ON_BEHALF_OF_NOT_SUPPORTED));

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, supplyAmount, onBehalfOf, 0);
  }

  function test_supply_after_collateral_enabled() public {
    test_first_supply();
    uint256 supplyAmount = 2e6;
    uint256 underlyingBalanceBefore = IERC20(tokenList.buidl).balanceOf(alice);
    uint256 scaledBalanceTokenBase = IAToken(aBuidl).scaledBalanceOf(alice);

    vm.expectEmit(report.poolProxy);
    emit SupplyLogic.Supply(tokenList.buidl, alice, alice, supplyAmount, 0);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, supplyAmount, alice, 0);

    assertEq(IERC20(tokenList.buidl).balanceOf(alice), underlyingBalanceBefore - supplyAmount);
    assertEq(IAToken(aBuidl).scaledBalanceOf(alice), scaledBalanceTokenBase + supplyAmount);
  }

  function test_supplyWithPermit(
    uint128 userPk,
    uint128 supplyAmount,
    uint128 underlyingBalance
  ) public {
    vm.assume(userPk != 0);
    vm.assume(supplyAmount != 0 && supplyAmount <= underlyingBalance);
    address user = vm.addr(userPk);
    vm.assume(user != alice);

    vm.startPrank(poolAdmin);
    buidl.authorize(user, true);
    buidl.mint(user, underlyingBalance);
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
    emit SupplyLogic.ReserveUsedAsCollateralEnabled(tokenList.buidl, user);
    vm.expectEmit(report.poolProxy);
    emit SupplyLogic.Supply(tokenList.buidl, user, user, supplyAmount, 0);

    vm.prank(user);
    contracts.poolProxy.supplyWithPermit(
      tokenList.buidl,
      supplyAmount,
      user,
      0,
      permit.deadline,
      v,
      r,
      s
    );

    assertEq(IERC20(tokenList.buidl).balanceOf(user), underlyingBalance - supplyAmount);
    assertEq(IAToken(aBuidl).scaledBalanceOf(user), supplyAmount);
  }

  function test_supplyWithPermit_not_failing_if_permit_was_used(
    uint128 userPk,
    uint128 supplyAmount,
    uint128 underlyingBalance
  ) public {
    vm.assume(userPk != 0);
    vm.assume(supplyAmount != 0 && supplyAmount <= underlyingBalance);
    address user = vm.addr(userPk);

    vm.startPrank(poolAdmin);
    buidl.authorize(user, true);
    buidl.mint(user, underlyingBalance);
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

    buidl.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

    vm.prank(user);
    contracts.poolProxy.supplyWithPermit(
      tokenList.buidl,
      supplyAmount,
      user,
      0,
      permit.deadline,
      v,
      r,
      s
    );

    assertEq(IERC20(tokenList.buidl).balanceOf(user), underlyingBalance - supplyAmount);
    assertEq(IAToken(aBuidl).scaledBalanceOf(user), supplyAmount);
  }

  function test_supplyWithPermit_should_revert_if_permit_is_less_then_supply_amount(
    uint128 valueInPermit,
    uint128 supplyAmount
  ) public {
    uint128 userPk = 0xB000;
    vm.assume(supplyAmount != 0 && valueInPermit < supplyAmount);
    address user = vm.addr(userPk);

    vm.startPrank(poolAdmin);
    buidl.authorize(user, true);
    buidl.mint(user, supplyAmount);
    vm.stopPrank();

    EIP712SigUtils.Permit memory permit = EIP712SigUtils.Permit({
      owner: user,
      spender: address(contracts.poolProxy),
      value: supplyAmount - 1,
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

    vm.prank(user);
    vm.expectRevert(bytes('ERC20: transfer amount exceeds allowance'));
    contracts.poolProxy.supplyWithPermit(
      tokenList.buidl,
      supplyAmount,
      user,
      0,
      permit.deadline,
      v,
      r,
      s
    );
  }

  function test_deprecated_deposit() public {
    uint256 supplyAmount = 0.1e6;
    uint256 underlyingBalanceBefore = IERC20(tokenList.buidl).balanceOf(alice);

    vm.expectEmit(report.poolProxy);
    emit SupplyLogic.ReserveUsedAsCollateralEnabled(tokenList.buidl, alice);
    vm.expectEmit(report.poolProxy);
    emit SupplyLogic.Supply(tokenList.buidl, alice, alice, supplyAmount, 0);

    vm.prank(alice);
    contracts.poolProxy.deposit(tokenList.buidl, supplyAmount, alice, 0);

    assertEq(IERC20(tokenList.buidl).balanceOf(alice), underlyingBalanceBefore - supplyAmount);
    assertEq(IAToken(aBuidl).scaledBalanceOf(alice), supplyAmount);
  }

  // deposit fails if onBehalfOf does not match caller
  function test_reverts_deprecated_deposit_onBehalfOfNotSupported() public {
    uint256 supplyAmount = 1e6;
    test_fuzz_reverts_deposit_onBehalfOfNotSupported(supplyAmount, bob);
  }

  // fuzz - deposit fails
  function test_fuzz_reverts_deposit_onBehalfOfNotSupported(
    uint256 supplyAmount,
    address onBehalfOf
  ) public {
    supplyAmount = bound(supplyAmount, 1, IERC20(tokenList.buidl).balanceOf(alice));
    vm.assume(onBehalfOf != alice && onBehalfOf != aBuidl);

    vm.expectRevert(bytes(Errors.ON_BEHALF_OF_NOT_SUPPORTED));

    vm.prank(alice);
    contracts.poolProxy.deposit(tokenList.buidl, supplyAmount, onBehalfOf, 0);
  }

  function test_reverts_supply_invalidAmount() public {
    test_fuzz_reverts_supply_invalidAmount(alice);
  }

  function test_fuzz_reverts_supply_invalidAmount(address onBehalfOf) public {
    vm.expectRevert(bytes(Errors.INVALID_AMOUNT));

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 0, onBehalfOf, 0);
  }

  function test_reverts_supply_to_aToken() public {
    test_fuzz_reverts_supply_to_aToken(alice);
  }

  function test_fuzz_reverts_supply_to_aToken(address caller) public {
    uint256 supplyAmount = 0.2e6;

    vm.expectRevert(bytes(Errors.SUPPLY_TO_ATOKEN));

    vm.prank(caller);
    contracts.poolProxy.supply(tokenList.buidl, supplyAmount, aBuidl, 0);
  }

  function test_reverts_supply_reserveInactive() public {
    test_fuzz_reverts_supply_reserveInactive(alice);
  }

  function test_fuzz_reverts_supply_reserveInactive(address onBehalfOf) public {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveActive(tokenList.buidl, false);

    vm.expectRevert(bytes(Errors.RESERVE_INACTIVE));

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 0.2e6, onBehalfOf, 0);
  }

  function test_reverts_supply_reservePaused() public {
    test_fuzz_reverts_supply_reservePaused(alice);
  }

  function test_fuzz_reverts_supply_reservePaused(address onBehalfOf) public {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReservePause(tokenList.buidl, true, 0);

    vm.expectRevert(bytes(Errors.RESERVE_PAUSED));

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 0.2e6, onBehalfOf, 0);
  }

  function test_reverts_supply_reserveFrozen() public {
    test_fuzz_reverts_supply_reserveFrozen(alice);
  }

  function test_fuzz_reverts_supply_reserveFrozen(address onBehalfOf) public {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveFreeze(tokenList.buidl, true);

    vm.expectRevert(bytes(Errors.RESERVE_FROZEN));

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 0.2e6, onBehalfOf, 0);
  }

  function test_reverts_supply_cap() public {
    test_fuzz_reverts_supply_cap(alice);
  }

  function test_fuzz_reverts_supply_cap(address onBehalfOf) public {
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setSupplyCap(tokenList.buidl, 1);

    vm.expectRevert(bytes(Errors.SUPPLY_CAP_EXCEEDED));

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 2e6, onBehalfOf, 0);
  }
}
