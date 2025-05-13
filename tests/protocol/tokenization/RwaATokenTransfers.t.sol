// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from 'src/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {RwaAToken} from 'src/contracts/protocol/tokenization/RwaAToken.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol'

contract RwaATokenTransferTests is TestnetProcedures {
  RwaAToken public aBuidl;

  function setUp() public {
    initTestEnvironment();
    aBuidl = RwaAToken(rwaATokenList.aBuidl);

    vm.prank(alice);
    contracts.poolProxy.supply(tokenList.buidl, 100e6, alice, 0);

    vm.prank(carol);
    contracts.poolProxy.supply(tokenList.buidl, 1e6, carol, 0);
  }

  function test_fuzz_reverts_rwaAToken_transfer_OperationNotSupported(
    address sender,
    address to,
    uint256 amount
  ) public {
    vm.assume(sender != report.poolConfiguratorProxy); // otherwise the proxy will not fallback

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));

    vm.prank(sender);
    aBuidl.transfer(to, amount);
  }

  function test_reverts_rwaAToken_transfer_OperationNotSupported() public {
    test_fuzz_reverts_rwaAToken_transfer_OperationNotSupported({sender: alice, to: bob, amount: 0});
  }

  function test_fuzz_reverts_rwaAToken_transferFrom_OperationNotSupported(
    address sender,
    address from,
    address to,
    uint256 amount
  ) public {
    vm.assume(sender != report.poolConfiguratorProxy); // otherwise the proxy will not fallback
    
    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));

    vm.prank(sender);
    aBuidl.transferFrom(from, to, amount);
  }

  function test_reverts_rwaAToken_transferFrom_OperationNotSupported() public {
    test_fuzz_reverts_rwaAToken_transferFrom_OperationNotSupported({
      sender: rwaATokenTransferAdmin,
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_fuzz_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin(
    address from,
    address to,
    uint256 amount
  ) public {
    uint256 fromBalanceBefore = aBuidl.balanceOf(from);
    amount = bound(amount, 0, fromBalanceBefore);

    uint256 toBalanceBefore = aBuidl.balanceOf(to);

    vm.expectEmit(address(aBuidl));
    emit IERC20.Transfer(from, to, amount);

    vm.prank(rwaATokenTransferAdmin);
    bool success = aBuidl.forceTransfer(from, to, amount);
    assertTrue(success, 'forceTransfer returned false');

    assertEq(aBuidl.balanceOf(from), fromBalanceBefore - amount);
    assertEq(aBuidl.balanceOf(to), toBalanceBefore + amount);
  }

  function test_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin_all() public {
    test_fuzz_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin({
      from: alice,
      to: bob,
      amount: aBuidl.balanceOf(alice)
    });
  }

  function test_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin_partial() public {
    test_fuzz_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin({from: alice, to: bob, amount: 1});
  }

  function test_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin_zero() public {
    test_fuzz_rwaAToken_forceTransfer_by_rwaATokenTransferAdmin({from: alice, to: bob, amount: 0});
  }

  function test_fuzz_reverts_rwaAToken_forceTransfer_CallerNotRwaATokenTransferAdmin(
    address sender,
    address from,
    address to,
    uint256 amount
  ) public {
    vm.assume(sender != aTokenTransferAdmin);
    vm.assume(sender != report.poolConfiguratorProxy); // otherwise the proxy will not fallback

    vm.expectRevert(bytes(Errors.CALLER_NOT_ATOKEN_TRANSFER_ADMIN));

    vm.prank(sender);
    aBuidl.forceTransfer(from, to, amount);
  }

  function test_reverts_rwaAToken_forceTransfer_CallerNotRwaATokenTransferAdmin() public {
    test_fuzz_reverts_rwaAToken_forceTransfer_CallerNotRwaATokenTransferAdmin({
      sender: carol,
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_fuzz_reverts_rwaAToken_transferOnLiquidation_RecipientNotTreasury(
    address from,
    address to,
    uint256 amount
  ) public {
    vm.assume(to != report.treasury);

    vm.expectRevert(bytes(Errors.RECIPIENT_NOT_TREASURY));

    vm.prank(report.poolProxy);
    aBuidl.transferOnLiquidation(from, to, amount);
  }

  function test_reverts_rwaAToken_transferOnLiquidation_RecipientNotTreasury() public {
    test_fuzz_reverts_rwaAToken_transferOnLiquidation_RecipientNotTreasury({
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_fuzz_reverts_rwaAToken_transferOnLiquidation_CallerNotPool(
    address sender,
    address from,
    uint256 amount
  ) public {
    vm.assume(sender != report.poolProxy);
    vm.assume(sender != report.poolConfiguratorProxy); // otherwise the proxy will not fallback

    vm.expectRevert(bytes(Errors.CALLER_MUST_BE_POOL));

    vm.prank(sender);
    aBuidl.transferOnLiquidation(from, report.treasury, amount);
  }

  function test_reverts_rwaAToken_transferOnLiquidation_CallerNotPool() public {
    test_fuzz_reverts_rwaAToken_transferOnLiquidation_CallerNotPool({
      sender: carol,
      from: alice,
      amount: 0
    });
  }

  function test_fuzz_rwaAToken_transferOnLiquidation(address from, uint256 amount) public {
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
    test_fuzz_rwaAToken_transferOnLiquidation({from: alice, amount: aBuidl.balanceOf(alice)});
  }

  function test_rwaAToken_transferOnLiquidation_partial() public {
    test_fuzz_rwaAToken_transferOnLiquidation({from: alice, amount: 1});
  }

  function test_rwaAToken_transferOnLiquidation_zero() public {
    test_fuzz_rwaAToken_transferOnLiquidation({from: alice, amount: 0});
  }
}
