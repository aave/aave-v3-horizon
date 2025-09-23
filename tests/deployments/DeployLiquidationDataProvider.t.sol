// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {DeployLiquidationDataProvider} from '../../scripts/misc/DeployLiquidationDataProvider.sol';
import {ILiquidationDataProvider} from '../../src/contracts/helpers/interfaces/ILiquidationDataProvider.sol';

contract DeployLiquidationDataProviderForkTest is Test {
  address public constant POOL = 0xAe05Cd22df81871bc7cC2a04BeCfb516bFe332C8;
  address public constant ADDRESSES_PROVIDER = 0x5D39E06b825C1F2B80bf2756a73e28eFAA128ba0;

  DeployLiquidationDataProvider internal deployLiquidationDataProvider;
  ILiquidationDataProvider internal liquidationDataProvider;

  function setUp() public virtual {
    vm.createSelectFork('mainnet', 23420687);

    deployLiquidationDataProvider = new DeployLiquidationDataProvider();
    liquidationDataProvider = ILiquidationDataProvider(
      deployLiquidationDataProvider.run(POOL, ADDRESSES_PROVIDER)
    );
  }

  function test_getUserPositionFullInfo() public view {
    address user = 0xFf09aAD651888ceFAd81271a79b4Ef7dEC245F49; // sample user with USDC debt
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    ILiquidationDataProvider.UserPositionFullInfo memory userInfo = liquidationDataProvider
      .getUserPositionFullInfo(user);

    assertGt(userInfo.healthFactor, 1e18); // healthy health factor

    ILiquidationDataProvider.DebtFullInfo memory debtInfo = liquidationDataProvider.getDebtFullInfo(
      user,
      USDC
    );

    assertGt(debtInfo.debtBalanceInBaseCurrency, 0);
  }

  function test_deployLiquidationDataProvider() public view {
    assertEq(address(liquidationDataProvider.POOL()), POOL);
    assertEq(address(liquidationDataProvider.ADDRESSES_PROVIDER()), ADDRESSES_PROVIDER);
  }
}
