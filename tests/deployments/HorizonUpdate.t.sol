// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import './HorizonPhaseOneListing.t.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {IPoolDataProvider} from '../../src/contracts/interfaces/IPoolDataProvider.sol';
import {AaveV3EthereumHorizonCustom} from '../horizon/utils/AaveV3EthereumHorizonCustom.sol';

/// forge-config: default.evm_version = "cancun"
contract HorizonUpdateBaseTest is HorizonListingBaseTest {
  function loadDeployment() internal virtual override returns (DeploymentInfo memory) {
    return
      DeploymentInfo({
        pool: AaveV3EthereumHorizonCustom.POOL,
        revenueSplitter: AaveV3EthereumHorizonCustom.REVENUE_SPLITTER,
        defaultInterestRateStrategy: AaveV3EthereumHorizonCustom.DEFAULT_INTEREST_RATE_STRATEGY,
        rwaATokenManager: AaveV3EthereumHorizonCustom.RWA_ATOKEN_MANAGER,
        aTokenImpl: AaveV3EthereumHorizonCustom.ATOKEN_IMPL,
        rwaATokenImpl: AaveV3EthereumHorizonCustom.RWA_ATOKEN_IMPL,
        variableDebtTokenImpl: AaveV3EthereumHorizonCustom.VARIABLE_DEBT_TOKEN_IMPL,
        poolAdmin: AaveV3EthereumHorizonCustom.HORIZON_EMERGENCY
      });
  }

  function OPERATIONAL_MULTISIG_ADDRESS() external view override returns (address) {
    return AaveV3EthereumHorizonCustom.HORIZON_OPS;
  }
  function EMERGENCY_MULTISIG_ADDRESS() external view override returns (address) {
    return AaveV3EthereumHorizonCustom.HORIZON_EMERGENCY;
  }
  function AAVE_DAO_EXECUTOR_ADDRESS() external view override returns (address) {
    return address(0);
  }
  function LISTING_EXECUTOR_ADDRESS() external view override returns (address) {
    return AaveV3EthereumHorizonCustom.HORIZON_EXECUTOR;
  }
  function DUST_BIN() external view override returns (address) {
    return address(0);
  }
}

/// forge-config: default.evm_version = "cancun"
contract HorizonUpdateTest is HorizonUpdateBaseTest {
  mapping(address asset => uint8 eModeId) public eModeIds;
  mapping(address asset => EModeCategoryParams params) public assetToEModeParams;
  mapping(address asset => ReserveParams params) public assetToReserveParams;

  struct ReserveParams {
    uint256 ltv;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
  }
  function setUp() public {
    vm.createSelectFork('mainnet');

    initEnvironment();
    _loadParams();
  }

  function _loadParams() internal {
    eModeIds[AaveV3EthereumHorizonCustom.VBILL_UNDERLYING] = 1;
    eModeIds[AaveV3EthereumHorizonCustom.USTB_UNDERLYING] = 2;
    eModeIds[AaveV3EthereumHorizonCustom.USCC_UNDERLYING] = 4;
    eModeIds[AaveV3EthereumHorizonCustom.USYC_UNDERLYING] = 6;
    eModeIds[AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING] = 8;
    eModeIds[AaveV3EthereumHorizonCustom.JAAA_UNDERLYING] = 10;

    assetToEModeParams[AaveV3EthereumHorizonCustom.VBILL_UNDERLYING] = EModeCategoryParams({
      ltv: 90_00,
      liquidationThreshold: 92_00,
      liquidationBonus: 100_00 + 3_00,
      label: 'VBILL GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.GHO_UNDERLYING)
    });
    assetToEModeParams[AaveV3EthereumHorizonCustom.USTB_UNDERLYING] = EModeCategoryParams({
      ltv: 90_00,
      liquidationThreshold: 92_00,
      liquidationBonus: 100_00 + 3_00,
      label: 'USTB GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.USTB_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.GHO_UNDERLYING)
    });
    assetToEModeParams[AaveV3EthereumHorizonCustom.USCC_UNDERLYING] = EModeCategoryParams({
      ltv: 87_00,
      liquidationThreshold: 90_00,
      liquidationBonus: 100_00 + 5_00,
      label: 'USCC GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.USCC_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.GHO_UNDERLYING)
    });
    assetToEModeParams[AaveV3EthereumHorizonCustom.USYC_UNDERLYING] = EModeCategoryParams({
      ltv: 90_00,
      liquidationThreshold: 92_00,
      liquidationBonus: 100_00 + 3_10,
      label: 'USYC GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.USYC_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.GHO_UNDERLYING)
    });

    assetToEModeParams[AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING] = EModeCategoryParams({
      ltv: 89_00,
      liquidationThreshold: 91_00,
      liquidationBonus: 100_00 + 3_50,
      label: 'JTRSY GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.GHO_UNDERLYING)
    });
    assetToEModeParams[AaveV3EthereumHorizonCustom.JAAA_UNDERLYING] = EModeCategoryParams({
      ltv: 88_00,
      liquidationThreshold: 90_00,
      liquidationBonus: 100_00 + 5_00,
      label: 'JAAA GHO',
      collateralAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.JAAA_UNDERLYING),
      borrowableAssets: _toDynamicAddressArray(AaveV3EthereumHorizonCustom.GHO_UNDERLYING)
    });

    assetToReserveParams[AaveV3EthereumHorizonCustom.USCC_UNDERLYING] = ReserveParams({
      ltv: 85_00,
      liquidationThreshold: 88_00,
      liquidationBonus: 100_00 + 5_00
    });
    assetToReserveParams[AaveV3EthereumHorizonCustom.JAAA_UNDERLYING] = ReserveParams({
      ltv: 81_00,
      liquidationThreshold: 86_00,
      liquidationBonus: 100_00 + 5_00
    });
    assetToReserveParams[AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING] = ReserveParams({
      ltv: 86_00,
      liquidationThreshold: 88_00,
      liquidationBonus: 100_00 + 3_50
    });
    assetToReserveParams[AaveV3EthereumHorizonCustom.USTB_UNDERLYING] = ReserveParams({
      ltv: 88_00,
      liquidationThreshold: 90_00,
      liquidationBonus: 100_00 + 3_00
    });
    assetToReserveParams[AaveV3EthereumHorizonCustom.USYC_UNDERLYING] = ReserveParams({
      ltv: 88_00,
      liquidationThreshold: 90_00,
      liquidationBonus: 100_00 + 3_10
    });
    assetToReserveParams[AaveV3EthereumHorizonCustom.VBILL_UNDERLYING] = ReserveParams({
      ltv: 88_00,
      liquidationThreshold: 90_00,
      liquidationBonus: 100_00 + 3_00
    });
  }
  function test_USTB_update() public view {
    _testParamsUpdate(AaveV3EthereumHorizonCustom.USTB_UNDERLYING);
  }
  function test_USCC_update() public view {
    _testParamsUpdate(AaveV3EthereumHorizonCustom.USCC_UNDERLYING);
  }
  function test_USYC_update() public view {
    _testParamsUpdate(AaveV3EthereumHorizonCustom.USYC_UNDERLYING);
  }
  function test_JAAA_update() public view {
    _testParamsUpdate(AaveV3EthereumHorizonCustom.JAAA_UNDERLYING);
  }
  function test_JTRSY_update() public view {
    _testParamsUpdate(AaveV3EthereumHorizonCustom.JTRSY_UNDERLYING);
  }
  function test_VBILL_update() public view {
    _testParamsUpdate(AaveV3EthereumHorizonCustom.VBILL_UNDERLYING);
  }

  function _testParamsUpdate(address asset) internal view {
    test_eMode_configuration({eModeCategory: eModeIds[asset], params: assetToEModeParams[asset]});
    _testReserveParams({asset: asset, params: assetToReserveParams[asset]});
  }

  function _testReserveParams(address asset, ReserveParams memory params) internal view {
    (
      ,
      uint256 ltv,
      uint256 liquidationThreshold,
      uint256 liquidationBonus,
      ,
      ,
      ,
      ,
      ,

    ) = IPoolDataProvider(AaveV3EthereumHorizonCustom.AAVE_PROTOCOL_DATA_PROVIDER)
        .getReserveConfigurationData(asset);
    assertEq(ltv, params.ltv, 'ltv');
    assertEq(liquidationThreshold, params.liquidationThreshold, 'liquidationThreshold');
    assertEq(liquidationBonus, params.liquidationBonus, 'liquidationBonus');
  }
}
