// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';

import {AToken} from 'src/contracts/protocol/tokenization/AToken.sol';
import {VariableDebtToken} from 'src/contracts/protocol/tokenization/VariableDebtToken.sol';
import {Errors} from 'src/contracts/protocol/libraries/helpers/Errors.sol';
import {ConfiguratorInputTypes, IPool, IPoolAddressesProvider} from 'src/contracts/protocol/pool/PoolConfigurator.sol';
import {MockVariableDebtToken} from 'src/contracts/mocks/tokens/MockDebtTokens.sol';
import {DataTypes} from 'src/contracts/protocol/libraries/types/DataTypes.sol';
import {ReserveLogic} from 'src/contracts/protocol/libraries/logic/ReserveLogic.sol';
import {IPoolConfigurator} from 'src/contracts/interfaces/IPoolConfigurator.sol';

import {SlotParser} from 'tests/utils/SlotParser.sol';
import {TestnetProcedures, MockRwaATokenInstance} from 'tests/utils/TestnetProcedures.sol';

contract PoolConfiguratorUpgradeabilityRwaTests is TestnetProcedures {
  using stdStorage for StdStorage;

  using ReserveLogic for DataTypes.ReserveCache;
  using ReserveLogic for DataTypes.ReserveData;

  DataTypes.ReserveData internal reserveData;
  DataTypes.ReserveData internal updatedReserveData;

  function setUp() public {
    initTestEnvironment();
  }

  function test_setReserveInterestRateStrategyAddress() public {
    address currentInterestRateStrategy = contracts
      .protocolDataProvider
      .getInterestRateStrategyAddress(tokenList.buidl);
    address updatedInterestsRateStrategy = _deployInterestRateStrategy();

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.ReserveInterestRateStrategyChanged(
      tokenList.buidl,
      currentInterestRateStrategy,
      updatedInterestsRateStrategy
    );

    // Perform change
    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveInterestRateStrategyAddress(
      tokenList.buidl,
      updatedInterestsRateStrategy,
      _getDefaultInterestRatesStrategyData()
    );

    address newInterestRateStrategy = contracts.protocolDataProvider.getInterestRateStrategyAddress(
      tokenList.buidl
    );

    assertEq(newInterestRateStrategy, updatedInterestsRateStrategy);
  }

  function test_setReserveInterestRateData() public {
    address currentInterestRateStrategy = contracts
      .protocolDataProvider
      .getInterestRateStrategyAddress(tokenList.buidl);

    bytes memory newInterestRateData = _getDefaultInterestRatesStrategyData();

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.ReserveInterestRateDataChanged(
      tokenList.buidl,
      currentInterestRateStrategy,
      newInterestRateData
    );

    vm.prank(poolAdmin);
    contracts.poolConfiguratorProxy.setReserveInterestRateData(
      tokenList.buidl,
      _getDefaultInterestRatesStrategyData()
    );

    address newInterestRateStrategy = contracts.protocolDataProvider.getInterestRateStrategyAddress(
      tokenList.buidl
    );
    assertEq(currentInterestRateStrategy, newInterestRateStrategy);
  }

  function test_updateAToken() public {
    ConfiguratorInputTypes.UpdateATokenInput memory input = ConfiguratorInputTypes
      .UpdateATokenInput({
        asset: tokenList.buidl,
        treasury: report.treasury,
        incentivesController: report.rewardsControllerProxy,
        name: 'new aBuidl',
        symbol: 'new aBuidl',
        implementation: address(new MockRwaATokenInstance(IPool(report.poolProxy))),
        params: abi.encode()
      });
    (address aTokenProxy, , ) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );

    address previousImplementation = SlotParser.loadAddressFromSlot(
      aTokenProxy,
      bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    );

    // Perform upgrade
    vm.startPrank(poolAdmin);

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.ATokenUpgraded(tokenList.buidl, aTokenProxy, input.implementation);

    contracts.poolConfiguratorProxy.updateAToken(input);
    vm.stopPrank();

    address upgradedImplementation = SlotParser.loadAddressFromSlot(
      aTokenProxy,
      bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    );

    assertTrue(upgradedImplementation != previousImplementation);
    assertEq(upgradedImplementation, input.implementation);
    assertEq(AToken(aTokenProxy).name(), input.name);
    assertEq(AToken(aTokenProxy).symbol(), input.symbol);
    assertEq(address(AToken(aTokenProxy).getIncentivesController()), input.incentivesController);
    assertEq(AToken(aTokenProxy).RESERVE_TREASURY_ADDRESS(), input.treasury);
  }

  function test_updateVariableDebtToken() public {
    (, , address variableDebtProxy) = contracts.protocolDataProvider.getReserveTokensAddresses(
      tokenList.buidl
    );
    ConfiguratorInputTypes.UpdateDebtTokenInput memory input = ConfiguratorInputTypes
      .UpdateDebtTokenInput({
        asset: tokenList.buidl,
        incentivesController: report.rewardsControllerProxy,
        name: 'New Variable Debt Test USDX',
        symbol: 'newTestVarDebtUSDX',
        implementation: address(new MockVariableDebtToken(IPool(report.poolProxy))),
        params: bytes('')
      });

    address previousImplementation = SlotParser.loadAddressFromSlot(
      variableDebtProxy,
      bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    );

    // Perform upgrade
    vm.startPrank(poolAdmin);

    vm.expectEmit(address(contracts.poolConfiguratorProxy));
    emit IPoolConfigurator.VariableDebtTokenUpgraded(
      tokenList.buidl,
      variableDebtProxy,
      input.implementation
    );

    contracts.poolConfiguratorProxy.updateVariableDebtToken(input);
    vm.stopPrank();

    address upgradedImplementation = SlotParser.loadAddressFromSlot(
      variableDebtProxy,
      bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1)
    );

    assertTrue(upgradedImplementation != previousImplementation);
    assertEq(upgradedImplementation, input.implementation);
    assertEq(VariableDebtToken(variableDebtProxy).name(), input.name);
    assertEq(VariableDebtToken(variableDebtProxy).symbol(), input.symbol);
    assertEq(
      address(VariableDebtToken(variableDebtProxy).getIncentivesController()),
      input.incentivesController
    );
  }

  function _getFullReserveData(address asset) internal view returns (DataTypes.ReserveData memory) {
    DataTypes.ReserveDataLegacy memory reserveDataLegacy = contracts.poolProxy.getReserveData(
      asset
    );
    DataTypes.ReserveData memory tempReserveData;
    tempReserveData.configuration = reserveDataLegacy.configuration;
    tempReserveData.liquidityIndex = reserveDataLegacy.liquidityIndex;
    tempReserveData.currentLiquidityRate = reserveDataLegacy.currentLiquidityRate;
    tempReserveData.variableBorrowIndex = reserveDataLegacy.variableBorrowIndex;
    tempReserveData.currentVariableBorrowRate = reserveDataLegacy.currentVariableBorrowRate;
    tempReserveData.lastUpdateTimestamp = reserveDataLegacy.lastUpdateTimestamp;
    tempReserveData.id = reserveDataLegacy.id;
    tempReserveData.aTokenAddress = reserveDataLegacy.aTokenAddress;
    tempReserveData.variableDebtTokenAddress = reserveDataLegacy.variableDebtTokenAddress;
    tempReserveData.interestRateStrategyAddress = reserveDataLegacy.interestRateStrategyAddress;
    tempReserveData.accruedToTreasury = reserveDataLegacy.accruedToTreasury;
    tempReserveData.unbacked = reserveDataLegacy.unbacked;
    tempReserveData.isolationModeTotalDebt = reserveDataLegacy.isolationModeTotalDebt;
    tempReserveData.virtualUnderlyingBalance = uint128(
      contracts.poolProxy.getVirtualUnderlyingBalance(asset)
    );
    tempReserveData.deficit = uint128(contracts.poolProxy.getReserveDeficit(asset));
    return tempReserveData;
  }
}
