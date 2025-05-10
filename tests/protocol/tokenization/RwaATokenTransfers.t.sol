// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/AccessControl.sol';
import {IERC20} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {RWAAToken} from 'src/contracts/protocol/tokenization/RWAAToken.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract RwaATokenTransferTests is TestnetProcedures {
  RWAAToken public aBuidl;

  address aTokenTransferAdmin;

  function setUp() public {
    initTestEnvironment(false);

    aTokenTransferAdmin = makeAddr('ATOKEN_TRANSFER_ADMIN_1');

    (address aBuidlAddress, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );
    aBuidl = RWAAToken(aBuidlAddress);

    vm.startPrank(poolAdmin);
    // authorize & mint BUIDL to alice
    buidl.authorize(alice, true);
    buidl.mint(alice, 100e6);
    // authorize & mint BUIDL to carol
    buidl.authorize(carol, true);
    buidl.mint(carol, 1e6);
    // grant Transfer Role to the aToken Transfer Admin
    AccessControl(aclManagerAddress).grantRole(aBuidl.ATOKEN_TRANSFER_ROLE(), aTokenTransferAdmin);
    // authorize aBUIDL contract to hold BUIDL
    buidl.authorize(aBuidlAddress, true);
    vm.stopPrank();

    vm.startPrank(alice);
    buidl.approve(report.poolProxy, UINT256_MAX);
    contracts.poolProxy.supply(tokenList.buidl, 100e6, alice, 0);
    vm.stopPrank();

    vm.startPrank(carol);
    buidl.approve(report.poolProxy, UINT256_MAX);
    contracts.poolProxy.supply(tokenList.buidl, 1e6, carol, 0);
    vm.stopPrank();
  }

  function test_rwaAToken_transfer_fuzz_revertsWith_OperationNotSupported(
    address sender,
    address to,
    uint256 amount
  ) public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));

    vm.prank(sender);
    aBuidl.transfer(to, amount);
  }

  function test_rwaAToken_transfer_revertsWith_OperationNotSupported() public {
    test_rwaAToken_transfer_fuzz_revertsWith_OperationNotSupported({
      sender: alice,
      to: bob,
      amount: 0
    });
  }

  function test_rwaAToken_transferFrom_fuzz_revertsWith_OperationNotSupported(
    address sender,
    address from,
    address to,
    uint256 amount
  ) public {
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));

    vm.prank(sender);
    aBuidl.transferFrom(from, to, amount);
  }

  function test_rwaAToken_transferFrom_revertsWith_OperationNotSupported() public {
    test_rwaAToken_transferFrom_fuzz_revertsWith_OperationNotSupported({
      sender: aTokenTransferAdmin,
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_rwaAToken_forceTransfer_fuzz_by_aTokenTransferAdmin(
    address from,
    address to,
    uint256 amount
  ) public {
    uint256 fromBalanceBefore = aBuidl.balanceOf(from);
    amount = bound(amount, 0, fromBalanceBefore);

    uint256 toBalanceBefore = aBuidl.balanceOf(to);

    vm.expectEmit(address(aBuidl));
    emit IERC20.Transfer(from, to, amount);

    vm.prank(aTokenTransferAdmin);
    bool success = aBuidl.forceTransfer(from, to, amount);
    assertTrue(success, 'forceTransfer returned false');

    assertEq(aBuidl.balanceOf(from), fromBalanceBefore - amount);
    assertEq(aBuidl.balanceOf(to), toBalanceBefore + amount);
  }

  function test_rwaAToken_forceTransfer_by_aTokenTransferAdmin_all() public {
    test_rwaAToken_forceTransfer_fuzz_by_aTokenTransferAdmin({
      from: alice,
      to: bob,
      amount: aBuidl.balanceOf(alice)
    });
  }

  function test_rwaAToken_forceTransfer_by_aTokenTransferAdmin_partial() public {
    test_rwaAToken_forceTransfer_fuzz_by_aTokenTransferAdmin({from: alice, to: bob, amount: 1});
  }

  function test_rwaAToken_forceTransfer_by_aTokenTransferAdmin_zero() public {
    test_rwaAToken_forceTransfer_fuzz_by_aTokenTransferAdmin({from: alice, to: bob, amount: 0});
  }

  function test_rwaAToken_forceTransfer_fuzz_revertsWith_CallerNotATokenTransferAdmin(
    address sender,
    address from,
    address to,
    uint256 amount
  ) public {
    vm.assume(sender != aTokenTransferAdmin);

    vm.expectRevert(bytes(Errors.CALLER_NOT_ATOKEN_TRANSFER_ADMIN));

    vm.prank(sender);
    aBuidl.forceTransfer(from, to, amount);
  }

  function test_rwaAToken_forceTransfer_revertsWith_CallerNotATokenTransferAdmin() public {
    test_rwaAToken_forceTransfer_fuzz_revertsWith_CallerNotATokenTransferAdmin({
      sender: carol,
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_rwaAToken_transferOnLiquidation_fuzz_revertsWith_RecipientNotTreasury(
    address from,
    address to,
    uint256 amount
  ) public {
    vm.assume(to != report.treasury);

    vm.expectRevert(bytes(Errors.RECIPIENT_NOT_TREASURY));

    vm.prank(report.poolProxy);
    aBuidl.transferOnLiquidation(from, to, amount);
  }

  function test_rwaAToken_transferOnLiquidation_revertsWith_RecipientNotTreasury() public {
    test_rwaAToken_transferOnLiquidation_fuzz_revertsWith_RecipientNotTreasury({
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_rwaAToken_transferOnLiquidation_fuzz_revertsWith_CallerNotPool(
    address sender,
    address from,
    uint256 amount
  ) public {
    vm.assume(sender != report.poolProxy);

    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));

    vm.prank(sender);
    aBuidl.transferOnLiquidation(from, report.treasury, amount);
  }

  function test_rwaAToken_transferOnLiquidation_revertsWith_CallerNotPool() public {
    test_rwaAToken_transferOnLiquidation_fuzz_revertsWith_CallerNotPool({
      sender: carol,
      from: alice,
      amount: 0
    });
  }

  function test_rwaAToken_transferOnLiquidation_fuzz(address from, uint256 amount) public {
    uint256 fromBalanceBefore = aBuidl.balanceOf(from);
    amount = bound(amount, 0, fromBalanceBefore);

    uint256 treasuryBalanceBefore = aBuidl.balanceOf(report.treasury);

    vm.expectEmit(address(aBuidl));
    emit IERC20.Transfer(from, report.treasury, amount);

    vm.prank(report.poolProxy);
    aBuidl.transferOnLiquidation(from, report.treasury, amount);

    assertEq(aBuidl.balanceOf(from), fromBalanceBefore - amount);
    assertEq(aBuidl.balanceOf(report.treasury), treasuryBalanceBefore + amount);
  }

  function test_rwaAToken_transferOnLiqudation_all() public {
    test_rwaAToken_transferOnLiquidation_fuzz({from: alice, amount: aBuidl.balanceOf(alice)});
  }

  function test_rwaAToken_transferOnLiquidation_partial() public {
    test_rwaAToken_transferOnLiquidation_fuzz({from: alice, amount: 1});
  }

  function test_rwaAToken_transferOnLiquidation_zero() public {
    test_rwaAToken_transferOnLiquidation_fuzz({from: alice, amount: 0});
  }
}
