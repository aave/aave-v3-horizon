// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/StdStorage.sol';

import {IAToken, IERC20} from 'src/contracts/interfaces/IAToken.sol';
import {IPool, DataTypes} from 'src/contracts/interfaces/IPool.sol';
import {IPoolAddressesProvider} from 'src/contracts/interfaces/IPoolAddressesProvider.sol';
import {PoolInstance} from 'src/contracts/instances/PoolInstance.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {ReserveConfiguration} from 'src/contracts/protocol/pool/PoolConfigurator.sol';
import {WadRayMath} from 'src/contracts/protocol/libraries/math/WadRayMath.sol';
import {IAaveOracle} from 'src/contracts/interfaces/IAaveOracle.sol';
import {TestnetProcedures} from 'tests/utils/TestnetProcedures.sol';

contract PoolRwaTests is TestnetProcedures {
  IPool internal pool;

  function setUp() public virtual {
    initTestEnvironment();

    (address aBorrowableBuidlAddress, , ) = contracts
      .protocolDataProvider
      .getReserveTokensAddresses(tokenList.borrowableBuidl);

    vm.startPrank(poolAdmin);
    // authorize & mint BUIDL to bob
    borrowableBuidl.authorize(bob, true);
    borrowableBuidl.mint(bob, 100_000e6);
    // authorize & mint BUIDL to carol
    borrowableBuidl.authorize(carol, true);
    borrowableBuidl.mint(carol, 100_000e6);
    // authorize aBUIDL to hold BUIDL
    borrowableBuidl.authorize(aBorrowableBuidlAddress, true);
    vm.stopPrank();

    vm.prank(bob);
    borrowableBuidl.approve(report.poolProxy, UINT256_MAX);

    pool = PoolInstance(report.poolProxy);
  }

  function test_reverts_mintToTreasury() public {
    (, , address varDebtBorrowableBuidl) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.borrowableBuidl
    );

    _seedBorrowableBuidlLiquidity();

    vm.startPrank(bob);
    pool.supply(tokenList.wbtc, 0.4e8, bob, 0);
    pool.borrow(tokenList.borrowableBuidl, 2000e6, 2, 0, bob);
    vm.warp(block.timestamp + 30 days);
    pool.repay(tokenList.borrowableBuidl, IERC20(varDebtBorrowableBuidl).balanceOf(bob), 2, bob);
    vm.stopPrank();

    // distribute fees to treasury
    address[] memory assets = new address[](1);
    assets[0] = tokenList.borrowableBuidl;

    vm.expectRevert(bytes(Errors.OPERATION_NOT_SUPPORTED));
    pool.mintToTreasury(assets);
  }

  function _seedBorrowableBuidlLiquidity() internal {
    vm.startPrank(carol);
    borrowableBuidl.approve(report.poolProxy, UINT256_MAX);
    pool.supply(tokenList.borrowableBuidl, 50_000e6, carol, 0);
    vm.stopPrank();
  }
}
