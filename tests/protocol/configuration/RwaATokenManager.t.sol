// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IAccessControl} from 'src/contracts/dependencies/openzeppelin/contracts/IAccessControl.sol';
import {TestnetRWAERC20} from 'src/contracts/mocks/testnet-helpers/TestnetRWAERC20.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {IRwaAToken} from 'src/contracts/interfaces/IRwaAToken.sol';
import {stdError} from 'forge-std/Test.sol';
import {Vm} from 'forge-std/Vm.sol';
import {RwaATokenManager} from 'src/contracts/protocol/configuration/RwaATokenManager.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract RwaATokenManagerTest is TestnetProcedures {
  struct RwaATokenInfo {
    address rwaToken;
    address rwaAToken;
    address rwaATokenAdmin;
  }

  address internal aBuidlAdmin;
  address internal aUstbAdmin;
  address internal aWtgxxAdmin;

  RwaATokenManager internal rwaATokenManager;

  RwaATokenInfo[] internal rwaATokenInfos;

  function setUp() public {
    initTestEnvironment();

    aBuidlAdmin = makeAddr('aBUIDL_ADMIN');
    aUstbAdmin = makeAddr('aUSTB_ADMIN');
    aWtgxxAdmin = makeAddr('aWTGXX_ADMIN');

    rwaATokenManager = RwaATokenManager(rwaATokenTransferAdmin);

    rwaATokenInfos.push(
      RwaATokenInfo({
        rwaToken: tokenList.buidl,
        rwaAToken: rwaATokenList.aBuidl,
        rwaATokenAdmin: aBuidlAdmin
      })
    );
    rwaATokenInfos.push(
      RwaATokenInfo({
        rwaToken: tokenList.ustb,
        rwaAToken: rwaATokenList.aUstb,
        rwaATokenAdmin: aUstbAdmin
      })
    );
    rwaATokenInfos.push(
      RwaATokenInfo({
        rwaToken: tokenList.wtgxx,
        rwaAToken: rwaATokenList.aWtgxx,
        rwaATokenAdmin: aWtgxxAdmin
      })
    );
  }

  function test_owner() public {
    assertEq(rwaATokenManager.OWNER(), rwaATokenManagerOwner);
  }

  function test_authorizedATokenTransferRole() public {
    assertEq(
      rwaATokenManager.AUTHORIZED_ATOKEN_TRANSFER_ROLE(),
      keccak256('AUTHORIZED_ATOKEN_TRANSFER_ROLE')
    );
  }

  function test_fuzz_getATokenTransferRole(address aTokenAddress) public {
    assertEq(
      rwaATokenManager.getATokenTransferRole(aTokenAddress),
      keccak256(abi.encode(rwaATokenManager.AUTHORIZED_ATOKEN_TRANSFER_ROLE(), aTokenAddress))
    );
  }

  function test_getATokenTransferRole() public {
    test_fuzz_getATokenTransferRole(rwaATokenList.aBuidl);
  }

  function test_reverts_fuzz_addATokenTransferRole_AccountIsMissingDefaultAdminRole(
    uint256 rwaATokenIndex,
    address sender
  ) public {
    vm.assume(sender != rwaATokenManagerOwner);

    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    vm.expectRevert(
      abi.encodePacked(
        'AccessControl: account ',
        vm.toLowercase(vm.toString(sender)),
        ' is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );

    vm.prank(sender);
    rwaATokenManager.addATokenTransferRole(rwaATokenInfo.rwaAToken, rwaATokenInfo.rwaATokenAdmin);
  }

  function test_reverts_addATokenTransferRole_AccountIsMissingDefaultAdminRole() public {
    test_reverts_fuzz_addATokenTransferRole_AccountIsMissingDefaultAdminRole({
      rwaATokenIndex: 0,
      sender: poolAdmin
    });
  }

  function test_fuzz_addATokenTransferRole(uint256 rwaATokenIndex) public {
    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    vm.expectEmit(address(rwaATokenManager));
    emit IAccessControl.RoleGranted(
      rwaATokenManager.getATokenTransferRole(rwaATokenInfo.rwaAToken),
      rwaATokenInfo.rwaATokenAdmin,
      rwaATokenManagerOwner
    );

    vm.prank(rwaATokenManagerOwner);
    rwaATokenManager.addATokenTransferRole(rwaATokenInfo.rwaAToken, rwaATokenInfo.rwaATokenAdmin);
  }

  function test_addATokenTransferRole_Twice() public {
    test_fuzz_addATokenTransferRole(0);

    vm.recordLogs();

    vm.prank(rwaATokenManagerOwner);
    rwaATokenManager.addATokenTransferRole(rwaATokenList.aBuidl, aBuidlAdmin);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 0);
  }

  function test_reverts_fuzz_removeATokenTransferRole_AccountIsMissingDefaultAdminRole(
    uint256 rwaATokenIndex,
    address sender
  ) public {
    vm.assume(sender != rwaATokenManagerOwner);

    uint256 rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    vm.expectRevert(
      abi.encodePacked(
        'AccessControl: account ',
        vm.toLowercase(vm.toString(sender)),
        ' is missing role 0x0000000000000000000000000000000000000000000000000000000000000000'
      )
    );

    vm.prank(sender);
    rwaATokenManager.removeATokenTransferRole(
      rwaATokenInfo.rwaAToken,
      rwaATokenInfo.rwaATokenAdmin
    );
  }

  function test_reverts_removeATokenTransferRole_AccountIsMissingDefaultAdminRole() public {
    test_reverts_fuzz_removeATokenTransferRole_AccountIsMissingDefaultAdminRole({
      rwaATokenIndex: 0,
      sender: poolAdmin
    });
  }

  function test_fuzz_removeATokenTransferRole(uint256 rwaATokenIndex) public {
    uint256 rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    test_fuzz_addATokenTransferRole(rwaATokenIndex);

    vm.expectEmit(address(rwaATokenManager));
    emit IAccessControl.RoleRevoked(
      rwaATokenManager.getATokenTransferRole(rwaATokenInfo.rwaAToken),
      rwaATokenInfo.rwaATokenAdmin,
      rwaATokenManagerOwner
    );

    vm.prank(rwaATokenManagerOwner);
    rwaATokenManager.removeATokenTransferRole(
      rwaATokenInfo.rwaAToken,
      rwaATokenInfo.rwaATokenAdmin
    );
  }

  function test_fuzz_removeATokenTransfeRole_NoEffect(uint256 rwaATokenIndex) public {
    uint256 rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    vm.recordLogs();

    vm.prank(rwaATokenManagerOwner);
    rwaATokenManager.removeATokenTransferRole(
      rwaATokenInfo.rwaAToken,
      rwaATokenInfo.rwaATokenAdmin
    );

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(entries.length, 0);
  }

  function test_fuzz_hasATokenTransferRole_True(uint256 rwaATokenIndex) public {
    uint256 rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    test_fuzz_addATokenTransferRole(rwaATokenIndex);

    assertTrue(
      rwaATokenManager.hasATokenTransferRole(rwaATokenInfo.rwaAToken, rwaATokenInfo.rwaATokenAdmin)
    );
  }

  function test_fuzz_hasATokenTransferRole_False(address aTokenAddress, address account) public {
    assertFalse(rwaATokenManager.hasATokenTransferRole(aTokenAddress, account));
  }

  /// @dev aBuidl admin is grante permission, and then it is revoked
  function test_fuzz_hasATokenTransfer_False_Scenario() public {
    address aTokenAddress = rwaATokenInfos[0].rwaAToken;

    test_fuzz_hasATokenTransferRole_True(0);
    test_fuzz_hasATokenTransferRole_False(aTokenAddress, poolAdmin);
    test_fuzz_hasATokenTransferRole_False(aTokenAddress, rwaATokenInfos[1].rwaATokenAdmin);
    test_fuzz_hasATokenTransferRole_False(aTokenAddress, rwaATokenInfos[2].rwaATokenAdmin);

    vm.prank(rwaATokenManagerOwner);
    rwaATokenManager.removeATokenTransferRole(rwaATokenList.aBuidl, aBuidlAdmin);
    test_fuzz_hasATokenTransferRole_False(aTokenAddress, rwaATokenInfos[1].rwaATokenAdmin);
  }

  function test_reverts_fuzz_transferRwaAToken_NotATokenTransferRole(
    uint256 rwaATokenIndex,
    address sender,
    address from,
    address to,
    uint256 amount
  ) public {
    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    vm.expectRevert(
      abi.encodePacked(
        'AccessControl: account ',
        vm.toLowercase(vm.toString(sender)),
        ' is missing role ',
        vm.toString(rwaATokenManager.getATokenTransferRole(rwaATokenInfo.rwaAToken))
      )
    );

    vm.prank(sender);
    rwaATokenManager.transferRwaAToken(rwaATokenInfo.rwaAToken, from, to, amount);
  }

  function test_reverts_transferRwaAToken_NotATokenTransferRole() public {
    test_fuzz_addATokenTransferRole(0);
    test_reverts_fuzz_transferRwaAToken_NotATokenTransferRole({
      rwaATokenIndex: 0,
      sender: rwaATokenManagerOwner,
      from: alice,
      to: bob,
      amount: 0
    });
  }

  function test_reverts_fuzz_transferRwaAToken_NotEnoughBalance(
    uint256 rwaATokenIndex,
    address from,
    address to,
    uint256 amount
  ) public {
    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    amount = bound(amount, 1, type(uint128).max);

    test_fuzz_addATokenTransferRole(rwaATokenIndex);

    vm.expectRevert(stdError.arithmeticError);

    vm.prank(rwaATokenInfo.rwaATokenAdmin);
    rwaATokenManager.transferRwaAToken(rwaATokenInfo.rwaAToken, from, to, amount);
  }

  function test_reverts_fuzz_transferRwaAToken_CallerNotATokenTransferAdmin(
    uint256 rwaATokenIndex,
    address from,
    address to,
    uint256 amount
  ) public {
    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    test_fuzz_addATokenTransferRole(rwaATokenIndex);

    vm.startPrank(poolAdmin);
    IAccessControl(report.aclManager).revokeRole(
      // fetch role from aBuild (it is the same for all RwaATokens)
      IRwaAToken(rwaATokenList.aBuidl).AUTHORIZED_ATOKEN_TRANSFER_ROLE(),
      rwaATokenTransferAdmin
    );
    vm.stopPrank();

    vm.expectRevert(bytes(Errors.CALLER_NOT_ATOKEN_TRANSFER_ADMIN));

    vm.prank(rwaATokenInfo.rwaATokenAdmin);
    rwaATokenManager.transferRwaAToken(rwaATokenInfo.rwaAToken, from, to, amount);
  }

  function test_reverts_fuzz_transferRwaAToken_AuthorizedTransferFails(
    uint256 rwaATokenIndex,
    address from,
    address to,
    uint256 amount
  ) public {
    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    test_fuzz_addATokenTransferRole(rwaATokenIndex);

    vm.mockCallRevert(
      rwaATokenInfo.rwaAToken,
      abi.encodeCall(IRwaAToken.authorizedTransfer, (from, to, amount)),
      bytes('INTERNAL_RWA_ATOKEN_REVERT')
    );

    vm.expectRevert(bytes('INTERNAL_RWA_ATOKEN_REVERT'));

    vm.prank(rwaATokenInfo.rwaATokenAdmin);
    rwaATokenManager.transferRwaAToken(rwaATokenInfo.rwaAToken, from, to, amount);
  }

  function test_transferRwaAToken(
    uint256 rwaATokenIndex,
    address from,
    address to,
    uint256 amount
  ) public {
    rwaATokenIndex = bound(rwaATokenIndex, 0, rwaATokenInfos.length - 1);
    RwaATokenInfo memory rwaATokenInfo = rwaATokenInfos[rwaATokenIndex];

    amount = bound(amount, 1, type(uint128).max);

    test_fuzz_addATokenTransferRole(rwaATokenIndex);

    vm.startPrank(poolAdmin);
    TestnetRWAERC20(rwaATokenInfo.rwaToken).authorize(from, true);
    TestnetRWAERC20(rwaATokenInfo.rwaToken).mint(from, amount);
    vm.stopPrank();

    vm.startPrank(from);
    TestnetRWAERC20(rwaATokenInfo.rwaToken).approve(report.poolProxy, amount);
    contracts.poolProxy.supply(rwaATokenInfo.rwaToken, amount, from, 0);
    vm.stopPrank();

    assertEq(TestnetRWAERC20(rwaATokenInfo.rwaAToken).balanceOf(from), amount);
    assertEq(TestnetRWAERC20(rwaATokenInfo.rwaAToken).balanceOf(to), 0);

    vm.prank(rwaATokenInfo.rwaATokenAdmin);
    bool success = rwaATokenManager.transferRwaAToken(rwaATokenInfo.rwaAToken, from, to, amount);

    assertTrue(success);

    assertEq(TestnetRWAERC20(rwaATokenInfo.rwaAToken).balanceOf(from), 0);
    assertEq(TestnetRWAERC20(rwaATokenInfo.rwaAToken).balanceOf(to), amount);
  }
}
