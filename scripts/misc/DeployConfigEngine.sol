// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveV3ConfigEngine, IAaveV3ConfigEngine, CapsEngine, BorrowEngine, CollateralEngine, RateEngine, PriceFeedEngine, EModeEngine, ListingEngine} from '../../src/contracts/extensions/v3-config-engine/AaveV3ConfigEngine.sol';
import {Create2Utils} from '../../src/deployments/contracts/utilities/Create2Utils.sol';
import {IAaveOracle} from '../../src/contracts/interfaces/IAaveOracle.sol';
import {IPool} from '../../src/contracts/interfaces/IPool.sol';
import {IPoolConfigurator} from '../../src/contracts/interfaces/IPoolConfigurator.sol';
import {AaveV3EthereumHorizonCustom} from '../../tests/horizon/utils/AaveV3EthereumHorizonCustom.sol';
import {Script} from 'forge-std/Script.sol';

/// @dev Reuses the sub-engines already deployed through `Create2Utils` and reverts if any is missing.
contract DeployConfigEngine is Script {
  bytes32 internal constant ENGINE_SALT = 'v1';

  function run() public returns (address) {
    IAaveV3ConfigEngine.EngineLibraries memory engineLibraries = IAaveV3ConfigEngine
      .EngineLibraries({
        listingEngine: _getDeployedEngine(type(ListingEngine).creationCode),
        eModeEngine: _getDeployedEngine(type(EModeEngine).creationCode),
        borrowEngine: _getDeployedEngine(type(BorrowEngine).creationCode),
        collateralEngine: _getDeployedEngine(type(CollateralEngine).creationCode),
        priceFeedEngine: _getDeployedEngine(type(PriceFeedEngine).creationCode),
        rateEngine: _getDeployedEngine(type(RateEngine).creationCode),
        capsEngine: _getDeployedEngine(type(CapsEngine).creationCode)
      });

    IAaveV3ConfigEngine.EngineConstants memory engineConstants = IAaveV3ConfigEngine
      .EngineConstants({
        pool: IPool(AaveV3EthereumHorizonCustom.POOL),
        poolConfigurator: IPoolConfigurator(AaveV3EthereumHorizonCustom.POOL_CONFIGURATOR),
        defaultInterestRateStrategy: AaveV3EthereumHorizonCustom.DEFAULT_INTEREST_RATE_STRATEGY,
        oracle: IAaveOracle(AaveV3EthereumHorizonCustom.AAVE_ORACLE),
        rewardsController: AaveV3EthereumHorizonCustom.REWARDS_CONTROLLER,
        collector: AaveV3EthereumHorizonCustom.COLLECTOR
      });

    vm.startBroadcast();
    AaveV3ConfigEngine configEngine = new AaveV3ConfigEngine({
      aTokenImpl: AaveV3EthereumHorizonCustom.ATOKEN_IMPL_REV_3,
      vTokenImpl: AaveV3EthereumHorizonCustom.VARIABLE_DEBT_TOKEN_IMPL,
      engineConstants: engineConstants,
      engineLibraries: engineLibraries
    });
    vm.stopBroadcast();

    return address(configEngine);
  }

  function _getDeployedEngine(bytes memory creationCode) internal view returns (address) {
    address engine = Create2Utils.computeCreate2Address(ENGINE_SALT, creationCode);
    require(Create2Utils.isContractDeployed(engine), 'ENGINE_NOT_DEPLOYED');
    return engine;
  }
}
